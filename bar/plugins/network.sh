#!/bin/bash
# Down + up throughput for the default-route interface: the gray bar (mini) or
# "<down> - <up>" in MB/s (classic).
# Each SketchyBar tick is a separate process, so cumulative byte counters + a timestamp are persisted in
# /tmp and the delta is divided by the REAL elapsed seconds.
source "$(dirname "$0")/lib.sh"

STATE="/tmp/sketchybar_net"
IFACE=$(route get default 2>/dev/null | awk '/interface:/{print $2}')

if [ -z "$IFACE" ]; then
  stat_show 0 off
  exit 0
fi

# netstat -ibn prints several rows per interface (one per address family) with
# identical cumulative totals; take the <Link> row only ($7=RX, $10=TX bytes).
read -r RX TX < <(netstat -ibn 2>/dev/null | awk -v i="$IFACE" '$1==i && /Link/{print $7, $10; exit}')
RX=${RX:-0}; TX=${TX:-0}
NOW=$(date +%s)

PRX=$RX; PTX=$TX; PT=$NOW
[ -f "$STATE" ] && read -r PRX PTX PT < "$STATE" 2>/dev/null
PRX=${PRX:-$RX}; PTX=${PTX:-$TX}; PT=${PT:-$NOW}

DT=$(( NOW - PT )); [ "$DT" -le 0 ] && DT=1
DRX=$(( RX - PRX )); [ "$DRX" -lt 0 ] && DRX=0   # counter reset / overflow guard
DTX=$(( TX - PTX )); [ "$DTX" -lt 0 ] && DTX=0
DOWN=$(( DRX / DT ))
UP=$(( DTX / DT ))

printf '%s %s %s\n' "$RX" "$TX" "$NOW" > "$STATE"

# Bar: log scale, since traffic spans five orders of magnitude: 1 KB/s or less
# is empty, every 10x adds a fifth, 100 MB/s and up is full (10 KB/s 20%,
# 1 MB/s 60%).
# The clamp is its own statement: macOS awk reads a ">" in printf's argument
# list as an output redirection, which left PCT empty and the bar at minimum.
PCT=$(awk -v b="$(( DOWN + UP ))" 'BEGIN{
  p = 0; if (b > 1000) p = (log(b) / log(10) - 3) * 20;
  if (p > 100) p = 100;
  printf "%.0f", p }')

# Text: always MB so the unit never changes (no K↔M flicker), and never more
# than three characters, so "999 - 999" is the widest value and the fixed cell
# in sketchybarrc holds every reading: under 10 → one decimal ("9.9"), 10–999 →
# integer ("12", "125"), from 1000 → "1k+". The cut-offs sit at the rounding
# points, or 9.96 would print "10.0" and 999.6 "1000".
human() {
  awk -v b="$1" 'BEGIN{
    mb = b / 1048576;
    if      (mb >= 999.5) printf "1k+";
    else if (mb >= 9.95)  printf "%.0f", mb;
    else                  printf "%.1f", mb }'
}

# "<down> - <up>", bare numbers — no ↓/↑ or letters; any marker sat oddly next
# to the SF Pro digits.
stat_show "$PCT" "$(human "$DOWN") - $(human "$UP")"
