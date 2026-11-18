#!/bin/bash
# Total CPU busy % (user + sys) over one second: the orange bar (mini) or
# "12%". iostat, not `top -l 1`: same 1s sample, but top cost ~0.18s of CPU a
# run (10% of a core at a 2s tick, just to draw this), iostat ~0.01s. It
# sleeps the second away, so a run takes ~1s of wall time.
source "$(dirname "$0")/lib.sh"

CPU=$(iostat -n 0 -c 2 -w 1 2>/dev/null | awk 'END {print $1 + $2}')
[ -z "$CPU" ] && CPU=0

stat_show "$CPU" "${CPU}%"
