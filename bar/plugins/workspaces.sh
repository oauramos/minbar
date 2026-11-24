#!/bin/bash
# App → workspace rules: which AeroSpace workspace an app's new windows open on.
# An app without a rule is dynamic: its windows open where you are.
#   sourced                        the ws_* functions (the CLI, space.sh)
#   workspaces.sh watch            the launchd agent: moves each new window
#   workspaces.sh set ID NAME WS   pin (or WS=dynamic), from a workspace's menu
#
# One rule per line, text only, never executed; a name makes several bundle ids
# one app:
#   Playwright = com.google.Chrome, com.google.chrome.for.testing -> 8
#   com.apple.mail -> 3
# Two files, later wins: ~/.config/minbar/workspaces.conf (the settings; read-only
# under home-manager), then ~/.local/state/minbar/workspaces.conf (`minbar
# workspaces set` and the bar's menu). `dynamic` there undoes a rule of the first.
# ~/.aerospace.toml is left alone: it is one file with no includes, often managed
# elsewhere, so the rules ride AeroSpace's window-detected event instead (0.21+).

: "${WS_CONF:=$HOME/.config/minbar/workspaces.conf}"
: "${WS_OVR:=$HOME/.local/state/minbar/workspaces.conf}"

# ws_parse FILE: "name<TAB>workspace<TAB>bundle id", one line per id.
ws_parse() {
  [ -f "$1" ] || return 0
  awk '
    function trim(s) { gsub(/^[ \t]+|[ \t\r]+$/, "", s); return s }
    { sub(/#.*/, ""); i = index($0, "->"); if (!i) next
      ws = trim(substr($0, i + 2)); left = trim(substr($0, 1, i - 1))
      if (ws !~ /^[A-Za-z0-9_-]+$/) next
      e = index(left, "="); name = ""
      if (e) { name = trim(substr(left, 1, e - 1)); left = substr(left, e + 1) }
      n = split(left, ids, ",")
      for (k = 1; k <= n; k++) {
        id = trim(ids[k]); if (id !~ /^[A-Za-z0-9._-]+$/) continue
        printf "%s\t%s\t%s\n", (name == "" ? id : name), ws, id
      } }' "$1"
}
# Every id once, under the rule in force (the last one that names it).
ws_rules() {
  { ws_parse "$WS_CONF"; ws_parse "$WS_OVR"; } | awk -F'\t' '
    !($3 in row) { order[++n] = $3 } { row[$3] = $0 } END { for (i = 1; i <= n; i++) print row[order[i]] }'
}
# ws_lookup ID: its workspace, or "dynamic". Bundle ids compare without case, as
# macOS does.
ws_lookup() {
  ws_rules | awk -F'\t' -v id="$1" 'tolower($3) == tolower(id) { ws = $2 } END { print (ws == "" ? "dynamic" : ws) }'
}
# "name<TAB>workspace<TAB>id, id…": the rules in force, one line per app.
ws_apps() {
  ws_rules | awk -F'\t' '
    { k = $1 "\t" $2; if (!(k in ids)) order[++n] = k; ids[k] = ids[k] (ids[k] == "" ? "" : ", ") $3 }
    END { for (i = 1; i <= n; i++) print order[i] "\t" ids[order[i]] }'
}
# ws_family ID NAME: "name<TAB>id id…" of the rule that names ID, so a named app
# moves as a whole; without one, NAME and the id itself.
ws_family() {
  ws_rules | awk -F'\t' -v id="$1" -v name="$2" '
    { ids[$1] = ids[$1] " " $3 } tolower($3) == tolower(id) { hit = $1 }
    END { if (hit == "") print name "\t" id; else print hit "\t" substr(ids[hit], 2) }'
}
# ws_set NAME WS ID...: the runtime file, rewritten without those ids, then with
# the new rule. It holds only what differs from the settings.
ws_set() {
  local name=$1 ws=$2 tmp id in_conf differs=0
  shift 2
  mkdir -p "${WS_OVR%/*}"
  tmp=$(mktemp "${WS_OVR%/*}/.workspaces.XXXXXX") || return 1
  for id in "$@"; do
    in_conf=$(WS_OVR=/dev/null ws_rules | awk -F'\t' -v id="$id" 'tolower($3) == tolower(id) { print $2 }')
    # An alias made here stays listed as dynamic, or its ids would be forgotten.
    if [ -z "$in_conf" ] && [ $# -eq 1 ]; then in_conf=dynamic; fi
    [ "$in_conf" = "$ws" ] || differs=1
  done
  {
    ws_parse "$WS_OVR" | awk -F'\t' -v drop="$*" '
      BEGIN { n = split(tolower(drop), d, " "); for (i = 1; i <= n; i++) gone[d[i]] = 1 }
      !(tolower($3) in gone) { print $1 " = " $3 " -> " $2 }'
    if [ "$differs" = 1 ]; then
      for id in "$@"; do echo "$name = $id -> $ws"; done
    fi
  } >"$tmp"
  if [ -s "$tmp" ]; then mv "$tmp" "$WS_OVR"; else rm -f "$tmp" "$WS_OVR"; fi
}

# The agent. The files are read again for every window, so a new rule needs no
# restart; AeroSpace quitting ends the stream, and the loop waits for it to
# return. The move never takes the focus along.
ws_watch() {
  local line id win ws
  while :; do
    aerospace subscribe --no-send-initial window-detected 2>/dev/null | while IFS= read -r line; do
      IFS=$'\t' read -r win id < <(jq -r '[.windowId, .appBundleId // ""] | @tsv' <<<"$line" 2>/dev/null)
      [ -n "$id" ] || continue
      ws=$(ws_lookup "$id")
      [ "$ws" = dynamic ] && continue
      aerospace move-node-to-workspace --window-id "$win" -- "$ws" </dev/null 2>/dev/null
    done
    sleep 10
  done
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  case "${1:-}" in
    watch) ws_watch ;;
    set)
      IFS=$'\t' read -r name ids < <(ws_family "${2:?}" "${3:?}")
      # shellcheck disable=SC2086  # a list of bundle ids
      ws_set "$name" "${4:?}" $ids ;;
    *) echo "workspaces.sh watch | set ID NAME WS" >&2; exit 64 ;;
  esac
fi
