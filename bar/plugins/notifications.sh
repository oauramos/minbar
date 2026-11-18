#!/bin/bash
# Notification Center bell (monochrome). Label: how many notifications arrived
# since the bell was last clicked, 1-9, "..." past 9, nothing at 0. Read from
# usernoted's database, which needs Full Disk Access for MinBar: without it
# the read fails and the bell just shows no count.
# `notifications.sh click`: marks them seen and toggles Notification Center
# through its keyboard shortcut (`menus -k`). Pressing the clock menu extra
# instead shows the panel for under half a second while the native bar is
# hidden, so the bell types the system shortcut "Show Notification Center",
# which `minbar setup` assigns (MINBAR_NC_KEY / MINBAR_NC_MODS, config.sh).
source "$(dirname "$0")/lib.sh"

DB="$HOME/Library/Group Containers/group.com.apple.usernoted/db2/db"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/minbar"
SEEN="$STATE/notifications.seen"
# usernoted stores Core Data dates: seconds since 2001-01-01 UTC.
now() { echo $(( $(date +%s) - 978307200 )); }
mark_seen() { mkdir -p "$STATE" && now > "$SEEN"; }

if [ "${1:-}" = click ]; then
  mark_seen
  sketchybar --set "$NAME" label.drawing=off
  menus -k "$MINBAR_NC_KEY" "$MINBAR_NC_MODS"
  exit 0
fi

# First run: start counting from now, not from the whole history (hundreds).
[ -f "$SEEN" ] || mark_seen
seen=$(cat "$SEEN" 2>/dev/null)
case "$seen" in '' | *[!0-9]*) seen=$(now) ;; esac

n=$(/usr/bin/sqlite3 -readonly "file:$DB?mode=ro" \
  "select count(*) from record where delivered_date > $seen" 2>/dev/null) || n=0
case "$n" in
  '' | 0 | *[!0-9]*) sketchybar --set "$NAME" label.drawing=off ;;
  [1-9]) sketchybar --set "$NAME" label.drawing=on label="$n" ;;
  *) sketchybar --set "$NAME" label.drawing=on label="..." ;;
esac
