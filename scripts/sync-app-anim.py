#!/usr/bin/env python3
"""Hand the shell's animation speed (appearance.anim.durations.scale) to the apps of the family: `animScale` in
~/.config/<app>/theme.json of Seeker, Things and Veo, without touching the rest. They watch the file and multiply their
durations by it, so a change in Nexus reaches them at once.

  sync-app-anim.py --scale 0.8
"""
from __future__ import annotations

import argparse
import json
import os
import tempfile
from pathlib import Path

CONFIG = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
APPS = ("seeker", "things", "veo")


def atomic_write(path: Path, text: str) -> None:
    fd, tmp = tempfile.mkstemp(dir=str(path.parent), prefix=".theme-", suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(text)
        os.replace(tmp, path)
    except Exception:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--scale", type=float, required=True)
    scale = max(0.0, min(5.0, p.parse_args().scale))
    for app in APPS:
        path = CONFIG / app / "theme.json"
        if not path.is_file():
            continue                    # the scheme apply writes it with the scale when the app gets its theme
        try:
            data = json.loads(path.read_text(encoding="utf-8") or "{}")
        except (OSError, json.JSONDecodeError):
            continue
        if not isinstance(data, dict) or data.get("animScale") == scale:
            continue
        data["animScale"] = scale
        atomic_write(path, json.dumps(data, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
