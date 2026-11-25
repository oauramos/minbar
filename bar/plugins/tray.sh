#!/bin/bash
# The right-click menu of a control (the box left of the clock): On, Off,
# Settings, with a check on the current state. `source tray.sh` FIRST in the
# control's plugin: it sources lib.sh itself, after the hovers (popup.sh), which
# must stay cheap. Then define
#   is_on            the state
#   turn on|off      changes it; the one it is already in must be harmless
#   settings         opens its settings
#   render           draws the item ($NAME)
# and end with `tray "$@"`. `menu` is the right click, `on`, `off` and `settings`
# are the menu's rows, `toggle` is `minbar toggle`, no argument draws.

TRAY="${NAME%%.row.*}"   # the item, also when one of its menu's rows runs this
popup_hide() { sketchybar --set "$TRAY" popup.drawing=off; }
# shellcheck source=popup.sh
source "$(dirname "$0")/popup.sh" "$TRAY"
popup_hover "${1:-}" && exit 0
# A row draws nothing of its own.
[ "$NAME" = "$TRAY" ] || [ $# -gt 0 ] || exit 0
NAME=$TRAY

source "$(dirname "$0")/lib.sh"

tray_menu() {
  local state=off verb label color n=0 rows=()
  if popup_is_open "$NAME"; then
    popup_close
    return
  fi
  popup_start
  is_on && state=on
  for verb in on off settings; do
    case $verb in on) label=On ;; off) label=Off ;; settings) label=Settings ;; esac
    # Every row keeps the check's width, so the labels line up.
    if [ "$verb" = "$state" ]; then color=$FG; else color=0x00000000; fi
    n=$((n + 1))
    rows+=(--add item "$NAME.row.$n" "popup.$NAME"
           --set "$NAME.row.$n" icon=󰄬 icon.font="$FONT_ICON" icon.color="$color"
                 icon.padding_left=10 icon.padding_right=6
                 label="$label" label.font="$FONT_TEXT" label.color="$FG"
                 label.padding_left=0 label.padding_right=16
                 script="$0" click_script="$0 $verb"
           --subscribe "$NAME.row.$n" mouse.entered mouse.exited)
  done
  # A regex that matches nothing only prints a warning, hence the redirect.
  sketchybar --remove "/$NAME\.row\..*/" >/dev/null 2>&1
  sketchybar "${rows[@]}" --set "$NAME" popup.drawing=on
}

tray() {
  case "${1:-}" in
    menu)     tray_menu ;;
    on | off) popup_close; turn "$1"; render
              sleep 2; render ;;   # a radio or a link takes a moment to settle
    settings) popup_close; settings ;;
    toggle)   if is_on; then turn off; else turn on; fi; render ;;
    *)        render ;;
  esac
}
