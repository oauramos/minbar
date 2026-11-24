#!/bin/bash
# Highlights the active AeroSpace workspace: near-white pill + dark number for
# the focused one, plain white number for the rest.
#   - aerospace_workspace_change: $FOCUSED_WORKSPACE is passed by the trigger.
#   - any other run (load / system_woke): query aerospace directly (Homebrew's
#     bin is on the daemon's PATH, see lib.sh).
#   - `space.sh menu` (right click): a popup that pins the front app to this
#     workspace or makes it dynamic again (workspaces.sh).
#   - mouse.exited.global (the ws_menu item): closes that popup.
source "$(dirname "$0")/lib.sh"

WORKSPACE="${NAME#space.}"

if [ "${SENDER:-}" = mouse.exited.global ]; then
  sketchybar --set '/space\..*/' popup.drawing=off
  exit 0
fi

if [ "${1:-}" = menu ]; then
  # shellcheck source=workspaces.sh
  source "$(dirname "$0")/workspaces.sh"
  if [ "$(sketchybar --query "$NAME" | jq -r '.popup.drawing')" = on ]; then
    sketchybar --set "$NAME" popup.drawing=off
    exit 0
  fi
  IFS=$'\t' read -r id app < <(aerospace list-windows --focused --format '%{app-bundle-id}%{tab}%{app-name}' 2>/dev/null)
  pinned=$(ws_apps | awk -F'\t' -v w="$WORKSPACE" '$2 == w { out = out (out == "" ? "" : ", ") $1 } END { print out }')
  row=(icon.drawing=off label.font="$FONT_TEXT" label.color="$FG"
       label.padding_left=12 label.padding_right=12)
  rows=() n=0
  add() { # add LABEL [COLOR] [CLICK]
    n=$((n + 1))
    rows+=(--add item "wsmenu.$n" "popup.$NAME"
           --set "wsmenu.$n" "${row[@]}" label="$1" label.color="${2:-$FG}" click_script="${3:-}")
  }
  # One click: the rule, then the popup closes.
  pick() { printf '%q set %q %q %q; sketchybar --set %q popup.drawing=off' \
    "$CONFIG_DIR/plugins/workspaces.sh" "$id" "$app" "$1" "$NAME"; }
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
