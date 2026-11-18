# MinBar build.
#   make                  native helpers into build/bin, the Simple Icons font into fonts/
#   make install PREFIX=… the install layout (Homebrew runs this):
#       bin/minbar                         the CLI
#       libexec/minbar/{menus,menubar-alpha,mic-cam}
#       share/minbar/{bar,clawd,fonts,app,cli}
#   make check            shellcheck every script
#
# The helpers link the private SkyLight framework, so they build only with
# Apple's clang (Xcode Command Line Tools) against the running macOS.

CC        ?= clang
PREFIX    ?= /usr/local
BUILD     := build
PRIVATE   := -F/System/Library/PrivateFrameworks

# Simple Icons as a font (CC0): brand logos Nerd Fonts lacks (Tailscale).
# Codepoints change per release, so fonts/simple-icons.tsv maps slug -> glyph
# and theme.sh's si_glyph looks them up. Homebrew passes the tarball it fetched
# as SI_TARBALL (its build has no network); otherwise it is downloaded here.
SI_VERSION := 16.32.0
SI_SHA256  := ba62d72011035947551db0b89f4d84814d8208c8c7b06f3f48f3ede38a20ff11
SI_URL     := https://registry.npmjs.org/simple-icons-font/-/simple-icons-font-$(SI_VERSION).tgz
SI_TARBALL ?= $(BUILD)/simple-icons-font-$(SI_VERSION).tgz

HELPERS := $(BUILD)/bin/menus $(BUILD)/bin/menubar-alpha $(BUILD)/bin/mic-cam
SCRIPTS := bin/minbar cli/*.sh bar/minbarrc bar/*.sh bar/plugins/*.sh scripts/*.sh

.PHONY: all helpers fonts install check clean

all: helpers fonts

helpers: $(HELPERS)

$(BUILD)/bin/menus: helpers/menus/menus.c
	@mkdir -p $(@D)
	$(CC) -std=c99 -O3 $(PRIVATE) -framework Carbon -framework SkyLight $< -o $@

$(BUILD)/bin/menubar-alpha: helpers/menubar-alpha/menubar-alpha.m
	@mkdir -p $(@D)
	$(CC) -fobjc-arc -O2 $(PRIVATE) -framework Cocoa -framework SkyLight $< -o $@

$(BUILD)/bin/mic-cam: helpers/mic-cam/mic-cam.c
	@mkdir -p $(@D)
	$(CC) -std=c11 -Wall -Wextra -O2 -framework CoreFoundation -framework CoreAudio \
	  -framework CoreMediaIO $< -o $@

fonts: fonts/simple-icons.tsv

$(BUILD)/simple-icons-font-$(SI_VERSION).tgz:
	@mkdir -p $(@D)
	curl -fsSL -o $@.part $(SI_URL)
	echo "$(SI_SHA256)  $@.part" | shasum -a 256 -c -
	mv $@.part $@

# The glyph is written out, not its hex: the bar runs on macOS /bin/bash 3.2,
# whose printf has no \u.
# One rule writes both files (macOS make 3.81 has no grouped targets).
fonts/simple-icons.tsv: $(SI_TARBALL)
	@mkdir -p $(BUILD)/si fonts
	tar -xzf $(SI_TARBALL) -C $(BUILD)/si
	cp $(BUILD)/si/package/font/SimpleIcons.otf fonts/SimpleIcons.otf
	jq -r '.[] | .slug + "\t" + ([.code | ascii_downcase | explode \
	  | reduce .[] as $$c (0; . * 16 + (if $$c >= 97 then $$c - 87 else $$c - 48 end))] \
	  | implode)' $(BUILD)/si/package/font/simple-icons.json > fonts/simple-icons.tsv

install: all
	install -d $(PREFIX)/bin $(PREFIX)/libexec/minbar $(PREFIX)/share/minbar
	install -m 0755 $(HELPERS) $(PREFIX)/libexec/minbar/
	cp -R bar clawd fonts app cli $(PREFIX)/share/minbar/
	sed 's|@MINBAR_ROOT@|$(PREFIX)/share/minbar|; s|@MINBAR_LIBEXEC@|$(PREFIX)/libexec/minbar|' \
	  bin/minbar > $(PREFIX)/bin/minbar
	chmod 0755 $(PREFIX)/bin/minbar

check:
	shellcheck -x -e SC1090,SC1091 $(SCRIPTS)

clean:
	rm -rf $(BUILD) fonts/SimpleIcons.otf fonts/simple-icons.tsv
