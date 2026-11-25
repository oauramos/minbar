#!/bin/bash
# Keep-awake (monochrome). Right click: On starts a detached `caffeinate`, Off
# stops it, Settings is System Settings > Energy (tray.sh). No arg = reflect
# current state (white filled cup = awake, muted empty cup = off).
source "$(dirname "$0")/tray.sh"

# Only our own caffeinate, matched by its full command line: other tools run
# their own (Claude Code keeps a `caffeinate -i -t 300` alive while it works),
# and a bare `-x caffeinate` showed the cup lit for them and killed theirs.
OURS='caffeinate -disu'

is_on() { pgrep -xf "$OURS" >/dev/null 2>&1; }
# In a session of its own: when the bar restarts, launchd kills what is left of
# the bar's process group. -d display -i idle -s system -u user.
turn() {
  if [ "$1" = off ]; then
    pkill -xf "$OURS"
  elif ! is_on; then
    /usr/bin/perl -MPOSIX=setsid -e 'setsid; exec @ARGV' caffeinate -disu </dev/null >/dev/null 2>&1 &
    for _ in 1 2 3 4 5; do is_on && break; sleep 0.1; done
  fi
}
# "Energy" on desktops, "Battery" on laptops — same pane id.
settings() { open "x-apple.systempreferences:com.apple.Battery-Settings.extension"; }

render() {
  if is_on; then
    sketchybar --set "$NAME" icon="󰅶" icon.color="$FG"
  else
    sketchybar --set "$NAME" icon="󰛊" icon.color="$MUTED"
  fi
}

tray "$@"
