#!/usr/bin/env python3
"""Make Veo, the video player of Sylphrena, the one that opens videos. Idempotent and done once; run by the installer
(also in --update, so it reaches machines that get Veo with an update) and usable by hand.

  setup-player.py            do it (once: after a first run it only reports, unless --force)
  setup-player.py --check    only say what it would do, change nothing
  setup-player.py --force    do it again even if it was done before

What it does, and nothing else:
  1. in ~/.config/mimeapps.list, [Default Applications]: Veo for each video type it declares, unless the user chose
     another app that is still installed (that choice is kept and reported);
  2. in ~/.config/sylphrena/shell.json, general.apps.playback = ["veo"] when it is empty or names a player that is not
     installed (the shell opens recordings with it).
Prints one JSON line: {"status", "changed": [...], "notes": [...]}; status is one of
  skipped (Veo is not installed) | done | already (nothing to do) | needed (--check: something to do) | seen (done before)
"""
import json
import os
import re
import shutil
import sys
from pathlib import Path

HOME = Path(os.environ.get("HOME") or Path.home())
CONFIG = Path(os.environ.get("XDG_CONFIG_HOME") or HOME / ".config")
DATA_DIRS = [Path(os.environ.get("XDG_DATA_HOME") or HOME / ".local/share"),
             *(Path(d) for d in (os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share").split(":") if d)]
MIMEAPPS = CONFIG / "mimeapps.list"
SHELL_JSON = CONFIG / "sylphrena" / "shell.json"
STATE = Path(os.environ.get("XDG_STATE_HOME") or HOME / ".local" / "state") / "sylphrena" / "player-setup.json"
DESKTOP = "veo.desktop"


def find_desktop(desktop_id: str) -> Path | None:
    for d in DATA_DIRS:
        p = d / "applications" / desktop_id
        if p.is_file():
            return p
    return None


def veo_installed() -> bool:
    return find_desktop(DESKTOP) is not None and (shutil.which("veo") is not None or (HOME / ".local/bin/veo").exists())


def veo_mimes() -> list[str]:
    text = find_desktop(DESKTOP).read_text(errors="replace")
    m = re.search(r"^MimeType=(.*)$", text, re.M)
    return [t for t in (m.group(1).split(";") if m else []) if t]


def read_defaults(text: str) -> dict[str, str]:
    """[Default Applications] of a mimeapps.list: type → first app."""
    out, inside = {}, False
    for line in text.splitlines():
        s = line.strip()
        if s.startswith("["):
            inside = s == "[Default Applications]"
        elif inside and "=" in s and not s.startswith("#"):
            k, v = s.split("=", 1)
            first = next((a for a in v.split(";") if a), "")
            if first:
                out[k.strip()] = first
    return out


def set_defaults(text: str, wanted: dict[str, str]) -> str:
    """The same file with these types set in [Default Applications] (the section is added if missing)."""
    lines = text.splitlines()
    start = next((i for i, ln in enumerate(lines) if ln.strip() == "[Default Applications]"), None)
    if start is None:
        if lines and lines[-1].strip():
            lines.append("")
        lines.append("[Default Applications]")
        start = len(lines) - 1
    end = next((i for i in range(start + 1, len(lines)) if lines[i].strip().startswith("[")), len(lines))
    pending = dict(wanted)
    for i in range(start + 1, end):
        key = lines[i].split("=", 1)[0].strip()
        if key in pending:
            lines[i] = f"{key}={pending.pop(key)};"
    lines[end:end] = [f"{k}={v};" for k, v in pending.items()]
    return "\n".join(lines) + "\n"


def plan() -> tuple[dict[str, str], bool, list[str]]:
    """(types to point at Veo, whether the shell's player changes, notes)."""
    notes = []
    current = read_defaults(MIMEAPPS.read_text(errors="replace")) if MIMEAPPS.is_file() else {}
    types = {}
    for t in veo_mimes():
        have = current.get(t)
        if have == DESKTOP:
            continue
        if have and find_desktop(have):
            notes.append(f"{t} keeps {have}, chosen by you")
            continue
        types[t] = DESKTOP
    shell_player = False
    try:
        cfg = json.loads(SHELL_JSON.read_text() or "{}")
        player = ((cfg.get("general") or {}).get("apps") or {}).get("playback") or []
        shell_player = not player or (player != ["veo"] and shutil.which(player[0]) is None)
    except (OSError, ValueError):
        pass
    return types, shell_player, notes


def write_atomic(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + ".sylphrena-tmp")
    tmp.write_text(text)
    os.replace(tmp, path)


def main() -> int:
    check, force = "--check" in sys.argv, "--force" in sys.argv

    def report(status: str, changed=(), notes=()) -> int:
        print(json.dumps({"status": status, "changed": list(changed), "notes": list(notes)}, ensure_ascii=False))
        return 0

    if not veo_installed():
        return report("skipped")
    if STATE.exists() and not force:
        return report("seen")
    types, shell_player, notes = plan()
    if not types and not shell_player:
        if not check:
            STATE.parent.mkdir(parents=True, exist_ok=True)
            STATE.write_text(json.dumps({"done": True, "changed": []}) + "\n")
        return report("already", notes=notes)
    if check:
        return report("needed", notes=notes)

    changed = []
    if types:
        write_atomic(MIMEAPPS, set_defaults(MIMEAPPS.read_text(errors="replace") if MIMEAPPS.is_file() else "", types))
        changed.append(f"{MIMEAPPS}: Veo opens {len(types)} video types")
    if shell_player:
        cfg = json.loads(SHELL_JSON.read_text() or "{}")
        cfg.setdefault("general", {}).setdefault("apps", {})["playback"] = ["veo"]
        write_atomic(SHELL_JSON, json.dumps(cfg, indent=4, ensure_ascii=False) + "\n")
        changed.append(f"{SHELL_JSON}: general.apps.playback = veo")
    STATE.parent.mkdir(parents=True, exist_ok=True)
    STATE.write_text(json.dumps({"done": True, "changed": changed}) + "\n")
    return report("done", changed, notes)


if __name__ == "__main__":
    sys.exit(main())
