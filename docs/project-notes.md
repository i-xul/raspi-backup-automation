# Project Notes

## Purpose

This project was created to build a reliable, repeatable, and production-tested backup workflow for self-hosted Raspberry Pi systems.

The objective was not only to automate backups, but also to verify that they can be successfully restored after an actual failure.

---

## What I Learned

During this project I gained practical experience with:

- snapshot-based backup strategies
- rsync over SSH
- encrypted offsite backups using rclone Crypt
- integrity verification using `rclone cryptcheck`
- snapshot retention policies
- disaster recovery planning
- automated email notifications
- defensive shell scripting
- validating real-world backup workflows

---

## Practical Lessons

Several important observations were made during development.

### A backup is not enough

Creating backups alone does not guarantee recoverability.

A backup should always be validated and periodically restored to confirm that recovery actually works.

### Validation before retention

Old backups should never be removed before the newest backup has been verified successfully.

This significantly reduces the risk of ending up without a usable backup.

### Separate backup stages

Separating local backups from offsite replication simplifies troubleshooting and reduces operational risk.

Each stage can be validated independently.

---

## Portfolio Note

This repository is based on a real self-hosted backup solution.

Sensitive information such as usernames, hostnames, email addresses, credentials, and filesystem paths has been replaced with generic examples before publication.

AI tools (ChatGPT) were used for brainstorming, debugging, documentation, and code review.

All production logic was manually implemented, tested, and validated in a real self-hosted environment before publication.
