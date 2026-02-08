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

Extra:
- --fix-bind-localhost: patch remote compose port mapping to bind 127.0.0.1
  (avoid exposing :8787 to the public internet), then redeploy.
"""

import argparse
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


def _run_ssh(remote: str, password: str, remote_cmd: str) -> str:
    cmd = (
        "ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "
        f"{remote} '{remote_cmd}'"
    )

    child = pexpect.spawn(cmd, encoding="utf-8", timeout=120)
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
            raise RuntimeError("ssh exited before password prompt")

        child.expect(pexpect.EOF)
        return child.before or ""
    finally:
        try:
            child.close(force=True)
        except Exception:
            pass


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--fix-bind-localhost",
        action="store_true",
        help="Patch remote compose port mapping to 127.0.0.1:8787:8787 and redeploy",
    )
    args = ap.parse_args()

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
    parts = [
        "set -euo pipefail",
        f"cd {REMOTE_DIR}",
    ]

    if args.fix_bind_localhost:
        # Replace common variants.
        parts += [
            r"sed -i -E 's/\"(0\.0\.0\.0:)?8787:8787\"/\"127.0.0.1:8787:8787\"/g' compose.yaml",
            "docker compose up -d --build",
        ]

    parts += [
        "docker compose ps",
        "echo ---HEALTHZ---",
        # Give the container a moment to come up after (re)deploy.
        r"for i in $(seq 1 20); do curl -fsS http://127.0.0.1:8787/healthz && break; sleep 0.5; done",
    ]

    remote_cmd = "; ".join(parts)

    try:
        out = _run_ssh(remote, password, remote_cmd)
        print(out)
        sys.exit(0)
    except Exception as e:
        print(f"[ERR] {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
