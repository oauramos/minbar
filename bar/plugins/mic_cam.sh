#!/bin/bash
# Microphone / camera in use: macOS's orange and green privacy dots, made
# legible. With the native menu bar hidden (menubar-alpha) macOS still draws its
# dot, but as a few pixels in the screen corner, and the app names live in the
# menu bar's Control Center, which is gone with it.
# Hidden while nothing records; otherwise its own box with an orange mic and/or
# a green camera. Slot 1 holds whichever is on (the mic first), slot 2 the
# camera when both are, so the box ends never need re-padding and the popup
# always hangs from a drawn item.
#
# The `mic-cam --watch` agent (installed by `minbar setup`) triggers
# mic_cam_change on every change, but the state itself always comes from a
# fresh `mic-cam` (helpers/mic-cam): a reload, a wake or a missed event cannot
# leave the indicator stale. Click: a popup with the apps recording sound. The
# camera has no public "which app", so its row only says it is on.
source "$(dirname "$0")/lib.sh"

GLYPH_MIC=󰍬
GLYPH_CAM=󰕧

if [ "${SENDER:-}" = mouse.exited.global ]; then
  sketchybar --set mic_cam.1 popup.drawing=off
  exit 0
fi

MIC=0 CAM=0 APPS=""
while read -r key value; do
  case $key in
    mic) MIC=$value ;;
    cam) CAM=$value ;;
    app) APPS="$APPS$value"$'\n' ;;
  esac
done < <(mic-cam 2>/dev/null)

# Everything named mic_cam*: both slots, the box and its caps, the spacer.
if [ "$MIC" != 1 ] && [ "$CAM" != 1 ]; then
  sketchybar --set mic_cam.1 popup.drawing=off --set '/mic_cam.*/' drawing=off
  exit 0
fi

if [ "$MIC" = 1 ]; then
  first=(icon="$GLYPH_MIC" icon.color="$MIC_ON")
else
  first=(icon="$GLYPH_CAM" icon.color="$CAM_ON")
fi
second=off
[ "$MIC" = 1 ] && [ "$CAM" = 1 ] && second=on

# Popup rows, rebuilt from scratch: one per app on the mic, one for the camera.
# A regex that matches nothing only prints a warning, hence the redirect.
sketchybar --remove '/mic_cam\.row\..*/' >/dev/null 2>&1
row=(icon.font="$FONT_ICON" label.font="$FONT_TEXT" label.color="$FG"
     icon.padding_left=10 icon.padding_right=6 label.padding_left=0 label.padding_right=12)
rows=()
n=0
while IFS= read -r app; do
  [ -n "$app" ] || continue
  n=$((n + 1))
  rows+=(--add item "mic_cam.row.$n" popup.mic_cam.1
         --set "mic_cam.row.$n" "${row[@]}" icon="$GLYPH_MIC" icon.color="$MIC_ON" label="$app")
done <<<"$APPS"
if [ "$CAM" = 1 ]; then
  n=$((n + 1))
  rows+=(--add item "mic_cam.row.$n" popup.mic_cam.1
         --set "mic_cam.row.$n" "${row[@]}" icon="$GLYPH_CAM" icon.color="$CAM_ON" label="Camera in use")
fi

sketchybar "${rows[@]}" \
           --set '/mic_cam.*/' drawing=on \
           --set mic_cam.1 "${first[@]}" \
           --set mic_cam.2 drawing="$second"
