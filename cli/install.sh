# shellcheck shell=bash
# shellcheck disable=SC2153,SC2016  # names come from common.sh; jq filters are single-quoted on purpose
# Install side of the CLI: the signed app, the launchd agents, the font, the
# Notification Center shortcut, the native menu bar, clawd's Claude Code hooks,
# and `minbar setup` / `minbar uninstall`, which run them in order. Every step
# is idempotent, so setup is also how an install is repaired or upgraded.

##### MinBar.app #####
#
# macOS ties Accessibility and Full Disk Access to the code signature of the
# process launchd starts, and every plugin and helper the bar spawns uses that
# process's grants. Package managers sign sketchybar ad hoc, so its identity is
# the file's hash and every upgrade drops the grants. MinBar copies the binary,
# unmodified, into MinBar.app (/Applications; a fixed bundle id) and signs it
# with a certificate of your own: the identity becomes "bundle id + that
# certificate", which an upgrade keeps. No certificate: signed ad hoc, as before.

APP_STAMP="$STATE/app-built-from"
APP_ICON="$MINBAR_ROOT/app/AppIcon.icns"

has_identity() {
  security find-identity -v -p codesigning 2>/dev/null | grep -F "\"$MINBAR_SIGNING_IDENTITY\"" >/dev/null
}
# -dvv: plain -dv prints no Authority lines, which read as "not signed by it"
# and rebuilt (and re-signed) the app on every restart.
app_signed_by_identity() {
  codesign -dvv "$APP" 2>&1 | grep -xF "Authority=$MINBAR_SIGNING_IDENTITY" >/dev/null
}
# Everything the bundle is made of; a different line means rebuild it.
app_wanted() {
  local sb
  sb=$(sketchybar_bin)
  printf '%s %s %s %s %s %s\n' "$APP" "$sb" "$(shasum -a 256 "$sb" | cut -d' ' -f1)" "$MINBAR_VERSION" \
    "$MINBAR_SIGNING_IDENTITY" "$(shasum -a 256 "$APP_ICON" | cut -d' ' -f1)"
}
app_current() {
  [ "$(cat "$APP_STAMP" 2>/dev/null)" = "$(app_wanted)" ] &&
    codesign --verify "$APP" 2>/dev/null &&
    { ! has_identity || app_signed_by_identity; }
}
# SketchyBar's own license goes in the bundle: Homebrew keeps it next to the
# binary's prefix; otherwise MinBar's copy (the same GPL-3.0 text).
sketchybar_license() {
  local prefix f
  prefix=$(cd "$(dirname "$(sketchybar_bin)")/.." && pwd)
  for f in "$prefix/LICENSE.md" "$prefix/LICENSE" "$prefix/share/doc/sketchybar/LICENSE.md" \
    "$MINBAR_ROOT/LICENSE"; do
    [ -f "$f" ] && { echo "$f"; return 0; }
  done
}

# shellcheck disable=SC2120  # tui.sh calls it with --quiet
do_app() { # minbar app [--force] [--quiet] [--restart]
  local force=0 quiet=0 restart=0 sb version
  for a in "$@"; do
    case "$a" in
      --force) force=1 ;; --quiet) quiet=1 ;; --restart) restart=1 ;;
      *) die "app [--force] [--quiet] [--restart]" ;;
    esac
  done
  load_settings
  if [ "$force" = 0 ] && app_current; then
    [ "$quiet" = 1 ] || note "MinBar.app is up to date ($(app_signature))"
    return 0
  fi
  sb=$(sketchybar_bin)
  version=$("$sb" --version 2>/dev/null | sed 's/^sketchybar-v//')
  rm -rf "$APP"
  mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$STATE"
  cp "$sb" "$APP/Contents/MacOS/sketchybar"
  chmod 0755 "$APP/Contents/MacOS/sketchybar"
  sed -e "s|@VERSION@|${version:-0}|g" -e "s|@BUNDLE_ID@|$BUNDLE_ID|g" \
    -e "s|@MINBAR_VERSION@|$MINBAR_VERSION|g" "$MINBAR_ROOT/app/Info.plist.in" >"$APP/Contents/Info.plist"
  cp "$(sketchybar_license)" "$APP/Contents/Resources/LICENSE.md"
  install -m 0644 "$APP_ICON" "$APP/Contents/Resources/AppIcon.icns"
  if ! { has_identity && codesign --force --sign "$MINBAR_SIGNING_IDENTITY" "$APP" 2>/dev/null; }; then
    note "no usable '$MINBAR_SIGNING_IDENTITY' certificate: MinBar.app is signed ad hoc, so its permissions reset whenever sketchybar is upgraded (minbar identity create)"
    codesign --force --sign - "$APP"
  fi
  app_wanted >"$APP_STAMP"
  remove_other_apps
  [ "$quiet" = 1 ] || note "built $APP ($(app_signature))"
  # --restart: a running bar moves onto the new binary (its agent is loaded).
  if [ "$restart" = 1 ] && launchctl print "$GUI/$LABEL" >/dev/null 2>&1; then
    launchctl kickstart -k "$GUI/$LABEL" || true
  fi
}
# A MinBar.app MinBar built elsewhere before (it moved): ours by bundle id.
remove_other_apps() {
  local d
  for d in /Applications "$HOME/Applications"; do
    [ "$d/MinBar.app" = "$APP" ] && continue
    [ "$(defaults read "$d/MinBar.app/Contents/Info" CFBundleIdentifier 2>/dev/null)" = "$BUNDLE_ID" ] || continue
    rm -rf "$d/MinBar.app" && note "removed the old $d/MinBar.app"
  done
}
app_signature() {
  if [ ! -d "$APP" ]; then echo "not built"
  elif app_signed_by_identity; then echo "signed by $MINBAR_SIGNING_IDENTITY"
  else echo "signed ad hoc"; fi
}

# A self-signed code-signing certificate in the login keychain, made once per
# Mac. macOS asks for your password when the certificate is trusted for code
# signing. /usr/bin/openssl on purpose: macOS's `security import` reads the
# PKCS#12 algorithms LibreSSL writes, not OpenSSL 3's defaults.
do_identity() { # minbar identity [status|create]
  load_settings
  case "${1:-status}" in
    status)
      if has_identity; then echo "'$MINBAR_SIGNING_IDENTITY': in the keychain, trusted for code signing"
      elif identity_imported; then echo "'$MINBAR_SIGNING_IDENTITY': in the keychain but NOT trusted (minbar identity create)"
      else echo "'$MINBAR_SIGNING_IDENTITY': missing (minbar identity create)"; fi ;;
    create) identity_create ;;
    *) die "identity [status|create]" ;;
  esac
}
# In the keychain at all, trusted or not (find-identity without -v).
identity_imported() {
  security find-identity -p codesigning 2>/dev/null | grep -F "\"$MINBAR_SIGNING_IDENTITY\"" >/dev/null
}
identity_trust_help() {
  note "trust it by hand: Keychain Access › login › My Certificates › '$MINBAR_SIGNING_IDENTITY' ›"
  note "Get Info › Trust › Code Signing: Always Trust; then \`minbar app --restart\`."
}
# macOS asks for your password (a system dialog) to store the trust setting.
identity_trust() {
  local tmp kc="$HOME/Library/Keychains/login.keychain-db"
  tmp=$(mktemp -d)
  security find-certificate -c "$MINBAR_SIGNING_IDENTITY" -p >"$tmp/cert.pem" 2>/dev/null
  note "trusting '$MINBAR_SIGNING_IDENTITY' for code signing: macOS asks for your password in a dialog"
  # trustRoot: the certificate is self-signed, so it is its own root
  # (trustAsRoot is for certificates someone else issued and is refused here).
  security add-trusted-cert -r trustRoot -p codeSign -k "$kc" "$tmp/cert.pem" ||
    security add-trusted-cert -r trustAsRoot -p codeSign -k "$kc" "$tmp/cert.pem" || true
  rm -rf "$tmp"
}
identity_create() {
  local id="$MINBAR_SIGNING_IDENTITY" tmp kc="$HOME/Library/Keychains/login.keychain-db"
  if has_identity; then note "'$id' is already in the keychain"; return 0; fi
  if identity_imported; then
    identity_trust
    if has_identity; then note "'$id' trusted; \`minbar app --restart\` signs MinBar.app with it"; return 0; fi
    identity_trust_help
    return 1
  fi
  tmp=$(mktemp -d)
  cat >"$tmp/req.cnf" <<EOT
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $id
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
EOT
  if /usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -config "$tmp/req.cnf" \
    -keyout "$tmp/key.pem" -out "$tmp/cert.pem" >/dev/null 2>&1 &&
    /usr/bin/openssl pkcs12 -export -inkey "$tmp/key.pem" -in "$tmp/cert.pem" -name "$id" \
      -out "$tmp/id.p12" -passout pass:minbar >/dev/null 2>&1 &&
    security import "$tmp/id.p12" -k "$kc" -P minbar -T /usr/bin/codesign >/dev/null; then
    rm -rf "$tmp"
    identity_trust
  else
    rm -rf "$tmp"
  fi
  if has_identity; then
    note "'$id' created; \`minbar app --restart\` signs MinBar.app with it"
  elif identity_imported; then
    identity_trust_help
    return 1
  else
    note "could not create '$id' from the command line. In Keychain Access: Certificate Assistant ›"
    note "Create a Certificate…, name '$id', Identity Type 'Self Signed Root', Certificate Type 'Code Signing'."
    return 1
  fi
}

##### launchd agents #####

xml() { local s=$1; s=${s//&/&amp;}; s=${s//</&lt;}; s=${s//>/&gt;}; printf '%s' "$s"; }
# write_agent <label> <log name> <program> [args…]
write_agent() {
  local label=$1 log=$2; shift 2
  local plist="$AGENTS/$label.plist" a
  # A read-only plist is managed elsewhere (the Nix module installs them 0444).
  if [ -e "$plist" ] && [ ! -w "$plist" ]; then
    note "$label is managed elsewhere (read-only plist); leaving it"
    return 0
  fi
  mkdir -p "$AGENTS" "$LOGS"
  {
    cat <<EOT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$label</string>
  <key>ProgramArguments</key>
  <array>
EOT
    for a in "$@"; do printf '    <string>%s</string>\n' "$(xml "$a")"; done
    cat <<EOT
  </array>
  <key>EnvironmentVariables</key>
  <dict><key>PATH</key><string>$(xml "$(agent_path)")</string></dict>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ProcessType</key><string>Interactive</string>
  <key>StandardOutPath</key><string>$(xml "$LOGS/$log.log")</string>
  <key>StandardErrorPath</key><string>$(xml "$LOGS/$log.log")</string>
</dict>
</plist>
EOT
  } >"$plist.tmp"
  mv "$plist.tmp" "$plist"
}
# The daemon's PATH: MinBar's helpers, then wherever the tools it calls by name
# live (sketchybar, aerospace, blueutil, tailscale, jq), then the system.
agent_path() {
  local p="$MINBAR_LIBEXEC" t d
  for t in sketchybar aerospace blueutil tailscale jq python3; do
    d=$(dirname "$(command -v "$t" 2>/dev/null || echo /usr/bin/x)")
    case ":$p:" in *":$d:"*) ;; *) p="$p:$d" ;; esac
  done
  for d in /opt/homebrew/bin /usr/local/bin /usr/bin /bin /usr/sbin /sbin; do
    case ":$p:" in *":$d:"*) ;; *) p="$p:$d" ;; esac
  done
  echo "$p"
}
load_agent() { # (re)load one agent from its plist
  launchctl bootout "$GUI/$1" 2>/dev/null || true
  launchctl bootstrap "$GUI" "$AGENTS/$1.plist"
}
unload_agent() {
  [ -e "$AGENTS/$1.plist" ] && [ ! -w "$AGENTS/$1.plist" ] && { note "$1 is managed elsewhere; leaving it"; return 0; }
  launchctl bootout "$GUI/$1" 2>/dev/null || true
  rm -f "$AGENTS/$1.plist"
}
# Another SketchyBar (brew services, Nix, a hand-started one) would draw a
# second bar on top of this one.
other_bars() {
  local mine
  mine=$(daemon_pid)
  pgrep -x sketchybar 2>/dev/null | grep -vx "${mine:-none}" || true
}
do_agents() { # minbar agents [install|remove]
  load_settings
  case "${1:-install}" in
    install)
      [ -z "$(other_bars)" ] || note "another sketchybar is running (pid $(other_bars | tr '\n' ' ')): stop it (brew services stop sketchybar) or two bars will draw"
      write_agent "$LABEL" minbar "$APP/Contents/MacOS/sketchybar" --config "$RC"
      write_agent "$MICCAM" mic-cam "$MINBAR_LIBEXEC/mic-cam" --watch "$(command -v sketchybar)" --trigger mic_cam_change
      load_agent "$LABEL"
      load_agent "$MICCAM"
      # The app → workspace rules (bar/plugins/workspaces.sh).
      if [ "$MINBAR_WORKSPACES" != off ] && has aerospace; then
        write_agent "$WORKSPACES" workspaces /bin/bash "$BAR/plugins/workspaces.sh" watch
        load_agent "$WORKSPACES"
      else
        unload_agent "$WORKSPACES"
      fi
      if [ "$MINBAR_HIDE_NATIVE_BAR" = 1 ]; then
        write_agent "$ALPHA" menubar-alpha "$MINBAR_LIBEXEC/menubar-alpha"
        load_agent "$ALPHA"
      else
        unload_agent "$ALPHA"
      fi ;;
    remove) unload_agent "$LABEL"; unload_agent "$MICCAM"; unload_agent "$WORKSPACES"; unload_agent "$ALPHA" ;;
    *) die "agents [install|remove]" ;;
  esac
}

##### The Simple Icons font #####

do_font() {
  local src="$MINBAR_ROOT/fonts/SimpleIcons.otf" dst="$HOME/Library/Fonts/SimpleIcons.otf"
  [ -f "$src" ] || die "$src missing (make fonts)"
  cmp -s "$src" "$dst" 2>/dev/null && return 0
  mkdir -p "${dst%/*}"
  # install, not cp: a copy from a read-only store would stay read-only and
  # block the next update.
  install -m 0644 "$src" "$dst"
  note "installed the Simple Icons font"
}
# Fonts the theme names but MinBar does not ship (Homebrew casks).
fonts_missing() {
  local dirs=("$HOME/Library/Fonts" /Library/Fonts) missing=()
  find "${dirs[@]}" -maxdepth 1 -iname 'HackNerdFont*' 2>/dev/null | grep . >/dev/null || missing+=(font-hack-nerd-font)
  find "${dirs[@]}" -maxdepth 1 -iname 'SF-Pro*' 2>/dev/null | grep . >/dev/null || missing+=(font-sf-pro)
  echo "${missing[*]:-}"
}

##### The Notification Center shortcut #####
#
# macOS's "Show Notification Center" (symbolic hotkey 163) ships unassigned.
# The bell types it (plugins/notifications.sh); pressing the clock menu extra
# instead shows the panel for under half a second while the native bar is
# hidden. One entry is added with -dict-add, so every other shortcut stays.

keycode_ascii() { # the character of an ANSI letter key code, else 65535
  local -a letters=(a s d f h g z x c v '' b q w e r y t)
  local c=$1
  if [ "$c" -ge 0 ] && [ "$c" -le 17 ] && [ -n "${letters[$c]}" ]; then
    printf '%d' "'${letters[$c]}"; return
  fi
  case "$c" in
    31) printf '%d' "'o" ;; 32) printf '%d' "'u" ;; 34) printf '%d' "'i" ;; 35) printf '%d' "'p" ;;
    37) printf '%d' "'l" ;; 38) printf '%d' "'j" ;; 40) printf '%d' "'k" ;; 45) printf '%d' "'n" ;;
    46) printf '%d' "'m" ;; *) echo 65535 ;;
  esac
}
do_hotkey() { # minbar hotkey [set|remove]
  load_settings
  local flags=0 m="$MINBAR_NC_MODS"
  case "${1:-set}" in
    set)
      [[ $m == *ctrl* ]] && flags=$((flags + 262144))
      [[ $m == *alt* ]] && flags=$((flags + 524288))
      [[ $m == *cmd* ]] && flags=$((flags + 1048576))
      [[ $m == *shift* ]] && flags=$((flags + 131072))
      defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 163 \
        "<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>$(keycode_ascii "$MINBAR_NC_KEY")</integer><integer>$MINBAR_NC_KEY</integer><integer>$flags</integer></array><key>type</key><string>standard</string></dict></dict>" ;;
    remove)
      defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 163 \
        "<dict><key>enabled</key><false/></dict>" ;;
    *) die "hotkey [set|remove]" ;;
  esac
  /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u 2>/dev/null || true
}

##### The native macOS menu bar #####

do_native_hide() { # auto-hide on; menubar-alpha (agents) keeps it invisible
  defaults write NSGlobalDomain _HIHideMenuBar -bool "$1"
}

##### clawd's Claude Code hooks #####
#
# ~/.claude/settings.json is merged in place: other keys and hooks are kept,
# clawd's own entries are replaced, and `cat >` keeps the file's owner and inode.

CLAUDE_SETTINGS="$HOME/.claude/settings.json"
HOOK="$MINBAR_ROOT/clawd/src/clawd.hook.sh"
JQ_STRIP='def strip(ev): (.hooks[ev] // []) | map(select(([.hooks[]? | (.command // "")] | any(test("clawd\\.hook\\.sh"))) | not));'
do_hooks() { # minbar hooks [install|remove|status]
  has jq || die "the clawd hooks need jq (brew install jq)"
  local verb=${1:-install} filter tmp
  case "$verb" in
    install)
      filter="$JQ_STRIP"'
        .hooks = (.hooks // {})
        | .hooks.SessionStart     = (strip("SessionStart")     + [{hooks:[{type:"command", command:($hook+" start")}]}])
        | .hooks.UserPromptSubmit = (strip("UserPromptSubmit") + [{hooks:[{type:"command", command:($hook+" working")}]}])
        | .hooks.Stop             = (strip("Stop")             + [{hooks:[{type:"command", command:($hook+" idle")}]}])
        | .hooks.StopFailure      = (strip("StopFailure")      + [{hooks:[{type:"command", command:($hook+" error")}]}])
        | .hooks.Notification     = (strip("Notification")     + [{matcher:"", hooks:[{type:"command", command:($hook+" notification")}]}])
        | .hooks.SubagentStart    = (strip("SubagentStart")    + [{hooks:[{type:"command", command:($hook+" agent-start")}]}])
        | .hooks.SubagentStop     = (strip("SubagentStop")     + [{hooks:[{type:"command", command:($hook+" agent-stop")}]}])
        | .hooks.SessionEnd       = (strip("SessionEnd")       + [{hooks:[{type:"command", command:($hook+" end")}]}])' ;;
    remove)
      [ -f "$CLAUDE_SETTINGS" ] || return 0
      filter="$JQ_STRIP"'
        .hooks = ((.hooks // {}) | with_entries(.value |= map(select(([.hooks[]? | (.command // "")] | any(test("clawd\\.hook\\.sh"))) | not))) | with_entries(select(.value != [])))' ;;
    status)
      if hooks_installed; then echo "installed"; else echo "missing"; fi
      return 0 ;;
    *) die "hooks [install|remove|status]" ;;
  esac
  mkdir -p "${CLAUDE_SETTINGS%/*}"
  [ -e "$CLAUDE_SETTINGS" ] || echo '{}' >"$CLAUDE_SETTINGS"
  jq -e . "$CLAUDE_SETTINGS" >/dev/null 2>&1 || die "$CLAUDE_SETTINGS is not valid JSON; fix it first"
  tmp=$(mktemp)
  if jq --arg hook "$HOOK" "$filter" "$CLAUDE_SETTINGS" >"$tmp" && jq -e . "$tmp" >/dev/null; then
    cat "$tmp" >"$CLAUDE_SETTINGS"
    if [ "$verb" = install ]; then note "clawd hooks installed in $CLAUDE_SETTINGS"
    else note "clawd hooks removed from $CLAUDE_SETTINGS"; fi
  fi
  rm -f "$tmp"
}
hooks_installed() {
  [ -f "$CLAUDE_SETTINGS" ] &&
    jq -e '[.hooks // {} | .[][]?.hooks[]?.command // ""] | any(test("clawd\\.hook\\.sh"))' "$CLAUDE_SETTINGS" >/dev/null 2>&1
}

##### The settings file #####

write_conf() {
  [ -f "$CONF_FILE" ] && return 0
  mkdir -p "$CONF_DIR"
  {
    echo "# MinBar settings: uncomment and change a line, then \`minbar reload\`."
    echo "# Every key, with its default and meaning: $BAR/config.sh"
    sed -n 's/^\(MINBAR_[A-Z_]*=.*\)$/# \1/p' "$BAR/config.sh"
    echo "#"
    echo "# clawd's look (the bar's defaults are in minbarrc; all keys: clawd/README.md), e.g."
    echo "# CLAWD_COLOR_WORK=ef7139"
  } >"$CONF_FILE"
  note "wrote $CONF_FILE"
}

##### Permissions #####

do_permissions() {
  # A first attempt from the running bar makes macOS list MinBar in both panes
  # (and ask for Accessibility), so there is a switch to turn on.
  if [ -n "$(daemon_pid)" ]; then sketchybar --trigger minbar_probe >/dev/null 2>&1 || true; fi
  cat <<EOT
MinBar needs two permissions, both for MinBar.app ($APP):
  Accessibility      the app menus on the left, the bell's click
  Full Disk Access   the bell's count (macOS's notification database)
System Settings opens on each: switch MinBar on. If it is not listed, drag
MinBar.app from the Finder window that opens into the list (or press +, then
⇧⌘G and $APP). Then: minbar restart.
After the app is re-signed (a new certificate), switch it off and on again.
EOT
  open -R "$APP" 2>/dev/null || true
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" 2>/dev/null || true
  sleep 1
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles" 2>/dev/null || true
}

##### setup / uninstall #####

do_setup() { # minbar setup [--yes] [--no-hooks] [--no-agents]
  local hooks=ask agents=1 a missing
  for a in "$@"; do
    case "$a" in
      -y | --yes) ASSUME_YES=1 ;;
      --no-hooks) hooks=no ;;
      --no-agents) agents=0 ;;
      *) die "setup [--yes] [--no-hooks] [--no-agents]" ;;
    esac
  done
  has sketchybar || die "sketchybar is not installed (brew install felixkratz/formulae/sketchybar)"
  [ -x "$MINBAR_LIBEXEC/menus" ] || die "helpers missing in $MINBAR_LIBEXEC (make)"
  write_conf
  load_settings
  # Fonts are Homebrew casks, which a formula cannot depend on: offer them here.
  missing=$(fonts_missing)
  if [ -n "$missing" ]; then
    # shellcheck disable=SC2086  # $missing is a list of cask names
    if has brew && confirm "Install the fonts the bar draws with (brew install --cask $missing)?"; then
      brew install --cask $missing || note "font install failed: brew install --cask $missing"
    else
      note "fonts the bar draws with are missing: brew install --cask $missing"
    fi
  fi
  do_font
  do_app
  do_hotkey set
  if [ "$MINBAR_HIDE_NATIVE_BAR" = 1 ] && confirm "Hide the macOS menu bar for good? (MINBAR_HIDE_NATIVE_BAR)"; then
    do_native_hide true
  else
    MINBAR_HIDE_NATIVE_BAR=0
  fi
  if [ "$agents" = 1 ]; then do_agents install; fi
  if [ "$MINBAR_CLAWD" = 1 ] || [ "$MINBAR_CLAWD" = on ]; then
    if [ "$hooks" = ask ] && has jq && confirm "Install clawd's hooks in ~/.claude/settings.json (one sprite per Claude Code session)?"; then
      do_hooks install
    fi
  fi
  echo
  do_permissions
  echo
  note "done. \`minbar doctor\` checks everything; \`minbar\` opens the menu."
}

do_uninstall() { # minbar uninstall [--yes]
  # shellcheck disable=SC2034  # read by confirm (common.sh)
  [ "${1:-}" = --yes ] && ASSUME_YES=1
  do_agents remove
  rm -rf "$APP" "$PREVIEW"
  do_hotkey remove
  do_native_hide false
  has jq && do_hooks remove || true
  rm -f "$HOME/Library/Fonts/SimpleIcons.otf"
  if confirm "Also delete your settings ($CONF_DIR) and state ($STATE)?"; then
    rm -rf "$CONF_DIR" "$STATE"
  fi
  note "MinBar removed (the formula itself: brew uninstall minbar)"
}
