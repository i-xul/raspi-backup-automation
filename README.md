# raspi-backup-automation

Automated snapshot-based backup solution for Raspberry Pi and other self-hosted Linux systems.

The project implements a multi-stage backup workflow consisting of local snapshot creation, encrypted offsite replication, integrity verification, retention management, and automatic email notifications.

---

## Overview

This repository documents a production-tested backup workflow developed for a self-hosted Raspberry Pi environment.

Rather than focusing only on creating backups, the project emphasizes backup validation, restore capability, and operational reliability.

The workflow has been designed to minimize manual maintenance while ensuring that backups remain both verifiable and recoverable.

---

## Architecture

```text
Raspberry Pi
     │
     ▼
Local NAS snapshots
     │
     ▼
Encrypted pCloud storage
     │
     ▼
Integrity verification
    (rclone cryptcheck)
     │
     ▼
Snapshot retention
     │
     ▼
Email notifications
```

---

## Backup Workflow

The backup process currently consists of the following stages:

1. Create a local NAS snapshot.
2. Verify snapshot freshness.
3. Upload the latest snapshot to encrypted cloud storage.
4. Validate uploaded data using `rclone cryptcheck`.
5. Remove expired cloud snapshots according to the retention policy.
6. Send a success or failure notification.

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

## Future Expansion

Planned future improvements include:

- additional Raspberry Pi backup targets
- Windows backup integration
- Ubuntu backup integration
- Raspberry Pi 3 integration
- multiple encrypted offsite destinations
- expanded documentation and monitoring

---

## Notes

This repository is based on a real production backup workflow adapted into a public example.

Sensitive information such as usernames, hostnames, credentials, email addresses, and storage paths has been replaced with generic examples.

AI tools (ChatGPT) were used for brainstorming, architecture discussions, script refinement, debugging, documentation support, and code review.
