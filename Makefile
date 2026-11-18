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
# Where the files are found at run time, baked into bin/minbar and the launchd
# agents: Homebrew installs into a versioned Cellar but runs through opt/.
RUNTIME_PREFIX ?= $(PREFIX)
BUILD     := build
PRIVATE   := -F/System/Library/PrivateFrameworks

# Simple Icons as a font (CC0): brand logos Nerd Fonts lacks (Tailscale).
# Codepoints change per release, so fonts/simple-icons.tsv maps slug -> glyph
# and theme.sh's si_glyph looks them up. Homebrew passes its staged resource as
# SI_DIR and Nix its fetched tarball as SI_TARBALL (no network in either build);
# otherwise the tarball is downloaded here.
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

# scripts/glyphs.jq turns the font's JSON into the slug -> glyph table.
# One rule writes both files (macOS make 3.81 has no grouped targets). SI_DIR:
# the package already unpacked (Homebrew stages its resource there); otherwise
# the tarball is unpacked into build/si.
fonts/simple-icons.tsv: $(if $(SI_DIR),,$(SI_TARBALL))
	@mkdir -p fonts
	@if [ -n "$(SI_DIR)" ]; then src="$(SI_DIR)"; \
	else mkdir -p $(BUILD)/si && tar -xzf $(SI_TARBALL) -C $(BUILD)/si && src=$(BUILD)/si; fi; \
	[ -d "$$src/font" ] || src="$$src/package"; \
	echo "fonts from $$src"; \
	cp "$$src/font/SimpleIcons.otf" fonts/SimpleIcons.otf && \
	jq -r -f scripts/glyphs.jq "$$src/font/simple-icons.json" > fonts/simple-icons.tsv

install: all
	install -d $(PREFIX)/bin $(PREFIX)/libexec/minbar $(PREFIX)/share/minbar
	install -m 0755 $(HELPERS) $(PREFIX)/libexec/minbar/
	cp -R bar clawd fonts app cli LICENSE NOTICE.md $(PREFIX)/share/minbar/
	sed 's|@MINBAR_ROOT@|$(RUNTIME_PREFIX)/share/minbar|; s|@MINBAR_LIBEXEC@|$(RUNTIME_PREFIX)/libexec/minbar|' \
	  bin/minbar > $(PREFIX)/bin/minbar
	chmod 0755 $(PREFIX)/bin/minbar

check:
	shellcheck -x -e SC1090,SC1091 $(SCRIPTS)

clean:
	rm -rf $(BUILD) fonts/SimpleIcons.otf fonts/simple-icons.tsv
