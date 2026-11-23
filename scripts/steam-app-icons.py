#!/usr/bin/env python3
"""Icons for the games Steam runs as non-Steam shortcuts (their windows have the class steam_app_<appid>).

Prints {"<appid>": "/path/to/icon", ...}: the icon chosen for the shortcut in Steam, or else its artwork in the
library grid (logo, then the small capsule). Steam's own games are not here: Steam installs their icons in the
icon theme as steam_icon_<appid>. Reads every Steam root (native and Flatpak) and every user.
"""
import json
import os
import struct
import sys
from pathlib import Path

HOME = Path.home()
ROOTS = [
    HOME / ".local/share/Steam",
    HOME / ".steam/steam",
    HOME / ".var/app/com.valvesoftware.Steam/.local/share/Steam",
]
ARTWORK = ["{}_logo.png", "{}p.png", "{}p.jpg", "{}.png", "{}.jpg"]


def parse_binary_vdf(data: bytes):
    """shortcuts.vdf: 0x00 map, 0x01 string, 0x02 int32, 0x08 end of map; keys and strings end in NUL."""
    pos = 0

    def cstring():
        nonlocal pos
        end = data.index(b"\0", pos)
        s = data[pos:end].decode("utf-8", "replace")
        pos = end + 1
        return s

    def parse_map():
        nonlocal pos
        out = {}
        while pos < len(data):
            kind = data[pos]
            pos += 1
            if kind == 0x08:
                return out
            key = cstring()
            if kind == 0x00:
                out[key] = parse_map()
            elif kind == 0x01:
                out[key] = cstring()
            elif kind == 0x02:
                out[key] = struct.unpack_from("<i", data, pos)[0]
                pos += 4
            else:
                raise ValueError(f"unknown type {kind:#x}")
        return out

    return parse_map()


def icons() -> dict:
    found = {}
    seen = set()
    for root in ROOTS:
        try:
            real = root.resolve(strict=True)
        except OSError:
            continue
        if real in seen:
            continue
        seen.add(real)
        for config in (real / "userdata").glob("*/config"):
            try:
                shortcuts = parse_binary_vdf((config / "shortcuts.vdf").read_bytes()).get("shortcuts", {})
            except (OSError, ValueError, IndexError, struct.error):
                continue
            for entry in shortcuts.values():
                if not isinstance(entry, dict):
                    continue
                lower = {k.lower(): v for k, v in entry.items()}
                if not isinstance(lower.get("appid"), int):
                    continue
                appid = str(lower["appid"] & 0xFFFFFFFF)
                if appid in found:
                    continue
                icon = str(lower.get("icon", "")).strip().strip('"')
                if icon and os.path.isfile(icon):
                    found[appid] = icon
                    continue
                for name in ARTWORK:
                    art = config / "grid" / name.format(appid)
                    if art.is_file():
                        found[appid] = str(art)
                        break
    return found


if __name__ == "__main__":
    json.dump(icons(), sys.stdout)
    sys.stdout.write("\n")
