# shellcheck shell=bash
# minbar: the verbs. Sourced by bin/minbar with MINBAR_ROOT and MINBAR_LIBEXEC
# set and the helpers on PATH.

# shellcheck source=common.sh
source "$MINBAR_ROOT/cli/common.sh"
# shellcheck source=install.sh
source "$MINBAR_ROOT/cli/install.sh"
# shellcheck source=tui.sh
source "$MINBAR_ROOT/cli/tui.sh"
# shellcheck source=workspaces.sh
source "$MINBAR_ROOT/cli/workspaces.sh"

usage() {
  cat <<'EOT'
minbar — a macOS menu bar on SketchyBar. `minbar --…` passes through to `sketchybar --…`.

Install
  minbar setup [--yes] [--no-hooks]   settings, app, agents, font, shortcut, hooks, permissions
  minbar uninstall [--yes]            undo setup (the formula stays: brew uninstall minbar)
  minbar app [--force]                (re)build and sign MinBar.app (/Applications)
  minbar identity [status|create]     the code-signing certificate that keeps permissions
  minbar permissions                  open the two System Settings panes MinBar needs
  minbar hooks [install|remove|status]  clawd's Claude Code hooks
  minbar hotkey [set|remove]          the Notification Center shortcut the bell types
  minbar agents [install|remove]      the launchd agents

The running bar
  minbar                              interactive menu (gum)
  minbar status | doctor
  minbar reload | restart | hide | show
  minbar toggle <caffeine|wifi|bluetooth|tailscale|mute>
  minbar volume <0-100>
  minbar font-size [10-16 | + | - | reset]   every text on the bar, and its icons
  minbar layout [variant <classic|mini|toggle> | <stats|net|wifi-name> <on|off|toggle> | reset]
  minbar workspaces                   how many pills, and where each app opens
  minbar workspaces count <1-20|reset>          pills on the bar
  minbar workspaces set <app> <workspace|dynamic>   app: a name, a bundle id, or Name=id,id
  minbar workspaces reset             back to the settings
  minbar clawd [N|reset]              clawds shown before +K
  minbar native-bar [show|hide]       the macOS menu bar (menubar-alpha)
  minbar preview [on [dir] | off]     run a checkout's bar live
  minbar inspect [item]               one item's properties
  minbar version

Settings: ~/.config/minbar/minbar.conf (every key: share/minbar/bar/config.sh).
EOT
}

case "${1:-}" in
  "") if interactive; then menu; else usage; exit 64; fi ;;
  setup) shift; do_setup "$@" ;;
  uninstall) shift; do_uninstall "$@" ;;
  app) shift; do_app "$@" ;;
  identity) shift; do_identity "$@" ;;
  permissions) do_permissions ;;
  hooks) shift; do_hooks "$@" ;;
  hotkey) shift; do_hotkey "$@" ;;
  agents) shift; do_agents "$@" ;;
  font) do_font ;;
  status) do_status ;;
  doctor) do_doctor ;;
  reload) do_reload ;;
  restart) do_restart ;;
  hide) do_hide on ;;
  show) do_hide off ;;
  toggle) shift; do_toggle "$@" ;;
  volume | vol) shift; do_volume "$@" ;;
  layout) shift; do_layout "$@" ;;
  font-size | fontsize) shift; do_layout font-size "$@" ;;
  workspace | workspaces | ws) shift; do_workspaces "$@" ;;
  clawd) shift; do_clawd "$@" ;;
  native-bar | menubar) shift; do_native_bar "$@" ;;
  preview) shift; do_preview "$@" ;;
  inspect | query) shift; do_inspect "$@" ;;
  version | --version) echo "minbar $MINBAR_VERSION" ;;
  -h | --help | help) usage ;;
  -*) exec sketchybar "$@" ;;
  *) die "unknown verb '$1' (minbar help)" ;;
esac
