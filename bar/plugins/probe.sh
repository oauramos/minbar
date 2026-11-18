#!/bin/bash
# `minbar doctor` triggers minbar_probe and reads what this writes: whether the
# daemon (MinBar.app, whose grants every plugin and helper uses) holds
# Accessibility and Full Disk Access. Only on that event; a reload just exits.
source "$(dirname "$0")/lib.sh"
[ "${SENDER:-}" = minbar_probe ] || exit 0

out="$HOME/.local/state/minbar/probe"
mkdir -p "${out%/*}"
# menus asks AXIsProcessTrusted first and exits 1 when untrusted (it also shows
# macOS's own prompt then, which is what we want).
if menus -l >/dev/null 2>&1; then ax=yes; else ax=no; fi
if /usr/bin/sqlite3 -readonly \
  "file:$HOME/Library/Group Containers/group.com.apple.usernoted/db2/db?mode=ro" \
  'select 1' >/dev/null 2>&1; then fda=yes; else fda=no; fi
printf 'accessibility=%s\nfull_disk_access=%s\nat=%s\n' "$ax" "$fda" "$(date +%s)" >"$out.tmp"
mv "$out.tmp" "$out"
