#!/usr/bin/env python3
"""Run the lunele CLI without broadcasting OSC colour sequences to every PTY.

apply_terms() writes ANSI OSC dumps to all /dev/pts devices. Some clients
(e.g. IDE embedded terminals) surface that as a system notification. We still
persist sequences.txt so new shells can pick up colours, but skip the broadcast.

After colours are applied (including user templates like kitty.conf), push the
palette into open Kitty windows via remote control.
"""

from __future__ import annotations

import os
import runpy
import subprocess
import sys
from pathlib import Path


def _display_name() -> str:
    """The name the login screen greets: the user's full name (GECOS), else the account name."""
    try:
        import pwd

        full = pwd.getpwuid(os.getuid()).pw_gecos.split(",")[0].strip()
        if full:
            return full.split()[0]
    except (ImportError, KeyError, OSError):
        pass
    return Path.home().name


def _weather_location() -> str:
    """"lat,lon" the user chose for the weather in Nexus (shell.json), or "" (the greeter then shows no weather)."""
    import json

    base = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
    try:
        value = json.loads((base / "lunele" / "shell.json").read_text())["services"]["weatherLocation"]
    except (OSError, ValueError, KeyError, TypeError):
        return ""
    return value if isinstance(value, str) and "," in value else ""

_XDG_CONFIG = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
_XDG_STATE = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state")


def _app_dir(base: Path) -> Path:
    return base / "lunele"


def _env_dir(name: str, default: Path) -> Path:
    value = os.environ.get(f"LUNELE_{name}")
    return Path(value) if value else default


def _atomic_write(path: Path, text: str) -> None:
    """Temp-file + os.replace: readers never see a half-written file, and the
    rename is what qt6ct's directory-scoped QFileSystemWatcher picks up live."""
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + ".tmp")
    tmp.write_text(text)
    os.replace(tmp, path)


def _reload_kitty() -> None:
    # The script that ships with the shell; a copy in the user's config (older setups) is the fallback
    script = Path(__file__).with_name("kitty-reload-colours.sh")
    if not script.is_file():
        script = Path.home() / ".config/lunele/scripts/kitty-reload-colours.sh"
    if not script.is_file():
        return
    try:
        subprocess.run([str(script)], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except OSError:
        pass


# QPalette::ColorRole enum order (Qt ≥ 6.6: 22 roles, Accent at 21). qt6ct maps
# scheme list index i → ColorRole(i), so this order is the file format.
_QT_ROLE_KEYS = (
    ("WindowText", "onSurface"),
    ("Button", "surfaceContainer"),
    ("Light", "surfaceBright"),
    ("Midlight", "surfaceContainerHigh"),
    ("Dark", "surfaceContainerLowest"),
    ("Mid", "surfaceContainerLow"),
    ("Text", "onSurface"),
    ("BrightText", "onSurface"),
    ("ButtonText", "onSurface"),
    ("Base", "surfaceContainerLowest"),
    ("Window", "surface"),
    ("Shadow", "shadow"),
    ("Highlight", "primary"),
    ("HighlightedText", "onPrimary"),
    ("Link", "primary"),
    ("LinkVisited", "tertiary"),
    ("AlternateBase", "surfaceContainer"),
    ("NoRole", "surface"),
    ("ToolTipBase", "surfaceContainerHighest"),
    ("ToolTipText", "onSurfaceVariant"),
    ("PlaceholderText", "outline"),
    ("Accent", "primary"),
)
# Disabled-state roles that read as text/selection get a muted tone instead.
_QT_DISABLED_MUTED = {
    "WindowText": "outline",
    "Text": "outline",
    "ButtonText": "outline",
    "PlaceholderText": "outlineVariant",
    "HighlightedText": "onSurface",
    "Highlight": "outlineVariant",
    "Accent": "outlineVariant",
}


def _qt6ct_scheme_body(colours: dict[str, str], mode: str) -> str:
    """Build the [ColorScheme] block from the scheme's Material tokens."""

    def token(key: str) -> str:
        # All roles are defined by the scheme generator; the fallback only
        # exists as a guard against scheme drift.
        return f"#{colours.get(key) or colours.get('surface') or '000000'}"

    active = [token(key) for _, key in _QT_ROLE_KEYS]
    inactive = list(active)
    disabled = [
        token(_QT_DISABLED_MUTED.get(role, fallback_key))
        for role, fallback_key in _QT_ROLE_KEYS
    ]

    def line(name: str, values: list[str]) -> str:
        return f"{name}=" + ", ".join(values)

    rows = (line("active_colors", active), line("inactive_colors", inactive), line("disabled_colors", disabled))
    return "[ColorScheme]\n" + "\n".join(rows) + "\n"


def _light_qt_colours(colours: dict[str, str]) -> dict[str, str]:
    """Light palette for Qt apps under "light apps", derived from the scheme's inverse tokens
    (inverseSurface/inverseOnSurface/inversePrimary are the light-mode counterparts of a dark scheme)."""

    def rgb(h: str) -> tuple[int, int, int]:
        return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)

    def mix(a: str, b: str, t: float) -> str:
        ra, rb = rgb(a), rgb(b)
        return "".join(f"{round(x + (y - x) * t):02x}" for x, y in zip(ra, rb))

    surf = colours.get("inverseSurface") or "e9e1dc"
    text = colours.get("inverseOnSurface") or "33302d"
    acc = colours.get("inversePrimary") or colours.get("primary") or "75593b"
    out = dict(colours)
    out.update(
        surface=surf,
        surfaceContainerLowest=mix(surf, "ffffff", 0.7),
        surfaceContainerLow=mix(surf, "ffffff", 0.35),
        surfaceContainer=mix(surf, text, 0.05),
        surfaceContainerHigh=mix(surf, text, 0.09),
        surfaceContainerHighest=mix(surf, text, 0.13),
        surfaceBright=mix(surf, "ffffff", 0.6),
        onSurface=text,
        onSurfaceVariant=mix(text, surf, 0.25),
        outline=mix(text, surf, 0.5),
        outlineVariant=mix(text, surf, 0.7),
        primary=acc,
        onPrimary="ffffff",
        tertiary=acc,
        shadow="000000",
    )
    return out


def _sync_qt6ct(colours: dict[str, str], mode: str, light_apps: bool = False) -> None:
    """Write the qt6ct scheme + config from the scheme's Material tokens.

    qt6ct is our Qt platform theme since leaving QT_QPA_PLATFORMTHEME=kde:
    icon_theme + custom palette live in ~/.config/qt6ct/qt6ct.conf, the palette
    itself in colors/lunele.conf. Both files are replaced atomically so
    qt6ct's directory watcher applies icon and colour changes to running Qt
    apps (VLC, transmission-qt, …) without restart.
    """
    import configparser

    colors_dir = Path.home() / ".config/qt6ct/colors"
    scheme_path = colors_dir / "lunele.conf"
    _atomic_write(scheme_path, _qt6ct_scheme_body(_light_qt_colours(colours) if light_apps else colours, mode))

    icon_mode = "light" if light_apps else mode
    icon_theme = f"Papirus-{icon_mode.capitalize()}" if icon_mode in ("dark", "light") else "Papirus-Dark"
    conf = Path.home() / ".config/qt6ct/qt6ct.conf"
    parser = configparser.ConfigParser(interpolation=None, strict=False)
    try:
        parser.read(conf, encoding="utf-8")
    except (OSError, configparser.Error):
        parser = configparser.ConfigParser(interpolation=None, strict=False)
    if not parser.has_section("Appearance"):
        parser.add_section("Appearance")
    parser.set("Appearance", "icon_theme", icon_theme)
    parser.set("Appearance", "custom_palette", "true")
    parser.set("Appearance", "color_scheme_path", str(scheme_path))
    parser.set("Appearance", "style", "Fusion")
    import io

    buf = io.StringIO()
    parser.write(buf)
    _atomic_write(conf, buf.getvalue())


# --- Greeter (Quickshell): palette + wallpaper for /etc/greetd/lunele -------

_GREETER_DIR = _env_dir("GREETER_DIR", Path("/etc/greetd/lunele"))
# The only part of it the session may write (scripts/system/10-greeter.sh): the rest is root's
_GREETER_DATA = _GREETER_DIR / "user"
_STATE = _app_dir(_XDG_STATE)
_SCHEME_JSON = _STATE / "scheme.json"
_WALLPAPER_LINK = _STATE / "wallpaper/current"
_FACE = Path.home() / ".face"
_FONT_SRC = Path(__file__).resolve().parent.parent / "assets/google-sans-flex/GoogleSansFlex-VariableFont_GRAD,ROND,opsz,slnt,wdth,wght.ttf"


def _greeter_copy(src: Path, dst: Path) -> None:
    """Best-effort copy; greeter dir may not exist or be root-owned yet."""
    import hashlib

    if not src.is_file() and not src.is_symlink():
        return
    try:
        src_bytes = src.resolve().read_bytes()
    except OSError:
        return
    digest = hashlib.sha256(src_bytes).hexdigest()
    marker = dst.with_name(dst.name + ".sha256")
    try:
        if dst.is_file() and marker.is_file() and marker.read_text().strip() == digest:
            return
        dst.parent.mkdir(parents=True, exist_ok=True)
        tmp = dst.with_name(dst.name + ".tmp")
        tmp.write_bytes(src_bytes)
        os.replace(tmp, dst)
        tmp_marker = marker.with_name(marker.name + ".tmp")
        tmp_marker.write_text(digest)
        os.replace(tmp_marker, marker)
    except OSError:
        pass


def _sync_greeter(colours: dict[str, str] | None = None) -> None:
    """Push greeter assets: scheme.json, greeter.json, wallpaper, face, font.

    Blur is done in QML (MultiEffect blurMax 64), so we only copy the raw
    wallpaper. All scheme/wallpaper applies go through apply_colours_quiet;
    wallpaper CLI hits this from main()'s finally.
    """
    import json

    if not _GREETER_DATA.is_dir():
        return  # login screen not installed (or installed before user/ existed: install-system.sh moves it)

    # Palette: prefer the live colours dict, else the persisted scheme.json.
    scheme: dict = {}
    try:
        if _SCHEME_JSON.is_file():
            scheme = json.loads(_SCHEME_JSON.read_text() or "{}")
            if not isinstance(scheme, dict):
                scheme = {}
    except (OSError, ValueError):
        scheme = {}

    if colours:
        scheme = dict(scheme)
        scheme["colours"] = colours

    if scheme.get("colours"):
        try:
            _atomic_write(
                _GREETER_DATA / "scheme.json",
                json.dumps(scheme, indent=2) + "\n",
            )
        except OSError:
            pass

    # Static-ish greeter config (user, location). Rewritten so a fresh install
    # always picks up the current session user without a separate setup step.
    greeter_cfg = {
        "user": Path.home().name,
        "displayName": _display_name(),
        "location": _weather_location(),
    }
    try:
        _atomic_write(_GREETER_DATA / "greeter.json", json.dumps(greeter_cfg, indent=2) + "\n")
    except OSError:
        pass

    # Wallpaper: a raw copy (the greeter blurs it). The login screen's QML is not copied from here: it is root's
    # and comes with install-system.sh (also run by the installer's update when the shell changes)
    _greeter_copy(_WALLPAPER_LINK, _GREETER_DATA / "wallpaper")
    # Avatar: greeter user cannot read ~/.face.
    _greeter_copy(_FACE, _GREETER_DATA / "face")
    # Google Sans Flex: copied once at install, refreshed if the asset changes.
    _greeter_copy(_FONT_SRC, _GREETER_DATA / "fonts" / "GoogleSansFlex.ttf")


def _light_gtk_css(filename: str, text: str) -> str:
    """Light-apps version of a GTK CSS the CLI generated (see gtk-light-css.py)."""
    import importlib.util

    spec = importlib.util.spec_from_file_location("gtk_light_css", Path(__file__).with_name("gtk-light-css.py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.light_css(filename, text)


def _sync_gtk_settings(mode: str, light_apps: bool = False) -> None:
    """Point GTK at the correct adw-gtk3 variant and enable live CSS reload.

    With light apps the GTK theme must be the LIGHT variant even if the shell scheme is dark:
    Chromium/Electron (Teams, Cursor…) take their dark mode from the GTK theme name, which beats
    the portal's color-scheme=prefer-light. A dark theme name kept them dark at login and again
    whenever the theme name changed.
    """
    dark = mode == "dark" and not light_apps
    gtk_theme = "adw-gtk3-dark" if dark else "adw-gtk3"
    icon_mode = "dark" if dark else "light"  # dark icons on light apps (Papirus-Dark vanishes on white)
    icon_theme = f"Papirus-{icon_mode.capitalize()}"
    prefer = "true" if dark else "false"
    body = (
        "[Settings]\n"
        f"gtk-theme-name={gtk_theme}\n"
        f"gtk-application-prefer-dark-theme={prefer}\n"
        f"gtk-icon-theme-name={icon_theme}\n"
        "gtk-cursor-theme-name=Adwaita\n"
        "gtk-cursor-theme-size=24\n"
        "gtk-font-name=Noto Sans 10\n"
        "gtk-modules=colorreload-gtk-module\n"
        "gtk-xft-dpi=98304\n"
    )
    for ver in ("gtk-3.0", "gtk-4.0"):
        path = Path.home() / f".config/{ver}/settings.ini"
        try:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(body)
        except OSError:
            pass

    key = "/org/gnome/desktop/interface/gtk-theme"
    try:
        cur = subprocess.run(
            ["dconf", "read", key],
            check=False,
            capture_output=True,
            text=True,
            stdin=subprocess.DEVNULL,
        ).stdout.strip()
        if cur != f"'{gtk_theme}'":  # a write is a change event for every running app
            subprocess.run(
                ["dconf", "write", key, f"'{gtk_theme}'"],
                check=False,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
    except OSError:
        pass


def _trigger_gtk_color_reload() -> None:
    """kde-gtk-config's colorreload module watches ~/.config/gtk-3.0/colors.css
    (not gtk.css). Mirror our Material/Thunar styles there and bump a stamp so
    open Thunar windows pick up activity scheme changes live.
    """
    import time

    # gtk.css is read back below: while staged it is not published yet
    if _Stage.active is not None:
        _Stage.active.after.insert(0, _trigger_gtk_color_reload)
        return
    stamp = f"/* lunele-reload {time.time_ns()} */\n"
    for ver in ("gtk-3.0", "gtk-4.0"):
        base = Path.home() / f".config/{ver}"
        gtk_css = base / "gtk.css"
        colors = base / "colors.css"
        try:
            if not gtk_css.is_file():
                continue
            # Inline thunar.css so the provider does not depend on @import caching
            text = gtk_css.read_text()
            thunar = base / "thunar.css"
            if thunar.is_file() and '@import "thunar.css"' in text:
                text = text.replace('@import "thunar.css";', thunar.read_text())
            colors.write_text(stamp + text)
        except OSError:
            pass


class _Stage:
    """Hold back what the apps see until everything is ready, then publish it in one go.

    Each app repaints when its own file (or a dconf key) changes, and the apply writes them one after another over
    ~150 ms. While a stage is open, atomic renames (``os.replace``, which every theme file goes through) and
    ``dconf write`` are recorded instead; ``commit`` renames all files, writes the dconf keys that end up different
    (one value per key: no adw-gtk3-dark → adw-gtk3 flip) and then runs what had to wait for them (GTK colour reload,
    the CLI postHook). The temp files are already on disk, so publishing takes a few milliseconds.
    """

    active: "_Stage | None" = None

    def __init__(self) -> None:
        self.renames: dict[str, str] = {}
        self.dconf: dict[str, str] = {}
        self.after: list = []
        self._replace = os.replace
        self._run = subprocess.run

    def __enter__(self) -> "_Stage":
        def replace(src, dst, *args, **kwargs):
            if args or kwargs:
                return self._replace(src, dst, *args, **kwargs)
            dst = os.fspath(dst)
            old = self.renames.pop(dst, None)
            if old is not None and old != os.fspath(src):
                try:
                    os.unlink(old)
                except OSError:
                    pass
            self.renames[dst] = os.fspath(src)

        def run(cmd, *args, **kwargs):
            if isinstance(cmd, (list, tuple)) and len(cmd) >= 3 and cmd[0] == "dconf":
                if cmd[1] == "write" and len(cmd) == 4:
                    self.dconf[cmd[2]] = cmd[3]
                    return subprocess.CompletedProcess(cmd, 0, "", "")
                if cmd[1] == "read" and cmd[2] in self.dconf:
                    out = self.dconf[cmd[2]] + "\n"
                    return subprocess.CompletedProcess(cmd, 0, out if kwargs.get("text") else out.encode(), "")
            # The CLI postHook (a shell string: kitty reload, prefer-light) must see the published files
            if kwargs.get("shell"):
                self.after.append(lambda: self._run(cmd, *args, **kwargs))
                return subprocess.CompletedProcess(cmd, 0, "", "")
            return self._run(cmd, *args, **kwargs)

        os.replace = replace
        subprocess.run = run
        _Stage.active = self
        return self

    def __exit__(self, *exc) -> None:
        os.replace = self._replace
        subprocess.run = self._run
        _Stage.active = None
        self.commit()

    def commit(self) -> None:
        for dst, src in self.renames.items():
            try:
                os.replace(src, dst)
            except OSError:
                pass
        self.renames.clear()
        changed = {}
        for key, value in self.dconf.items():
            cur = subprocess.run(["dconf", "read", key], check=False, capture_output=True, text=True,
                                 stdin=subprocess.DEVNULL).stdout.strip()
            if cur != value:  # a write is a change event for every running app
                changed[key] = value
        # One dconf process for every key, so the portal and the GTK theme change together
        by_dir: dict[str, list[str]] = {}
        for key, value in changed.items():
            folder, name = key.rsplit("/", 1)
            by_dir.setdefault(folder + "/", []).append(f"{name}={value}")
        for folder, lines in by_dir.items():
            subprocess.run(["dconf", "load", folder], input="[/]\n" + "\n".join(lines) + "\n", text=True,
                           check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        for fn in self.after:
            try:
                fn()
            except Exception:
                pass
        self.after.clear()


def _patch_theme() -> None:
    import atexit

    import lunele.utils.scheme as scheme_mod
    import lunele.utils.theme as theme
    from lunele.utils.paths import c_state_dir

    # The shell repaints the moment scheme.json changes; the apps when their own files do, written by
    # apply_colours a few hundred ms later. Save scheme.json last so the shell and the apps switch together;
    # atexit covers a save with no apply after it
    orig_save = scheme_mod.Scheme.save
    pending_saves: list = []

    def deferred_save(self) -> None:
        if self not in pending_saves:
            pending_saves.append(self)

    def flush_saves() -> None:
        while pending_saves:
            orig_save(pending_saves.pop(0))

    scheme_mod.Scheme.save = deferred_save
    atexit.register(flush_saves)

    # Chrome's policy refresh blocks ~0.3 s in the middle of the apply: let it finish on its own
    orig_apply_chromium = theme.apply_chromium

    def apply_chromium_detached(colours: dict[str, str]) -> None:
        real_run = subprocess.run

        def run(cmd, *args, **kwargs):
            if isinstance(cmd, (list, tuple)) and "--refresh-platform-policy" in cmd:
                subprocess.Popen(cmd, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                                 stderr=subprocess.DEVNULL, start_new_session=True)
                return subprocess.CompletedProcess(cmd, 0)
            return real_run(cmd, *args, **kwargs)

        subprocess.run = run
        try:
            orig_apply_chromium(colours)
        finally:
            subprocess.run = real_run

    theme.apply_chromium = apply_chromium_detached

    def apply_terms_quiet(sequences: str) -> None:
        state = c_state_dir / "sequences.txt"
        state.parent.mkdir(parents=True, exist_ok=True)
        state.write_text(sequences)

    orig_apply_gtk = theme.apply_gtk

    scheme_key = "/org/gnome/desktop/interface/color-scheme"
    gtk_theme_key = "/org/gnome/desktop/interface/gtk-theme"

    def apply_gtk_fixed(colours: dict[str, str], mode: str, icon_theme: str | None = None) -> None:
        flag = _STATE / "force-apps-light"
        light_apps = flag.is_file()
        real_run = subprocess.run

        def run_keep_scheme(cmd, *args, **kwargs):
            # Upstream writes prefer-{mode} (dark in dark activities). With light apps
            # that dark value would only be undone ~20 ms later, and apps that follow
            # the portal live (Zen, Electron) flash dark→light on every apply.
            if isinstance(cmd, (list, tuple)) and scheme_key in cmd:
                return subprocess.CompletedProcess(cmd, 0)
            # Upstream also writes gtk-theme='adw-gtk3-dark' on every apply; with light apps that
            # would turn Chromium/Electron dark (see _sync_gtk_settings). We write the right one.
            if isinstance(cmd, (list, tuple)) and gtk_theme_key in cmd:
                return subprocess.CompletedProcess(cmd, 0)
            return real_run(cmd, *args, **kwargs)

        # With light apps the scheme's dark GTK colours must never reach GTK apps (black headers and
        # inputs over the light theme): filter the CSS while the CLI writes it, so there is no dark
        # flash either.
        orig_atomic_write = getattr(theme, "atomic_write", None)

        def atomic_write_light(path, content, *args, **kwargs):
            p = Path(path)
            if p.name in ("gtk.css", "thunar.css") and p.parent.name in ("gtk-3.0", "gtk-4.0") and isinstance(content, str):
                content = _light_gtk_css(p.name, content)
            return orig_atomic_write(path, content, *args, **kwargs)

        # Upstream always writes adw-gtk3-dark; use the light variant for light mode.
        if light_apps:
            subprocess.run = run_keep_scheme
            if orig_atomic_write is not None:
                theme.atomic_write = atomic_write_light
        try:
            orig_apply_gtk(colours, mode, "Papirus-Light" if light_apps else icon_theme)
        finally:
            subprocess.run = real_run
            if orig_atomic_write is not None:
                theme.atomic_write = orig_atomic_write
        _sync_gtk_settings(mode, light_apps)
        _trigger_gtk_color_reload()
        # Light apps: keep prefer-light so Adwaita/Qt apps stay light while Thunar
        # keeps scheme CSS. Only write it when it is not already set.
        if light_apps:
            try:
                cur = real_run(
                    ["dconf", "read", scheme_key],
                    check=False,
                    capture_output=True,
                    text=True,
                    stdin=subprocess.DEVNULL,
                ).stdout.strip()
                if cur != "'prefer-light'":
                    real_run(
                        ["dconf", "write", scheme_key, "'prefer-light'"],
                        check=False,
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL,
                    )
            except OSError:
                pass

    theme.apply_gtk = apply_gtk_fixed

    orig_apply_colours = theme.apply_colours

    def apply_colours_quiet(colours: dict[str, str], mode: str) -> None:
        # Ensure GTK theming is on even if a stale light-apps sync flipped the flag.
        try:
            from lunele.utils.paths import user_config_path

            if user_config_path.is_file():
                import json

                cfg = json.loads(user_config_path.read_text() or "{}")
                theme_cfg = cfg.setdefault("theme", {})
                if theme_cfg.get("enableGtk") is False:
                    theme_cfg["enableGtk"] = True
                    user_config_path.write_text(json.dumps(cfg, indent=4) + "\n")
        except Exception:
            pass

        # Everything the apps see is prepared first and published at once (_Stage), the shell's scheme.json just
        # after it: the shell and the apps switch in the same few milliseconds
        with _Stage():
            orig_apply_colours(colours, mode)
            # Always push GTK/Thunar + colors.css reload stamp (colorreload watches
            # colors.css, not gtk.css — without this, open Thunar keeps stale styles).
            try:
                theme.apply_gtk(colours, mode)
            except Exception:
                pass
            _sync_qt6ct(colours, mode, (_STATE / "force-apps-light").is_file())
            _sync_seeker(colours, mode)
            _sync_things(colours, mode)
            _sync_veo(colours, mode)
        flush_saves()
        # Templates land inside apply_colours; refresh Kitty after that.
        _reload_kitty()
        # Not on screen now (login screen, OpenCode theme file): after the switch
        _sync_greeter(colours)
        _sync_opencode_theme(colours, mode)

    theme.apply_terms = apply_terms_quiet
    theme.apply_colours = apply_colours_quiet


def _write_qt_app_theme(app: str, colours: dict[str, str], mode: str) -> None:
    """Write Material tokens for a Qt/QML app that hot-reloads ~/.config/<app>/theme.json.

    Colours are stored without '#'; the apps accept both forms.
    Transparency mirrors shell appearance.transparency so the apps match drawers.
    """
    import json as _json

    if not colours:
        return
    tr_enabled: bool | None = None  # None = could not read the shell config
    tr_base = 0.85
    try:
        from lunele.utils.paths import user_config_path

        if user_config_path.is_file():
            cfg = _json.loads(user_config_path.read_text() or "{}")
            tr = (cfg.get("appearance") or {}).get("transparency") or {}
            if isinstance(tr, dict):
                tr_enabled = bool(tr.get("enabled", False))
                tr_base = float(tr.get("base", 0.85))
    except Exception:
        pass
    out = _XDG_CONFIG / app / "theme.json"
    # The shell (Colours.syncSeekerTransparency) owns base/layers/wallLuminance: base is already
    # adjusted for light mode there. Keep what it wrote instead of resetting it on every scheme apply.
    tr_layers = 0.4
    tr_wall = 0.5
    try:
        if out.is_file():
            old_tr = (_json.loads(out.read_text() or "{}").get("transparency")) or {}
            if isinstance(old_tr, dict):
                if tr_enabled is None:
                    # Shell config unreadable here: keep what the shell last synced instead of
                    # silently switching Seeker's transparency off on every scheme apply.
                    tr_enabled = bool(old_tr.get("enabled", False))
                tr_base = float(old_tr.get("base", tr_base))
                tr_layers = float(old_tr.get("layers", tr_layers))
                tr_wall = float(old_tr.get("wallLuminance", tr_wall))
    except Exception:
        pass
    if tr_enabled is None:
        tr_enabled = False
    # The shell's animation speed (Nexus): the apps multiply their durations by it (sync-app-anim.py keeps it current)
    anim_scale = 1.0
    try:
        from lunele.utils.paths import user_config_path

        if user_config_path.is_file():
            cfg = _json.loads(user_config_path.read_text() or "{}")
            anim_scale = float((((cfg.get("appearance") or {}).get("anim") or {}).get("durations") or {}).get("scale", 1.0))
    except Exception:
        pass
    payload = {
        "mode": mode if mode in ("dark", "light") else "dark",
        "colours": {k: (v[1:] if isinstance(v, str) and v.startswith("#") else v) for k, v in colours.items()},
        "transparency": {"enabled": tr_enabled, "base": tr_base, "layers": tr_layers, "wallLuminance": tr_wall},
        "animScale": anim_scale,
    }
    _atomic_write(out, _json.dumps(payload, indent=2) + "\n")


def _sync_seeker(colours: dict[str, str], mode: str) -> None:
    """Seeker (Qt/QML file manager) watches ~/.config/seeker/theme.json."""
    _write_qt_app_theme("seeker", colours, mode)


def _sync_things(colours: dict[str, str], mode: str) -> None:
    """Things (Qt/QML package manager) watches ~/.config/things/theme.json."""
    _write_qt_app_theme("things", colours, mode)


def _sync_veo(colours: dict[str, str], mode: str) -> None:
    """Veo (Qt/QML video player) watches ~/.config/veo/theme.json."""
    _write_qt_app_theme("veo", colours, mode)


def _sync_opencode_theme(colours: dict[str, str], mode: str) -> None:
    """Push the activity scheme into OpenCode's TUI theme files and point
    cli.json at them.

    OpenCode hot-reloads cli.json keywords (theme *name*) but NOT theme file
    contents, so the theme lives under two names (lunele / lunele-alt)
    with identical content; each real palette change flips cli.json to the
    other name, which forces running TUIs to re-read and re-apply the theme.
    A no-op (same palette + same mode) is skipped to avoid reload churn.
    """
    import json as _json

    gen = Path(__file__).resolve().parent / "generate-opencode-theme.py"
    themes_dir = Path.home() / ".config/opencode/themes"
    canonical = themes_dir / "lunele.json"
    naming = {"lunele": "lunele.json", "lunele-alt": "lunele-alt.json"}
    cli_path = Path.home() / ".config/opencode/cli.json"
    cli, current_name, current_payload = {}, None, ""
    try:
        cli = _json.loads(cli_path.read_text() or "{}") if cli_path.is_file() else {}
        if not isinstance(cli, dict):
            cli = {}
        theme = cli.setdefault("theme", {})
        current_name = theme.get("name") if isinstance(theme, dict) else None
        if current_name in naming:
            current_payload = (themes_dir / naming[current_name]).read_text()
    except (OSError, ValueError):
        return
    try:
        subprocess.run(
            [sys.executable, str(gen), mode],
            input=_json.dumps(colours),
            text=True,
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        payload = canonical.read_text()
    except (OSError, ValueError):
        return

    try:
        theme = cli.setdefault("theme", {})
        if current_payload == payload and theme.get("mode") == mode:
            return  # nothing changed; do not churn running TUIs
        if current_name == "lunele":
            # The TUI shows the canonical; the twin gets the new palette first
            (themes_dir / naming["lunele-alt"]).write_text(payload)
        # current_name == "lunele-alt" (or not ours): canonical already holds
        # the new payload because the generator writes it directly.
        theme["name"] = "lunele-alt" if current_name == "lunele" else "lunele"
        theme["mode"] = mode
        cli_path.write_text(_json.dumps(cli, indent=2) + "\n")
    except (OSError, ValueError):
        pass


def main() -> None:
    _patch_theme()
    # Replace argv so the CLI sees a normal invocation
    sys.argv = ["lunele", *sys.argv[1:]]
    try:
        runpy.run_module("lunele", run_name="__main__")
    finally:
        # Wallpaper CLI applies also touch the greeter (no colours payload in
        # this path — read the persisted scheme).
        if len(sys.argv) > 1 and sys.argv[1] == "wallpaper":
            _sync_greeter()


if __name__ == "__main__":
    main()
