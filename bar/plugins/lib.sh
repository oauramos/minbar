#!/bin/bash
# Shared plugin prelude: `source "$(dirname "$0")/lib.sh"` first thing in every
# plugin (dblclick.sh stays a separate opt-in, sourced after it). The launchd
# daemon spawns plugins with ITS env, not the rc's, so the rc's variables never
# reach us: the theme and the user's settings are re-read here, once, instead
# of being re-declared as literal fallbacks in each script. Tools the plugins
# call by name (sketchybar, menus, mic-cam, blueutil, aerospace) are on the
# daemon's PATH, set by MinBar's launchd agent.
set -u
# SketchyBar exports CONFIG_DIR (the rc's directory); run by hand, it is the
# directory above this file.
: "${CONFIG_DIR:=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# Hard source, no guard: they ship next to the plugins, and with set -u a
# silent skip would crash every plugin anyway.
source "$CONFIG_DIR/theme.sh"
source "$CONFIG_DIR/config.sh"

# The Wi-Fi device (en0 or en1, by hardware port name), for wifi.sh.
wifi_iface() { networksetup -listallhardwareports 2>/dev/null | awk '/Wi-Fi/{getline; print $2; exit}'; }
# Wired devices for connection.sh: every hardware port that is not Wi-Fi, a
# Thunderbolt port/bridge or a tethered phone, so USB LAN adapters count too.
wired_ifaces() {
  networksetup -listallhardwareports 2>/dev/null | awk '
    /^Hardware Port:/ { skip = /Wi-Fi|Thunderbolt|Bridge|Bluetooth|iPhone|iPad/ }
    /^Device:/ && !skip { print $2 }'
}

# System-monitor value, drawn per MINBAR_VARIANT: mini → a bar at $1 percent,
# classic → the text $2 as the label.
stat_show() {
  if [ "$MINBAR_VARIANT" = mini ]; then
    stat_bar "$1"
  else
    sketchybar --set "$NAME" label="$2"
  fi
}

# System-monitor bar at $1 percent (0-100, clamped): the height glides there,
# and the bar stays bottom-aligned because a background is centred on the item,
# so the y_offset drops it by half the height it is missing. Every animation
# frame is a WindowServer redraw, so an unchanged height (most ticks: a pixel
# is 6% of the range) is skipped, and the glide is a short 8 frames. The rc
# clears these caches on every load, when the bars restart at the minimum.
stat_bar() {
  local h=$(( STAT_BAR_MIN + (STAT_BAR_MAX - STAT_BAR_MIN) * $1 / 100 ))
  [ "$h" -gt "$STAT_BAR_MAX" ] && h=$STAT_BAR_MAX
  [ "$h" -lt "$STAT_BAR_MIN" ] && h=$STAT_BAR_MIN
  local last="/tmp/sketchybar_bar_$NAME"
  [ "$(cat "$last" 2>/dev/null)" = "$h" ] && return 0
  echo "$h" >"$last"
  sketchybar --animate sin 8 --set "$NAME" background.height="$h" \
             background.y_offset=$(( (h - STAT_BAR_MAX) / 2 ))
}
