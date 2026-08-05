#!/usr/bin/env python3

###############################################################################
#
# Backup Email Notification Helper
#
# Sends success or failure notifications for the backup automation workflows.
#
# Configuration is loaded from an external environment file so SMTP
# credentials are never stored inside the repository.
#
# Requirements:
#     - Python 3
#     - SMTP server with STARTTLS support
#
###############################################################################

import smtplib
import socket
import ssl
import sys
import os
from datetime import datetime
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

###############################################################################
# Configuration
###############################################################################

ENV_FILE = "/etc/backup-mail.env"

###############################################################################
# Environment Loader
###############################################################################


def load_env(path: str) -> dict:
    env = {}

    with open(path, "r", encoding="utf-8") as file:
        for line in file:
            line = line.strip()

            if not line or line.startswith("#"):
                continue

            if "=" in line:
                key, value = line.split("=", 1)
                env[key.strip()] = value.strip()

    return env


###############################################################################
# Email Sender
###############################################################################


def send_email(status: str, body: str) -> None:
    env = load_env(ENV_FILE)

    smtp_server = env.get("SMTP_SERVER", "smtp.gmail.com")
    smtp_port = int(env.get("SMTP_PORT", "587"))
    smtp_user = env["SMTP_USER"]
    smtp_pass = env["SMTP_PASS"]

    from_email = env.get("FROM_EMAIL", smtp_user)
    to_email = env.get("TO_EMAIL", smtp_user)

    hostname = socket.gethostname()
    today = datetime.now().strftime("%Y-%m-%d")
    backup_name = os.environ.get("BACKUP_NAME", "Raspberry Pi 5 offsite")

    subject = f"[Backup] {backup_name} {status} — {hostname} — {today}"

    message = MIMEMultipart()
    message["From"] = from_email
    message["To"] = to_email
    message["Subject"] = subject
    message.attach(MIMEText(body, "plain", "utf-8"))

    context = ssl.create_default_context()

    with smtplib.SMTP(smtp_server, smtp_port, timeout=30) as server:
        server.ehlo()
        server.starttls(context=context)
        server.login(smtp_user, smtp_pass)
        server.sendmail(from_email, [to_email], message.as_string())


###############################################################################
# Program Entry Point
###############################################################################


def main() -> None:
    if len(sys.argv) != 2:
        print("Usage: send-backup-mail.py OK|FAILED", file=sys.stderr)
        sys.exit(1)

    status = sys.argv[1].upper()

    if status not in {"OK", "FAILED"}:
        print("Status must be OK or FAILED.", file=sys.stderr)
        sys.exit(1)

    # Read the backup report from standard input.
    body = sys.stdin.read()

    if not body.strip():
        body = "No backup report content provided."

    send_email(status, body)


if __name__ == "__main__":
    main()
