#!/bin/bash
# app/AppIcon.icns from the two drawings in app/icon. The .icns is committed, so
# only a change to a drawing needs this (and rsvg-convert: brew install librsvg).
#   minbar.svg        128 px and up
#   minbar-small.svg  16 and 32 px: the claw in one piece, a bar for the word
set -euo pipefail
cd "$(dirname "$0")/../app"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
set_dir="$tmp/AppIcon.iconset"
mkdir "$set_dir"
for size in 16 32 128 256 512; do
  drawing=icon/minbar.svg
  [ "$size" -gt 32 ] || drawing=icon/minbar-small.svg
  rsvg-convert -w "$size" -h "$size" "$drawing" -o "$set_dir/icon_${size}x${size}.png"
  rsvg-convert -w $((size * 2)) -h $((size * 2)) "$drawing" -o "$set_dir/icon_${size}x${size}@2x.png"
done
iconutil --convert icns --output AppIcon.icns "$set_dir"
echo "app/AppIcon.icns"
