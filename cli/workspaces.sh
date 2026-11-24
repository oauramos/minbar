# shellcheck shell=bash
# shellcheck disable=SC2153  # names come from common.sh
# The workspaces: how many pills the bar draws, and which workspace each app's
# windows open on (the rules: bar/plugins/workspaces.sh). Sourced by main.sh.

# shellcheck source=../bar/plugins/workspaces.sh
source "$BAR/plugins/workspaces.sh"

##### How many pills #####

# The count in force. Not base_val: the default follows the variant, which has
# its own override.
ws_count() { (load_settings && echo "$MINBAR_WORKSPACE_COUNT"); }
workspaces_row() {
  if [ -n "$(ovr_val MINBAR_WORKSPACE_COUNT)" ]; then printf '%-10s %-8s overridden (minbar workspaces count reset)\n' workspaces "$(ws_count)"
  else printf '%-10s %-8s from settings\n' workspaces "$(ws_count)"; fi
}
# Kept even when it equals the default: the default moves with the variant.
set_count() { # set_count <1-20|reset>
  local tmp
  mkdir -p "$STATE"
  tmp=$(mktemp "$STATE/.layout.XXXXXX")
  { [ -f "$OVR" ] && grep -v '^MINBAR_WORKSPACE_COUNT=' "$OVR"; [ "$1" = reset ] || echo "MINBAR_WORKSPACE_COUNT=$1"; } >"$tmp" || true
  if [ -s "$tmp" ]; then mv "$tmp" "$OVR"; else rm -f "$tmp" "$OVR"; fi
  if [ -n "$(daemon_pid)" ]; then sketchybar --reload; fi
  note "the bar shows workspaces 1-$(ws_count)"
}

##### Apps #####

# app_id NAME: the bundle id of a running or installed app, by its name.
app_id() {
  local id d
  id=$(aerospace list-apps --format '%{app-bundle-id}%{tab}%{app-name}' 2>/dev/null |
    awk -F'\t' -v n="$1" 'tolower($2) == tolower(n) && $1 != "" { id = $1 } END { print id }' || true)
  if [ -z "$id" ]; then
    for d in /Applications "$HOME/Applications" /System/Applications /System/Applications/Utilities; do
      [ -d "$d/$1.app" ] || continue
      id=$(defaults read "$d/$1.app/Contents/Info" CFBundleIdentifier 2>/dev/null || true)
      break
    done
  fi
  [ -n "$id" ] && echo "$id"
}
# A bundle id as it is; anything else is an app's name.
app_or_id() {
  if [[ $1 =~ ^[A-Za-z0-9-]+(\.[A-Za-z0-9_-]+)+$ ]]; then echo "$1"; else
    app_id "$1" || die "no app called '$1' is running or installed (its bundle id works too)"
  fi
}
# set_app <app> <workspace|dynamic>; <app>: a rule's name, an app's name, a
# bundle id, or Name=app,app… to give several one name.
set_app() {
  local app=${1:-} ws=${2:-} name ids="" part
  [ -n "$app" ] && [[ $ws =~ ^[A-Za-z0-9_-]+$ ]] || die "workspaces set <app> <workspace|dynamic>"
  if [[ $app == *=* ]]; then
    name=${app%%=*}
    local -a parts
    IFS=, read -r -a parts <<<"${app#*=}"
    [ -n "$name" ] && [ "${#parts[@]}" -gt 0 ] || die "workspaces set Name=app,app <workspace|dynamic>"
    for part in "${parts[@]}"; do ids="$ids $(app_or_id "$part")" || exit 1; done
  else
    # A rule's own name first (Playwright), then an app or a bundle id.
    ids=$(ws_rules | awk -F'\t' -v n="$app" 'tolower($1) == tolower(n) { print $3 }' | tr '\n' ' ')
    name=$(ws_rules | awk -F'\t' -v n="$app" 'tolower($1) == tolower(n) { x = $1 } END { print x }')
    if [ -z "$name" ]; then
      part=$(app_or_id "$app") || exit 1
      IFS=$'\t' read -r name ids < <(ws_family "$part" "$app")
    fi
  fi
  # shellcheck disable=SC2086  # a list of bundle ids
  ws_set "$name" "$ws" $ids
  if [ "$ws" = dynamic ]; then note "$name opens anywhere"; else note "$name opens on workspace $ws (new windows)"; fi
}

workspaces_apps() {
  local name ws ids count
  count=$(ws_count)
  ws_apps | while IFS=$'\t' read -r name ws ids; do
    if [[ $ws =~ ^[0-9]+$ ]] && [ "$ws" -gt "$count" ]; then ws="$ws (no pill)"; fi
    printf '%-22s %-12s %s\n' "$name" "$ws" "$ids"
  done
}
workspaces_show() {
  workspaces_row
  if [ -z "$(ws_apps)" ]; then echo "every app opens where you are (minbar workspaces set <app> <workspace>)"
  else workspaces_apps; fi
}
do_workspaces() {
  has aerospace || die "workspaces need AeroSpace (brew install --cask nikitabobko/tap/aerospace)"
  case "${1:-}" in
    "") workspaces_show ;;
    count)
      [[ ${2:-} =~ ^([1-9]|1[0-9]|20|reset)$ ]] || die "workspaces count <1-20|reset>"
      set_count "$2" ;;
    set) shift; set_app "$@" ;;
    reset) rm -f "$WS_OVR"; set_count reset; workspaces_show ;;
    *) die "workspaces [count <1-20|reset> | set <app> <workspace|dynamic> | reset]" ;;
  esac
}
doctor_workspaces() {
  if [ "$MINBAR_WORKSPACES" = off ] || ! has aerospace; then return 0; fi
  local st
  st=$(launchctl print "$GUI/$WORKSPACES" 2>/dev/null || true)
  if grep -q 'state = running' <<<"$st"; then ok "app workspaces watching ($(ws_apps | grep -vc $'\tdynamic\t' || true) pinned)"
  elif [ -z "$(ws_apps)" ]; then info "app workspaces agent not running (no rules yet; minbar agents install)"
  else bad "app workspaces agent not running, the rules do nothing (minbar agents install)"; fi
}

##### Menu #####

menu_workspace_pick() { # menu_workspace_pick <header> <current>: a workspace or dynamic
  local i count opts=(dynamic)
  count=$(ws_count)
  for i in $(seq 1 "$count"); do opts+=("$i"); done
  gum choose --height 14 --selected "$2" --header "$1 — dynamic: where you are  (esc: back)" "${opts[@]}"
}
menu_workspaces() {
  local choice n name ws
  if ! has aerospace; then action do_workspaces; return 0; fi
  while true; do
    choice=$(
      {
        printf '%-22s %s\n' "Workspaces on the bar" "$(ws_count)"
        ws_apps | while IFS=$'\t' read -r name ws _; do printf '%-22s %s\n' "App: $name" "$ws"; done
        echo "Pin another app…"
        echo "Back to the settings"
      } | gum choose --height 20 --header "workspaces — the pills, and where each app opens  (esc: back)"
    ) || return 0
    case "$choice" in
      "Workspaces on the bar"*)
        n=$(seq 1 10 | gum choose --height 12 --selected "$(ws_count)" --header "workspaces on the bar  (esc: back)") &&
          action do_workspaces count "$n" ;;
      "App: "*)
        name=${choice#App: }
        ws=${name##* }
        name=${name%"$ws"}
        name=${name%"${name##*[! ]}"}
        n=$(menu_workspace_pick "$name opens on" "$ws") && [ -n "$n" ] && action do_workspaces set "$name" "$n" ;;
      "Pin another app"*)
        name=$(aerospace list-apps --format '%{app-name}' | sort -fu | gum filter --height 16 --header "which app?  (esc: back)") || continue
        n=$(menu_workspace_pick "$name opens on" 1) && [ -n "$n" ] && action do_workspaces set "$name" "$n" ;;
      "Back to the settings") action do_workspaces reset ;;
    esac >/dev/null
  done
}
