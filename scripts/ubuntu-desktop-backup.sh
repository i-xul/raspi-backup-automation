#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

REPO_CONFIG_DIR="${PROJECT_ROOT}/config/ubuntu"
SYSTEM_CONFIG_DIR="/etc/raspi-backup-automation/ubuntu"

if [[ -f "${SYSTEM_CONFIG_DIR}/backup.conf" ]]; then
    CONFIG_DIR="${SYSTEM_CONFIG_DIR}"
elif [[ -f "${REPO_CONFIG_DIR}/backup.conf" ]]; then
    CONFIG_DIR="${REPO_CONFIG_DIR}"
else
    echo "ERROR: Ubuntu backup configuration was not found." >&2
    echo "Checked:" >&2
    echo "  ${SYSTEM_CONFIG_DIR}/backup.conf" >&2
    echo "  ${REPO_CONFIG_DIR}/backup.conf" >&2
    exit 1
fi

CONFIG_FILE="${CONFIG_DIR}/backup.conf"
INCLUDE_FILE="${CONFIG_DIR}/include.txt"
EXCLUDE_FILE="${CONFIG_DIR}/excludes.txt"

# shellcheck source=/dev/null
source "${CONFIG_FILE}"

require_file() {
    local file_path="$1"

    if [[ ! -r "${file_path}" ]]; then
        echo "ERROR: Required file is missing or unreadable: ${file_path}" >&2
        exit 1
    fi
}

if [[ "${EUID}" -ne 0 ]]; then
    echo "ERROR: ${SCRIPT_NAME} must be run as root." >&2
    echo "Run it with: sudo ${0}" >&2
    exit 1
fi

command -v restic >/dev/null 2>&1 || {
    echo "ERROR: restic is not installed or is not available in PATH." >&2
    exit 1
}

command -v mountpoint >/dev/null 2>&1 || {
    echo "ERROR: mountpoint is not installed or is not available in PATH." >&2
    exit 1
}

require_file "${RESTIC_PASSWORD_FILE}"
require_file "${INCLUDE_FILE}"
require_file "${EXCLUDE_FILE}"

if ! mountpoint -q "${BACKUP_MOUNT}"; then
    echo "ERROR: Backup destination is not mounted: ${BACKUP_MOUNT}" >&2
    exit 1
fi

if [[ ! -d "${RESTIC_REPOSITORY}" ]]; then
    echo "ERROR: Restic repository directory does not exist: ${RESTIC_REPOSITORY}" >&2
    exit 1
fi

mkdir -p "${LOG_DIR}"
: > "${LOG_FILE}"

exec > >(tee -a "${LOG_FILE}") 2>&1

START_TIME="$(date --iso-8601=seconds)"

echo "============================================================"
echo "Ubuntu Desktop Restic Backup"
echo "============================================================"
echo "Started:          ${START_TIME}"
echo "Repository:       ${RESTIC_REPOSITORY}"
echo "Include file:     ${INCLUDE_FILE}"
echo "Exclude file:     ${EXCLUDE_FILE}"
echo "Log file:         ${LOG_FILE}"
echo "============================================================"

if restic \
    --repo "${RESTIC_REPOSITORY}" \
    --password-file "${RESTIC_PASSWORD_FILE}" \
    backup \
    --files-from "${INCLUDE_FILE}" \
    --exclude-file "${EXCLUDE_FILE}" \
    --one-file-system; then

    END_TIME="$(date --iso-8601=seconds)"

    echo "============================================================"
    echo "Backup completed successfully."
    echo "Finished: ${END_TIME}"
    echo "============================================================"
else
    EXIT_CODE=$?
    END_TIME="$(date --iso-8601=seconds)"

    echo "============================================================"
    echo "ERROR: Backup failed with exit code ${EXIT_CODE}."
    echo "Finished: ${END_TIME}"
    echo "============================================================"

    exit "${EXIT_CODE}"
fi
