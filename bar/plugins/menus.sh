#!/bin/bash
# Populate the LEFT menu slots from the frontmost app's native macOS menu bar,
# read live via the `menus` Accessibility helper (helpers/menus, on the daemon's
# PATH). Fired on front_app_switched (and
# on load) by the hidden menu_watcher item.
#
# Requires Accessibility for MinBar (System Settings > Privacy & Security >
# Accessibility; the helper runs on the daemon's grant) — until then `menus -l` prints nothing
# and the slots stay hidden (only the Apple glyph shows).
source "$(dirname "$0")/lib.sh"

MAX=$MENU_SLOTS

# Hide every slot first so stale labels from the previous app don't linger.
for i in $(seq 1 "$MAX"); do
  sketchybar --set "menu.$i" drawing=off
done

command -v menus >/dev/null 2>&1 || exit 0

id=1
while IFS= read -r title; do
  [ "$id" -gt "$MAX" ] && break
  [ -z "$title" ] && continue
  # The app-name menu (first line) is bold like macOS; the rest are regular.
  if [ "$id" -eq 1 ]; then font="$FONT_TEXT_BOLD"; else font="$FONT_TEXT"; fi
  sketchybar --set "menu.$id" label="$title" label.font="$font" drawing=on
  id=$((id + 1))
done < <(menus -l 2>/dev/null)
