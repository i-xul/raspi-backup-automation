# raspi-backup-automation

Automated backup framework for Raspberry Pi, Windows, Ubuntu, and other self-hosted systems using centralized encrypted offsite replication.

The project implements a multi-stage backup workflow consisting of local snapshot creation, encrypted offsite replication, integrity verification, retention management, and automatic email notifications.

---

## Overview

This repository documents a production-tested backup workflow developed for a self-hosted Raspberry Pi environment.

Rather than focusing only on creating backups, the project emphasizes backup validation, restore capability, and operational reliability.

The workflow has been designed to minimize manual maintenance while ensuring that backups remain both verifiable and recoverable.

---

## Architecture

```text
Raspberry Pi 5 ──┐
                 │
Windows 11 ──────┼──► NAS storage attached to Raspberry Pi 4
                 │                    │
Ubuntu ──────────┘                    ▼
                           Central backup coordinator
                                      │
                                      ▼
                           Encrypted pCloud storage
                                      │
                                      ▼
                           Integrity verification
                              (rclone cryptcheck)
                                      │
                                      ▼
                              Backup retention
                                      │
                                      ▼
                              Email notifications
```

---

## Backup Workflow

Each source system first creates or transfers a local backup to the NAS.

The central backup coordinator then performs the following stages:

1. Detect and validate the latest available backup.
2. Upload the backup to encrypted cloud storage.
3. Validate uploaded data using `rclone cryptcheck`.
4. Remove expired cloud backups according to the retention policy.
5. Send a success or failure notification.

Backup discovery and retention rules may differ by source system. Raspberry Pi backups use timestamped snapshots, while Windows backups are created as EaseUS `.pbd` files.

---

## Features

Current functionality includes:

- snapshot-based backup workflow
- encrypted offsite backups
- automated snapshot retention
- integrity verification using `rclone cryptcheck`
- restore-tested backup chain
- success and failure email notifications
- timeout protection
- locking to prevent overlapping jobs
- production-tested automation

---

## Validation

The complete workflow has been validated in a real production environment.

Successfully verified:

- local snapshot creation
- encrypted cloud upload
- integrity verification
- full restore procedure
- symbolic link preservation
- retention policy
- success notifications
- failure notifications

Detailed validation results are documented in `VALIDATION.md`.

---

## Environment

Current technologies include:

- Raspberry Pi
- Linux
- Bash
- rsync
- SSH
- rclone
- pCloud Crypt
- cron
- SMTP email notifications

---

## Repository Structure

```
README.md              Project overview

VALIDATION.md          Production validation results

docs/                  Architecture and project documentation

scripts/               Backup automation scripts

examples/              Example configuration and email templates
```

---

## Implementations

### Completed

- Raspberry Pi 5 local NAS snapshots
- Raspberry Pi 5 encrypted offsite replication
- Integrity verification, retention, restore validation, and notifications

### In Progress

- Windows 11 EaseUS backup replication from NAS to encrypted pCloud storage

### Planned

- Ubuntu local NAS backup and encrypted offsite replication
- Raspberry Pi 4 NAS configuration backup
- Additional Raspberry Pi systems

---

## Future Expansion

Planned future improvements include:

- Ubuntu backup integration
- Raspberry Pi 4 NAS configuration backup
- additional Raspberry Pi backup targets
- multiple encrypted offsite destinations
- expanded documentation and monitoring
- optional centralized backup status dashboard

---

## Notes

This repository is based on a real production backup workflow adapted into a public example.

Sensitive information such as usernames, hostnames, credentials, email addresses, and storage paths has been replaced with generic examples.

AI tools (ChatGPT) were used for brainstorming, architecture discussions, script refinement, debugging, documentation support, and code review.
