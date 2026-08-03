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

# shellcheck source=/dev/null
source "${CONFIG_FILE}"

require_file() {
    local file_path="$1"

    if [[ ! -r "${file_path}" ]]; then
        echo "ERROR: Required file is missing or unreadable: ${file_path}" >&2
        exit 1
    fi
}

require_variable() {
    local variable_name="$1"

    if [[ -z "${!variable_name:-}" ]]; then
        echo "ERROR: Required configuration variable is missing: ${variable_name}" >&2
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

require_variable "RESTIC_REPOSITORY"
require_variable "RESTIC_PASSWORD_FILE"
require_variable "BACKUP_MOUNT"
require_variable "LOG_DIR"
require_variable "RETENTION_LOG_FILE"
require_variable "RESTIC_KEEP_WEEKLY"
require_variable "RESTIC_KEEP_MONTHLY"
require_variable "RESTIC_KEEP_YEARLY"
require_variable "RETENTION_DRY_RUN"

require_file "${RESTIC_PASSWORD_FILE}"

if ! mountpoint -q "${BACKUP_MOUNT}"; then
    echo "ERROR: Backup destination is not mounted: ${BACKUP_MOUNT}" >&2
    exit 1
fi

if [[ ! -d "${RESTIC_REPOSITORY}" ]]; then
    echo "ERROR: Restic repository directory does not exist: ${RESTIC_REPOSITORY}" >&2
    exit 1
fi

if [[ "${RETENTION_DRY_RUN}" != "true" && "${RETENTION_DRY_RUN}" != "false" ]]; then
    echo "ERROR: RETENTION_DRY_RUN must be either true or false." >&2
    exit 1
fi

mkdir -p "${LOG_DIR}"
: > "${RETENTION_LOG_FILE}"

exec > >(tee -a "${RETENTION_LOG_FILE}") 2>&1

START_TIME="$(date --iso-8601=seconds)"

echo "============================================================"
echo "Ubuntu Desktop Restic Retention"
echo "============================================================"
echo "Started:          ${START_TIME}"
echo "Repository:       ${RESTIC_REPOSITORY}"
echo "Keep weekly:      ${RESTIC_KEEP_WEEKLY}"
echo "Keep monthly:     ${RESTIC_KEEP_MONTHLY}"
echo "Keep yearly:      ${RESTIC_KEEP_YEARLY}"
echo "Dry run:          ${RETENTION_DRY_RUN}"
echo "Log file:         ${RETENTION_LOG_FILE}"
echo "============================================================"

RESTIC_FORGET_ARGS=(
    forget
    --keep-weekly "${RESTIC_KEEP_WEEKLY}"
    --keep-monthly "${RESTIC_KEEP_MONTHLY}"
    --keep-yearly "${RESTIC_KEEP_YEARLY}"
)

if [[ "${RETENTION_DRY_RUN}" == "true" ]]; then
    RESTIC_FORGET_ARGS+=(--dry-run)
    echo "DRY RUN enabled: no snapshots or repository data will be removed."
else
    RESTIC_FORGET_ARGS+=(--prune)
    echo "Production mode enabled: expired snapshots and unused data may be removed."
fi

if restic \
    --repo "${RESTIC_REPOSITORY}" \
    --password-file "${RESTIC_PASSWORD_FILE}" \
    "${RESTIC_FORGET_ARGS[@]}"; then

    END_TIME="$(date --iso-8601=seconds)"

    echo "============================================================"

    if [[ "${RETENTION_DRY_RUN}" == "true" ]]; then
        echo "Retention dry run completed successfully."
    else
        echo "Retention and repository pruning completed successfully."
    fi

    echo "Finished: ${END_TIME}"
    echo "============================================================"
else
    EXIT_CODE=$?
    END_TIME="$(date --iso-8601=seconds)"

    echo "============================================================"
    echo "ERROR: Retention failed with exit code ${EXIT_CODE}."
    echo "Finished: ${END_TIME}"
    echo "============================================================"

    exit "${EXIT_CODE}"
fi
