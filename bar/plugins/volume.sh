#!/bin/bash
# Output volume + mute. Reacts to volume_change ($INFO=percent) and to scroll
# (adjusts the system volume); on a poll/first run it queries AppleScript.
# `volume.sh click`: single click toggles mute, double click opens
# System Settings > Sound (see dblclick.sh).
source "$(dirname "$0")/lib.sh"
source "$(dirname "$0")/dblclick.sh"

set_icon() {
  VOL=$1; IS_MUTED=$2
  if [ "$IS_MUTED" = "true" ] || [ "${VOL:-0}" -eq 0 ] 2>/dev/null; then
    sketchybar --set "$NAME" icon="󰖁" label="muted"
    return
  fi
  case "$VOL" in
    [6-9][0-9]|100)   ICON="󰕾" ;;
    [3-5][0-9])       ICON="󰖀" ;;
    [1-9]|[1-2][0-9]) ICON="󰕿" ;;
    *)                ICON="󰖁" ;;
  esac
  sketchybar --set "$NAME" icon="$ICON" label="${VOL}%"
}

render() {
  VOL=$(osascript -e 'output volume of (get volume settings)' 2>/dev/null)
  IS_MUTED=$(osascript -e 'output muted of (get volume settings)' 2>/dev/null)
  set_icon "${VOL:-0}" "${IS_MUTED:-false}"
}

toggle_mute() { osascript -e 'set volume output muted (not (output muted of (get volume settings)))' >/dev/null 2>&1; }
settings()    { open "x-apple.systempreferences:com.apple.Sound-Settings.extension"; }

case "${1:-}" in
  click)  click_dispatch toggle_mute settings; render; exit 0 ;;
  toggle) toggle_mute; render; exit 0 ;;   # mute now, no double-click window (the `sketchybar` TUI)
esac

case "${SENDER:-}" in
  volume_change)
    set_icon "${INFO:-0}" "false"
    ;;
  mouse.scrolled)
    osascript -e "set volume output volume (output volume of (get volume settings) + (${SCROLL_DELTA:-0} * 5))" >/dev/null 2>&1
    VOL=$(osascript -e 'output volume of (get volume settings)' 2>/dev/null)
    set_icon "${VOL:-0}" "false"
    ;;
  *)
    render
    ;;
esac
