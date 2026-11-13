# Greeter Quickshell for greetd.
# Sourced as root by scripts/install-system.sh. Defines step_main.
# Safe to re-run. Scripts and QML are root's; the session user only writes user/ (theme, wallpaper, avatar, font).

step_main() {
  local greeter_dir data_dir session_user qs_dst

  # What this step needs; the Sylphrena installer (./install.sh) installs them first
  local tool
  for tool in rsync python3; do
    command -v "$tool" >/dev/null || { echo "Missing $tool: install it and run this again." >&2; return 1; }
  done
  [[ -x /usr/bin/greetd ]] || { echo "Missing greetd: install it (pacman -S greetd) and run this again." >&2; return 1; }
  greeter_dir="${SYLPHRENA_GREETER_DIR:-/etc/greetd/sylphrena}"
  data_dir="$greeter_dir/user"
  qs_dst="$greeter_dir/qs"

  # Everything the login screen runs (its scripts and its QML, which receives the passwords) is root's: on a
  # computer with several accounts, one of them could otherwise change it and read another's password. Only
  # user/ (the theme, wallpaper, avatar and font the session copies there) belongs to the user.
  mkdir -p "$greeter_dir" "$data_dir"
  # Before user/ existed those files were at the top, owned by the user: move them in
  local f
  for f in scheme.json greeter.json wallpaper face fonts; do
    if [[ -e "$greeter_dir/$f" && ! -e "$data_dir/$f" ]]; then
      mv "$greeter_dir/$f" "$data_dir/$f"
    else
      rm -rf "${greeter_dir:?}/$f"
    fi
  done
  # The old regreet background and the copy markers (the session writes them again in user/)
  rm -f "$greeter_dir"/wallpaper.jpg "$greeter_dir"/*.sha256

  mkdir -p "$qs_dst"
  rsync -a --delete --chown=root:root \
    --exclude 'install-greeter.sh' \
    --exclude 'hyprland-greeter.lua' \
    --exclude 'launch-qs.sh' \
    --exclude 'exit-compositor.sh' \
    --exclude 'start-user-session.sh' \
    --exclude 'quiet-exec.sh' \
    --exclude 'start-greeter-compositor.sh' \
    --exclude 'systemd' \
    --exclude 'config.toml.snippet' \
    "$SYLPHRENA_ROOT/greeter/" "$qs_dst/"

  install_wrappers() {
    cp -f "$SYLPHRENA_ROOT/greeter/hyprland-greeter.lua" "$greeter_dir/hyprland-greeter.lua"
    cp -f "$SYLPHRENA_ROOT/greeter/launch-qs.sh" "$greeter_dir/launch-qs.sh"
    cp -f "$SYLPHRENA_ROOT/greeter/exit-compositor.sh" "$greeter_dir/exit-compositor.sh"
    cp -f "$SYLPHRENA_ROOT/greeter/start-user-session.sh" "$greeter_dir/start-user-session.sh"
    cp -f "$SYLPHRENA_ROOT/greeter/quiet-exec.sh" "$greeter_dir/quiet-exec.sh"
    cp -f "$SYLPHRENA_ROOT/greeter/start-greeter-compositor.sh" "$greeter_dir/start-greeter-compositor.sh"
    chmod 755 "$greeter_dir/launch-qs.sh" "$greeter_dir/exit-compositor.sh" \
      "$greeter_dir/start-user-session.sh" "$greeter_dir/quiet-exec.sh" \
      "$greeter_dir/start-greeter-compositor.sh"
  }

  install_wrappers
  chown -R root:root "$greeter_dir"
  chmod 755 "$greeter_dir" "$qs_dst"
  chown -R "$SYLPHRENA_OWNER:$SYLPHRENA_OWNER" "$data_dir"
  chmod 755 "$data_dir"
  # Which shell the login screen was copied from (the installer's update refreshes it when the shell changes)
  local version
  version="$(pacman -Q sylphrena-shell-git 2>/dev/null | awk '{print $2}')"
  [[ -n "$version" ]] || version="$(git -C "$SYLPHRENA_ROOT" describe --tags --always 2>/dev/null || echo unknown)"
  printf '%s\n' "$version" >"$greeter_dir/version"

  # Scheme, wallpaper and face come from the session user. Path.home()
  # would be /root if this ran as root.
  runuser -u "$SYLPHRENA_OWNER" -- env \
    SYLPHRENA_GREETER_DIR="$greeter_dir" \
    SYLPHRENA_ROOT="$SYLPHRENA_ROOT" \
    HOME="$SYLPHRENA_OWNER_HOME" \
    python3 - <<'PY'
import os
from pathlib import Path

quiet = Path(os.environ["SYLPHRENA_ROOT"]) / "scripts" / "sylphrena-quiet.py"
src = quiet.read_text()
cut = src.find("\nif __name__")
ns: dict = {"__name__": "sylphrena_quiet", "__file__": str(quiet)}
exec(compile(src if cut < 0 else src[:cut], str(quiet), "exec"), ns)
ns["_sync_greeter"]()
print(f"Synced greeter assets into {ns['_GREETER_DIR']}")
PY

  install -m 644 "$SYLPHRENA_ROOT/greeter/hyprland-greeter.lua" /etc/greetd/hyprland-greeter.lua

  session_user="$(awk '
    /^\[/ { sec = $0 }
    sec == "[initial_session]" && $0 ~ /^user = / {
      split($0, a, "\"")
      print a[2]
      exit
    }
  ' /etc/greetd/config.toml 2>/dev/null || true)"
  session_user="${session_user:-$SYLPHRENA_OWNER}"

  cat > /etc/greetd/config.toml <<EOF
[terminal]
vt = 1

# Primera sesión del boot: autologin directo a Hyprland (como plasmalogin).
# Wrapped so the ASCII logo/cursor never hits tty1.
[initial_session]
command = "${greeter_dir}/start-user-session.sh /usr/bin/start-hyprland"
user = "${session_user}"

# Tras cerrar sesión desde Hyprland: greeter Quickshell (Material You) sobre Hyprland.
# HOME/XDG se fijan aquí porque el usuario greeter tiene HOME=/ en passwd.
[default_session]
command = "${greeter_dir}/start-greeter-compositor.sh"
# Rollback a CLI: sustituir por tuigreet.
# command = "/usr/bin/tuigreet --time --cmd /usr/bin/start-hyprland"
user = "greeter"
EOF

  # Shorter hand-off from the greeter to the session (no 10 s black screen after typing the password; a stuck
  # leftover app cannot hold the next session for 90 s). The names it had before the rename are cleaned up.
  mkdir -p /etc/systemd/logind.conf.d /etc/systemd/system/user@.service.d
  install -m 644 "$SYLPHRENA_ROOT/greeter/systemd/logind.conf" \
    /etc/systemd/logind.conf.d/sylphrena-greeter.conf
  install -m 644 "$SYLPHRENA_ROOT/greeter/systemd/user-service.conf" \
    /etc/systemd/system/user@.service.d/sylphrena-timeout.conf
  rm -f /etc/systemd/logind.conf.d/caelestia-greeter.conf \
    /etc/systemd/system/user@.service.d/caelestia-timeout.conf
  systemctl daemon-reload
  systemctl reload systemd-logind.service

  # greetd has to be the display manager. Nothing is restarted (that would end the session you are in):
  # it takes over at the next boot or when the display manager is restarted from a text console.
  local current
  current="$(basename "$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null || true)" .service)"
  if [[ -n "$current" && "$current" != "greetd" && "$current" != "display-manager" ]]; then
    echo "Replacing the display manager $current with greetd (disabled, not stopped)"
    systemctl disable "$current.service"
  fi
  systemctl enable -f greetd.service
  echo "greetd is enabled: it takes over at the next boot"

  echo "Greeter dir: $greeter_dir (the session writes only $data_dir)"
  echo "greetd initial_session user: $session_user"
  echo "Logs: /var/lib/regreet/state/qs.log and /tmp/sylphrena-greeter-qs.log"
}
