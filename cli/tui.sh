# shellcheck shell=bash
# The running bar: status, doctor, the toggles its own clicks drive, runtime
# layout overrides, the clawd cap, the native menu bar, a live preview of a
# checkout, and the gum menu over all of it. Every menu item is also a verb, so
# it scripts and tests. Plugins run from here too, with the BSD tools the
# daemon gives them.

##### The daemon #####

# The config the bar runs: a preview while one is live, else the installed one.
# A preview is live while the daemon that loaded it is: a restart or a login
# comes back on the agent's --config, and the pid tells.
preview_live() { [ -f "$PREVIEW/.pid" ] && [ "$(cat "$PREVIEW/.pid")" = "$(daemon_pid)" ]; }
config_dir() { if preview_live; then echo "$PREVIEW"; else echo "$BAR"; fi; }

do_reload() { need_bar; sketchybar --reload; note "reloaded ($(config_dir))"; }
do_restart() {
  [ -f "$AGENTS/$LABEL.plist" ] || die "MinBar's agent is not installed (minbar setup)"
  load_settings
  do_app --quiet # an upgraded sketchybar needs a fresh copy in MinBar.app
  launchctl kickstart -k "$GUI/$LABEL" || die "launchctl kickstart failed"
  rm -rf "$PREVIEW"
  note "restarted"
}
bar_hidden() { [ "$(sketchybar --query bar 2>/dev/null | jq -r '.hidden // "off"')" = on ]; }
do_hide() { need_bar; sketchybar --bar hidden="$1"; }

##### Controls: the same scripts the bar's clicks run #####

# Runs a plugin as the daemon would ($NAME = the item it redraws). nohup: the
# caffeine toggle leaves a `caffeinate` behind, which must outlive this terminal.
plugin() { # plugin <item> <script> [verb]
  local item=$1 script=$2
  shift 2
  NAME=$item CONFIG_DIR=$(config_dir) nohup "$(config_dir)/plugins/$script.sh" "$@" </dev/null >/dev/null 2>&1 || true
}
caffeine_on() { pgrep -xf 'caffeinate -disu' >/dev/null 2>&1; } # caffeine.sh's own process only
wifi_iface() { networksetup -listallhardwareports 2>/dev/null | awk '/Wi-Fi/{getline; print $2; exit}' || true; }
wifi_on() { networksetup -getairportpower "$(wifi_iface)" 2>/dev/null | grep -q ': On'; }
bt_on() { [ "$(blueutil -p 2>/dev/null)" = 1 ]; }
ts_state() {
  local s
  s=$(tailscale status --json --peers=false 2>/dev/null | jq -r '.BackendState // empty' 2>/dev/null || true)
  echo "${s:-unknown}"
}
volume_now() { osascript -e 'set s to get volume settings' -e '(output volume of s as text) & " " & (output muted of s as text)' 2>/dev/null || echo "? ?"; }
# What the privacy indicator shows: "off", or "mic: App, App · camera on".
mic_cam_now() {
  local key value apps="" cam=0 out=""
  while read -r key value; do
    case $key in
      app) apps="${apps:+$apps, }$value" ;;
      cam) cam=$value ;;
    esac
  done < <(mic-cam 2>/dev/null || true)
  [ -n "$apps" ] && out="mic: $apps"
  [ "$cam" = 1 ] && out="${out:+$out · }camera on"
  echo "${out:-off}"
}
state_of() {
  case "$1" in
    caffeine) if caffeine_on; then echo on; else echo off; fi ;;
    wifi) if wifi_on; then echo on; else echo off; fi ;;
    bluetooth) if bt_on; then echo on; else echo off; fi ;;
    tailscale) if has tailscale; then ts_state; else echo "not installed"; fi ;;
    mute | volume)
      local v m
      read -r v m <<<"$(volume_now)"
      if [ "$m" = true ]; then echo "muted ($v%)"; else echo "$v%"; fi ;;
  esac
}
do_toggle() {
  local what=${1:-}
  case "$what" in
    caffeine) plugin caffeine caffeine toggle ;;
    wifi) plugin wifi wifi toggle ;;
    bt | bluetooth) what=bluetooth; plugin bluetooth bluetooth toggle ;;
    ts | tailscale) what=tailscale; has tailscale || die "tailscale is not installed"; plugin tailscale tailscale toggle ;;
    mute) plugin volume volume toggle ;;
    *) die "toggle what? caffeine | wifi | bluetooth | tailscale | mute" ;;
  esac
  note "$what: $(state_of "$what")"
}
do_volume() {
  local n=${1:-}
  [[ $n =~ ^[0-9]+$ ]] && [ "$n" -le 100 ] || die "volume: a number from 0 to 100"
  osascript -e "set volume output volume $n" -e 'set volume output muted false' >/dev/null
  plugin volume volume
  note "volume: $(state_of volume)"
}

##### Layout: runtime overrides of minbar.conf #####

# KEY=value lines in $OVR, read by config.sh after minbar.conf (only these four
# keys). A value equal to the settings' one is dropped, so the file only holds
# real overrides and `layout reset` is deleting it.
layout_key() {
  case "$1" in
    variant) echo MINBAR_VARIANT ;;
    stats) echo MINBAR_SHOW_STATS ;;
    net | network) echo MINBAR_SHOW_NETWORK ;;
    wifi-name | wifi | ssid) echo MINBAR_SHOW_WIFI_NAME ;;
    *) return 1 ;;
  esac
}
base_val() { (MINBAR_NO_OVERRIDES=1 load_settings && printf '%s\n' "${!1}"); }
ovr_val() { [ -f "$OVR" ] && sed -n "s/^$1=//p" "$OVR" | tail -n1 || true; }
cur_val() {
  local v
  v=$(ovr_val "$1")
  echo "${v:-$(base_val "$1")}"
}
set_ovr() { # set_ovr KEY VALUE
  local tmp
  mkdir -p "$STATE"
  tmp=$(mktemp "$STATE/.layout.XXXXXX")
  { [ -f "$OVR" ] && grep -v "^$1=" "$OVR"; [ "$2" = "$(base_val "$1")" ] || echo "$1=$2"; } >"$tmp" || true
  if [ -s "$tmp" ]; then mv "$tmp" "$OVR"; else rm -f "$tmp" "$OVR"; fi
}
layout_row() { # layout_row <label> KEY: value, plus where it comes from
  local v n
  v=$(cur_val "$2")
  n=$(base_val "$2")
  [ "$2" = MINBAR_VARIANT ] || { v=$(onoff "$v"); n=$(onoff "$n"); }
  if [ -n "$(ovr_val "$2")" ]; then printf '%-10s %-8s overridden (settings: %s)\n' "$1" "$v" "$n"
  else printf '%-10s %-8s from settings\n' "$1" "$v"; fi
}
layout_show() {
  layout_row variant MINBAR_VARIANT
  layout_row stats MINBAR_SHOW_STATS
  layout_row net MINBAR_SHOW_NETWORK
  layout_row wifi-name MINBAR_SHOW_WIFI_NAME
  if has aerospace; then
    printf '%-10s %-8s from settings (MINBAR_WORKSPACE_COUNT)\n' workspaces "$(base_val MINBAR_WORKSPACE_COUNT)"
  else
    printf '%-10s %-8s AeroSpace not installed\n' workspaces none
  fi
}
apply_layout() { if [ -n "$(daemon_pid)" ]; then sketchybar --reload; fi; layout_show; }
do_layout() {
  local key v
  case "${1:-}" in
    "") layout_show ;;
    reset) rm -f "$OVR"; note "layout back to the settings ($CONF_FILE)"; apply_layout ;;
    variant)
      case "${2:-}" in
        classic | mini) set_ovr MINBAR_VARIANT "$2" ;;
        toggle) if [ "$(cur_val MINBAR_VARIANT)" = mini ]; then set_ovr MINBAR_VARIANT classic; else set_ovr MINBAR_VARIANT mini; fi ;;
        *) die "layout variant classic|mini|toggle" ;;
      esac
      apply_layout ;;
    *)
      key=$(layout_key "$1") || die "layout: unknown setting '$1' (variant, stats, net, wifi-name, reset)"
      case "${2:-}" in
        on | 1) v=1 ;;
        off | 0) v=0 ;;
        toggle) if [ "$(cur_val "$key")" = 1 ]; then v=0; else v=1; fi ;;
        *) die "layout $1 on|off|toggle" ;;
      esac
      set_ovr "$key" "$v"
      apply_layout ;;
  esac
}

##### clawd #####

# The cap is clawd's own state: it survives reloads and applies at once.
do_clawd() { "$MINBAR_ROOT/clawd/src/clawd.ctl.sh" "$@"; }
menu_clawd() {
  local now n
  now=$(do_clawd | sed -n 's/^cap: *//p' || true)
  n=$(ask "clawds shown before +K — now: ${now:-unknown}. A number, or reset" "10") || return 0
  [ -n "$n" ] || return 0
  [[ $n =~ ^[0-9]+$ || $n == reset ]] || die "not a number: '$n'"
  do_clawd "$n"
}

##### The native macOS menu bar (menubar-alpha) #####

alpha_loaded() { launchctl print "$GUI/$ALPHA" >/dev/null 2>&1; }
do_native_bar() {
  [ -f "$AGENTS/$ALPHA.plist" ] || die "menubar-alpha is not installed (MINBAR_HIDE_NATIVE_BAR=1, then minbar setup)"
  case "${1:-}" in
    "") if alpha_loaded; then echo "hidden (menubar-alpha running)"; else echo "shown (menubar-alpha stopped)"; fi ;;
    show)
      alpha_loaded && launchctl bootout "$GUI/$ALPHA"
      note "native menu bar back: it slides in at the top edge until \`minbar native-bar hide\` or the next login" ;;
    hide)
      alpha_loaded || launchctl bootstrap "$GUI" "$AGENTS/$ALPHA.plist"
      note "native menu bar hidden for good again" ;;
    *) die "native-bar show|hide" ;;
  esac
}

##### Live preview of a checkout #####

# A dir standing in for bar/, whose theme, settings loader and plugins are the
# checkout's. The rc is the one real file in it, a wrapper that sources the
# checkout's rc with MINBAR_ROOT on the checkout: `sketchybar --reload <path>`
# RESOLVES a symlinked rc and sets $CONFIG_DIR to the target's dir, which
# would skip this dir. `preview off` restarts the daemon, which comes back on
# its agent's --config; a plain `--reload` keeps whatever path is loaded.
do_preview() { # preview [on [dir] | off]
  local src f bad=""
  case "${1:-on}" in
    on)
      need_bar
      src=${2:-${MINBAR_DEV:-$PWD}}
      src=$(cd "$src" 2>/dev/null && pwd) || die "preview: no such directory"
      [ -f "$src/bar/minbarrc" ] || die "$src is not a MinBar checkout (no bar/minbarrc); pass its path or set MINBAR_DEV"
      rm -rf "$PREVIEW"
      mkdir -p "$PREVIEW"
      ln -s "$src/bar/theme.sh" "$src/bar/config.sh" "$src/bar/plugins" "$PREVIEW/"
      printf '#!/bin/bash\n# minbar preview: the checkout'"'"'s rc, CONFIG_DIR = this dir\nMINBAR_ROOT=%q\nsource %q\n' \
        "$src" "$src/bar/minbarrc" >"$PREVIEW/minbarrc"
      chmod +x "$PREVIEW/minbarrc"
      echo "$src" >"$PREVIEW/.src"
      daemon_pid >"$PREVIEW/.pid"
      for f in "$src"/bar/plugins/*.sh; do
        [ "${f##*/}" = lib.sh ] || [ -x "$f" ] || bad="$bad ${f##*/}"
      done
      [ -z "$bad" ] || note "not executable, the bar cannot run them (chmod +x):$bad"
      [ -f "$src/fonts/simple-icons.tsv" ] || note "$src/fonts has no glyph table (make fonts): brand icons stay blank"
      sketchybar --reload "$PREVIEW/minbarrc"
      note "previewing $src — edit, then \`minbar reload\`; \`minbar preview off\` goes back" ;;
    off)
      preview_live || { rm -rf "$PREVIEW"; note "no preview running"; return 0; }
      do_restart ;;
    *) die "preview on [dir] | off" ;;
  esac
}

##### Status / doctor / inspect #####

do_status() {
  local pid
  load_settings
  pid=$(daemon_pid)
  heading "MinBar $MINBAR_VERSION"
  echo "  app        $APP ($(app_signature))"
  echo "  settings   $CONF_FILE$([ -f "$CONF_FILE" ] || echo " (none: defaults)")"
  if [ -z "$pid" ]; then echo "  daemon     not running (minbar restart)"; return 0; fi
  echo "  daemon     running, pid $pid"
  if preview_live; then echo "  config     PREVIEW of $(cat "$PREVIEW/.src")"; else echo "  config     $BAR"; fi
  if bar_hidden; then echo "  bar        hidden (minbar show)"; else echo "  bar        shown, $(sketchybar --query bar | jq '.items | length') items"; fi
  [ -f "$AGENTS/$ALPHA.plist" ] && echo "  macOS bar  $(do_native_bar)"
  echo
  heading "Layout"
  layout_show | sed 's/^/  /'
  echo
  heading "Controls"
  printf '  %-10s %s\n' caffeine "$(state_of caffeine)" wifi "$(state_of wifi)" bluetooth "$(state_of bluetooth)" \
    tailscale "$(state_of tailscale)" volume "$(state_of volume)" mic/cam "$(mic_cam_now)"
  if [ "$MINBAR_CLAWD" = on ]; then
    echo
    heading "clawd"
    do_clawd | sed 's/^/  /' || true
  fi
}

DOC_RC=0
ok() { echo "  ✓ $*"; }
bad() { echo "  ✗ $*"; DOC_RC=1; }
info() { echo "  · $*"; }
# Ask the daemon itself (plugins/probe.sh): the grants are its, not this shell's.
probe() {
  local f="$STATE/probe" before
  before=$(stat -f %m "$f" 2>/dev/null || echo 0)
  sketchybar --trigger minbar_probe >/dev/null 2>&1 || return 1
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    [ "$(stat -f %m "$f" 2>/dev/null || echo 0)" != "$before" ] && break
    sleep 0.3
  done
  [ -f "$f" ] && cat "$f"
}
do_doctor() {
  local pid focused mc p missing
  DOC_RC=0
  load_settings
  pid=$(daemon_pid)
  if [ -z "$pid" ]; then bad "MinBar not running: minbar restart (or minbar setup)"; return 1; fi
  ok "daemon running (pid $pid, launchd $LABEL)"
  [ -z "$(other_bars)" ] || bad "another sketchybar is running too (pid $(other_bars | tr '\n' ' ')): two bars draw (brew services stop sketchybar)"
  if app_current; then ok "MinBar.app current ($(app_signature))"
  else bad "MinBar.app is stale or unsigned for this sketchybar: minbar restart rebuilds it"; fi
  has_identity || info "no '$MINBAR_SIGNING_IDENTITY' certificate: grants reset on every sketchybar upgrade (minbar identity create)"
  if preview_live; then ok "config: PREVIEW of $(cat "$PREVIEW/.src") (minbar preview off)"; fi
  [ -f "$OVR" ] && ok "layout overrides in force: $(tr '\n' ' ' <"$OVR")(minbar layout reset)"

  p=$(probe || true)
  case "$p" in
    *accessibility=yes*) ok "Accessibility granted (app menus, the bell's click)" ;;
    *accessibility=no*) bad "no Accessibility: app menus and the bell's click are off (minbar permissions)" ;;
    *) bad "the bar did not answer the probe (minbar reload)" ;;
  esac
  case "$p" in
    *full_disk_access=yes*) ok "Full Disk Access granted (the bell's count)" ;;
    *full_disk_access=no*) bad "no Full Disk Access: the bell shows no count (minbar permissions)" ;;
  esac

  missing=$(fonts_missing)
  if [ -z "$missing" ]; then ok "fonts installed"; else bad "fonts missing: brew install --cask $missing"; fi

  if [ "$MINBAR_WORKSPACES" = off ]; then info "workspaces off (MINBAR_WORKSPACES=off)"
  elif ! has aerospace; then info "AeroSpace not installed: no workspaces (optional)"
  else
    focused=$(aerospace list-workspaces --focused 2>/dev/null || true)
    if [ -z "$focused" ]; then bad "aerospace not answering: workspace pills cannot follow focus"
    elif [ "$(sketchybar --query "space.$focused" 2>/dev/null | jq -r '.geometry.background.drawing // "off"')" = on ]; then
      ok "workspace pill follows AeroSpace (workspace $focused)"
    else
      bad "workspace $focused is focused but its pill is not lit; add to ~/.aerospace.toml:"
      echo "      exec-on-workspace-change = ['/bin/bash', '-c',"
      echo "        'sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE=\$AEROSPACE_FOCUSED_WORKSPACE']"
    fi
  fi

  if [ -f "$AGENTS/$ALPHA.plist" ]; then
    if alpha_loaded; then ok "native menu bar hidden (menubar-alpha running)"
    else bad "menubar-alpha stopped, the native bar slides in on hover (minbar native-bar hide)"; fi
  fi

  mc=$(launchctl print "$GUI/$MICCAM" 2>/dev/null || true)
  if [ -z "$mc" ]; then bad "mic-cam watcher not installed, the mic/camera indicator cannot react (minbar setup)"
  elif grep -q 'state = running' <<<"$mc"; then ok "mic/camera indicator watching ($(mic_cam_now))"
  else bad "mic-cam watcher stopped: launchctl kickstart $GUI/$MICCAM"; fi

  if [ "$MINBAR_CLAWD" = on ]; then
    if [ -f "$CLAUDE_SETTINGS" ] && [ ! -O "$CLAUDE_SETTINGS" ]; then bad "$CLAUDE_SETTINGS is not yours (a sudo'd installer?): sudo chown $USER:staff it"
    elif hooks_installed; then ok "clawd hooks in $CLAUDE_SETTINGS"
    else info "clawd hooks not installed: clawd only appears with them (minbar hooks install)"; fi
  fi
  return "$DOC_RC"
}

do_inspect() {
  local item=${1:-}
  need_bar
  if [ -z "$item" ]; then
    interactive || die "inspect which item? (sketchybar --query bar lists them)"
    item=$(sketchybar --query bar | jq -r '.items[]' | sort | gum filter --header "inspect which item?  (esc: back)") || return 0
  fi
  if interactive && has gum; then sketchybar --query "$item" | jq . | gum pager; else sketchybar --query "$item" | jq .; fi
}

##### Interactive menu #####

# Every action runs in a subshell: a die() or an esc ends only that action.
action() { ("$@") || true; }
paged() { "$@" 2>&1 | gum pager; }
menu_controls() {
  local choice
  while true; do
    choice=$(
      {
        printf '%-26s %s\n' "Caffeine (keep awake)" "$(state_of caffeine)"
        printf '%-26s %s\n' "Wi-Fi radio" "$(state_of wifi)"
        printf '%-26s %s\n' "Bluetooth" "$(state_of bluetooth)"
        has tailscale && printf '%-26s %s\n' "Tailscale" "$(state_of tailscale)"
        printf '%-26s %s\n' "Sound: mute / unmute" "$(state_of volume)"
        printf '%s\n' "Sound: set volume…"
      } | gum choose --header "controls — enter toggles  (esc: back)"
    ) || return 0
    case "$choice" in
      Caffeine*) action do_toggle caffeine ;;
      Wi-Fi*) action do_toggle wifi ;;
      Bluetooth*) action do_toggle bluetooth ;;
      Tailscale*) action do_toggle tailscale ;;
      "Sound: mute"*) action do_toggle mute ;;
      "Sound: set"*) local n; n=$(ask "volume 0-100" "40") && action do_volume "$n" ;;
    esac
  done
}
menu_layout() {
  local choice
  while true; do
    choice=$(
      { layout_show | grep -v '^workspaces'; echo "reset to the settings"; } |
        gum choose --header "layout — enter flips it and reloads; runtime only, minbar.conf stays the default  (esc: back)"
    ) || return 0
    case "$choice" in
      variant*) action do_layout variant toggle ;;
      stats*) action do_layout stats toggle ;;
      net*) action do_layout net toggle ;;
      wifi-name*) action do_layout wifi-name toggle ;;
      reset*) action do_layout reset ;;
    esac >/dev/null
  done
}
menu() {
  has gum || die "the interactive menu needs gum (brew install gum); \`minbar help\` lists the verbs"
  local choice header preview_item native_item
  while true; do
    if [ -n "$(daemon_pid)" ]; then
      header="MinBar — $(cur_val MINBAR_VARIANT)"
      if preview_live; then header="$header, PREVIEW of $(cat "$PREVIEW/.src")"; fi
    else header="MinBar — NOT RUNNING"; fi
    if preview_live; then preview_item="Preview: back to the installed config"; else preview_item="Preview a checkout live"; fi
    native_item=()
    [ -f "$AGENTS/$ALPHA.plist" ] && { if alpha_loaded; then native_item=("macOS menu bar: show it"); else native_item=("macOS menu bar: hide it again"); fi; }
    choice=$(gum choose --header "$header   (enter: pick, esc: quit)" \
      "Status" "Doctor" "Controls" "Layout" "Clawd: sessions shown before +K" \
      "Reload" "Restart" "$(if bar_hidden; then echo "Show the bar"; else echo "Hide the bar"; fi)" \
      "${native_item[@]}" "$preview_item" "Inspect an item" "Permissions" "Quit") || return 0
    case "$choice" in
      Status) action paged do_status ;;
      Doctor) action paged do_doctor ;;
      Controls) menu_controls ;;
      Layout) menu_layout ;;
      Clawd*) action menu_clawd ;;
      Reload) action do_reload ;;
      Restart) action do_restart ;;
      "Show the bar") action do_hide off ;;
      "Hide the bar") action do_hide on ;;
      "macOS menu bar: show it") action do_native_bar show ;;
      "macOS menu bar: hide it again") action do_native_bar hide ;;
      "Preview a checkout"*) local d; d=$(ask "checkout to preview" "$PWD") && action do_preview on "$d" ;;
      "Preview: back"*) action do_preview off ;;
      Inspect*) action do_inspect ;;
      Permissions) action do_permissions ;;
      Quit) return 0 ;;
    esac
  done
}
