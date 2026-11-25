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
MUTED=0xff8e8e93          # secondary label (macOS system gray): off, inactive
PREFIX=0xffaeaeb2         # the stats' "CPU:" prefixes (macOS system gray 2): small Regular text needs more contrast
DIM=0xff5a5a5e            # separators / tertiary
ACTIVE_BG=0xfff5f5f7      # active workspace fill (near-white pill)
ACTIVE_FG=0xff1c1c1e      # dark glyph on the active pill
# The only colour on the bar: one per system-monitor bar.
STAT_CPU=0xffff9f0a       # orange (macOS system orange)
STAT_RAM=0xffbf5af2       # purple (macOS system purple)
STAT_DISK=$FG             # white
STAT_NET=$MUTED           # gray

##### Type: one face, one weight, one size #####
# Every text on the bar is FONT_TEXT, SF Pro Regular at MINBAR_FONT_SIZE
# (config.sh; `minbar font-size`): menu titles, workspace digits, stats and their
# prefixes, volume, bell, clock, popups. No bold headings and no smaller values:
# at 1x a bold grey prefix smears, and a 12 sits half a pixel lower than a 13.
# Colour alone tells a prefix (MUTED) from its value (FG).
# FONT_FEATURES gives figures one width, so a value never shifts as it changes.
#
# Glyphs are Hack Nerd Font, a point bigger than the text. Most (clock, battery,
# the control box) fill their em box; the speaker does not and is four points
# bigger: 11-12px of ink at 13, as tall as the others.
#
# SketchyBar puts a baseline on a whole point, so what is centred at one size is
# up to 0.7px off at another. ICON_Y lifts the glyphs where the error is over half
# a pixel. Measured on screen, ink against the box's centre, at every size: the
# text is within 0.7, the glyphs within 0.5.
FONT_FEATURES=tnum
BADGE_FONT="SF Pro:Regular:10.0"   # the counts on clawd's sprites, the one smaller text
# set_fonts SIZE: the rc and plugins/lib.sh call it, after config.sh.
set_fonts() {
  FONT_TEXT="SF Pro:Regular:$1.0"
  FONT_ICON="Hack Nerd Font:Regular:$(($1 + 1)).0"
  FONT_ICON_VOLUME="Hack Nerd Font:Regular:$(($1 + 4)).0"
  # A brand glyph fills its whole em box: at the icons' size it reads bigger.
  FONT_BRAND="Simple Icons:Regular:$(($1 - 1)).0"
  case $1 in 11 | 14) ICON_Y=1 ;; *) ICON_Y=0 ;; esac
}
# Brand logos Nerd Fonts lacks, from Simple Icons (fonts/, `make fonts`). Set
# icon.font="$FONT_BRAND" icon="$(si_glyph <slug>)" on the item; the slug is the
# one in the simpleicons.org URL. Codepoints move between releases, hence the
# lookup instead of a literal glyph.
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
