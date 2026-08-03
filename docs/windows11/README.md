# Windows 11 Backup

## Overview

This document describes how Windows 11 backups are integrated into the backup automation framework.

Unlike the Linux systems, Windows does not upload directly to the cloud.

Instead, EaseUS Todo Backup creates local image backups on NAS storage. A Raspberry Pi 4 acts as the backup coordinator and automatically synchronizes validated backup files to encrypted pCloud storage.

The implementation consists of:

- EaseUS Todo Backup
- Raspberry Pi backup coordinator
- encrypted pCloud replication
- integrity verification
- logging
- email notifications

## Prerequisites

Before using the Windows backup workflow, ensure that:

- EaseUS Todo Backup is installed
- the NAS share is available
- Windows stores backup images on the NAS
- Raspberry Pi has access to the backup directory
- rclone with pCloud Crypt has been configured

## Configuration

The public script contains generic example paths that must be adapted to the target environment before deployment.

Important settings include:

```bash
LOCAL_BASE="/path/to/nas/easeus_w11_backups/<COMPUTER_NAME>/Disks backup"
REMOTE_BASE="pcloud-crypt:windows-11/easeus"

RCLONE_TIMEOUT="24h"
MINIMUM_FILE_AGE_MINUTES=60

DRY_RUN=true

LOCK_FILE="/tmp/windows11-offsite-backup.lock"
LOG_FILE="/path/to/nas/easeus_w11_backups/windows11-offsite-backup.log"

MAIL_HELPER="/usr/local/bin/send-backup-mail.py"
RCLONE_CONFIG="/path/to/rclone/rclone.conf"
```

`DRY_RUN=true` should remain enabled until the detected changes have been reviewed. Production execution requires an environment-specific installed copy with validated paths and `DRY_RUN=false`.

## Backup Workflow

The Windows backup process consists of several stages.

```text
Windows 11
      │
      ▼
EaseUS Todo Backup
      │
      ▼
NAS Storage
      │
      ▼
Raspberry Pi Backup Coordinator
      │
      ▼
Encrypted pCloud
      │
      ▼
cryptcheck
      │
      ▼
Email notification
```

## Backup Files

The coordinator automatically detects the current EaseUS backup set.

Typical files include:

```text
Disks backup_YYYYMMDD_Full_v1.pbd
Disks backup_YYYYMMDD_Inc_v1.pbd
```

Expired backup files removed by EaseUS are automatically removed from encrypted cloud storage during synchronization.

## EaseUS Backup Chain Behaviour

EaseUS may occasionally consolidate or rewrite an existing backup chain.

A large Full `.pbd` file can therefore retain the same filename and size while its contents change. Modification times alone are not sufficient to determine whether the cloud copy is current.

During production validation, `rclone cryptcheck` confirmed that a local and cloud Full backup with the same name and size contained different data. The updated Full backup therefore had to be uploaded again.

For this reason:

- `--size-only` must not be used
- large uploads may occur after EaseUS consolidation
- the first run after a changed backup chain should be reviewed using dry-run mode
- encrypted upload validation must complete before the run is considered successful

## Synchronization

Synchronization is performed using:

```text
rclone sync
```

Before synchronization, the coordinator:

1. verifies that the source directory exists
2. detects EaseUS `.pbd` files
3. checks that the backup files are old enough to be considered complete
4. creates a source manifest containing file paths, sizes, and modification times
5. verifies access to the encrypted pCloud remote

The default minimum file age is 60 minutes. The script does not wait for a newly created backup to become old enough; it exits safely and can be run again later.

During synchronization:

- a lock prevents overlapping executions
- a 24-hour timeout limits stalled or unexpectedly long transfers
- `rclone sync` updates the encrypted destination to match the current local EaseUS backup set
- files removed locally by EaseUS may also be removed from the encrypted cloud mirror
- transfer statistics are reported at five-minute intervals

After synchronization:

- `rclone cryptcheck` validates the encrypted cloud copy
- a second source manifest is created
- the initial and final manifests are compared
- the run fails if the EaseUS backup set changed during synchronization
- a success or failure notification is generated

In dry-run mode, pCloud is not modified and `cryptcheck` is skipped.

Verified functionality includes:

- EaseUS `.pbd` backup detection
- minimum backup age validation
- source manifest creation
- encrypted pCloud connectivity validation
- safe dry-run execution
- encrypted upload
- `rclone cryptcheck` validation
- source stability verification during the complete run
- synchronization after new incremental backups
- replacement of a modified Full backup
- deletion of obsolete cloud backup-chain files
- timeout protection
- overlapping-run prevention
- success logging

## Logging

The synchronization process generates a dedicated log.

Example:

```text
windows11-offsite-backup.log
```

The log contains:

- backup discovery
- file validation
- synchronization results
- cryptcheck results
- completion status

## Troubleshooting

### No backup found

Verify that the NAS share contains valid EaseUS .pbd files.

---

### Synchronization fails

Verify:

- network connectivity
- pCloud access
- rclone configuration

---

### `cryptcheck` fails

A failed `cryptcheck` means that the encrypted cloud copy does not match the local EaseUS backup set.

Do not treat the backup as successful.

Check:

- whether EaseUS modified or consolidated the backup chain
- whether a same-named Full backup changed internally
- whether the upload completed without network or storage errors
- whether the local source remained unchanged during the run

Run a dry-run comparison before repeating production synchronization.

Current implementation status:

- ✅ EaseUS integration
- ✅ Manual offsite synchronization workflow
- ✅ Safe dry-run validation
- ✅ Encrypted pCloud replication
- ✅ `cryptcheck` validation
- ✅ Source stability verification
- ✅ Logging
- ✅ Email notification support
- ✅ Production tested
- ⏳ Scheduled execution on the Raspberry Pi 4 coordinator