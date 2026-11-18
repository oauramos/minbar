# MinBar as a Nix package: the same `make install` Homebrew runs. The helpers
# link the private SkyLight framework from /System/Library/PrivateFrameworks,
# so this builds with the Nix sandbox off (nix-darwin's default on macOS).
{
  lib,
  stdenv,
  fetchurl,
  jq,
  makeWrapper,
  gum,
  blueutil,
  sketchybar,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "minbar";
  version = "0.1.0";

  src = lib.cleanSourceWith {
    src = ../.;
    filter =
      path: _type:
      let
        rel = lib.removePrefix (toString ../. + "/") (toString path);
      in
      !(lib.hasPrefix "build" rel || lib.hasPrefix "result" rel || rel == ".privacy-patterns");
  };

  simpleIcons = fetchurl {
    url = "https://registry.npmjs.org/simple-icons-font/-/simple-icons-font-16.32.0.tgz";
    hash = "sha256-umLXIBEDWUdVHbC4n02EgU2CCMjHsG8/SPPt44og/xE=";
  };

  nativeBuildInputs = [
    jq
    makeWrapper
  ];

  # Keep #!/bin/bash: the bar's scripts run on macOS's own bash, as from Homebrew.
  dontPatchShebangs = true;

  makeFlags = [
    "PREFIX=${placeholder "out"}"
    "SI_TARBALL=${finalAttrs.simpleIcons}"
  ];

  # The CLI calls these by name; the daemon gets its own PATH from the agent.
  postInstall = ''
    wrapProgram $out/bin/minbar --prefix PATH : ${
      lib.makeBinPath [
        jq
        gum
        blueutil
        sketchybar
      ]
    }
  '';

  meta = {
    description = "Menu bar on SketchyBar: app menus, workspaces, controls, a bell and clawd";
    homepage = "https://github.com/oauramos/minbar";
    license = with lib.licenses; [
      gpl3Only
      mit
    ];
    platforms = lib.platforms.darwin;
    mainProgram = "minbar";
  };
})
