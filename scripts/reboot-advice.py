#!/usr/bin/env python3
"""Whether a restart is recommended after an update, and why.

    reboot-advice.py check                 what is known now
    reboot-advice.py record --since EPOCH  also look at what the update that started then installed

Prints JSON: {"kernel": bool, "packages": [names], "recommended": bool}.
- kernel: the running kernel's modules are gone (/usr/lib/modules/$(uname -r)), so a newer one is installed; reliable
  and needs no memory.
- packages: system pieces that only take effect after a restart (kernel, firmware, microcode, systemd, glibc, the
  graphics drivers), read from /var/log/pacman.log (its [ALPM] lines are always in English). They are kept in
  ~/.local/state/sylenara/reboot.json with the boot they belong to, so they are forgotten after the next restart.
"""
import json
import os
import re
import sys
from datetime import datetime
from pathlib import Path

PACMAN_LOG = Path(os.environ.get("SYLENARA_PACMAN_LOG", "/var/log/pacman.log"))
STATE = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "sylenara/reboot.json"
MODULES = Path(os.environ.get("SYLENARA_MODULES_DIR", "/usr/lib/modules"))
BOOT_ID = Path("/proc/sys/kernel/random/boot_id")

NEEDS_RESTART = re.compile(
    r"^(linux(-lts|-zen|-hardened|-rt|-rt-lts)?|linux-firmware(-[a-z0-9]+)?|amd-ucode|intel-ucode"
    r"|systemd|systemd-libs|glibc|lib32-glibc|mesa|lib32-mesa|vulkan-radeon|vulkan-intel|nvidia(-[a-z0-9]+)?"
    r"|dbus|dbus-broker)$"
)
LINE = re.compile(r"^\[(?P<ts>[^\]]+)\] \[ALPM\] (?:upgraded|installed|reinstalled|downgraded) (?P<pkg>\S+) ")


def boot_id() -> str:
    try:
        return BOOT_ID.read_text().strip()
    except OSError:
        return ""


def kernel_replaced() -> bool:
    return not (MODULES / os.uname().release).is_dir()


def stamp(text: str) -> float | None:
    for fmt in ("%Y-%m-%dT%H:%M:%S%z", "%Y-%m-%d %H:%M"):
        try:
            return datetime.strptime(text, fmt).timestamp()
        except ValueError:
            continue
    return None


def updated_since(since: float) -> list[str]:
    found: list[str] = []
    try:
        lines = PACMAN_LOG.read_text(errors="replace").splitlines()
    except OSError:
        return found
    for line in lines:
        m = LINE.match(line)
        if not m:
            continue
        when = stamp(m["ts"])
        if when is None or when < since:
            continue
        name = m["pkg"]
        if NEEDS_RESTART.match(name) and name not in found:
            found.append(name)
    return found


def load() -> list[str]:
    try:
        data = json.loads(STATE.read_text())
    except (OSError, ValueError):
        return []
    if data.get("bootId") != boot_id():
        return []  # from an earlier boot: already restarted since
    return [p for p in data.get("packages", []) if isinstance(p, str)]


def save(packages: list[str]) -> None:
    STATE.parent.mkdir(parents=True, exist_ok=True)
    tmp = STATE.with_suffix(".tmp")
    tmp.write_text(json.dumps({"bootId": boot_id(), "packages": packages}))
    tmp.replace(STATE)


def main(argv: list[str]) -> int:
    if not argv or argv[0] not in ("check", "record"):
        print(__doc__.strip().splitlines()[2:4], file=sys.stderr)
        return 2
    packages = load()
    if argv[0] == "record":
        try:
            since = float(argv[argv.index("--since") + 1])
        except (ValueError, IndexError):
            print("record needs --since EPOCH", file=sys.stderr)
            return 2
        for name in updated_since(since):
            if name not in packages:
                packages.append(name)
        save(packages)
    kernel = kernel_replaced()
    print(json.dumps({"kernel": kernel, "packages": packages, "recommended": kernel or bool(packages)}))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
