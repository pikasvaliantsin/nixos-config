#!/usr/bin/env python3
"""Снимает программное удержание при физическом нажатии той же клавиши.

Читает /dev/input/event* (группа input), устройства с именем reel-hold
пропускает. События не перехватывает — они идут в композитор как обычно.
"""

import glob
import os
import select
import signal
import struct
import sys

STATE = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "reel-hold")
PIDFILE = STATE + ".pid"
WATCHPID = STATE + ".watch"
KEY = int(os.environ.get("REEL_KEYCODE", "26"))  # KEY_LEFTBRACE
EVENT = struct.Struct("llHHi")

fds = []
for path in glob.glob("/dev/input/event*"):
    namefile = f"/sys/class/input/{os.path.basename(path)}/device/name"
    try:
        with open(namefile) as f:
            name = f.read()
    except OSError:
        name = ""
    if "reel-hold" in name:
        continue
    try:
        fds.append(os.open(path, os.O_RDONLY | os.O_NONBLOCK))
    except OSError:
        pass

if not fds:
    sys.exit(1)

while True:
    ready, _, _ = select.select(fds, [], [], 2.0)
    for fd in ready:
        try:
            data = os.read(fd, EVENT.size * 64)
        except OSError:
            continue
        for i in range(0, len(data) - EVENT.size + 1, EVENT.size):
            _, _, typ, code, value = EVENT.unpack_from(data, i)
            if typ == 1 and code == KEY and value == 1:  # физическое нажатие
                try:
                    with open(PIDFILE) as f:
                        os.kill(int(f.read().strip()), signal.SIGTERM)
                except (OSError, ValueError):
                    pass
                for p in (STATE, PIDFILE, WATCHPID):
                    try:
                        os.remove(p)
                    except FileNotFoundError:
                        pass
                sys.exit(0)
