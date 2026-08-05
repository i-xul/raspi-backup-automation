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

See the [architecture documentation](docs/architecture.md) for a detailed description of the complete architecture and backup workflow.

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

- Restic-based backup automation
- snapshot-based backup workflow
- encrypted offsite backups
- automated backup scheduling with systemd
- automated snapshot retention and repository pruning
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
- automated retention policy
- repository pruning
- NFS-based backup repository
- success notifications
- failure notifications

Detailed validation results are documented in [VALIDATION.md](VALIDATION.md).

---

## Environment

Current technologies include:

- Raspberry Pi
- Raspberry Pi OS
- Ubuntu Desktop
- Ubuntu Server
- Windows 11
- Linux
- Bash
- Restic
- rsync
- SSH
- NFS
- systemd
- rclone
- pCloud Crypt
- SMTP email notifications

---

## Repository Structure

```text
README.md                         Project overview
CHANGELOG.md                      Release history
VALIDATION.md                     Production validation results
LICENSE                           MIT License

config/
└── ubuntu/                       Ubuntu backup and retention configuration

docs/
├── architecture.md               Overall architecture
├── project-notes.md              Project background and lessons
├── ubuntu/
│   └── README.md                 Ubuntu Desktop documentation
└── windows11/
    └── README.md                 Windows 11 documentation

examples/
├── backup-mail.env.example       SMTP configuration example
├── backup-email-ok.txt           Successful notification example
└── backup-email-failed.txt       Failed notification example

scripts/
├── raspi5-offsite-backup.sh
├── windows11-offsite-backup.sh
├── ubuntu-desktop-backup.sh
├── ubuntu-desktop-retention.sh
└── send-backup-mail.py

systemd/
└── ubuntu/                       Backup and retention service/timer units
```

---

## Documentation

Project documentation is organized by platform and topic.

- [Architecture](docs/architecture.md) — Overall backup architecture
- [Project Notes](docs/project-notes.md) — Design lessons and project background
- [Ubuntu Desktop](docs/ubuntu/README.md) — Ubuntu Desktop backup implementation
- [Windows 11](docs/windows11/README.md) — Windows 11 backup workflow
- [Validation](VALIDATION.md) — Production validation and testing
- [Changelog](CHANGELOG.md) — Release history and planned development

---

## Implementations

### Completed

- Raspberry Pi 5 local Restic backups
- Raspberry Pi 5 encrypted offsite replication
- Windows 11 EaseUS offsite replication
- Ubuntu Desktop Restic backup automation
- Ubuntu Desktop automated retention and pruning
- Ubuntu systemd scheduling
- Restore validation
- Integrity verification
- Email notifications

### In Progress

- Long-term monitoring of scheduled backup and retention automation

### Planned

- Raspberry Pi 4 NAS configuration backup
- Additional Raspberry Pi backup targets

---

## Future Expansion

Planned long-term improvements include:

- multiple encrypted offsite destinations
- centralized backup monitoring dashboard
- backup health reporting
- backup metrics and statistics
- optional Telegram notifications for backup status and failure reporting

---

## Notes

This repository is based on a real production backup workflow adapted into a public example.

Sensitive information such as usernames, hostnames, credentials, email addresses, and storage paths has been replaced with generic examples.

AI tools (ChatGPT) were used for architecture discussions, documentation drafting, troubleshooting, shell command validation, script refinement, and code review.

Final implementation, deployment, production testing, validation, and operational verification were performed manually on the target systems.
