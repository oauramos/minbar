#!/bin/bash
# Keep-awake toggle (monochrome). `caffeine.sh click`: single click starts/stops
# a detached `caffeinate`, double click opens System Settings > Energy (see
# dblclick.sh). `caffeine.sh toggle` toggles right away (no double-click
# window). No arg = reflect current state (white filled cup = awake, muted empty
# cup = off).
source "$(dirname "$0")/lib.sh"
source "$(dirname "$0")/dblclick.sh"

# Only our own caffeinate, matched by its full command line: other tools run
# their own (Claude Code keeps a `caffeinate -i -t 300` alive while it works),
# and a bare `-x caffeinate` showed the cup lit for them and killed theirs.
OURS='caffeinate -disu'

toggle() {
  if pgrep -xf "$OURS" >/dev/null 2>&1; then
    pkill -xf "$OURS"
  else
    ( caffeinate -disu & ) >/dev/null 2>&1   # -d display -i idle -s system -u user
  fi
}
# "Energy" on desktops, "Battery" on laptops — same pane id.
settings() { open "x-apple.systempreferences:com.apple.Battery-Settings.extension"; }

render() {
  if pgrep -xf "$OURS" >/dev/null 2>&1; then
    sketchybar --set "$NAME" icon="󰅶" icon.color="$FG"
  else
    sketchybar --set "$NAME" icon="󰛊" icon.color="$MUTED"
  fi
}

case "${1:-}" in
  click)  click_dispatch toggle settings ;;
  toggle) toggle ;;
esac
render
