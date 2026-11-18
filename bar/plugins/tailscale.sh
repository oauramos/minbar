#!/bin/bash
# Tailscale connection (monochrome): white glyph when tailscaled reports
# Running, muted glyph when stopped, logged out or the daemon is down.
# `tailscale.sh click`: single click runs `tailscale up` / `down`, double click
# opens the admin console's Machines page (see dblclick.sh). No arg = refresh.
#
# With the open-source tailscaled (running as root), up/down work without sudo
# once the login set --operator=$USER (`sudo tailscale up --operator=$USER`).
# A bare `tailscale up` on a logged-in node only flips it back on and keeps
# its saved prefs (exit node and the rest), so no flags are repeated here. The
# rc adds this item only where `tailscale` is on the daemon's PATH.
source "$(dirname "$0")/lib.sh"
source "$(dirname "$0")/dblclick.sh"

state() { tailscale status --json --peers=false 2>/dev/null | awk -F'"' '/"BackendState"/{print $4; exit}'; }

toggle() {
  if [ "$(state)" = "Running" ]; then tailscale down
  else                                tailscale up
  fi >/dev/null 2>&1
}
settings() { open "https://login.tailscale.com/admin/machines"; }

render() {
  if [ "$(state)" = "Running" ]; then
    sketchybar --set "$NAME" icon.color="$FG"
  else
    sketchybar --set "$NAME" icon.color="$MUTED"
  fi
}

case "${1:-}" in
  click)  click_dispatch toggle settings ;;
  toggle) toggle ;;   # straight away, no double-click window (the `sketchybar` TUI)
esac
render
