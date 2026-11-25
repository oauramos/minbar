#!/bin/bash
# A popup that closes when the mouse leaves it. mouse.exited.global alone is not
# enough: SketchyBar misses it when the mouse leaves an item's window straight to
# the outside, as it does down from the popup's last row, and fires it in the gap
# between the bar and the popup. So the items the popup hangs from and its rows
# report their own exits (subscribe them to mouse.entered mouse.exited;
# mouse.exited.global counts too, from any item that subscribes to it), and the
# popup closes unless something of it was entered meanwhile.
#
# Define popup_hide, then `source popup.sh <name>` BEFORE lib.sh, since every hover
# runs it, and call `popup_hover "${1:-}" && exit 0`. To open: popup_start, as
# early as possible (an exit that comes before it is not seen), then draw.
#
# Each event is a process of its own, and opening a popup makes SketchyBar send
# the item an exit and an entry together: whichever of the two runs first must
# not matter. They are spawned in order, so their PIDs tell which event is the
# later one.

# Exists while the popup is open: a line "PID ITEM" per item entered.
POPUP_STATE="${TMPDIR:-/tmp}/minbar.popup.$1"
popup_start() { echo "$$ $NAME" >"$POPUP_STATE"; }
popup_close() { rm -f "$POPUP_STATE"; popup_hide; }
popup_is_open() { [ "$(sketchybar --query "$1" | jq -r '.popup.drawing')" = on ]; }
# popup_later A B: PID A was given out after PID B (they start over at 99999).
popup_later() { [ "$1" != "$2" ] && [ $((($1 - $2 + 100000) % 100000)) -lt 50000 ]; }

# popup_hover [ARG]: handles a hover event; fails on any other run. A click script
# inherits the item's last SENDER, hence ARG (its first word), which wins.
popup_hover() {
  local pid item last='' over=''
  case "${1:-${SENDER:-}}" in
    mouse.entered)
      [ ! -e "$POPUP_STATE" ] || echo "$$ $NAME" >>"$POPUP_STATE" ;;
    mouse.exited | mouse.exited.global)
      [ -e "$POPUP_STATE" ] || return 0
      sleep 0.4
      [ -e "$POPUP_STATE" ] || return 0
      while read -r pid item; do
        if [ -z "$last" ] || popup_later "$pid" "$last"; then last=$pid over=$item; fi
      done <"$POPUP_STATE"
      [ -n "$last" ] && popup_later $$ "$last" || return 0
      # An item's own exit counts only while it is the last one entered.
      if [ "$SENDER" = mouse.exited.global ] || [ "$over" = "$NAME" ]; then popup_close; fi ;;
    *) return 1 ;;
  esac
  return 0
}
