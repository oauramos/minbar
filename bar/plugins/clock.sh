#!/bin/bash
source "$(dirname "$0")/lib.sh"
sketchybar --set "$NAME" label="$(date '+%a %d %b  %H:%M')"
