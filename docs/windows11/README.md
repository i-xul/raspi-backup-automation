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

## Synchronization

Synchronization is performed using:

```text
rclone sync
```

The coordinator:

- validates the newest backup
- waits until files become stable
- synchronizes to encrypted storage
- verifies uploaded data using cryptcheck

## Validation

The Windows workflow has been validated using production backups.

Verified functionality includes:

- EaseUS backup detection
- backup stability verification
- encrypted upload
- cryptcheck validation
- synchronization after new incremental backups
- deletion of obsolete cloud backups
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

### cryptcheck fails

Run the synchronization again.

The backup is not considered successful until cryptcheck completes successfully.

## Status

Current implementation status:

- ✅ EaseUS integration
- ✅ Automatic synchronization
- ✅ Encrypted pCloud replication
- ✅ cryptcheck validation
- ✅ Logging
- ✅ Production tested