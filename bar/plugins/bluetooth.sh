#!/bin/bash
# Bluetooth power (monochrome): white glyph when on, muted glyph when off.
# Right click: On, Off, Settings (tray.sh). No arg = refresh.
#
# State and switching go through blueutil (a MinBar dependency, on the daemon's
# PATH), which needs MinBar's Bluetooth permission and dies without it. Then the
# state comes from system_profiler (~0.1s), and switching opens the permission's
# pane. On macOS 26 the Bluetooth plist is not user-readable, hence no `defaults
# read` shortcut.
source "$(dirname "$0")/tray.sh"

is_on() {
  local power
  if power=$(blueutil -p 2>/dev/null); then
    [ "$power" = 1 ]
  else
    [ "$(system_profiler SPBluetoothDataType 2>/dev/null | awk -F': ' '/State:/{print $2; exit}')" = "On" ]
  fi
}

turn() {
  blueutil -p "$1" >/dev/null 2>&1 ||
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth"
}
settings() { open "x-apple.systempreferences:com.apple.BluetoothSettings"; }

render() {
  if is_on; then
    sketchybar --set "$NAME" icon="󰂯" icon.color="$FG"
  else
    sketchybar --set "$NAME" icon="󰂲" icon.color="$MUTED"
  fi
}

tray "$@"
