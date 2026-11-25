# Lets the theme set the bar colour of Chromium browsers (Chrome, Chromium, Brave) with no root at each change.
#
# They read their colour from a managed policy file under /etc, a root folder. This creates, for each one that is
# installed, its policy folder and a sylenara.json owned by the user, which sylenara-cli rewrites when the scheme
# changes (activity, desktop, wallpaper). The policy from the old name, caelestia.json, is removed: it held one
# fixed colour that won over ours.

BROWSER_POLICIES=(
  "google-chrome-stable:/etc/opt/chrome/policies/managed"
  "chromium:/etc/chromium/policies/managed"
  "brave:/etc/brave/policies/managed"
)

step_main() {
  local entry cmd dir found=0
  for entry in "${BROWSER_POLICIES[@]}"; do
    cmd="${entry%%:*}"
    dir="${entry#*:}"
    command -v "$cmd" >/dev/null 2>&1 || continue
    found=1
    install -d -m 755 "$dir"
    rm -f "$dir/caelestia.json"
    # Only this file is the user's; the folder stays root's
    [[ -f "$dir/sylenara.json" ]] || printf '{"BrowserColorScheme": "device"}\n' >"$dir/sylenara.json"
    chown "$SYLENARA_OWNER": "$dir/sylenara.json"
    chmod 644 "$dir/sylenara.json"
    echo "$cmd: $dir/sylenara.json belongs to $SYLENARA_OWNER"
  done
  [[ $found -eq 1 ]] || echo "No Chromium browser installed: nothing to do"
}
