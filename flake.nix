{
  description = "MinBar: a macOS menu bar on SketchyBar";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      forAll = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAll (pkgs: rec {
        minbar = pkgs.callPackage ./nix/package.nix { };
        default = minbar;
      });

      homeManagerModules = rec {
        minbar = import ./nix/hm-module.nix self;
        default = minbar;
      };

      checks = forAll (pkgs: {
        build = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
        shellcheck = pkgs.runCommand "minbar-shellcheck" { nativeBuildInputs = [ pkgs.shellcheck ]; } ''
          cd ${./.}
          shellcheck -x -e SC1090,SC1091 bin/minbar cli/*.sh bar/minbarrc bar/*.sh bar/plugins/*.sh scripts/*.sh
          touch $out
        '';
      });

      formatter = forAll (pkgs: pkgs.nixfmt-rfc-style);
    };
}
