# Architecture

## Overview

The backup solution uses a centralized coordinator architecture.

Source systems create or transfer their backups to NAS storage attached directly to a Raspberry Pi 4. The Raspberry Pi 4 then handles encrypted offsite replication, integrity verification, retention, logging, and email notifications.

The workflow remains divided into two independent stages:

1. Source-system backup creation
2. Centralized encrypted offsite replication

Separating these stages improves reliability, simplifies troubleshooting, and allows each phase to be validated independently.

---

## Backup Workflow

```text
Raspberry Pi 5 ──► Timestamped NAS snapshots ──┐
                                               │
Windows 11 ─────► EaseUS backup files ─────────┼──►    Raspberry Pi 4
                                               │     Backup Coordinator
Ubuntu ─────────► Restic repository on NAS ─-──┘              │
                                                              ▼
                                                   Encrypted pCloud storage
                                                              │
                                                              ▼
                                                   Integrity verification
                                                    (rclone cryptcheck)
                                                              │
                                                              ▼
                                                    Source-specific retention
                                                              │
                                                              ▼
                                                   Success / Failure email
```

---

## Workflow Design

### Central Backup Coordinator

The Raspberry Pi 4 acts as the central backup coordinator because the NAS storage is physically attached to it.

This design avoids requiring an additional Raspberry Pi to remain online solely for cloud replication. Once a source backup exists on the NAS, the original source system can be offline while the coordinator completes the offsite workflow.

Coordinator responsibilities include:

- detecting available source backups
- validating backup freshness or completeness
- encrypted pCloud upload
- `rclone cryptcheck`
- source-specific retention
- logging
- success and failure notifications


### Stage 1 – Local Backup

Each source system creates or transfers its local backup to NAS storage.

Current and planned source formats include:

- timestamped Raspberry Pi snapshots
- Windows EaseUS `.pbd` backup files
- Ubuntu restic repositories stored on NFS-mounted NAS storage

This stage focuses only on producing a reliable local recovery point. No cloud synchronization is performed by the source system.

---

### Stage 2 – Offsite Replication

The Raspberry Pi 4 backup coordinator uploads validated backups from NAS storage to encrypted cloud storage.

The upload process is independent from source-system backup creation. This allows offsite replication to continue even when the original Windows, Ubuntu, or Raspberry Pi source system is offline.

Backup discovery and retention are handled separately for each source type.

---

## Integrity Verification

Uploading data is not considered sufficient.

After every upload the backup is verified using:

- `rclone cryptcheck`

Retention is processed only after successful verification.

This prevents removal of older backups if the newest upload cannot be trusted.

---

## Restore Strategy

The backup strategy assumes that backups must be recoverable.

The workflow therefore includes:

- restore testing
- directory structure verification
- symbolic link verification
- integrity verification

A backup is considered successful only after it has been demonstrated that it can be restored successfully.

---

## Error Handling

The workflow includes several defensive mechanisms:

- snapshot freshness validation
- execution locking
- timeout protection
- upload verification
- safe retention logic
- success and failure notifications

These mechanisms reduce the likelihood of silent backup failures.

---

## Scalability

The architecture has been designed so additional systems can reuse the same workflow.

Future backup targets may include:

- additional Raspberry Pi systems
- Ubuntu servers
- Windows workstations
- other Linux hosts

Each system can maintain independent local snapshots while sharing the same offsite backup strategy.
