#!/usr/bin/env python3
"""Print the niri keybinding sheet as JSON.

Reads the live `~/.config/niri/binds.kdl` (a Home Manager symlink) so the
sheet always matches what the compositor loaded. Only the KDL shape this
repository writes is parsed: one bind per line, optional
`hotkey-overlay-title`, section comments of the form `// --- name ---`.
"""

import json
import os
import re
import sys

PATH = os.path.join(os.path.expanduser("~"), ".config/niri/binds.kdl")
SECTION = re.compile(r"^//\s*---\s*(.*?)\s*---\s*$")
BIND = re.compile(r'^(?P<keys>"[^"]+"|[^\s{]+)\s*(?P<rest>.*)$')
TITLE = re.compile(r'hotkey-overlay-title="((?:[^"\\]|\\.)*)"')
QUOTED = re.compile(r'"((?:[^"\\]|\\.)*)"')


def clean(value):
    value = value.strip()
    if len(value) >= 2 and value[0] == '"' and value[-1] == '"':
        return value[1:-1]
    return value


def action_label(action):
    """A readable fallback when a bind has no hotkey-overlay-title."""
    text = action.strip().rstrip(";").strip()
    if text.startswith("spawn "):
        parts = QUOTED.findall(text)
        if parts:
            return " ".join(parts[:3])
        return text[6:].strip()
    return text


def main():
    try:
        handle = open(PATH, encoding="utf-8")
    except OSError:
        json.dump({"sections": []}, sys.stdout)
        return

    sections = []
    current = {"title": "General", "items": []}
    with handle:
        for raw in handle:
            line = raw.strip()
            if not line:
                continue
            if line.startswith("//"):
                match = SECTION.match(line)
                if match:
                    if current["items"]:
                        sections.append(current)
                    title = re.sub(r"[\s-]+$", "", match.group(1)).strip()
                    current = {"title": title or "General", "items": []}
                continue
            if line in ("binds {", "}"):
                continue
            if line.startswith(("include ", "spawn-at-startup ")):
                continue

            match = BIND.match(line)
            if not match:
                continue
            keys = clean(match.group("keys"))
            rest = match.group("rest")

            title_match = TITLE.search(rest)
            title = title_match.group(1) if title_match else ""

            brace = rest.find("{")
            end = rest.rfind("}")
            if brace < 0 or end <= brace:
                continue
            action = rest[brace + 1:end].strip().rstrip(";").strip()
            if not action:
                continue

            current["items"].append({
                "keys": keys,
                "title": title or action_label(action),
                "action": action,
            })

    if current["items"]:
        sections.append(current)

    json.dump({"sections": sections}, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
