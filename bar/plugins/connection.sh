#!/bin/bash
# Wired (Ethernet) indicator (monochrome): white server-network glyph when any
# wired port has an IPv4 address, muted crossed one when every port is unplugged
# or its service is inactive. Hidden on a Mac with no wired port at all. Wi-Fi is the
# wifi item's job (wifi.sh), so this never shows a Wi-Fi glyph: it used to
# follow the default route, and with Ethernet off that drew a second Wi-Fi
# glyph next to the wifi item.
# Right click: On, Off, Settings (tray.sh). On and Off make the wired ports'
# network services active or inactive, as in System Settings > Network; the check
# is on On while any of them is active, cable or not. Off cuts the wired link: on
# a Mac reached over it, only its own screen can turn it back on.
source "$(dirname "$0")/tray.sh"

WIRED=$(wired_ifaces)

# "on" or "off", a tab and the name of each network service on a wired port.
# An inactive one is listed as (*) instead of its number.
wired_services() {
  networksetup -listnetworkserviceorder 2>/dev/null | awk -v devs=" ${WIRED//$'\n'/ } " '
    /^\([0-9*]+\) / { state = /^\(\*/ ? "off" : "on"; sub(/^\([0-9*]+\) /, ""); name = $0; next }
    /^\(Hardware Port: / {
      sub(/.*Device: /, ""); sub(/\)$/, "")
      if ($0 != "" && index(devs, " " $0 " ")) print state "\t" name
    }'
}

is_on() { [ -n "$(wired_services | awk -F'\t' '$1 == "on"')" ]; }
turn() {
  local state service
  while IFS=$'\t' read -r state service; do
    [ "$state" = "$1" ] || networksetup -setnetworkserviceenabled "$service" "$1"
  done < <(wired_services)
}
settings() { open "x-apple.systempreferences:com.apple.Network-Settings.extension"; }

render() {
  local if_
  if [ -z "$WIRED" ]; then
    sketchybar --set "$NAME" drawing=off
    return
  fi
  for if_ in $WIRED; do
    if [ -n "$(ipconfig getifaddr "$if_" 2>/dev/null)" ]; then
      sketchybar --set "$NAME" drawing=on icon="󰒍" icon.color="$FG" label.drawing=off
      return
    fi
  done
  sketchybar --set "$NAME" drawing=on icon="󰒎" icon.color="$MUTED" label.drawing=off
}

tray "$@"
