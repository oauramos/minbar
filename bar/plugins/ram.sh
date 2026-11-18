#!/bin/bash
# RAM usage as a percentage of total, via vm_stat (active + wired + compressed
# pages) ÷ hw.memsize: the purple bar (mini) or "56%". Page size resolved dynamically
# (16384 on Apple Silicon).
source "$(dirname "$0")/lib.sh"

PAGE=$(pagesize 2>/dev/null); [ -z "$PAGE" ] && PAGE=$(getconf PAGE_SIZE 2>/dev/null); [ -z "$PAGE" ] && PAGE=16384
TOTAL_B=$(sysctl -n hw.memsize 2>/dev/null); [ -z "$TOTAL_B" ] && TOTAL_B=0

read -r A W C < <(vm_stat 2>/dev/null | awk '
  /Pages active/                 {a=$3}
  /Pages wired down/             {w=$4}
  /Pages occupied by compressor/ {c=$5}
  END { gsub(/\./,"",a); gsub(/\./,"",w); gsub(/\./,"",c);
        if(a=="")a=0; if(w=="")w=0; if(c=="")c=0; print a, w, c }')
A=${A:-0}; W=${W:-0}; C=${C:-0}

USED_B=$(( (A + W + C) * PAGE ))
PCT=0
[ "$TOTAL_B" -gt 0 ] && PCT=$(awk -v u="$USED_B" -v t="$TOTAL_B" 'BEGIN{printf "%.0f", (u/t)*100}')

stat_show "$PCT" "${PCT}%"
