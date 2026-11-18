#!/bin/bash
# Highlights the active AeroSpace workspace: near-white pill + dark number for
# the focused one, plain white number for the rest.
#   - aerospace_workspace_change: $FOCUSED_WORKSPACE is passed by the trigger.
#   - any other run (load / system_woke): query aerospace directly (Homebrew's
#     bin is on the daemon's PATH, see lib.sh).
source "$(dirname "$0")/lib.sh"

WORKSPACE="${NAME#space.}"

case "${SENDER:-}" in
  aerospace_workspace_change) FOCUSED="${FOCUSED_WORKSPACE:-}" ;;
  *)                          FOCUSED=$(aerospace list-workspaces --focused 2>/dev/null) ;;
esac

if [ "$FOCUSED" = "$WORKSPACE" ]; then
  sketchybar --set "$NAME" background.drawing=on  icon.color="$ACTIVE_FG"
else
  sketchybar --set "$NAME" background.drawing=off icon.color="$FG"
fi
