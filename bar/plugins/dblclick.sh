#!/bin/bash
# Single vs double click on top of SketchyBar's single click event. Source it
# from a plugin, then `click_dispatch <single-fn> <double-fn>` in the click_script
# branch. The first click arms a short window (a marker dir keyed by $NAME) and
# waits; a second click inside it consumes the marker and runs <double-fn>; if
# nobody does, the first instance runs <single-fn>. click_scripts are spawned as
# independent processes, so the two instances only meet through the marker.
#
# Arming is `mkdir`, which is atomic: when both clicks race to the marker (the
# plugins run slow lookups like `networksetup` before dispatching, so two
# instances can easily arrive together) exactly one wins and the other becomes
# the double click. A check-then-touch here once let both instances run the
# single action — for connection.sh that meant Ethernet off, twice.
DOUBLE_CLICK_S="${DOUBLE_CLICK_S:-0.35}"

click_dispatch() {
  local single=$1 double=$2 armed="/tmp/sketchybar-click.$UID.$NAME"
  # A marker older than 2s is a leftover from a killed instance, not a click.
  if [ -d "$armed" ] && [ $(( $(date +%s) - $(stat -f %m "$armed" 2>/dev/null || echo 0) )) -gt 2 ]; then
    rmdir "$armed" 2>/dev/null
  fi
  if ! mkdir "$armed" 2>/dev/null; then   # already armed: second click
    rmdir "$armed" 2>/dev/null
    "$double"
    return 0
  fi
  sleep "$DOUBLE_CLICK_S"
  rmdir "$armed" 2>/dev/null || return 0   # a double click consumed it meanwhile
  "$single"
}
