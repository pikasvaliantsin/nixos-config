#!/usr/bin/env python3
"""Держит физический keycode (по умолчанию [ = 26) через uinput до SIGTERM.

Работает на уровне ядра, поэтому не зависит от раскладки и не путает
keycode с Escape, как wtype под niri.
"""

import fcntl
import os
import signal
import struct
import time

KEY = int(os.environ.get("REEL_KEYCODE", "26"))  # KEY_LEFTBRACE
EV_KEY = 1
UI_SET_EVBIT = 0x40045564
UI_SET_KEYBIT = 0x40045565
UI_DEV_SETUP = 0x405c5503
UI_DEV_CREATE = 0x5501
UI_DEV_DESTROY = 0x5502

stop = False


def on_signal(signum, frame):  # noqa: ARG001
    global stop
    stop = True


signal.signal(signal.SIGTERM, on_signal)
signal.signal(signal.SIGINT, on_signal)

fd = os.open("/dev/uinput", os.O_WRONLY | os.O_NONBLOCK)
fcntl.ioctl(fd, UI_SET_EVBIT, EV_KEY)
fcntl.ioctl(fd, UI_SET_KEYBIT, KEY)
fcntl.ioctl(fd, UI_DEV_SETUP,
            struct.pack("HHHH80sI", 0x0003, 0x1209, 0x0001, 1, b"reel-hold", 0))
fcntl.ioctl(fd, UI_DEV_CREATE)
time.sleep(0.2)


def emit(value: int) -> None:
    now = time.time_ns()
    ev = struct.pack("llHHi", now // 10**9, (now % 10**9) // 1000, EV_KEY, KEY, value)
    os.write(fd, ev)
    os.write(fd, struct.pack("llHHi", 0, 0, 0, 0, 0))


emit(1)
while not stop:
    time.sleep(0.2)
emit(0)
fcntl.ioctl(fd, UI_DEV_DESTROY)
os.close(fd)
