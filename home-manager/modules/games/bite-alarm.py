#!/usr/bin/env python3
"""Звуковой сигнал при появлении значка рыбки в RF4.

Только читает экран (grim) и играет звук. В игру не вмешивается,
ввод не эмулирует.

Запуск:
    ./bite-alarm.py              # слежение, звук при поклёвке
    ./bite-alarm.py --verbose    # печатать число белых пикселей
    ./bite-alarm.py --stdin      # разобрать PPM из stdin (для теста)

Настройки через переменные окружения:
    BITE_REGION      область grim (по умолчанию "692,886 36x36")
    BITE_SCORE       порог совпадения с шаблоном 0..1 (0.5)
    BITE_WHITE       порог яркости пикселя 0-255 (140; ночью значок тусклее)
    BITE_RECALL      минимум совпадения белых пикселей шаблона (0.6)
    BITE_SPEC        минимум совпадения тёмного фона шаблона (0.6)
    BITE_RELEASE     сколько кадров подряд без значка до перевзвода (3)
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
REGION = os.environ.get("BITE_REGION", "692,886 36x36")
WHITE_LEVEL = int(os.environ.get("BITE_WHITE", "140"))
SOUND = os.environ.get("BITE_SOUND", os.path.join(CACHE, "bite-alarm", "beep.wav"))
INTERVAL = float(os.environ.get("BITE_INTERVAL", "0.15"))
NEED_FRAMES = 2  # столько кадров подряд выше порога
RELEASE_FRAMES = int(os.environ.get("BITE_RELEASE", "3"))  # false-кадров до перевзвода
MATCH_SCORE = float(os.environ.get("BITE_SCORE", "0.5"))
MATCH_RECALL = float(os.environ.get("BITE_RECALL", "0.6"))
MATCH_SPEC = float(os.environ.get("BITE_SPEC", "0.6"))

# Бинарный шаблон значка (30x30), снят с дневного кадра при WHITE_LEVEL=140.
TEMPLATE = [
    "000000000111111111111000000000",
    "000000011111111111111110000000",
    "000000111111111111111111000000",
    "000011111111000000111111110000",
    "000111111000000000000111111000",
    "000111110000000000000011111000",
    "001111100000000000000001111100",
    "011111000000000000000000111110",
    "011110000000000000000000011110",
    "111100010000001110000000001111",
    "111100110001111110111000001111",
    "111100110011111110111110001111",
    "111000111111111110111111000111",
    "111000111111111101111111000111",
    "111000011111111101111111100111",
    "111000011111111101111111100111",
    "111000111111111101111111000111",
    "111000111111111110111111000111",
    "111100110011111110111110001111",
    "111100110001111110111000001111",
    "111100010000001110000000001111",
    "011110000000000000000000011110",
    "011111000000000000000000111110",
    "001111100000000000000001111100",
    "000111110000000000000011111000",
    "000111111000000000000111111000",
    "000011111111000000111111110000",
    "000000111111111111111111000000",
    "000000011111111111111110000000",
    "000000000111111111111000000000",
]
TW = TH = len(TEMPLATE)
T_ONES = sum(row.count("1") for row in TEMPLATE)
T_ZEROS = TW * TH - T_ONES


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


def match_icon(px: bytes, w: int, h: int):
    """Сравнивает область с шаблоном значка. Возвращает (score, recall, spec)."""
    bright = bytearray(w * h)
    for idx in range(w * h):
        i = idx * 3
        r, g, b = px[i], px[i + 1], px[i + 2]
        mn = min(r, g, b)
        mx = max(r, g, b)
        bright[idx] = 1 if (mn > WHITE_LEVEL and mx - mn < 45) else 0

    best = (0.0, 0.0, 0.0, 0, 0)
    for dy in range(h - TH + 1):
        for dx in range(w - TW + 1):
            ones = zeros = 0
            for y in range(TH):
                row = TEMPLATE[y]
                base = (y + dy) * w + dx
                for x in range(TW):
                    if row[x] == "1":
                        ones += bright[base + x]
                    else:
                        zeros += 1 - bright[base + x]
            rec = ones / T_ONES
            spec = zeros / T_ZEROS
            score = rec * spec
            if score > best[0]:
                best = (score, rec, spec, dx, dy)
    return best[0], best[1], best[2]


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

    if "--beep" in sys.argv:
        make_beep(SOUND)
        count = 2 if "--double" in sys.argv else 1
        for i in range(count):
            for player in (["pw-play", SOUND], ["paplay", SOUND], ["aplay", "-q", SOUND]):
                try:
                    subprocess.run(player, stdout=subprocess.DEVNULL,
                                   stderr=subprocess.DEVNULL, check=False)
                    break
                except FileNotFoundError:
                    continue
            if i + 1 < count:
                time.sleep(0.15)
        return 0

    if "--stdin" in sys.argv:
        w, h, px = parse_ppm(sys.stdin.buffer.read())
        score, rec, spec = match_icon(px, w, h)
        ok = score >= MATCH_SCORE and rec >= MATCH_RECALL and spec >= MATCH_SPEC
        print(f"score={score:.2f} rec={rec:.2f} spec={spec:.2f} -> "
              f"{'BITE' if ok else 'no'}")
        return 0

    make_beep(SOUND)
    print(f"region={REGION} score>={MATCH_SCORE} interval={INTERVAL}s "
          f"release={RELEASE_FRAMES}")
    print("Ctrl+C — остановить")
    above = 0
    below = 0
    armed = True
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
            w, h, px = parse_ppm(capture())
            score, rec, spec = match_icon(px, w, h)
        except Exception as exc:  # noqa: BLE001
            print(f"capture error: {exc}", file=sys.stderr)
            time.sleep(0.5)
            continue

        if verbose:
            print(f"score={score:.2f} rec={rec:.2f} spec={spec:.2f}", flush=True)

        if score >= MATCH_SCORE and rec >= MATCH_RECALL and spec >= MATCH_SPEC:
            above += 1
            below = 0
            if above >= NEED_FRAMES and armed:
                print(f"ПОКЛЁВКА (score={score:.2f})", flush=True)
                play()
                armed = False
                if once:
                    return 0
        else:
            above = 0
            below += 1
            if below >= RELEASE_FRAMES:
                armed = True

        time.sleep(INTERVAL)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        print("\nстоп")
