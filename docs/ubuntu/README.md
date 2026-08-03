# Ubuntu Desktop Backup

## Overview

This document describes how Ubuntu Desktop backups are implemented in this project.

The backup workflow uses Restic to create encrypted snapshots on an NFS-mounted NAS repository. Automatic retention is handled by a separate systemd service using Restic's built-in forget and prune functionality.

The implementation consists of:

- backup script
- retention script
- systemd services
- systemd timers
- centralized configuration files
- logging

## Prerequisites

Before installing the backup system, ensure that:

- Restic is installed
- an NFS share is mounted
- the backup repository exists
- a password file has been created
- systemd is available

## Installing Restic

```bash
sudo apt update
sudo apt install restic
```

## Creating the Repository

Initialize the repository:

```bash
restic init
```

The repository is stored on the NAS.


## Repository Layout

The backup repository is stored on the NAS and contains standard Restic repository data.

Example structure:

```text
repository/
├── config
├── data
├── index
├── keys
├── locks
└── snapshots
```

The repository is shared over NFS and mounted on the Ubuntu Desktop before scheduled backups are executed.

## Configuration Files

The backup configuration is stored under:

```text
config/ubuntu/
├── backup.conf
├── include.txt
└── excludes.txt
```

### backup.conf

Contains repository paths, password file location, retention settings, logging configuration, and other runtime options.

### include.txt

Lists all directories included in the backup.

Example:

```text
/etc
/home
/opt
/srv
/usr/local
```

### excludes.txt

Contains paths that should never be backed up.

Typical exclusions include cache directories, temporary files, trash folders, and other non-essential data.

## Running the First Backup

The backup can be started manually:

```bash
sudo /usr/local/sbin/ubuntu-desktop-backup
```

Verify that the backup completed successfully:

```bash
sudo restic \
    -r /path/to/repository \
    snapshots
```

The backup service writes detailed logs to:

```text
/var/log/raspi-backup-automation/
```

When deployed, backups are normally executed automatically by the associated systemd timer.

## Restoring Files

To restore data from a snapshot:

List available snapshots:

```bash
sudo restic \
    -r /path/to/repository \
    snapshots
```

Restore a snapshot:

```bash
sudo restic \
    -r /path/to/repository \
    restore <snapshot-id> \
    --target /restore/location
```

Individual files or directories can also be restored using Restic's include options.

## Retention Policy

Snapshot retention is handled automatically by a dedicated systemd service.

The current policy keeps:

- 8 weekly snapshots
- 12 monthly snapshots
- 3 yearly snapshots

After expired snapshots are removed, Restic automatically performs repository pruning to reclaim unused storage space.

Retention can be tested safely using dry-run mode before enabling production execution.

## systemd Services

The Ubuntu implementation consists of two independent services.

### Backup

Creates a new Restic snapshot.

Service:

```text
ubuntu-desktop-backup.service
```

Timer:

```text
ubuntu-desktop-backup.timer
```

Runs every Sunday at 02:00.

The timer uses `Persistent=true`, allowing missed backups to execute automatically after the system starts.

### Retention

Applies the snapshot retention policy and prunes unused repository data.

Service:

```text
ubuntu-desktop-retention.service
```

Timer:

```text
ubuntu-desktop-retention.timer
```

Runs every Sunday after the scheduled backup has completed.

## Logging

Both backup and retention generate dedicated log files.

```text
/var/log/raspi-backup-automation/
├── ubuntu-desktop-backup.log
└── ubuntu-desktop-retention.log
```

Logs include:

- start time
- finish time
- repository information
- snapshot statistics
- retention results
- error messages

## Validation

The Ubuntu backup implementation has been validated using real backups.

Verified functionality includes:

- repository creation
- snapshot creation
- snapshot listing
- manual execution
- automatic execution through systemd
- retention dry run
- production retention
- repository pruning
- log generation

## Troubleshooting

### Repository is not mounted

Verify that the NAS share is mounted before running the backup.

```bash
mount | grep nfs
```

---

### Backup fails

Check the backup log:

```bash
sudo less /var/log/raspi-backup-automation/ubuntu-desktop-backup.log
```

---

### Retention fails

Check the retention log:

```bash
sudo less /var/log/raspi-backup-automation/ubuntu-desktop-retention.log
```

---

### Verify available snapshots

```bash
sudo restic \
    -r /path/to/repository \
    snapshots
```
