#!/bin/bash
# A popup that closes when the mouse leaves it. mouse.exited.global alone is not
# enough: SketchyBar misses it when the mouse leaves an item's window straight to
# the outside, as it does down from the popup's last row, and fires it in the gap
# between the bar and the popup. So the items the popup hangs from and its rows
# report their own exits (subscribe them to mouse.entered mouse.exited, and one
# updates=on item to mouse.exited.global), and the popup closes unless something
# of it was entered meanwhile.
#
# Define popup_hide, then `source popup.sh <name>` BEFORE lib.sh, since every hover
# runs it, and call `popup_hover "${1:-}" && exit 0`.

# Exists while the popup is open and holds what the mouse was last over.
POPUP_STATE="${TMPDIR:-/tmp}/minbar.popup.$1"
popup_over() { printf '%s %s\n' "$NAME" "$RANDOM$RANDOM" >"$POPUP_STATE"; }
popup_close() { rm -f "$POPUP_STATE"; popup_hide; }
popup_is_open() { [ "$(sketchybar --query "$1" | jq -r '.popup.drawing')" = on ]; }

# popup_hover [ARG]: handles a hover event; fails on any other run. A click script
# inherits the item's last SENDER, hence ARG (its first word), which wins.
popup_hover() {
  local was='' now=''
  case "${1:-${SENDER:-}}" in
    mouse.entered)
      [ ! -e "$POPUP_STATE" ] || popup_over ;;
    mouse.exited | mouse.exited.global)
      [ -e "$POPUP_STATE" ] || return 0
      read -r was <"$POPUP_STATE"
      sleep 0.4
      [ -e "$POPUP_STATE" ] && read -r now <"$POPUP_STATE"
      [ "$was" = "$now" ] || return 0
      # An item's own exit counts only while it is the last one entered.
      if [ "$SENDER" = mouse.exited.global ] || [ "${was% *}" = "$NAME" ]; then popup_close; fi ;;
    *) return 1 ;;
  esac
  return 0
}
