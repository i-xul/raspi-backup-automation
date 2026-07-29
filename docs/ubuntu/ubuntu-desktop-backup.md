# Ubuntu Desktop Backup

## Overview

The Ubuntu Desktop backup workflow uses **restic** to create encrypted, deduplicated snapshots directly on NAS storage mounted over NFS.

The Ubuntu workstation is responsible only for creating and maintaining the local backup repository. Encrypted offsite replication is handled separately by the Raspberry Pi 4 backup coordinator.

This preserves the project's two-stage backup architecture:

1. Local backup creation by the source system.
2. Centralized encrypted offsite replication by the Raspberry Pi 4.

---

## Architecture

```text
Ubuntu Desktop
      │
      │ restic
      ▼
NFS mount: /mnt/nas-backups
      │
      ▼
ubuntu-desktop/repository
      │
      ▼
NAS attached to Raspberry Pi 4
      │
      ▼
Encrypted offsite replication
      │
      ▼
Integrity verification
      │
      ▼
Retention management
      │
      ▼
Email notifications
```

---

## Local Storage Layout

The Ubuntu workstation mounts the shared backup storage at:

```text
/mnt/nas-backups
```

The planned restic repository location is:

```text
/mnt/nas-backups/ubuntu-desktop/repository
```

---

## NFS Configuration

The backup storage is mounted persistently through `/etc/fstab`.

Example configuration:

```fstab
<NAS_IP>:/mnt/usb2_raid/share/backups  /mnt/nas-backups  nfs  defaults,_netdev,nofail,x-systemd.automount  0  0
```

The current production environment uses:

- NFS version 4.2
- TCP transport
- systemd automount
- `_netdev` to wait for network availability
- `nofail` to allow normal boot if the NAS is temporarily unavailable

---

## Planned Workflow

The Ubuntu backup workflow will perform the following steps:

1. Verify that the NFS share is mounted.
2. Verify access to the restic repository.
3. Create a new restic snapshot.
4. Verify repository integrity.
5. Apply the configured retention policy.
6. Write execution logs.
7. Send a success or failure notification.
8. Allow the Raspberry Pi 4 backup coordinator to replicate the repository to encrypted offsite storage.

---

## Current Status

Completed:

- NFS share exported from the Raspberry Pi 4 NAS
- Persistent NFS mount configured on Ubuntu Desktop
- Backup directory structure prepared

In progress:

- Restic installation
- Repository initialization
- Backup script implementation

Planned:

- Automated scheduling
- Repository maintenance
- Restore validation
- Integration with the centralized offsite backup workflow
