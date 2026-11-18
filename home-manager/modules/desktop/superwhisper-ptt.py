#!/usr/bin/env python3
"""Right Alt push-to-talk for Superwhisper on niri.

niri 26.04 has no key-release binds, and Superwhisper's desktop shortcut
registration needs the GlobalShortcuts portal that niri only gained after
26.04. This daemon watches the keyboard devices directly (the user is in the
`input` group) and drives Superwhisper's own CLI:

  press Right Alt   -> superwhisper record start
  release Right Alt -> superwhisper record stop

A 120 ms grace window ignores Right Alt when it is used as AltGr in a chord.
"""
from __future__ import annotations

import argparse
import os
import selectors
import shutil
import subprocess
import sys
import time
from pathlib import Path

import evdev
from evdev import ecodes

START_DELAY = 0.12
RESCAN_SECONDS = 2.0


def is_keyboard(device: evdev.InputDevice) -> bool:
    keys = device.capabilities(verbose=False).get(ecodes.EV_KEY, [])
    return ecodes.KEY_A in keys and ecodes.KEY_RIGHTALT in keys


def open_keyboards(selector: selectors.BaseSelector, known: dict[str, evdev.InputDevice]) -> None:
    for path in evdev.list_devices():
        if path in known:
            continue
        try:
            device = evdev.InputDevice(path)
        except OSError:
            continue
        if not is_keyboard(device):
            device.close()
            continue
        known[path] = device
        selector.register(device, selectors.EVENT_READ)
        print(f"[ptt] watching {path} ({device.name})", flush=True)


def forget(selector: selectors.BaseSelector, known: dict[str, evdev.InputDevice], path: str) -> None:
    device = known.pop(path, None)
    if device is None:
        return
    try:
        selector.unregister(device)
    except (KeyError, ValueError):
        pass
    try:
        device.close()
    except OSError:
        pass


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("binary", nargs="?", default=shutil.which("superwhisper") or "superwhisper")
    ap.add_argument("--dry-run", action="store_true", help="log Right Alt only")
    args = ap.parse_args()
    binary = args.binary

    selector = selectors.DefaultSelector()
    known: dict[str, evdev.InputDevice] = {}
    open_keyboards(selector, known)
    if not known:
        print("[ptt] no keyboard devices found; is the user in the input group?", file=sys.stderr)
        return 1

    pending_at: float | None = None
    held = False
    last_scan = time.monotonic()

    def run(*command: str) -> None:
        if args.dry_run:
            print("[ptt] would run:", binary, *command, flush=True)
            return
        try:
            subprocess.Popen([binary, *command], stdout=subprocess.DEVNULL,
                             stderr=subprocess.DEVNULL, start_new_session=True)
        except OSError as exc:
            print(f"[ptt] {binary} {' '.join(command)} failed: {exc}", file=sys.stderr)

    def start() -> None:
        nonlocal held
        held = True
        print("[ptt] down -> superwhisper record start", flush=True)
        run("record", "start")

    def stop() -> None:
        nonlocal held
        held = False
        print("[ptt] up -> superwhisper record stop", flush=True)
        run("record", "stop")

    try:
        while True:
            now = time.monotonic()
            if pending_at is not None and now >= pending_at:
                pending_at = None
                start()

            if now - last_scan >= RESCAN_SECONDS:
                last_scan = now
                open_keyboards(selector, known)

            for key, _mask in selector.select(timeout=0.05):
                device = key.fileobj
                path = device.path
                try:
                    events = list(device.read())
                except OSError:
                    forget(selector, known, path)
                    continue
                for event in events:
                    if event.type != ecodes.EV_KEY:
                        continue
                    if event.code == ecodes.KEY_RIGHTALT:
                        if event.value == 1 and not held and pending_at is None:
                            pending_at = time.monotonic() + START_DELAY
                        elif event.value == 0:
                            pending_at = None
                            if held:
                                stop()
                    elif event.value == 1 and pending_at is not None:
                        print("[ptt] chord detected, ignoring Right Alt", flush=True)
                        pending_at = None
    except KeyboardInterrupt:
        pass
    finally:
        if held:
            stop()
        for path in list(known):
            forget(selector, known, path)
        selector.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
