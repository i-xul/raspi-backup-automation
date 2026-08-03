#!/bin/bash
set -Eeuo pipefail

###############################################################################
#
# Windows 11 EaseUS Offsite Backup
#
# Synchronizes a stable EaseUS backup set from local NAS storage to encrypted
# pCloud storage, verifies uploaded data using rclone cryptcheck, and sends
# success or failure notifications.
#
# Purpose:
#     Replicate the Windows 11 EaseUS backup set from NAS storage to encrypted
#     offsite storage.
#
# Requirements:
#     - rclone
#     - rclone crypt remote
#     - flock
#     - timeout
#     - find
#
# Workflow:
#
#   Windows 11
#        │
#        ▼
#   EaseUS backup
#        │
#        ▼
#   NAS on Raspberry Pi 4
#        │
#        ▼
#   Encrypted pCloud
#        │
#        ▼
#     cryptcheck
#        │
#        ▼
#   Email notification
#
###############################################################################

###############################################################################
# Configuration
###############################################################################

LOCAL_BASE="/path/to/nas/easeus_w11_backups/<COMPUTER_NAME>/Disks backup"
REMOTE_BASE="pcloud-crypt:windows-11/easeus"

RCLONE_TIMEOUT="24h"
MINIMUM_FILE_AGE_MINUTES=60
REMOTE_CHECK_TIMEOUT="5m"

# Keep enabled until the script has been validated on the backup coordinator.
# In dry-run mode, rclone reports planned changes without modifying pCloud.
DRY_RUN=true

LOCK_FILE="/tmp/windows11-offsite-backup.lock"
LOG_FILE="/path/to/nas/easeus_w11_backups/windows11-offsite-backup.log"

MAIL_HELPER="/usr/local/bin/send-backup-mail.py"
RCLONE_CONFIG="/path/to/rclone/rclone.conf"

START_TIME="$(date '+%Y-%m-%d %H:%M:%S')"
REPORT_FILE="$(mktemp)"
SOURCE_MANIFEST_BEFORE="$(mktemp)"
SOURCE_MANIFEST_AFTER="$(mktemp)"

PBD_COUNT=0

###############################################################################
# Runtime State
###############################################################################

cleanup() {
    rm -f "$REPORT_FILE"
    rm -f "$SOURCE_MANIFEST_BEFORE"
    rm -f "$SOURCE_MANIFEST_AFTER"
}

###############################################################################
# Notification Helpers
###############################################################################

send_mail() {
    local status="$1"
    local body_file="$2"

    if ! sudo BACKUP_NAME="Windows 11 EaseUS offsite" \
        "$MAIL_HELPER" "$status" < "$body_file"
    then
        logger -t windows11-offsite-backup \
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
        echo "Windows 11 EaseUS offsite backup FAILED"
        echo
        echo "Host: $(hostname)"
        echo "Source: $LOCAL_BASE"
        echo "Start time: $START_TIME"
        echo "End time: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Exit code: $exit_code"

        if [ "$PBD_COUNT" -gt 0 ]; then
            echo "EaseUS .pbd files detected: $PBD_COUNT"
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
        logger -t windows11-offsite-backup \
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
        logger -t windows11-offsite-backup \
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
    fail "Another Windows 11 EaseUS offsite backup is already running."
fi

: > "$LOG_FILE"

log "=== Windows 11 EaseUS offsite backup started ==="
log "Start time: $START_TIME"

###############################################################################
# EaseUS Backup Set Validation
###############################################################################

# Verify that the EaseUS backup directory exists.
if [ ! -d "$LOCAL_BASE" ]; then
    fail "EaseUS backup directory does not exist: $LOCAL_BASE"
fi


# Verify that at least one EaseUS .pbd backup file exists.
PBD_COUNT="$(
    find "$LOCAL_BASE" \
        -maxdepth 1 \
        -type f \
        -name '*.pbd' \
        -printf '.' |
    wc -c
)"

if [ "$PBD_COUNT" -eq 0 ]; then
    fail "No EaseUS .pbd backup files found in: $LOCAL_BASE"
fi

log "EaseUS backup directory: $LOCAL_BASE"
log "EaseUS .pbd files detected: $PBD_COUNT"


# Reject the backup set if any file was modified recently.
#
# This reduces the risk of starting an offsite sync while EaseUS is still
# creating, consolidating, or modifying the local backup chain.
if find "$LOCAL_BASE" \
    -type f \
    -mmin "-$MINIMUM_FILE_AGE_MINUTES" \
    -print -quit |
    grep -q .
then
    fail "EaseUS backup set contains files modified within the last $MINIMUM_FILE_AGE_MINUTES minutes."
fi

log "EaseUS backup age check passed."


# Record the source state before synchronization.
#
# The manifest contains relative paths, file sizes, and modification times.
# It is used to detect changes to the backup set while the cloud operation is
# running without calculating hashes for very large EaseUS backup files.
if ! find "$LOCAL_BASE" \
    -type f \
    -printf '%P|%s|%T@\n' \
    | sort \
    > "$SOURCE_MANIFEST_BEFORE"
then
    fail "Could not create the initial EaseUS source manifest."
fi

log "Initial EaseUS source manifest created."


RCLONE_SYNC_ARGS=(
    --log-level INFO
)

if [ "$DRY_RUN" = true ]; then
    RCLONE_SYNC_ARGS+=(--dry-run)
    log "DRY RUN enabled: pCloud content will not be modified."
fi

###############################################################################
# Offsite Synchronization
###############################################################################

# Verify access to the encrypted cloud remote before synchronizing.
#
# Check the encrypted remote itself instead of the destination directory,
# because the Windows backup destination may not exist before the first run.
log "Checking encrypted pCloud connection..."

if ! timeout "$REMOTE_CHECK_TIMEOUT" \
    rclone --config "$RCLONE_CONFIG" lsd "pcloud-crypt:" \
    >> "$REPORT_FILE" 2>&1
then
    fail "Cannot access encrypted pCloud remote or connection timed out."
fi

log "pCloud connection OK."


# Synchronize the complete EaseUS backup set.
#
# rclone sync updates the destination to match the source. Files removed by
# EaseUS from the local backup set may therefore also be removed from the
# encrypted cloud mirror.
log "Starting encrypted EaseUS backup synchronization..."

if ! timeout "$RCLONE_TIMEOUT" \
    rclone --config "$RCLONE_CONFIG" \
    --stats=5m \
    --stats-one-line \
    sync \
    "$LOCAL_BASE" \
    "$REMOTE_BASE" \
    "${RCLONE_SYNC_ARGS[@]}" \
    >> "$REPORT_FILE" 2>&1
then
    fail "Encrypted pCloud synchronization failed or timed out."
fi

if [ "$DRY_RUN" = true ]; then
    log "pCloud synchronization dry run completed."
else
    log "pCloud synchronization completed."
fi

###############################################################################
# Integrity Verification
###############################################################################

if [ "$DRY_RUN" = true ]; then
    log "Skipping cryptcheck because dry-run mode did not modify pCloud."
else
    # Validate the encrypted cloud mirror against the local EaseUS backup set.
    log "Validating encrypted cloud backup..."

    if ! timeout "$RCLONE_TIMEOUT" \
        rclone --config "$RCLONE_CONFIG" cryptcheck \
        "$LOCAL_BASE" \
        "$REMOTE_BASE" \
        >> "$REPORT_FILE" 2>&1
    then
        fail "cryptcheck validation failed or timed out."
    fi

    log "Cloud validation successful."
fi


# Record the source state after synchronization and optional cloud validation.
if ! find "$LOCAL_BASE" \
    -type f \
    -printf '%P|%s|%T@\n' \
    | sort \
    > "$SOURCE_MANIFEST_AFTER"
then
    fail "Could not create the final EaseUS source manifest."
fi


# Ensure that the EaseUS backup set remained unchanged for the entire run.
if ! cmp -s "$SOURCE_MANIFEST_BEFORE" "$SOURCE_MANIFEST_AFTER"; then
    fail "EaseUS backup set changed during the offsite backup process."
fi

log "EaseUS backup set remained unchanged during the entire run."

###############################################################################
# Completion
###############################################################################

END_TIME="$(date '+%Y-%m-%d %H:%M:%S')"

if [ "$DRY_RUN" = true ]; then
    RESULT_DESCRIPTION="dry run completed successfully"
    VALIDATION_DESCRIPTION="cryptcheck skipped in dry-run mode"
else
    RESULT_DESCRIPTION="completed successfully"
    VALIDATION_DESCRIPTION="cryptcheck completed successfully"
fi

log "Windows 11 EaseUS offsite backup $RESULT_DESCRIPTION."
log "End time: $END_TIME"
log "=== Windows 11 EaseUS offsite backup finished ==="


{
    echo "Windows 11 EaseUS offsite backup $RESULT_DESCRIPTION."
    echo
    echo "Host: $(hostname)"
    echo "Source: $LOCAL_BASE"
    echo "Destination: $REMOTE_BASE"
    echo "EaseUS .pbd files: $PBD_COUNT"
    echo "Dry run: $DRY_RUN"
    echo "Start time: $START_TIME"
    echo "End time: $END_TIME"
    echo
    echo "Synchronization: $RESULT_DESCRIPTION"
    echo "Validation: $VALIDATION_DESCRIPTION"
} > "${REPORT_FILE}.mail"

send_mail OK "${REPORT_FILE}.mail"

rm -f "${REPORT_FILE}.mail"
