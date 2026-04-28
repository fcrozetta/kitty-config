#!/bin/bash
set -e

# Usage: ./scripts/generate-formula.sh <version> <sha256> <repo-url>
# Example: ./scripts/generate-formula.sh 0.1.0 abc123 https://github.com/fcrozetta/kitty-config

VERSION="${1:?Usage: $0 <version> <sha256> <repo-url>}"
SHA256="${2:?Usage: $0 <version> <sha256> <repo-url>}"
REPO_URL="${3:?Usage: $0 <version> <sha256> <repo-url>}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEPS_FILE="$SCRIPT_DIR/../deps/brew.txt"

# Generate depends_on lines from brew.txt.
# Plain lines become top-level `depends_on "name"`.
# Lines starting with "cask:" are SKIPPED here — setup.sh installs them
# at user level via `brew install --cask`. Declaring casks in the
# formula is unreliable across Homebrew versions.
# Blank lines and comments (#) are skipped.
DEPENDS_TOP=""
while IFS= read -r pkg || [ -n "$pkg" ]; do
  pkg="$(echo "$pkg" | sed 's/[[:space:]]*#.*$//' | xargs)"
  [ -z "$pkg" ] && continue
  case "$pkg" in
    cask:*)
      ;;  # handled by setup.sh, not the formula
    *)
      DEPENDS_TOP="${DEPENDS_TOP}  depends_on \"${pkg}\"
"
      ;;
  esac
done < "$DEPS_FILE"

DEPS_SECTION="  depends_on :macos
"
if [ -n "$DEPENDS_TOP" ]; then
  DEPS_SECTION="${DEPS_SECTION}
${DEPENDS_TOP}"
fi

cat <<EOF
class KittyConfig < Formula
  desc "Personal kitty terminal configuration"
  homepage "${REPO_URL}"
  url "${REPO_URL}/archive/refs/tags/${VERSION}.tar.gz"
  sha256 "${SHA256}"
  license "MIT"

${DEPS_SECTION}
  def install
    bin.install "setup.sh" => "kitty-config-setup"
    bin.install "scripts/uninstall.sh" => "kitty-config-uninstall"
    inreplace bin/"kitty-config-setup", /^SCRIPT_DIR=.*$/, "SCRIPT_DIR=\"#{opt_pkgshare}\""
    pkgshare.install Dir["*"], ".gitignore"
  end

  def caveats
    <<~EOS
      Brew cannot write outside its prefix during install.
      Finish setup by running:

        kitty-config-setup

      This adds a managed BEGIN_KITTY_CONFIG block to your
      ~/.config/kitty/kitty.conf, symlinks themes/ and kittens/
      from this formula's pkgshare, and seeds current-theme.conf
      on first install.

      Re-run kitty-config-setup after each 'brew upgrade' to pick
      up new themes, kittens, or base.conf changes.

      Run 'kitty-config-uninstall' before 'brew uninstall' for a
      clean removal.
    EOS
  end
end
EOF
