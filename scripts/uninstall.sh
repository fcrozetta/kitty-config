#!/bin/bash
set -euo pipefail

KITTY_DIR="$HOME/.config/kitty"
KITTY_CONF="$KITTY_DIR/kitty.conf"

CONFIG_BEGIN="# BEGIN_KITTY_CONFIG"
CONFIG_END="# END_KITTY_CONFIG"

echo "==> kitty-config uninstall"

if [ "${KITTY_CONFIG_UNINSTALL_FORCE:-}" != "1" ] && [ -t 0 ]; then
  echo "This will:"
  echo "  - remove the BEGIN_KITTY_CONFIG block from $KITTY_CONF"
  echo "  - remove kitty-config-managed symlinks from themes/ and kittens/"
  echo
  echo "It will NOT touch:"
  echo "  - your current-theme.conf"
  echo "  - your own files in themes/ or kittens/"
  echo "  - the BEGIN_KITTY_THEME block (kitten themes manages it)"
  echo "  - any other content in kitty.conf"
  echo
  printf "Continue? [y/N] "
  read -r reply
  case "$reply" in
    y|Y|yes|YES) ;;
    *) echo "==> Aborted"; exit 1 ;;
  esac
fi

# --- Strip BEGIN_KITTY_CONFIG block from kitty.conf ---
if [ -f "$KITTY_CONF" ] && grep -qF "$CONFIG_BEGIN" "$KITTY_CONF"; then
  echo "==> Removing kitty-config block from kitty.conf"
  awk -v begin="$CONFIG_BEGIN" -v end="$CONFIG_END" '
    $0 == begin { in_block = 1; next }
    in_block && $0 == end { in_block = 0; next }
    !in_block { print }
  ' "$KITTY_CONF" > "$KITTY_CONF.tmp" && mv "$KITTY_CONF.tmp" "$KITTY_CONF"
fi

# --- Remove symlinks pointing into kitty-config's brew prefix ---
remove_brew_symlinks() {
  local dir="$1"
  [ -d "$dir" ] || return 0
  while IFS= read -r -d '' link; do
    target="$(readlink "$link")"
    case "$target" in
      */share/kitty-config/*)
        echo "    remove: ${link#$HOME/}"
        rm "$link"
        ;;
    esac
  done < <(find "$dir" -maxdepth 1 -type l -print0)
}

echo "==> Cleaning themes/"
remove_brew_symlinks "$KITTY_DIR/themes"

# Top-level *.py symlinks (current kitten layout)
echo "==> Cleaning top-level kitten symlinks"
if [ -d "$KITTY_DIR" ]; then
  while IFS= read -r -d '' link; do
    target="$(readlink "$link")"
    case "$target" in
      */share/kitty-config/*)
        echo "    remove: ${link#$HOME/}"
        rm "$link"
        ;;
    esac
  done < <(find "$KITTY_DIR" -maxdepth 1 -type l -name "*.py" -print0 2>/dev/null)
fi

# Legacy kittens/ subdir from <= 0.0.5
if [ -d "$KITTY_DIR/kittens" ]; then
  echo "==> Cleaning legacy kittens/ subdir"
  remove_brew_symlinks "$KITTY_DIR/kittens"
  rmdir "$KITTY_DIR/kittens" 2>/dev/null || true
fi

# --- Reload running kitty instances ---
if pgrep -x kitty >/dev/null 2>&1; then
  pkill -SIGUSR1 -x kitty 2>/dev/null || true
fi

echo "==> Done. Run 'brew uninstall kitty-config' and 'brew autoremove' to clean up brew deps."
