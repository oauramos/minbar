# MinBar for home-manager on macOS: the settings files, the launchd agents
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
    MINBAR_APP_DIR=${cfg.appDirectory}
  ''
  + cfg.extraConfig;

  appRules = ''
    # Written by home-manager (programs.minbar.workspaces.apps); edits here are overwritten.
  ''
  + lib.concatStrings (
    lib.mapAttrsToList (name: app: ''
      ${name} = ${lib.concatStringsSep ", " app.ids} -> ${toString app.workspace}
    '') cfg.workspaces.apps
  );

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
      apps = mkOption {
        type = types.attrsOf (
          types.submodule {
            options = {
              ids = mkOption {
                type = types.nonEmptyListOf (types.strMatching "[A-Za-z0-9._-]+");
                description = "Bundle ids; several make one app.";
              };
              workspace = mkOption {
                type = types.either types.ints.positive (types.strMatching "[A-Za-z0-9_-]+");
                description = "The AeroSpace workspace its new windows open on.";
              };
            };
          }
        );
        default = { };
        example = lib.literalExpression ''
          {
            Playwright = {
              ids = [ "com.google.Chrome" "com.google.chrome.for.testing" ];
              workspace = 8;
            };
          }
        '';
        description = "Apps whose windows always open on one workspace; the others open where you are.";
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
    appDirectory = mkOption {
      type = types.str;
      default = "/Applications";
      example = lib.literalExpression ''"''${config.home.homeDirectory}/Applications"'';
      description = "Where MinBar.app is built (/Applications needs an admin account, no sudo).";
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
    # sketchybar too: AeroSpace's exec-on-workspace-change and you call it by name.
    home.packages = [
      pkg
      cfg.sketchybarPackage
    ];
    home.file.".config/minbar/minbar.conf".text = conf;
    home.file.".config/minbar/workspaces.conf" = mkIf (cfg.workspaces.apps != { }) { text = appRules; };

    launchd.agents = {
      minbar = agent label "minbar" [
        "${cfg.appDirectory}/MinBar.app/Contents/MacOS/sketchybar"
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
    // lib.optionalAttrs cfg.workspaces.enable {
      minbar-workspaces = agent "${label}.workspaces" "workspaces" [
        "/bin/bash"
        "${root}/bar/plugins/workspaces.sh"
        "watch"
      ];
    }
    // lib.optionalAttrs cfg.hideNativeMenuBar {
      minbar-menubar-alpha = agent "${label}.menubar-alpha" "menubar-alpha" [
        "${libexec}/menubar-alpha"
      ];
    };

    # Before the agents load, so the app they run exists; `app --restart`
    # moves a running bar onto a rebuilt binary. Every step is idempotent, and a
    # failing one only warns: the bar must never stop a home-manager switch.
    home.activation.minbar = lib.hm.dag.entryBetween [ "setupLaunchAgents" ] [ "linkGeneration" ] ''
      _minbar() {
        run ${pkg}/bin/minbar "$@" ||
          echo "minbar: '$*' failed during activation; run \`minbar $*\` to see why" >&2
      }
      export PATH="${lib.makeBinPath [ cfg.sketchybarPackage ]}:$PATH"
      _minbar font
      _minbar app --quiet --restart
      _minbar hotkey set
      ${optionalString cfg.hideNativeMenuBar "run /usr/bin/defaults write NSGlobalDomain _HIHideMenuBar -bool true || true"}
      ${optionalString (cfg.clawd.enable && cfg.clawd.hooks) "_minbar hooks install"}
      unset -f _minbar
    '';
  };
}
