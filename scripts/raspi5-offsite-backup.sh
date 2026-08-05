#!/usr/bin/env bash
set -Eeuo pipefail

###############################################################################
#
# Raspberry Pi 5 Offsite Backup
#
# Copies the latest validated NAS snapshot to encrypted pCloud storage,
# verifies uploaded data using rclone cryptcheck, applies snapshot retention,
# and sends success or failure notifications.
#
# Purpose:
#     Replicate the latest validated NAS snapshot to encrypted offsite storage.
#
# Requirements:
#     - rclone
#     - rclone crypt remote
#     - flock
#     - timeout
#
# Workflow:
#
#   Raspberry Pi 5
#          │
#          ▼
#     Local NAS snapshot
#          │
#          ▼
#    Encrypted pCloud
#          │
#          ▼
#      cryptcheck
#          │
#          ▼
#      Retention
#          │
#          ▼
#   Email notification
#
###############################################################################

###############################################################################
# Configuration
###############################################################################

LOCAL_BASE="/path/to/nas/raspi5-backup"
LOCAL_LATEST="$LOCAL_BASE/latest"

REMOTE_BASE="pcloud-crypt:raspberry-pi-5/snapshots"

KEEP=3
MAX_SNAPSHOT_AGE_DAYS=3
RCLONE_TIMEOUT="6h"

LOCK_FILE="/tmp/raspi5-offsite-backup.lock"
LOG_FILE="$LOCAL_BASE/offsite-backup.log"

MAIL_HELPER="/usr/local/bin/send-backup-mail.py"

START_TIME="$(date '+%Y-%m-%d %H:%M:%S')"
REPORT_FILE="$(mktemp)"

SNAPSHOT=""

###############################################################################
# Runtime State
###############################################################################

cleanup() {
    rm -f "$REPORT_FILE"
}

###############################################################################
# Notification Helpers
###############################################################################

send_mail() {
    local status="$1"
    local body_file="$2"

    # Input redirection is intentionally handled by the calling shell.
    # shellcheck disable=SC2024
    if ! sudo "$MAIL_HELPER" "$status" < "$body_file"; then
        logger -t raspi5-offsite-backup \
            "Could not send $status email notification. See $LOG_FILE"

        echo "WARNING: Could not send $status email notification." \
            >> "$LOG_FILE"
    fi
}


send_failed_report() {
    local exit_code="${1:-1}"

    # Prevent recursive ERR trap calls inside this handler.
    trap - ERR

    {
        echo "Raspberry Pi 5 offsite backup FAILED"
        echo
        echo "Host: $(hostname)"
        echo "Start time: $START_TIME"
        echo "End time: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Exit code: $exit_code"

        if [ -n "$SNAPSHOT" ]; then
            echo "Snapshot: $SNAPSHOT"
        fi

        echo
        echo "Last log output:"

        if [ -f "$REPORT_FILE" ]; then
            tail -n 40 "$REPORT_FILE"
        fi
    } > "${REPORT_FILE}.mail"

    cat "${REPORT_FILE}.mail" >> "$LOG_FILE"

    send_mail FAILED "${REPORT_FILE}.mail"

    rm -f "${REPORT_FILE}.mail"

    cleanup

    exit "$exit_code"
}

###############################################################################
# Failure Handling
###############################################################################

fail() {
    local message="$1"

    echo "ERROR: $message" >> "$REPORT_FILE"

    if ! echo "ERROR: $message" >> "$LOG_FILE" 2>/dev/null; then
        logger -t raspi5-offsite-backup \
            "Could not write failure to local backup log: $LOG_FILE"
    fi

    echo "ERROR: $message"

    send_failed_report 1
}


trap 'send_failed_report $?' ERR
trap cleanup EXIT

###############################################################################
# Logging
###############################################################################

log() {
    local message="$1"

    echo "$message" >> "$REPORT_FILE"

    if ! echo "$message" >> "$LOG_FILE" 2>/dev/null; then
        logger -t raspi5-offsite-backup \
            "Could not write to local backup log: $LOG_FILE"
    fi

    echo "$message"
}

###############################################################################
# Main Workflow
###############################################################################

# Prevent overlapping backup runs.
exec 9>"$LOCK_FILE"

if ! flock -n 9; then
    fail "Another Raspberry Pi 5 offsite backup is already running."
fi


log "=== Raspberry Pi 5 offsite backup started ==="
log "Start time: $START_TIME"

###############################################################################
# Snapshot Validation
###############################################################################

# Verify that the latest symlink exists.
if [ ! -L "$LOCAL_LATEST" ]; then
    fail "latest symlink does not exist: $LOCAL_LATEST"
fi


LATEST_PATH="$(readlink -f "$LOCAL_LATEST")"


# Verify that the resolved snapshot directory exists.
if [ ! -d "$LATEST_PATH" ]; then
    fail "latest points to a missing directory: $LATEST_PATH"
fi


SNAPSHOT="$(basename "$LATEST_PATH")"
REMOTE_DEST="$REMOTE_BASE/$SNAPSHOT"

log "Latest local snapshot: $SNAPSHOT"
log "Source: $LATEST_PATH"
log "Destination: $REMOTE_DEST"


# Validate the snapshot naming convention.
if [[ ! "$SNAPSHOT" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}$ ]]; then
    fail "Unexpected snapshot name: $SNAPSHOT"
fi


# Reject stale snapshots.
SNAPSHOT_DATE="${SNAPSHOT%%_*}"

if ! SNAPSHOT_EPOCH="$(date -d "$SNAPSHOT_DATE" +%s)"; then
    fail "Could not parse snapshot date: $SNAPSHOT_DATE"
fi

CURRENT_EPOCH="$(date +%s)"
MAX_AGE_SECONDS=$((MAX_SNAPSHOT_AGE_DAYS * 86400))

if (( CURRENT_EPOCH - SNAPSHOT_EPOCH > MAX_AGE_SECONDS )); then
    fail "Latest NAS snapshot is too old: $SNAPSHOT"
fi

log "Snapshot freshness check passed."

###############################################################################
# Offsite Upload
###############################################################################

# Verify access to the encrypted cloud remote before uploading.
log "Checking encrypted pCloud connection..."

if ! timeout 5m rclone lsd "$REMOTE_BASE" >> "$REPORT_FILE" 2>&1; then
    fail "Cannot access encrypted pCloud backup location or connection timed out."
fi

log "pCloud connection OK."


# Upload the snapshot.
log "Starting encrypted pCloud upload..."

if ! timeout "$RCLONE_TIMEOUT" rclone copy \
    "$LATEST_PATH" \
    "$REMOTE_DEST" \
    --links \
    --log-level INFO \
    >> "$REPORT_FILE" 2>&1
then
    fail "Encrypted pCloud upload failed."
fi

log "pCloud upload completed."

###############################################################################
# Integrity Verification
###############################################################################

# Validate the uploaded encrypted backup.
log "Validating encrypted cloud backup..."

if ! timeout "$RCLONE_TIMEOUT" rclone cryptcheck \
    "$LATEST_PATH" \
    "$REMOTE_DEST" \
    --links \
    >> "$REPORT_FILE" 2>&1
then
    fail "cryptcheck validation failed or timed out."
fi

log "Cloud validation successful."

###############################################################################
# Retention
###############################################################################

# Obtain the cloud snapshot list safely before retention processing.
log "Checking cloud retention..."

SNAPSHOT_LIST="$(mktemp)"


if ! timeout 5m rclone lsf "$REMOTE_BASE" \
    --dirs-only \
    > "$SNAPSHOT_LIST" 2>> "$REPORT_FILE"
then
    rm -f "$SNAPSHOT_LIST"
    fail "Failed to retrieve cloud snapshot list or operation timed out."
fi

mapfile -t CLOUD_SNAPSHOTS < <(
    sed 's:/$::' "$SNAPSHOT_LIST" | sort -r
)

rm -f "$SNAPSHOT_LIST"

log "Cloud snapshots found: ${#CLOUD_SNAPSHOTS[@]}"


# Remove old cloud snapshots only after successful upload and validation.
if [ "${#CLOUD_SNAPSHOTS[@]}" -gt "$KEEP" ]; then
    log "Removing old cloud snapshots..."

    for old_snapshot in "${CLOUD_SNAPSHOTS[@]:$KEEP}"; do
        log "Removing: $old_snapshot"

if ! timeout "$RCLONE_TIMEOUT" rclone purge \
    "$REMOTE_BASE/$old_snapshot" \
    >> "$REPORT_FILE" 2>&1
then
    fail "Failed or timed out while removing old cloud snapshot: $old_snapshot"
fi

    done
else
    log "No cloud snapshots need removal."
fi

###############################################################################
# Completion
###############################################################################

END_TIME="$(date '+%Y-%m-%d %H:%M:%S')"

log "Offsite backup completed successfully: $SNAPSHOT"
log "End time: $END_TIME"
log "=== Raspberry Pi 5 offsite backup finished ==="


{
    echo "Raspberry Pi 5 offsite backup completed successfully."
    echo
    echo "Host: $(hostname)"
    echo "Snapshot: $SNAPSHOT"
    echo "Start time: $START_TIME"
    echo "End time: $END_TIME"
    echo "Cloud retention: keeping latest $KEEP snapshots"
    echo
    echo "Validation: cryptcheck completed successfully"
} > "${REPORT_FILE}.mail"

send_mail OK "${REPORT_FILE}.mail"

rm -f "${REPORT_FILE}.mail"
