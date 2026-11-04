#!/usr/bin/env python3
"""Звуковой сигнал при появлении значка рыбки в RF4.

Только читает экран (grim) и играет звук. В игру не вмешивается,
ввод не эмулирует.

Запуск:
    ./bite-alarm.py              # слежение, звук при поклёвке
    ./bite-alarm.py --verbose    # печатать число белых пикселей
    ./bite-alarm.py --stdin      # разобрать PPM из stdin (для теста)

Настройки через переменные окружения:
    BITE_REGION      область grim (по умолчанию "690,884 40x40")
    BITE_THRESHOLD   сколько белых пикселей считать значком (120)
    BITE_COOLDOWN    пауза между сигналами, сек (6)
    BITE_INTERVAL    пауза между кадрами, сек (0.15)
    BITE_SOUND       путь к wav (по умолчанию в XDG_CACHE_HOME)
"""

import json
import math
import os
import struct
import subprocess
import sys
import time
import wave

HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache"))
REGION = os.environ.get("BITE_REGION", "690,884 40x40")
THRESHOLD = int(os.environ.get("BITE_THRESHOLD", "120"))
COOLDOWN = float(os.environ.get("BITE_COOLDOWN", "6"))
SOUND = os.environ.get("BITE_SOUND", os.path.join(CACHE, "bite-alarm", "beep.wav"))
INTERVAL = float(os.environ.get("BITE_INTERVAL", "0.15"))
NEED_FRAMES = 2  # столько кадров подряд выше порога


def make_beep(path: str) -> None:
    if os.path.exists(path):
        return
    os.makedirs(os.path.dirname(path), exist_ok=True)
    rate = 48000
    dur = 0.28
    frames = []
    for i in range(int(rate * dur)):
        t = i / rate
        env = min(1.0, i / (rate * 0.01), (rate * dur - i) / (rate * 0.05))
        sample = 0.45 * math.sin(2 * math.pi * 880 * t) * max(0.0, env)
        frames.append(struct.pack("<h", int(sample * 32767)))
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(b"".join(frames))


def parse_ppm(data: bytes):
    if not data.startswith(b"P6"):
        raise ValueError("не PPM P6")
    idx = 2
    vals = []
    while len(vals) < 3:
        while idx < len(data) and data[idx] in b" \t\r\n":
            idx += 1
        if data[idx:idx + 1] == b"#":
            while idx < len(data) and data[idx] != 0x0A:
                idx += 1
            continue
        start = idx
        while idx < len(data) and data[idx] not in b" \t\r\n":
            idx += 1
        vals.append(int(data[start:idx]))
    idx += 1
    width, height, _ = vals
    return width, height, data[idx:idx + width * height * 3]


def white_pixels(px: bytes) -> int:
    n = 0
    for i in range(0, len(px) - 2, 3):
        r, g, b = px[i], px[i + 1], px[i + 2]
        mn = min(r, g, b)
        mx = max(r, g, b)
        if mn > 190 and mx - mn < 45:
            n += 1
    return n


def capture() -> bytes:
    res = subprocess.run(
        ["grim", "-g", REGION, "-t", "ppm", "-"],
        capture_output=True,
        check=True,
    )
    return res.stdout


def game_visible() -> bool:
    """Игра должна быть активна на HDMI, иначе grim снимет браузер/десктоп."""
    try:
        wins = json.loads(subprocess.check_output(
            ["niri", "msg", "--json", "windows"], stderr=subprocess.DEVNULL))
        wss = json.loads(subprocess.check_output(
            ["niri", "msg", "--json", "workspaces"], stderr=subprocess.DEVNULL))
    except Exception:  # noqa: BLE001
        return True  # не блокируем, если niri недоступен

    game = [w for w in wins
            if w.get("app_id") == "steam_app_0"
            or "Russian Fishing 4" in (w.get("title") or "")]
    if not game:
        return False

    active = {w["id"] for w in wss
              if w.get("is_active") and w.get("output") == "HDMI-A-1"}

    for w in game:
        if w.get("workspace_id") not in active:
            continue
        size = (w.get("layout") or {}).get("window_size") or [0, 0]
        if size[0] >= 2000 and size[1] >= 900:
            return True
    return False


def play() -> None:
    for player in (["pw-play", SOUND], ["paplay", SOUND], ["aplay", "-q", SOUND]):
        try:
            subprocess.Popen(player, stdout=subprocess.DEVNULL,
                             stderr=subprocess.DEVNULL)
            return
        except FileNotFoundError:
            continue


def main() -> int:
    verbose = "--verbose" in sys.argv
    once = "--once" in sys.argv

    if "--stdin" in sys.argv:
        n = white_pixels(parse_ppm(sys.stdin.buffer.read())[2])
        print(f"white={n} threshold={THRESHOLD} -> {'BITE' if n >= THRESHOLD else 'no'}")
        return 0

    make_beep(SOUND)
    print(f"region={REGION} threshold={THRESHOLD} cooldown={COOLDOWN}s")
    print("Ctrl+C — остановить")
    above = 0
    last_beep = 0.0
    last_check = 0.0
    visible = True

    while True:
        now = time.time()
        if now - last_check >= 1.0:
            visible = game_visible()
            last_check = now
            if verbose and not visible:
                print("игра не на экране — жду", flush=True)

        if not visible:
            above = 0
            time.sleep(0.3)
            continue

        try:
            n = white_pixels(parse_ppm(capture())[2])
        except Exception as exc:  # noqa: BLE001
            print(f"capture error: {exc}", file=sys.stderr)
            time.sleep(0.5)
            continue

        if verbose:
            print(f"white={n}", flush=True)

        if n >= THRESHOLD:
            above += 1
        else:
            above = 0

        if above >= NEED_FRAMES and (time.time() - last_beep) > COOLDOWN:
            print(f"ПОКЛЁВКА (white={n})", flush=True)
            play()
            last_beep = time.time()
            above = 0
            if once:
                return 0

        time.sleep(INTERVAL)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        print("\nстоп")
