#!/usr/bin/env bash
# Install Sylenara pieces that live under /etc.
#
# Asks for root once (re-exec via sudo) and runs every step in
# scripts/system/NN-name.sh. A step is a file that defines step_main.
# (Root pieces of extensions are not here: each one installs its own from Nexus → Extensions,
# manifest `system`.) Drop a new file there to add another privileged install; the next run
# of this script picks it up. User-owned refresh (theme, wallpaper) stays
# outside sudo: the login screen's user/ folder belongs to the invoking user (the rest is root's).
#
#   scripts/install-system.sh
#   scripts/install-system.sh --only browser-policy    # one step (its file name without number and .sh)
#   greeter/install-greeter.sh    # same entry, kept for the old path
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
ROOT="$(cd "$(dirname "$SELF")/.." && pwd)"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Sylenara system install. One root prompt."
  if [[ -t 0 ]] || sudo -n true 2>/dev/null; then
    exec sudo -- "$SELF" "$@"
  elif command -v pkexec >/dev/null; then
    exec pkexec "$SELF" "$@"
  else
    exec sudo -- "$SELF" "$@"
  fi
fi

OWNER="${SUDO_USER:-}"
if [[ -z "$OWNER" && -n "${PKEXEC_UID:-}" ]]; then
  OWNER="$(id -nu "$PKEXEC_UID")"
fi
if [[ -z "$OWNER" || "$OWNER" == "root" ]]; then
  echo "Run this from your user account: the login screen takes your theme, wallpaper and avatar." >&2
  exit 1
fi
OWNER_HOME="$(getent passwd "$OWNER" | cut -d: -f6)"
if [[ -z "$OWNER_HOME" || ! -d "$OWNER_HOME" ]]; then
  echo "No home directory for $OWNER." >&2
  exit 1
fi

ONLY=""
if [[ "${1:-}" == "--only" && -n "${2:-}" ]]; then
  ONLY="$2"
fi

export SYLENARA_ROOT="$ROOT"
export SYLENARA_OWNER="$OWNER"
export SYLENARA_OWNER_HOME="$OWNER_HOME"

shopt -s nullglob
steps=("$ROOT"/scripts/system/[0-9]*.sh)
if [[ ${#steps[@]} -eq 0 ]]; then
  echo "No steps in $ROOT/scripts/system." >&2
  exit 1
fi

for step in "${steps[@]}"; do
  name="$(basename "$step" .sh)"
  [[ -z "$ONLY" || "${name#*-}" == "$ONLY" ]] || continue
  echo "== $(basename "$step") =="
  (
    # shellcheck disable=SC1090
    source "$step"
    step_main
  )
done

echo "Done."
