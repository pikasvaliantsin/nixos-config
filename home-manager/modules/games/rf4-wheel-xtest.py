#!/usr/bin/env python3
import os
import selectors
import subprocess
import time

import evdev
from evdev import ecodes

XDOTOOL = os.environ.get("XDOTOOL", "xdotool")
DISPLAY = os.environ.get("DISPLAY", ":0")

KEYMAP = {
    ecodes.KEY_F13: "4",  # wheel up
    ecodes.KEY_F14: "5",  # wheel down
    ecodes.KEY_F15: "4",  # R + wheel up
    ecodes.KEY_F16: "5",  # R + wheel down
}


def find_keyboards():
    result = []
    for path in evdev.list_devices():
        try:
            device = evdev.InputDevice(path)
        except Exception:
            continue
        if device.name in ("input-remapper keyboard", "input-remapper keyboard + mouse"):
            result.append(device)
            print(f"MON {path} {device.name}", flush=True)
    return result


def main():
    while True:
        devices = find_keyboards()
        if not devices:
            time.sleep(0.5)
            continue
        selector = selectors.DefaultSelector()
        for device in devices:
            selector.register(device.fd, selectors.EVENT_READ, device)
        try:
            while True:
                for key, _ in selector.select(timeout=1):
                    device = key.data
                    for event in device.read():
                        if (
                            event.type == ecodes.EV_KEY
                            and event.value == 1
                            and event.code in KEYMAP
                        ):
                            button = KEYMAP[event.code]
                            print(f"{device.name}: key={event.code} -> click {button}", flush=True)
                            subprocess.run(
                                [XDOTOOL, "click", button],
                                env={**os.environ, "DISPLAY": DISPLAY},
                                check=False,
                            )
        except Exception as error:
            print(f"read error: {error}", flush=True)
            time.sleep(0.5)
        finally:
            selector.close()


if __name__ == "__main__":
    main()
