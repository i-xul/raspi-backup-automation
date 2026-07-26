# Architecture

## Overview

The backup solution is intentionally divided into two independent stages:

1. Local snapshot creation
2. Encrypted offsite replication

Separating these stages improves reliability, simplifies troubleshooting, and allows each phase to be validated independently before the next one begins.

---

## Backup Workflow

```text
                    Raspberry Pi 5
                          │
                          ▼
                Weekly local backup
                          │
                          ▼
                     NAS snapshots
                          │
                          ▼
              Verify snapshot freshness
                          │
                          ▼
        Encrypted offsite upload (pCloud Crypt)
                          │
                          ▼
        Integrity verification (rclone cryptcheck)
                          │
                          ▼
           Cloud snapshot retention policy
                          │
                          ▼
          Success / Failure email notification
```

---

## Workflow Design

### Stage 1 – Local Backup

The Raspberry Pi creates a local snapshot on NAS storage.

This stage focuses only on producing a reliable local recovery point.

No cloud synchronization is performed during this phase.

---

### Stage 2 – Offsite Replication

The latest validated snapshot is uploaded to encrypted cloud storage.

The upload process is completely independent from local backup creation.

Running these stages separately reduces complexity and prevents one operation from affecting the other.

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
