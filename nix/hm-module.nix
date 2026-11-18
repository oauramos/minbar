# MinBar for home-manager on macOS: the settings file, the three launchd agents
# and, on activation, the steps `minbar setup` would run (font, signed app,
# Notification Center shortcut, native-bar hiding, clawd's hooks).
#
#   inputs.minbar.url = "github:oauramos/minbar";
#   home-manager.sharedModules = [ inputs.minbar.homeManagerModules.default ];
#   programs.minbar = { enable = true; variant = "mini"; };
#
# Permissions are still granted once by hand (`minbar permissions`), and the
# code-signing certificate made once per Mac (`minbar identity create`).
self:
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    mkEnableOption
    mkOption
    mkIf
    types
    optionalString
    ;
  cfg = config.programs.minbar;
  pkg = cfg.package;
  home = config.home.homeDirectory;
  root = "${pkg}/share/minbar";
  libexec = "${pkg}/libexec/minbar";
  label = "com.github.oauramos.minbar";
  logs = "${home}/Library/Logs/MinBar";
  bool = b: if b then "1" else "0";

  conf = ''
    # Written by home-manager (programs.minbar); edits here are overwritten.
    MINBAR_VARIANT=${cfg.variant}
    MINBAR_SHOW_STATS=${bool cfg.showStats}
    MINBAR_SHOW_NETWORK=${bool cfg.showNetwork}
    MINBAR_SHOW_WIFI_NAME=${bool cfg.showWifiName}
    MINBAR_WORKSPACES=${if cfg.workspaces.enable then "auto" else "off"}
    MINBAR_WORKSPACE_COUNT=${
      lib.optionalString (cfg.workspaces.count != null) (toString cfg.workspaces.count)
    }
    MINBAR_CLAWD=${if cfg.clawd.enable then "on" else "off"}
    MINBAR_NC_KEY=${toString cfg.notificationCenter.key}
    MINBAR_NC_MODS=${cfg.notificationCenter.mods}
    MINBAR_HIDE_NATIVE_BAR=${bool cfg.hideNativeMenuBar}
    MINBAR_SIGNING_IDENTITY="${cfg.signingIdentity}"
  ''
  + cfg.extraConfig;

  # The daemon's PATH: the helpers and the tools the plugins call by name.
  path = lib.concatStringsSep ":" (
    [
      libexec
      (lib.makeBinPath [
        cfg.sketchybarPackage
        pkgs.blueutil
        pkgs.jq
      ])
    ]
    ++ cfg.extraPath
    ++ [
      "${home}/.nix-profile/bin"
      "/etc/profiles/per-user/${config.home.username}/bin"
      "/run/current-system/sw/bin"
      "/opt/homebrew/bin"
      "/usr/local/bin"
      "/usr/bin"
      "/bin"
      "/usr/sbin"
      "/sbin"
    ]
  );
  agent = name: log: args: {
    enable = true;
    config = {
      Label = name;
      ProgramArguments = args;
      EnvironmentVariables.PATH = path;
      RunAtLoad = true;
      KeepAlive = true;
      ProcessType = "Interactive";
      StandardOutPath = "${logs}/${log}.log";
      StandardErrorPath = "${logs}/${log}.log";
    };
  };
in
{
  options.programs.minbar = {
    enable = mkEnableOption "MinBar, a macOS menu bar on SketchyBar";
    package = mkOption {
      type = types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
      description = "The MinBar package.";
    };
    sketchybarPackage = mkOption {
      type = types.package;
      default = pkgs.sketchybar;
      description = "The SketchyBar MinBar.app is built from.";
    };
    variant = mkOption {
      type = types.enum [
        "classic"
        "mini"
      ];
      default = "classic";
      description = "classic for big screens; mini for laptops (smaller values, slower polling).";
    };
    showStats = mkOption {
      type = types.bool;
      default = true;
      description = "The CPU / RAM / DISK box.";
    };
    showNetwork = mkOption {
      type = types.bool;
      default = true;
      description = "NET in the stats box.";
    };
    showWifiName = mkOption {
      type = types.bool;
      default = false;
      description = "The SSID next to the Wi-Fi glyph.";
    };
    workspaces = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "AeroSpace workspaces (drawn only when `aerospace` is installed).";
      };
      count = mkOption {
        type = types.nullOr types.ints.positive;
        default = null;
        description = "Workspace pills; null: 5 on mini, 8 on classic.";
      };
    };
    clawd = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "clawd, one pixel Claude Code mascot per session.";
      };
      hooks = mkOption {
        type = types.bool;
        default = true;
        description = "Merge clawd's hooks into ~/.claude/settings.json on activation.";
      };
    };
    hideNativeMenuBar = mkOption {
      type = types.bool;
      default = true;
      description = "Hide the macOS menu bar for good (auto-hide plus the menubar-alpha agent).";
    };
    notificationCenter = {
      key = mkOption {
        type = types.ints.between 0 127;
        default = 45;
        description = "Key code of the Notification Center shortcut the bell types (45 = N).";
      };
      mods = mkOption {
        type = types.str;
        default = "ctrl,alt,cmd";
        description = "Its modifiers, a comma list of ctrl, alt, cmd, shift.";
      };
    };
    signingIdentity = mkOption {
      type = types.str;
      default = "MinBar Code Signing";
      description = "Code-signing certificate MinBar.app is signed with (`minbar identity create`).";
    };
    extraPath = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "More directories on the daemon's PATH (e.g. where aerospace or tailscale live).";
    };
    extraConfig = mkOption {
      type = types.lines;
      default = "";
      example = "CLAWD_COLOR_WORK=ef7139";
      description = "Extra minbar.conf lines (CLAWD_* and the rest of bar/config.sh).";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ pkg ];
    home.file.".config/minbar/minbar.conf".text = conf;

    launchd.agents = {
      minbar = agent label "minbar" [
        "${home}/Applications/MinBar.app/Contents/MacOS/sketchybar"
        "--config"
        "${root}/bar/minbarrc"
      ];
      minbar-mic-cam = agent "${label}.mic-cam" "mic-cam" [
        "${libexec}/mic-cam"
        "--watch"
        "${cfg.sketchybarPackage}/bin/sketchybar"
        "--trigger"
        "mic_cam_change"
      ];
    }
    // lib.optionalAttrs cfg.hideNativeMenuBar {
      minbar-menubar-alpha = agent "${label}.menubar-alpha" "menubar-alpha" [
        "${libexec}/menubar-alpha"
      ];
    };

    # Before the agents load, so the app they run exists; `app --restart`
    # moves a running bar onto a rebuilt binary. Every step is idempotent.
    home.activation.minbar = lib.hm.dag.entryBetween [ "setupLaunchAgents" ] [ "linkGeneration" ] ''
      export PATH="${lib.makeBinPath [ cfg.sketchybarPackage ]}:$PATH"
      run ${pkg}/bin/minbar font
      run ${pkg}/bin/minbar app --quiet --restart || true
      run ${pkg}/bin/minbar hotkey set
      ${optionalString cfg.hideNativeMenuBar "run /usr/bin/defaults write NSGlobalDomain _HIHideMenuBar -bool true"}
      ${optionalString (
        cfg.clawd.enable && cfg.clawd.hooks
      ) "run ${pkg}/bin/minbar hooks install || true"}
    '';
  };
}
