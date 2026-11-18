#!/bin/bash
# Battery: one fixed upright battery glyph (md-battery) and the percentage; the
# number carries the level, the glyph does not change with it. Color signals
# state: charging = green, low = red, otherwise the theme foreground.
source "$(dirname "$0")/lib.sh"

PERCENTAGE="$(pmset -g batt | grep -Eo "\d+%" | cut -d% -f1)"
CHARGING="$(pmset -g batt | grep 'AC Power')"

if [ "$PERCENTAGE" = "" ]; then
  exit 0
fi

# Status semantics, not palette: these stay local.
GREEN=0xff30d158
RED=0xffff453a

COLOR="$FG"
if [ "$CHARGING" != "" ]; then
  COLOR="$GREEN"
elif [ "$PERCENTAGE" -le 20 ]; then
  COLOR="$RED"
fi

sketchybar --set "$NAME" icon.color="$COLOR" label="${PERCENTAGE}%"
