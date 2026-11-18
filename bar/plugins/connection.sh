#!/bin/bash
# Wired (Ethernet) indicator (monochrome): white server-network glyph when any
# wired port has an IPv4 address, muted crossed one when every port is unplugged
# or its service is inactive. Hidden on a Mac with no wired port at all. Wi-Fi is the
# wifi item's job (wifi.sh), so this never shows a Wi-Fi glyph: it used to
# follow the default route, and with Ethernet off that drew a second Wi-Fi
# glyph next to the wifi item.
# Click opens System Settings > Network (set in sketchybarrc); no toggle here —
# cutting the wired link from the bar is one misclick from losing the box.
source "$(dirname "$0")/lib.sh"

WIRED=$(wired_ifaces)

if [ -z "$WIRED" ]; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

for IF in $WIRED; do
  if [ -n "$(ipconfig getifaddr "$IF" 2>/dev/null)" ]; then
    sketchybar --set "$NAME" drawing=on icon="󰒍" icon.color="$FG" label.drawing=off
    exit 0
  fi
done
sketchybar --set "$NAME" drawing=on icon="󰒎" icon.color="$MUTED" label.drawing=off
