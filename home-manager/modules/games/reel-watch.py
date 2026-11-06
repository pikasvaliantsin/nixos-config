#!/usr/bin/env python3
"""Снимает программное удержание клавиши при физическом нажатии той же клавиши.

Читает /dev/input/event* (нужна группа input), ничего не инжектит и не
перехватывает: события идут в композитор как обычно.
"""

import glob
import os
import select
import struct
import subprocess
import sys

STATE = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "reel-hold")
PIDFILE = STATE + ".pid"
KEY = os.environ.get("REEL_KEY", "bracketleft")
CODE = 26  # KEY_LEFTBRACE
EVENT = struct.Struct("llHHi")

fds = []
for path in glob.glob("/dev/input/event*"):
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
            if typ == 1 and code == CODE and value == 1:  # физическое нажатие
                subprocess.run(["wtype", "-p", KEY],
                               stdout=subprocess.DEVNULL,
                               stderr=subprocess.DEVNULL, check=False)
                for f in (STATE, PIDFILE):
                    try:
                        os.remove(f)
                    except FileNotFoundError:
                        pass
                sys.exit(0)
