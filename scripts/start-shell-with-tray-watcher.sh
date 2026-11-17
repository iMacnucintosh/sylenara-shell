#!/usr/bin/env bash
# Ensure the persistent StatusNotifierWatcher is running, then start the
# Lunele shell as a StatusNotifierHost. See status-notifier-watcher.py.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WATCHER="${ROOT}/scripts/status-notifier-watcher.py"
# The compositor PATH may lack ~/.local/bin (user-local install): fall back to it explicitly
LUNELE="${LUNELE:-$(command -v lunele || echo "$HOME/.local/bin/lunele")}"

# Without the watcher only the tray icons of some apps are lost: the shell must start anyway
python3 "$WATCHER" || echo "status-notifier-watcher did not start; starting the shell without it" >&2

# On a cold start we own the name immediately. Mid-session qs may still hold
# it until the next `lunele shell -r`; either way the shell can start.
for _ in $(seq 1 50); do
  if [[ -f "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/lunele/status-notifier-watcher.pid" ]]; then
    break
  fi
  sleep 0.05
done

exec "$LUNELE" shell -d "$@"
