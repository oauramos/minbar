#!/bin/bash
# Bluetooth power (monochrome): white glyph when on, muted glyph when off.
# `bluetooth.sh click`: single click toggles the radio, double click opens
# System Settings > Bluetooth (see dblclick.sh). No arg = refresh.
#
# State and toggling go through blueutil (a MinBar dependency, on the daemon's
# PATH). Without
# it, state falls back to system_profiler (~0.1s) and the toggle is a no-op. On macOS 26 the Bluetooth plist is not user-readable, hence no
# `defaults read` shortcut.
source "$(dirname "$0")/lib.sh"
source "$(dirname "$0")/dblclick.sh"

BLUEUTIL=$(command -v blueutil 2>/dev/null || true)

bt_on() {
  if [ -n "$BLUEUTIL" ]; then
    [ "$("$BLUEUTIL" -p 2>/dev/null)" = "1" ]
  else
    [ "$(system_profiler SPBluetoothDataType 2>/dev/null | awk -F': ' '/State:/{print $2; exit}')" = "On" ]
  fi
}

toggle()   { [ -n "$BLUEUTIL" ] && "$BLUEUTIL" -p toggle >/dev/null 2>&1; }
settings() { open "x-apple.systempreferences:com.apple.BluetoothSettings"; }

render() {
  if bt_on; then
    sketchybar --set "$NAME" icon="󰂯" icon.color="$FG"
  else
    sketchybar --set "$NAME" icon="󰂲" icon.color="$MUTED"
  fi
}

case "${1:-}" in
  click)  click_dispatch toggle settings ;;
  toggle) toggle ;;   # straight away, no double-click window (the `sketchybar` TUI)
esac
render
