#!/usr/bin/env python3
"""Apply activity wallpaper + colour scheme in one process.

Wallpaper CLI always regenerates colours; pairing it with `scheme set` meant
two full theme applies (~2× latency). Here we only update wallpaper files,
then regenerate and apply colours once.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path


def _patch_theme_quiet():
    import importlib.util

    # Reuse sylphrena-quiet patches (GTK live theme, Papirus via qt6ct, Kitty).
    quiet_path = Path(__file__).with_name("sylphrena-quiet.py")
    spec = importlib.util.spec_from_file_location("sylphrena_quiet", quiet_path)
    quiet = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(quiet)
    quiet._patch_theme()
    return quiet


def _set_light_apps(quiet, on: bool) -> None:
    """Light apps on or off before the apply, so GTK CSS, Qt palette and icons come out right in the same pass
    (the shell used to switch them after it, and they waited for the next apply)."""
    import subprocess

    flag = quiet._STATE / "force-apps-light"
    if on:
        flag.parent.mkdir(parents=True, exist_ok=True)
        flag.touch()
    else:
        flag.unlink(missing_ok=True)
    # cli.json: Qt theming off while apps stay light
    subprocess.run([sys.executable, str(Path(__file__).with_name("sync-light-apps-cli.py")),
                    "--light-apps" if on else "--no-light-apps"], check=False, stdin=subprocess.DEVNULL)


def _set_wallpaper_files(wall: Path) -> None:
    from sylphrena.utils.paths import (
        compute_hash,
        wallpaper_link_path,
        wallpaper_path_path,
        wallpaper_thumbnail_path,
        wallpapers_cache_dir,
    )
    from sylphrena.utils.wallpaper import (
        extract_first_frame,
        get_thumb,
        is_animated,
        is_valid_wallpaper,
    )

    wall = wall.resolve()
    if not is_valid_wallpaper(wall):
        raise ValueError(f'"{wall}" is not a valid image or video')

    # Match set_wallpaper(): animated → 1st frame for score/thumb only.
    wall_cache = extract_first_frame(wall) if is_animated(wall) else wall

    wallpaper_path_path.parent.mkdir(parents=True, exist_ok=True)
    wallpaper_path_path.write_text(str(wall))
    wallpaper_link_path.parent.mkdir(parents=True, exist_ok=True)
    wallpaper_link_path.unlink(missing_ok=True)
    wallpaper_link_path.symlink_to(wall)

    cache = wallpapers_cache_dir / compute_hash(wall_cache)
    thumb = get_thumb(wall_cache, cache)
    wallpaper_thumbnail_path.parent.mkdir(parents=True, exist_ok=True)
    wallpaper_thumbnail_path.unlink(missing_ok=True)
    wallpaper_thumbnail_path.symlink_to(thumb)


def _apply_scheme(
    name: str | None,
    flavour: str | None,
    mode: str | None,
    variant: str | None,
    *,
    force: bool,
) -> None:
    from sylphrena.utils.scheme import (
        get_scheme,
        get_scheme_flavours,
        get_scheme_modes,
        get_scheme_names,
        scheme_variants,
    )
    from sylphrena.utils.theme import apply_colours

    scheme = get_scheme()
    dirty = force

    if name and name != scheme._name:
        if name not in get_scheme_names():
            raise ValueError(f"Invalid scheme name: {name}")
        scheme._name = name
        scheme._check_flavour()
        scheme._check_mode()
        dirty = True

    if flavour and flavour != scheme._flavour:
        if flavour not in get_scheme_flavours(scheme._name):
            raise ValueError(f'Invalid scheme flavour: "{flavour}"')
        scheme._flavour = flavour
        scheme._check_mode()
        dirty = True

    if mode and mode != scheme._mode:
        if mode not in get_scheme_modes(scheme._name, scheme._flavour):
            # A flavour with one mode only (Catppuccin Latte is light): the mode wins, as the dark mode quick toggle
            # asks, so take the scheme's first flavour that has it
            sibling = next((f for f in get_scheme_flavours(scheme._name)
                            if mode in get_scheme_modes(scheme._name, f)), None)
            if sibling is None:
                raise ValueError(f'Invalid scheme mode: "{mode}"')
            print(f"{scheme._name} {scheme._flavour} has no {mode} mode: using {sibling}", file=sys.stderr)
            scheme._flavour = sibling
        scheme._mode = mode
        dirty = True

    if variant and variant != scheme._variant:
        if variant not in scheme_variants:
            raise ValueError(f'Invalid scheme variant: "{variant}"')
        scheme._variant = variant
        dirty = True

    # Dynamic scores the wallpaper thumbnail. Selecting/keeping "dynamic" or
    # syncing a wall must always regenerate — otherwise a scheme set with no
    # field changes keeps the previous wall's palette.
    if scheme._name == "dynamic" and (force or name == "dynamic"):
        dirty = True

    if not dirty:
        return

    # One colour regen + one theme apply (templates, hypr, kitty, …)
    scheme.update_colours()
    apply_colours(scheme.colours, scheme.mode)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--wallpaper", default="", help="wallpaper path (optional)")
    parser.add_argument("--name", default="", help="scheme name")
    parser.add_argument("--flavour", default="", help="scheme flavour")
    parser.add_argument("--mode", default="", choices=["", "dark", "light"])
    parser.add_argument("--variant", default="", help="scheme variant")
    parser.add_argument("--light-apps", default="", choices=["", "on", "off"], help="switch light apps in this apply")
    args = parser.parse_args()

    if not args.wallpaper and not any((args.name, args.flavour, args.mode, args.variant, args.light_apps)):
        print("nothing to apply", file=sys.stderr)
        return 1

    quiet = _patch_theme_quiet()
    if args.light_apps:
        _set_light_apps(quiet, args.light_apps == "on")

    wall_set = False
    if args.wallpaper:
        _set_wallpaper_files(Path(args.wallpaper))
        wall_set = True

    if wall_set or any((args.name, args.flavour, args.mode, args.variant, args.light_apps)):
        _apply_scheme(
            args.name or None,
            args.flavour or None,
            args.mode or None,
            args.variant or None,
            force=wall_set or bool(args.light_apps),
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
