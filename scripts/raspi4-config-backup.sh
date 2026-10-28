#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

REPO_CONFIG_DIR="${PROJECT_ROOT}/config/raspi4"
SYSTEM_CONFIG_DIR="/etc/raspi-backup-automation/raspi4"

die() {
    echo "ERROR: $*" >&2
    exit 1
}

require_variable() {
    local name="$1"
    [[ -n "${!name:-}" ]] || die "Missing configuration variable: ${name}"
}

require_file() {
    local path="$1"
    [[ -f "${path}" && -r "${path}" ]] ||
        die "Required file missing or unreadable: ${path}"
}

[[ "${EUID}" -eq 0 ]] || die "${SCRIPT_NAME} must be run as root."

if [[ -f "${SYSTEM_CONFIG_DIR}/backup.conf" ]]; then
    CONFIG_DIR="${SYSTEM_CONFIG_DIR}"
elif [[ -f "${REPO_CONFIG_DIR}/backup.conf" ]]; then
    CONFIG_DIR="${REPO_CONFIG_DIR}"
else
    die "Raspberry Pi 4 backup configuration not found."
fi

CONFIG_FILE="${CONFIG_DIR}/backup.conf"
INCLUDE_FILE="${CONFIG_DIR}/include.txt"
EXCLUDE_FILE="${CONFIG_DIR}/excludes.txt"

# shellcheck source=/dev/null
source "${CONFIG_FILE}"

for command_name in restic findmnt blkid mountpoint tee realpath stat; do
    command -v "${command_name}" >/dev/null 2>&1 ||
        die "Required command not found: ${command_name}"
done

for variable in \
    RESTIC_REPOSITORY \
    RESTIC_PASSWORD_FILE \
    BACKUP_MOUNT \
    BACKUP_UUID \
    BACKUP_FSTYPE \
    LOG_DIR \
    LOG_FILE; do
    require_variable "${variable}"
done

require_file "${RESTIC_PASSWORD_FILE}"
require_file "${INCLUDE_FILE}"
require_file "${EXCLUDE_FILE}"

# Verify that the expected NAS filesystem is mounted.
mountpoint -q "${BACKUP_MOUNT}" ||
    die "Backup mount is not active: ${BACKUP_MOUNT}"

MOUNT_SOURCE="$(findmnt -n -o SOURCE --mountpoint "${BACKUP_MOUNT}")"
MOUNT_FSTYPE="$(findmnt -n -o FSTYPE --mountpoint "${BACKUP_MOUNT}")"
MOUNT_UUID="$(blkid -s UUID -o value "${MOUNT_SOURCE}")"

[[ "${MOUNT_UUID}" == "${BACKUP_UUID}" ]] ||
    die "Backup filesystem UUID mismatch."

[[ "${MOUNT_FSTYPE}" == "${BACKUP_FSTYPE}" ]] ||
    die "Backup filesystem type mismatch."

# Resolve symlinks and reject paths outside the mounted NAS.
MOUNT_REAL="$(realpath -e -- "${BACKUP_MOUNT}")"
REPO_REAL="$(realpath -e -- "${RESTIC_REPOSITORY}")" ||
    die "Restic repository directory does not exist."

[[ -d "${REPO_REAL}" ]] ||
    die "Restic repository is not a directory."

case "${REPO_REAL}" in
    "${MOUNT_REAL}"/*) ;;
    *) die "Restic repository must be located under ${MOUNT_REAL}" ;;
esac

# Restrict log location and reject symbolic links.
[[ "${LOG_FILE}" == "${LOG_DIR}/"* ]] ||
    die "Log file must be located under LOG_DIR."

mkdir -p -- "${LOG_DIR}"
chmod 700 -- "${LOG_DIR}"

[[ ! -L "${LOG_FILE}" ]] ||
    die "Log file must not be a symbolic link."

if [[ -e "${LOG_FILE}" ]]; then
    [[ -f "${LOG_FILE}" ]] ||
        die "Log path is not a regular file."
else
    ( set -C; : > "${LOG_FILE}" ) ||
        die "Unable to create log file safely."
fi

chmod 600 -- "${LOG_FILE}"

exec > >(tee -a -- "${LOG_FILE}") 2>&1

echo "============================================================"
echo "Raspberry Pi 4 Configuration Backup"
echo "============================================================"
echo "Started:     $(date --iso-8601=seconds)"
echo "Repository:  ${REPO_REAL}"
echo "Mount:       ${MOUNT_REAL}"
echo "UUID:        ${MOUNT_UUID}"
echo "Include:     ${INCLUDE_FILE}"
echo "Exclude:     ${EXCLUDE_FILE}"
echo "============================================================"

if restic \
    --repo "${REPO_REAL}" \
    --password-file "${RESTIC_PASSWORD_FILE}" \
    backup \
    --files-from "${INCLUDE_FILE}" \
    --exclude-file "${EXCLUDE_FILE}"; then

    echo "============================================================"
    echo "Backup completed successfully."
    echo "Finished: $(date --iso-8601=seconds)"
    echo "============================================================"
else
    EXIT_CODE=$?

    echo "============================================================"
    echo "ERROR: Backup failed with exit code ${EXIT_CODE}."
    echo "Finished: $(date --iso-8601=seconds)"
    echo "============================================================"

    exit "${EXIT_CODE}"
fi
