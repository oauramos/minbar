#!/bin/bash
# Tailscale connection (monochrome): white glyph when tailscaled reports
# Running, muted glyph when stopped, logged out or the daemon is down.
# Right click: On (`tailscale up`), Off (`down`), Settings, the admin console's
# Machines page (tray.sh). No arg = refresh.
#
# With the open-source tailscaled (running as root), up/down work without sudo
# once the login set --operator=$USER (`sudo tailscale up --operator=$USER`).
# A bare `tailscale up` on a logged-in node only flips it back on and keeps
# its saved prefs (exit node and the rest), so no flags are repeated here. The
# rc adds this item only where `tailscale` is on the daemon's PATH.
source "$(dirname "$0")/tray.sh"

is_on() {
  [ "$(tailscale status --json --peers=false 2>/dev/null | awk -F'"' '/"BackendState"/{print $4; exit}')" = Running ]
}

turn() {
  if [ "$1" = on ]; then tailscale up; else tailscale down; fi >/dev/null 2>&1
}
settings() { open "https://login.tailscale.com/admin/machines"; }

render() {
  if is_on; then
    sketchybar --set "$NAME" icon.color="$FG"
  else
    sketchybar --set "$NAME" icon.color="$MUTED"
  fi
}

tray "$@"
