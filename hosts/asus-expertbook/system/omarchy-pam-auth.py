"""Graphical sudo authentication helper.

Run by pam_exec as root (or as the user under pamtester for testing). It talks
to the Omarchy shell's auth dialog over a Unix socket in the user's runtime
directory and returns PAM_SUCCESS only after the helper itself verified the
chosen method:

* password: checked with pamtester against the password-only PAM service;
* fingerprint: checked with fprintd-verify.

The dialog can switch between the two at any time; it is not a terminal prompt
that makes fingerprint fail first and only then offers a password.
"""

import json
import os
import pwd
import select
import socket
import subprocess
import sys
import time

PAMTESTER = "@PAMTESTER@"
FPRINTD = "@FPRINTD@"
PASSWORD_SERVICE = "omarchy-password"
TIMEOUT_SECONDS = 120


def socket_path(user):
    try:
        uid = pwd.getpwnam(user).pw_uid
    except KeyError:
        return None
    return "/run/user/%d/omarchy-auth.sock" % uid


def send(connection, payload):
    try:
        connection.sendall((json.dumps(payload, separators=(",", ":")) + "\n").encode())
        return True
    except OSError:
        return False


def verify_password(user, password):
    if not password:
        return False
    try:
        result = subprocess.run(
            [PAMTESTER, PASSWORD_SERVICE, user, "authenticate"],
            input=password + "\n",
            text=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=15,
        )
    except (OSError, subprocess.TimeoutExpired):
        return False
    return result.returncode == 0


def stop_fingerprint(process):
    if not process or process.poll() is not None:
        return
    process.terminate()
    try:
        process.wait(timeout=2)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait()


def main():
    user = os.environ.get("PAM_USER", "")
    if not user:
        return 1

    path = socket_path(user)
    if not path:
        return 1

    connection = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    connection.settimeout(2)
    try:
        connection.connect(path)
    except OSError:
        return 1
    connection.setblocking(False)

    if not send(connection, {
        "type": "auth_request",
        "user": user,
        "service": os.environ.get("PAM_SERVICE", "sudo"),
    }):
        return 1

    buffer = b""
    fingerprint = None
    deadline = time.monotonic() + TIMEOUT_SECONDS

    while True:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            send(connection, {"event": "cancelled"})
            stop_fingerprint(fingerprint)
            # pam_exec maps 5 to PAM_AUTH_ERR: the user cancelled, so do not
            # fall through to a terminal fingerprint/password prompt.
            return 5

        try:
            readable, _, _ = select.select([connection], [], [], min(0.1, remaining))
        except InterruptedError:
            continue

        if readable:
            try:
                data = connection.recv(4096)
            except OSError:
                data = b""
            if not data:
                stop_fingerprint(fingerprint)
                return 1
            buffer += data
            while b"\n" in buffer:
                line, buffer = buffer.split(b"\n", 1)
                try:
                    message = json.loads(line)
                except ValueError:
                    continue

                action = message.get("action")
                if action == "cancel":
                    send(connection, {"event": "cancelled"})
                    stop_fingerprint(fingerprint)
                    return 5

                if action == "fingerprint":
                    if fingerprint is None or fingerprint.poll() is not None:
                        fingerprint = subprocess.Popen(
                            [FPRINTD, user],
                            stdout=subprocess.DEVNULL,
                            stderr=subprocess.DEVNULL,
                        )
                        send(connection, {"event": "fingerprint_wait"})
                    continue

                if action == "password":
                    stop_fingerprint(fingerprint)
                    fingerprint = None
                    password = str(message.get("password", ""))
                    if verify_password(user, password):
                        send(connection, {"event": "success"})
                        return 0
                    send(connection, {"event": "password_failed"})
                    continue

        if fingerprint is not None and fingerprint.poll() is not None:
            code = fingerprint.returncode
            fingerprint = None
            if code == 0:
                send(connection, {"event": "success"})
                return 0
            send(connection, {"event": "fingerprint_failed"})

    return 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(1)
