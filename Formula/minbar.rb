# MinBar's Homebrew formula. This file is the source of truth; each release
# copies it into the tap (github.com/oauramos/homebrew-minbar, Formula/).
#
# Release:
#   1. Bump MINBAR_VERSION in cli/common.sh, tag vX.Y.Z, push the tag.
#   2. curl -fsSL https://github.com/oauramos/minbar/archive/refs/tags/vX.Y.Z.tar.gz | shasum -a 256
#   3. Update url + sha256 below, copy this file into the tap, commit "minbar X.Y.Z".
# Check locally: brew style Formula/minbar.rb; in a tap: brew audit --strict --new minbar,
# brew install --build-from-source minbar, brew test minbar.
# Users tap felixkratz/formulae and `brew trust --formula felixkratz/formulae/sketchybar`
# first: Homebrew neither taps nor trusts a dependency's tap on its own.
class Minbar < Formula
  desc "Menu bar on SketchyBar: app menus, workspaces, controls, a bell and clawd"
  homepage "https://github.com/oauramos/minbar"
  url "https://github.com/oauramos/minbar/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"
  license all_of: ["GPL-3.0-only", "MIT"]
  head "https://github.com/oauramos/minbar.git", branch: "main"

  depends_on "blueutil"
  depends_on "felixkratz/formulae/sketchybar"
  depends_on "gum"
  depends_on "jq"
  # mic-cam reads CoreAudio's per-process objects, new in macOS 14.2.
  depends_on macos: :sonoma

  # Simple Icons as a font (CC0): the brand logos Nerd Fonts lacks.
  resource "simple-icons-font" do
    url "https://registry.npmjs.org/simple-icons-font/-/simple-icons-font-16.32.0.tgz"
    sha256 "ba62d72011035947551db0b89f4d84814d8208c8c7b06f3f48f3ede38a20ff11"
  end

  def install
    resource("simple-icons-font").stage(buildpath/"si")
    system "make", "install", "PREFIX=#{prefix}", "RUNTIME_PREFIX=#{opt_prefix}",
           "SI_DIR=#{buildpath}/si", "CC=#{ENV.cc}"
  end

  def caveats
    <<~EOS
      Set MinBar up (settings, the signed app, launchd agents, permissions;
      it also offers the fonts, which are casks a formula cannot depend on):
        minbar setup
      Or install the fonts yourself:
        brew install --cask font-hack-nerd-font font-sf-pro
      Keep its macOS permissions across sketchybar upgrades (once per Mac):
        minbar identity create
      After `brew upgrade minbar` or `brew upgrade sketchybar`:
        minbar restart
      If sketchybar runs as a brew service too, stop it (two bars would draw):
        brew services stop sketchybar
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/minbar version")
    assert_path_exists libexec/"minbar/menus"
    assert_path_exists libexec/"minbar/menubar-alpha"
    assert_path_exists libexec/"minbar/mic-cam"
    assert_match "tailscale", (pkgshare/"fonts/simple-icons.tsv").read
  end
end
