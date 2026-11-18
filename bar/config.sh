#!/bin/bash
# MinBar settings. Sourced by the rc and, through plugins/lib.sh, by every
# plugin: the daemon spawns plugins with its own environment, so nothing the rc
# sets reaches them. Read in this order, later wins:
#   1. the defaults below;
#   2. ~/.config/minbar/minbar.conf (or $MINBAR_CONF), the user's settings,
#      plain KEY=value lines (`minbar setup` writes a commented one);
#   3. ~/.local/state/minbar/layout.env, runtime overrides from `minbar layout`:
#      only the four layout keys, taken as text, never executed.
# shellcheck disable=SC2034  # every value is read by whoever sources this

MINBAR_VARIANT=classic       # classic (big screens) | mini (laptops: smaller values, slower polling)
MINBAR_SHOW_STATS=1          # CPU / RAM / DISK (/ NET) box
MINBAR_SHOW_NETWORK=1        # NET in that box
MINBAR_SHOW_WIFI_NAME=0      # SSID next to the Wi-Fi glyph
MINBAR_WORKSPACES=auto       # auto: AeroSpace workspaces when `aerospace` is installed | off
MINBAR_WORKSPACE_COUNT=      # empty: 5 on mini, 8 on classic
MINBAR_CLAWD=on              # clawd, one pixel Claude Code mascot per session | off
MINBAR_NC_KEY=45             # the bell types this Notification Center shortcut: N
MINBAR_NC_MODS=ctrl,alt,cmd  #   with these modifiers (`minbar setup` assigns the same one)

: "${MINBAR_CONF:=${XDG_CONFIG_HOME:-$HOME/.config}/minbar/minbar.conf}"
# shellcheck source=/dev/null
[ -f "$MINBAR_CONF" ] && source "$MINBAR_CONF"

_minbar_layout="${XDG_STATE_HOME:-$HOME/.local/state}/minbar/layout.env"
if [ -f "$_minbar_layout" ]; then
  while IFS='=' read -r _minbar_k _minbar_v; do
    case "$_minbar_k" in
      MINBAR_VARIANT | MINBAR_SHOW_STATS | MINBAR_SHOW_NETWORK | MINBAR_SHOW_WIFI_NAME)
        printf -v "$_minbar_k" '%s' "$_minbar_v" ;;
    esac
  done <"$_minbar_layout"
  unset _minbar_k _minbar_v
fi
unset _minbar_layout

if [ -z "$MINBAR_WORKSPACE_COUNT" ]; then
  if [ "$MINBAR_VARIANT" = mini ]; then MINBAR_WORKSPACE_COUNT=5; else MINBAR_WORKSPACE_COUNT=8; fi
fi
