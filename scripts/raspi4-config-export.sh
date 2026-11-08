#!/usr/bin/env bash
set -Eeuo pipefail

# NAS Raspberry Pi 4 configuration export.
# Creates a metadata-preserving tar archive for restricted SSH transfer.
# Does not schedule backups or modify existing Restic repositories.

umask 077

EXPORT_DIR="/var/lib/raspi4-config-export"
BACKUP_USER="raspi4backup"
ARCHIVE="${EXPORT_DIR}/raspi4-config.tar"
LOCK_FILE="/run/raspi4-config-export.lock"
TEMP_ARCHIVE=""

SOURCES=(
    etc
    boot/firmware
    home/hmasi/.config
    home/hmasi/.ssh
    home/hmasi/scripts
    opt/raspi-audit
    usr/local/bin
    usr/local/etc
)

EXCLUDES=(
    "--exclude=home/hmasi/.config/*/Cache"
    "--exclude=home/hmasi/.config/*/cache"
    "--exclude=home/hmasi/.config/nordvpn/fileshare_history.db"
    "--exclude=*.tmp"
    "--exclude=*.part"
    "--exclude=*.swp"
    "--exclude=*.swo"
)

cleanup() {
    if [[ -n "${TEMP_ARCHIVE}" ]]; then
        rm -f -- "${TEMP_ARCHIVE}"
    fi
}

trap cleanup EXIT

if [[ "${EUID}" -ne 0 ]]; then
    echo "ERROR: This script must run as root." >&2
    exit 1
fi

if [[ ! -d "${EXPORT_DIR}" || -L "${EXPORT_DIR}" ]]; then
    echo "ERROR: Export directory is missing or is a symlink." >&2
    exit 1
fi

if [[ "$(stat -c '%u:%g' "${EXPORT_DIR}")" != "0:0" ]]; then
    echo "ERROR: Export directory must be owned by root:root." >&2
    exit 1
fi

if [[ -n "$(find "${EXPORT_DIR}" -maxdepth 0 -perm /022 -print)" ]]; then
    echo "ERROR: Export directory has unsafe write permissions." >&2
    exit 1
fi

exec 9>"${LOCK_FILE}"

if ! flock -n 9; then
    echo "ERROR: Another configuration export is already running." >&2
    exit 1
fi

for source in "${SOURCES[@]}"; do
    if [[ ! -d "/${source}" || -L "/${source}" ]]; then
        echo "ERROR: Invalid source directory: /${source}" >&2
        exit 1
    fi
done

TEMP_ARCHIVE="$(mktemp "${EXPORT_DIR}/.raspi4-config.XXXXXXXX.tar")"

tar \
    --create \
    --file="${TEMP_ARCHIVE}" \
    --directory=/ \
    --acls \
    --xattrs \
    --xattrs-include='*' \
    --numeric-owner \
    --one-file-system \
    "${EXCLUDES[@]}" \
    "${SOURCES[@]}"

# Verify that the archive can be read before publishing it.
tar --list --file="${TEMP_ARCHIVE}" >/dev/null

chown root:root "${TEMP_ARCHIVE}"
chmod 600 "${TEMP_ARCHIVE}"

# Grant the dedicated backup account read-only access.
setfacl -m "u:${BACKUP_USER}:r--" "${TEMP_ARCHIVE}"

# Publish only a completed archive.
mv -f -- "${TEMP_ARCHIVE}" "${ARCHIVE}"
TEMP_ARCHIVE=""

echo "Configuration export completed: ${ARCHIVE}"
stat -c 'Size: %s bytes | Owner: %U:%G | Mode: %a' "${ARCHIVE}"
