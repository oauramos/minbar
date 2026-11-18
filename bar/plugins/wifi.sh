#!/bin/bash
# Wi-Fi radio power (monochrome): white glyph when the radio is on, muted
# crossed glyph when off, plus the SSID as a label once joined (unless the host
# sets MINBAR_SHOW_WIFI_NAME=0). Distinct from connection.sh, which shows the wired
# link. `wifi.sh click`: single click toggles the radio,
# double click opens System Settings > Wi-Fi (see dblclick.sh). No arg = refresh.
# shellcheck disable=SC2153  # $NAME is SketchyBar's item name, not a typo for the local $name (the SSID)
source "$(dirname "$0")/lib.sh"
source "$(dirname "$0")/dblclick.sh"

WIFI_IF=$(wifi_iface)

radio_on() { networksetup -getairportpower "$WIFI_IF" 2>/dev/null | grep -q ': On'; }

toggle() {
  if radio_on; then networksetup -setairportpower "$WIFI_IF" off
  else              networksetup -setairportpower "$WIFI_IF" on
  fi
}
settings() { open "x-apple.systempreferences:com.apple.wifi-settings-extension"; }

# On Tahoe `networksetup -getairportnetwork` is unreliable, so the SSID comes
# from `ipconfig getsummary`, which prints "<redacted>" to a process without
# Location Services access (the daemon has none) unless `sudo ipconfig
# setverbose 1` was run. A redacted name is dropped, not shown.
ssid() {
  [ "$MINBAR_SHOW_WIFI_NAME" = 0 ] && return
  ipconfig getsummary "$WIFI_IF" 2>/dev/null |
    awk -F' SSID : ' '/ SSID : / && $2 != "<redacted>" {print $2; exit}'
}

render() {
  if radio_on; then
    local name
    name=$(ssid)
    if [ -n "$name" ]; then
      sketchybar --set "$NAME" icon="󰖩" icon.color="$FG" label="$name" label.drawing=on
    else
      sketchybar --set "$NAME" icon="󰖩" icon.color="$FG" label.drawing=off
    fi
  else
    sketchybar --set "$NAME" icon="󰖪" icon.color="$MUTED" label.drawing=off
  fi
}

case "${1:-}" in
  click)  click_dispatch toggle settings ;;
  toggle) toggle ;;   # straight away, no double-click window (the `sketchybar` TUI)
esac
render
