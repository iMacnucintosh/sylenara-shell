"""scripts/steam-app-icons.py: icons of non-Steam shortcuts from shortcuts.vdf and the library grid."""
import json
import os
import struct
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent.parent / "scripts" / "steam-app-icons.py"


def vdf_map(entries: dict) -> bytes:
    out = b""
    for key, value in entries.items():
        k = key.encode() + b"\0"
        if isinstance(value, dict):
            out += b"\x00" + k + vdf_map(value)
        elif isinstance(value, int):
            out += b"\x02" + k + struct.pack("<i", value)
        else:
            out += b"\x01" + k + value.encode() + b"\0"
    return out + b"\x08"


class SteamAppIcons(unittest.TestCase):
    def test_icon_then_artwork(self):
        with tempfile.TemporaryDirectory() as home:
            config = Path(home) / ".local/share/Steam/userdata/42/config"
            (config / "grid").mkdir(parents=True)
            icon = Path(home) / "My Icons" / "wow.png"
            icon.parent.mkdir()
            icon.write_bytes(b"png")
            (config / "grid" / "1000_logo.png").write_bytes(b"png")
            shortcuts = {"shortcuts": {
                # appid is stored as a signed int32: 4195243827 reads as -99723469
                "0": {"appid": 4195243827 - 2**32, "AppName": "World of Warcraft", "icon": f'"{icon}"'},
                "1": {"appid": 1000, "AppName": "No icon", "icon": ""},
                "2": {"appid": 2000, "AppName": "Missing icon", "icon": "/nope.png"},
            }}
            (config / "shortcuts.vdf").write_bytes(b"\x00" + b"shortcuts\0" + vdf_map(shortcuts["shortcuts"]) + b"\x08")
            out = subprocess.run([sys.executable, str(SCRIPT)], env={**os.environ, "HOME": home},
                                 capture_output=True, text=True, check=True)
            self.assertEqual(json.loads(out.stdout), {
                "4195243827": str(icon),
                "1000": str(config / "grid" / "1000_logo.png"),
            })

    def test_no_steam(self):
        with tempfile.TemporaryDirectory() as home:
            out = subprocess.run([sys.executable, str(SCRIPT)], env={**os.environ, "HOME": home},
                                 capture_output=True, text=True, check=True)
            self.assertEqual(json.loads(out.stdout), {})


if __name__ == "__main__":
    unittest.main()
