#!/usr/bin/env python3
"""Non-interactive quota-proxy healthcheck via SSH *password*.

Why:
- Some runners don't have sshpass and can't sudo install it.
- We still want a cron-friendly check.

How:
- Reads server ip/password from /tmp/server.txt by default.
- Uses pexpect to answer the ssh password prompt.

Server file format (minimum):
  ip:8.8.8.8
  password:...   (optional; can also pass PASSWORD env)

Security note:
- Prefer SSH keys. Password-in-file is only for short-lived bootstrap.
"""

import os
import re
import sys
import pexpect

SERVER_FILE = os.environ.get("SERVER_FILE", "/tmp/server.txt")
REMOTE_DIR = os.environ.get("REMOTE_DIR", "/opt/roc/quota-proxy")
REMOTE_USER = os.environ.get("REMOTE_USER", "root")
PASSWORD = os.environ.get("PASSWORD", "")


def _read_server_file(path: str):
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as f:
            txt = f.read()
    except FileNotFoundError:
        print(f"[ERR] server file missing: {path}", file=sys.stderr)
        sys.exit(2)

    m_ip = re.search(r"^ip:\s*(.+)\s*$", txt, re.M)
    if not m_ip:
        print(f"[ERR] cannot find ip:<addr> in {path}", file=sys.stderr)
        sys.exit(2)

    m_pw = re.search(r"^password:\s*(.+)\s*$", txt, re.M)

    ip = m_ip.group(1).strip()
    pw = (m_pw.group(1).strip() if m_pw else "")
    return ip, pw


def main():
    ip, pw_from_file = _read_server_file(SERVER_FILE)
    password = PASSWORD or pw_from_file
    if not password:
        print(
            "[ERR] password not provided. Set PASSWORD env or add password:... to server file.",
            file=sys.stderr,
        )
        sys.exit(2)

    remote = f"{REMOTE_USER}@{ip}"

    # Keep it as one remote shell to ensure `set -e` works.
    remote_cmd = (
        "set -euo pipefail; "
        f"cd {REMOTE_DIR}; "
        "docker compose ps; "
        "echo ---HEALTHZ---; "
        "curl -fsS http://127.0.0.1:8787/healthz"
    )

    cmd = (
        "ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "
        f"{remote} '{remote_cmd}'"
    )

    child = pexpect.spawn(cmd, encoding="utf-8", timeout=60)
    try:
        i = child.expect(
            [r"password:", r"Are you sure you want to continue connecting", pexpect.EOF]
        )
        if i == 1:
            child.sendline("yes")
            child.expect(r"password:")
            child.sendline(password)
        elif i == 0:
            child.sendline(password)
        else:
            print(child.before)
            sys.exit(1)

        child.expect(pexpect.EOF)
        out = child.before
        print(out)
        sys.exit(0)
    except Exception as e:
        print(f"[ERR] {e}", file=sys.stderr)
        try:
            print("[DBG] BEFORE:\n" + (child.before or ""), file=sys.stderr)
        except Exception:
            pass
        sys.exit(1)


if __name__ == "__main__":
    main()
