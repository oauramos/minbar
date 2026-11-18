# shellcheck shell=bash
# shellcheck disable=SC2034  # read by install.sh, tui.sh and main.sh, sourced after this
# Paths, names and small helpers every part of the CLI shares. Sourced by
# cli/main.sh after bin/minbar has set MINBAR_ROOT and MINBAR_LIBEXEC.

MINBAR_VERSION=0.1.0

# launchd labels: the bar, and the two helper agents next to it.
LABEL=com.github.oauramos.minbar
ALPHA=$LABEL.menubar-alpha
MICCAM=$LABEL.mic-cam
AGENTS="$HOME/Library/LaunchAgents"
GUI="gui/$(id -u)"

APP="$HOME/Applications/MinBar.app"
BUNDLE_ID=com.github.oauramos.minbar
# Fixed paths, not $XDG_*: bar/config.sh reads the same ones from the daemon.
CONF_DIR="$HOME/.config/minbar"
CONF_FILE="$CONF_DIR/minbar.conf"
STATE="$HOME/.local/state/minbar"
OVR="$STATE/layout.env"
PREVIEW="$HOME/.cache/minbar-preview"
LOGS="$HOME/Library/Logs/MinBar"
BAR="$MINBAR_ROOT/bar"
RC="$BAR/minbarrc"

# The user's settings, as the bar sees them (defaults, minbar.conf, overrides).
load_settings() {
  # shellcheck source=../bar/config.sh
  source "$BAR/config.sh"
}

# bin/minbar runs with pipefail: never pipe into `grep -q`, which exits on the
# first match and fails the producer with SIGPIPE (a race: sometimes "no
# match"). Pipe into `grep … >/dev/null`, which reads to the end.
die() { echo "minbar: $*" >&2; exit 1; }
note() { echo "minbar: $*" >&2; }
# stdin + stderr, not stdout: menus run inside $(…).
interactive() { [ -t 0 ] && [ -t 2 ]; }
has() { command -v "$1" >/dev/null 2>&1; }
onoff() { if [ "$1" = 1 ]; then echo on; else echo off; fi; }

# confirm <question>: yes with --yes, the default answer off a terminal.
ASSUME_YES=0
confirm() {
  [ "$ASSUME_YES" = 1 ] && return 0
  interactive || return 0
  if has gum; then gum confirm "$1"; else
    local a
    read -r -p "$1 [Y/n] " a </dev/tty
    case "$a" in n | N | no | No) return 1 ;; *) return 0 ;; esac
  fi
}
ask() { # ask <prompt> [placeholder]; esc makes gum exit 130 and the caller goes back
  interactive || die "missing value: $1 (not a terminal; pass it as an argument)"
  has gum || die "the interactive menu needs gum (brew install gum)"
  gum input --header "$1  (esc: back)" --placeholder "${2:-}"
}
heading() { if has gum; then gum style --bold "$*"; else echo "$*"; fi; }

# The sketchybar MinBar runs: the one on PATH, resolved through symlinks so the
# app copies a real file (Homebrew's bin/ entry is a link into the Cellar).
sketchybar_bin() {
  local b
  b=$(command -v sketchybar) || die "sketchybar is not installed (brew install felixkratz/formulae/sketchybar)"
  realpath "$b"
}

daemon_pid() {
  launchctl print "$GUI/$LABEL" 2>/dev/null | awk '$1 == "pid" && $2 == "=" { print $3; exit }' || true
}
need_bar() { [ -n "$(daemon_pid)" ] || die "MinBar is not running (minbar restart)"; }
