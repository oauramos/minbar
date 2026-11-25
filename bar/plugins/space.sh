#!/bin/bash
# Highlights the active AeroSpace workspace: near-white pill + dark number for
# the focused one, plain white number for the rest.
#   - aerospace_workspace_change: $FOCUSED_WORKSPACE is passed by the trigger.
#   - any other run (load / system_woke): query aerospace directly (Homebrew's
#     bin is on the daemon's PATH, see lib.sh).
#   - `space.sh menu` (right click): a popup that pins the front app to this
#     workspace or makes it dynamic again (workspaces.sh).
#   - mouse.entered / mouse.exited (the pills and the popup's rows) and
#     mouse.exited.global (the ws_menu item): close that popup.

# MENU exists while the popup is open and holds what the mouse was last over.
# mouse.exited.global alone is not enough: SketchyBar misses it when the mouse
# leaves a pill's or a row's window straight to the outside, as it does down
# from the last row. So each of them reports its exit, and the popup closes
# unless something was entered meanwhile (the gap between the bar and the popup
# is outside too). This comes before lib.sh: every hover on a pill runs it.
MENU="${TMPDIR:-/tmp}/minbar.wsmenu"
menu_over() { printf '%s %s\n' "$NAME" "$RANDOM$RANDOM" >"$MENU"; }
menu_close() {
  rm -f "$MENU"
  sketchybar --set '/space\..*/' popup.drawing=off
}
# A click script inherits the item's last SENDER, hence no event with "menu".
case "${1:-${SENDER:-}}" in
  mouse.entered)
    [ ! -e "$MENU" ] || menu_over
    exit 0 ;;
  mouse.exited | mouse.exited.global)
    [ -e "$MENU" ] || exit 0
    was='' now=''
    read -r was <"$MENU"
    sleep 0.4
    [ -e "$MENU" ] && read -r now <"$MENU"
    [ "$was" = "$now" ] || exit 0
    # An item's own exit counts only while it is the last one entered.
    if [ "$SENDER" = mouse.exited.global ] || [ "${was% *}" = "$NAME" ]; then menu_close; fi
    exit 0 ;;
esac

source "$(dirname "$0")/lib.sh"

WORKSPACE="${NAME#space.}"

if [ "${1:-}" = menu ]; then
  # shellcheck source=workspaces.sh
  source "$(dirname "$0")/workspaces.sh"
  if [ "$(sketchybar --query "$NAME" | jq -r '.popup.drawing')" = on ]; then
    menu_close
    exit 0
  fi
  IFS=$'\t' read -r id app < <(aerospace list-windows --focused --format '%{app-bundle-id}%{tab}%{app-name}' 2>/dev/null)
  pinned=$(ws_apps | awk -F'\t' -v w="$WORKSPACE" '$2 == w { out = out (out == "" ? "" : ", ") $1 } END { print out }')
  row=(icon.drawing=off label.font="$FONT_TEXT" label.color="$FG"
       label.padding_left=12 label.padding_right=12 script="$CONFIG_DIR/plugins/space.sh")
  rows=() n=0
  add() { # add LABEL [COLOR] [CLICK]
    n=$((n + 1))
    rows+=(--add item "wsmenu.$n" "popup.$NAME"
           --set "wsmenu.$n" "${row[@]}" label="$1" label.color="${2:-$FG}" click_script="${3:-}"
           --subscribe "wsmenu.$n" mouse.entered mouse.exited)
  }
  # One click: the rule, then the popup closes.
  pick() { printf '%q set %q %q %q; rm -f %q; sketchybar --set %q popup.drawing=off' \
    "$CONFIG_DIR/plugins/workspaces.sh" "$id" "$app" "$1" "$MENU" "$NAME"; }
  if [ -n "${id:-}" ]; then
    ws=$(ws_lookup "$id")
    if [ "$ws" = dynamic ]; then add "$app opens anywhere" "$MUTED"; else add "$app opens on $ws" "$MUTED"; fi
    [ "$ws" = "$WORKSPACE" ] || add "Always open $app on $WORKSPACE" "$FG" "$(pick "$WORKSPACE")"
    [ "$ws" = dynamic ] || add "Open $app anywhere" "$FG" "$(pick dynamic)"
  fi
  [ -z "$pinned" ] || add "Pinned here: $pinned" "$MUTED"
  [ "$n" -gt 0 ] || add "No app in front, nothing pinned here" "$MUTED"
  # A regex that matches nothing only prints a warning, hence the redirect.
  sketchybar --remove '/wsmenu\..*/' >/dev/null 2>&1
  menu_over
  sketchybar --set '/space\..*/' popup.drawing=off \
             "${rows[@]}" \
             --set "$NAME" popup.drawing=on
  exit 0
fi

case "${SENDER:-}" in
  aerospace_workspace_change) FOCUSED="${FOCUSED_WORKSPACE:-}" ;;
  *)                          FOCUSED=$(aerospace list-workspaces --focused 2>/dev/null) ;;
esac

if [ "$FOCUSED" = "$WORKSPACE" ]; then
  sketchybar --set "$NAME" background.drawing=on  icon.color="$ACTIVE_FG"
else
  sketchybar --set "$NAME" background.drawing=off icon.color="$FG"
fi
