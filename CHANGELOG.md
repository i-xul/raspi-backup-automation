# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog, and this project follows Semantic Versioning.

## [Unreleased]

### Planned

- Raspberry Pi 4 backup coordinator configuration backup
- Additional Raspberry Pi backup targets
- Expanded monitoring and backup health reporting

## [1.0.0] - 2026-08-05

### Added

- Raspberry Pi 5 local backup and encrypted offsite replication workflow
- Windows 11 EaseUS backup replication from NAS to encrypted pCloud storage
- Ubuntu Desktop Restic backup workflow over NFS-mounted NAS storage
- Ubuntu Desktop automated snapshot retention and repository pruning
- systemd services and timers for Ubuntu backup and retention
- encrypted upload validation using `rclone cryptcheck`
- source stability validation for Windows EaseUS backup sets
- backup age checks, locking, timeout protection, and failure handling
- success and failure email notifications
- platform-specific Ubuntu and Windows documentation
- architecture and production validation documentation
- example configuration and notification files
- MIT License

### Validated

- production backup creation
- encrypted offsite replication
- individual file restore
- complete Raspberry Pi restore workflow
- Restic retention and pruning
- EaseUS backup-chain synchronization
- modified Full backup replacement
- obsolete cloud backup-chain removal
- successful and failed backup notifications