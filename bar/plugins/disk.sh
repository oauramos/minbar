#!/bin/bash
# Disk usage as a percentage (df's capacity column): the white bar (mini) or "58%". The
# Data volume, not /: on APFS / is the sealed system snapshot, a few GB that
# never fill, while everything you store lands on Data.
source "$(dirname "$0")/lib.sh"

PCT=$(df -k /System/Volumes/Data 2>/dev/null | awk 'NR==2 {print $5}')
PCT=${PCT%\%}
[ -z "$PCT" ] && PCT=0

stat_show "$PCT" "${PCT}%"
