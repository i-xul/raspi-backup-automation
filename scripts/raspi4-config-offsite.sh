#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

REPO_CONFIG_DIR="${PROJECT_ROOT}/config/raspi4"
SYSTEM_CONFIG_DIR="/etc/raspi-backup-automation/raspi4"

OFFSITE_REPOSITORY="rclone:pcloud-crypt:raspberry-pi-4/config-backup/repository"
RCLONE_CONFIG_FILE="/home/hmasi/.config/rclone/rclone.conf"

die() {
    echo "ERROR: $*" >&2
    exit 1
}

require_variable() {
    local name="$1"
    [[ -n "${!name:-}" ]] ||
        die "Missing configuration variable: ${name}"
}

require_file() {
    local path="$1"
    [[ -f "${path}" && -r "${path}" ]] ||
        die "Required file missing or unreadable: ${path}"
}

[[ "${EUID}" -eq 0 ]] ||
    die "${SCRIPT_NAME} must be run as root."

if [[ -f "${SYSTEM_CONFIG_DIR}/backup.conf" ]]; then
    CONFIG_DIR="${SYSTEM_CONFIG_DIR}"
elif [[ -f "${REPO_CONFIG_DIR}/backup.conf" ]]; then
    CONFIG_DIR="${REPO_CONFIG_DIR}"
else
    die "Raspberry Pi 4 backup configuration not found."
fi

# shellcheck source=/dev/null
source "${CONFIG_DIR}/backup.conf"

for command_name in restic rclone findmnt blkid mountpoint tee realpath; do
    command -v "${command_name}" >/dev/null 2>&1 ||
        die "Required command not found: ${command_name}"
done

for variable in \
    RESTIC_REPOSITORY \
    RESTIC_PASSWORD_FILE \
    BACKUP_MOUNT \
    BACKUP_UUID \
    BACKUP_FSTYPE \
    LOG_DIR; do
    require_variable "${variable}"
done

require_file "${RESTIC_PASSWORD_FILE}"
require_file "${RCLONE_CONFIG_FILE}"

mountpoint -q "${BACKUP_MOUNT}" ||
    die "Backup mount is not active: ${BACKUP_MOUNT}"

MOUNT_SOURCE="$(findmnt -n -o SOURCE --mountpoint "${BACKUP_MOUNT}")"
MOUNT_FSTYPE="$(findmnt -n -o FSTYPE --mountpoint "${BACKUP_MOUNT}")"
MOUNT_UUID="$(blkid -s UUID -o value "${MOUNT_SOURCE}")"

[[ "${MOUNT_UUID}" == "${BACKUP_UUID}" ]] ||
    die "Backup filesystem UUID mismatch."

[[ "${MOUNT_FSTYPE}" == "${BACKUP_FSTYPE}" ]] ||
    die "Backup filesystem type mismatch."

MOUNT_REAL="$(realpath -e -- "${BACKUP_MOUNT}")"
REPO_REAL="$(realpath -e -- "${RESTIC_REPOSITORY}")" ||
    die "Local Restic repository directory does not exist."

[[ -d "${REPO_REAL}" ]] ||
    die "Local Restic repository is not a directory."

case "${REPO_REAL}" in
    "${MOUNT_REAL}"/*) ;;
    *) die "Local repository must be located under ${MOUNT_REAL}" ;;
esac

OFFSITE_LOG_FILE="${LOG_DIR}/raspi4-config-offsite.log"

mkdir -p -- "${LOG_DIR}"
chmod 700 -- "${LOG_DIR}"

[[ ! -L "${OFFSITE_LOG_FILE}" ]] ||
    die "Offsite log file must not be a symbolic link."

if [[ -e "${OFFSITE_LOG_FILE}" ]]; then
    [[ -f "${OFFSITE_LOG_FILE}" ]] ||
        die "Offsite log path is not a regular file."
else
    ( set -C; : > "${OFFSITE_LOG_FILE}" ) ||
        die "Unable to create offsite log safely."
fi

chmod 600 -- "${OFFSITE_LOG_FILE}"

export RCLONE_CONFIG="${RCLONE_CONFIG_FILE}"

exec > >(tee -a -- "${OFFSITE_LOG_FILE}") 2>&1

echo "============================================================"
echo "Raspberry Pi 4 Configuration Offsite Backup"
echo "============================================================"
echo "Started:           $(date --iso-8601=seconds)"
echo "Local repository:  ${REPO_REAL}"
echo "Offsite repository: ${OFFSITE_REPOSITORY}"
echo "NAS mount:         ${MOUNT_REAL}"
echo "NAS UUID:          ${MOUNT_UUID}"
echo "============================================================"

if restic \
    --repo "${OFFSITE_REPOSITORY}" \
    --password-file "${RESTIC_PASSWORD_FILE}" \
    copy \
    --from-repo "${REPO_REAL}" \
    --from-password-file "${RESTIC_PASSWORD_FILE}"; then

    echo "============================================================"
    echo "Offsite backup completed successfully."
    echo "Finished: $(date --iso-8601=seconds)"
    echo "============================================================"
else
    EXIT_CODE=$?

    echo "============================================================"
    echo "ERROR: Offsite backup failed with exit code ${EXIT_CODE}."
    echo "Finished: $(date --iso-8601=seconds)"
    echo "============================================================"

    exit "${EXIT_CODE}"
fi
