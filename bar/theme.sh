#!/bin/bash
# Theme — one file for the rc AND the plugins. The launchd daemon spawns plugins
# with its own env, so nothing the rc exports reaches them; both sides source
# this instead (the rc directly, plugins via plugins/lib.sh). Tweak + `minbar reload`.
# shellcheck disable=SC2034  # every value is read by whoever sources this

##### Palette — sober macOS monochrome (0xAARRGGBB) #####
BAR_COLOR=0x00000000      # transparent bar so the boxes detach
BOX_BG=0xbf1c1c1e         # graphite box fill (~75% opaque — frosted glass)
BOX_BORDER=0xff48484a     # subtle gray border
FG=0xfff5f5f7             # primary label (near-white)
MUTED=0xff8e8e93          # secondary label (macOS system gray)
DIM=0xff5a5a5e            # separators / tertiary
ACTIVE_BG=0xfff5f5f7      # active workspace fill (near-white pill)
ACTIVE_FG=0xff1c1c1e      # dark glyph on the active pill
# The only colour on the bar: one per system-monitor bar…
STAT_CPU=0xffff9f0a       # orange (macOS system orange)
STAT_RAM=0xffbf5af2       # purple (macOS system purple)
STAT_DISK=$FG             # white
STAT_NET=$MUTED           # gray
# …and the privacy indicator (plugins/mic_cam.sh), in macOS's own dot colours.
MIC_ON=0xffff9f0a         # microphone in use: system orange
CAM_ON=0xff30d158         # camera in use: system green

##### Type scale — weight carries meaning #####
# Text is SF Pro 13: Regular for values (stats, menu titles), Bold for headings
# (the "CPU:" prefixes, the app name in the menu row), Semibold for the
# workspace digits in their pills. On the mini bar (MINBAR_VARIANT) the icon +
# value boxes (clock, volume, battery) go one step down to FONT_VALUE, 12: at
# the same 13 as the workspace digits, a run of Regular text like
# "Sun 25 Oct 19:51" reads bigger than the spaced-out Semibold pills. The rc
# sets FONT_VALUE back to FONT_TEXT on classic.
# Glyphs are Hack Nerd Font 14. Most (clock, battery, the control box) fill
# their em box and draw 24px tall on Retina; the volume speaker draws only 18px
# at 14, so it alone gets FONT_ICON_VOLUME (16): 18 matched them on paper but
# the solid speaker read bigger than the thin glyphs.
FONT_TEXT="SF Pro:Regular:13.0"
FONT_VALUE="SF Pro:Regular:12.0"
FONT_TEXT_BOLD="SF Pro:Bold:13.0"
FONT_TEXT_SEMI="SF Pro:Semibold:13.0"
FONT_ICON="Hack Nerd Font:Regular:14.0"
FONT_ICON_VOLUME="Hack Nerd Font:Regular:16.0"
# Brand logos Nerd Fonts lacks, from Simple Icons (fonts/, `make fonts`). Set
# icon.font="$FONT_BRAND" icon="$(si_glyph <slug>)" on the item; the slug is the
# one in the simpleicons.org URL. Codepoints move between releases, hence the
# lookup instead of a literal glyph. 12, not 14: these glyphs fill the whole
# em box, so at 14 they read bigger than the Nerd Font icons next to them.
FONT_BRAND="Simple Icons:Regular:12.0"
si_glyph() { awk -F'\t' -v s="$1" '$1 == s { print $2; exit }' "${MINBAR_ROOT:-$CONFIG_DIR/..}/fonts/simple-icons.tsv" 2>/dev/null; }

##### Layout #####
# Box spacing standard, THE token, measured on what is drawn: BOX_PAD is the
# count of EMPTY pixels between a box's border line and the nearest ink (glyph,
# text or bar), on both sides of every box. An icon row (the control box) uses
# the same BOX_PAD between neighbouring icons, ink to ink, so it reads
# ( icon icon icon ) and never (icon  icon  icon). The rc's `box` function
# builds every box (but the workspace pills, see PILL_INSET) and enforces it,
# so items never pad their own box ends. Check it on screen, not on paper:
# a frame or cell edge is not where the ink is. Glyph side bearings still move
# the ink by about 1px; that is the font, not the layout.
# classic (big screens) breathes more than mini (laptops); the rc picks one.
BOX_PAD_CLASSIC=12
BOX_PAD_MINI=10
BOX_PAD=$BOX_PAD_MINI
ITEM_PAD=4
# A box whose content is a pill (the workspaces) insets the end pills by the
# same amount horizontally as vertically: (box height 26 - pill height 22) / 2.
PILL_INSET=2
# System-monitor bars: STAT_BAR_W wide, STAT_BAR_GAP apart, STAT_BAR_MAX tall
# at 100% (inside the 26px box, 5px top and bottom), never under STAT_BAR_MIN
# so an idle bar still shows.
STAT_BAR_W=4
STAT_BAR_GAP=3
STAT_BAR_MAX=16
STAT_BAR_MIN=2
# Menu slots on the left: the rc creates this many items, menus.sh fills them.
MENU_SLOTS=15
