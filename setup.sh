#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KITTY_DIR="$HOME/.config/kitty"
KITTY_CONF="$KITTY_DIR/kitty.conf"
CURRENT_THEME="$KITTY_DIR/current-theme.conf"
DEFAULT_THEME_FILE="$SCRIPT_DIR/themes/Japanesque.conf"

CONFIG_BEGIN="# BEGIN_KITTY_CONFIG"
CONFIG_END="# END_KITTY_CONFIG"
THEME_BEGIN="# BEGIN_KITTY_THEME"
THEME_END="# END_KITTY_THEME"

echo "==> kitty-config setup"
echo "    pkgshare:   $SCRIPT_DIR"
echo "    user dir:   $KITTY_DIR"

# --- Detect a font already on the system regardless of install method ---
# Translates a cask name like `font-fira-code-nerd-font` into the glob
# `*fira*code*nerd*font*` and looks for any matching file in macOS font
# dirs. Returns success if the font is present (manual install, Font
# Book, brew under a different cask name, etc).
font_already_present() {
  local cask_name="$1"
  case "$cask_name" in
    font-*) ;;
    *) return 1 ;;  # only font-* casks are checked this way
  esac

  local stripped="${cask_name#font-}"
  local pattern="*$(echo "$stripped" | tr '-' '*')*"

  local dir
  for dir in "$HOME/Library/Fonts" "/Library/Fonts"; do
    [ -d "$dir" ] || continue
    if find "$dir" -maxdepth 1 -type f -iname "$pattern" 2>/dev/null | head -n 1 | grep -q .; then
      return 0
    fi
  done
  return 1
}

# --- Install cask deps listed in deps/brew.txt ---
install_casks() {
  local deps_file="$SCRIPT_DIR/deps/brew.txt"
  [ -f "$deps_file" ] || return 0

  if ! command -v brew >/dev/null 2>&1; then
    echo "WARNING: brew not found; skipping cask deps"
    return 0
  fi

  while IFS= read -r pkg || [ -n "$pkg" ]; do
    pkg="$(echo "$pkg" | sed 's/[[:space:]]*#.*$//' | xargs)"
    [ -z "$pkg" ] && continue
    case "$pkg" in
      cask:*)
        local name="${pkg#cask:}"
        if brew list --cask --versions "$name" >/dev/null 2>&1; then
          echo "==> Cask already installed: $name"
        elif font_already_present "$name"; then
          echo "==> Font already on system (non-brew): $name — skipping install"
        else
          echo "==> Installing cask: $name"
          if ! brew install --cask "$name"; then
            echo "WARNING: brew install --cask $name failed."
            echo "         (continuing — install or manage manually if needed)"
          fi
        fi
        ;;
    esac
  done < "$deps_file"
}

install_casks

mkdir -p "$KITTY_DIR/themes"

# --- Sync themes/: per-file symlinks into pkgshare ---
sync_dir() {
  local subdir="$1"
  local src="$SCRIPT_DIR/$subdir"
  local dst="$KITTY_DIR/$subdir"

  # Prune stale symlinks pointing into pkgshare whose targets no longer exist
  if [ -d "$dst" ]; then
    while IFS= read -r -d '' link; do
      target="$(readlink "$link")"
      case "$target" in
        "$SCRIPT_DIR"/*)
          if [ ! -e "$link" ]; then
            echo "    prune stale symlink: ${link#$KITTY_DIR/}"
            rm "$link"
          fi
          ;;
      esac
    done < <(find "$dst" -maxdepth 1 -type l -print0)
  fi

  # Create/refresh symlinks for everything in pkgshare/<subdir>
  if [ -d "$src" ]; then
    for f in "$src"/*; do
      [ -e "$f" ] || continue
      name="$(basename "$f")"
      [ "$name" = ".gitkeep" ] && continue
      ln -sfn "$f" "$dst/$name"
    done
  fi
}

# --- Sync kittens: kitty's `kitten <name>` only resolves *.py in the
#     config dir root, not subfolders. Repo keeps them under kittens/
#     for organization; setup symlinks each *.py to ~/.config/kitty/<name>.py.
sync_kittens() {
  local src="$SCRIPT_DIR/kittens"
  [ -d "$src" ] || return 0

  # Prune stale top-level *.py symlinks pointing into pkgshare/kittens
  while IFS= read -r -d '' link; do
    local target
    target="$(readlink "$link")"
    case "$target" in
      "$src"/*)
        if [ ! -e "$link" ]; then
          echo "    prune stale kitten symlink: ${link#$KITTY_DIR/}"
          rm "$link"
        fi
        ;;
    esac
  done < <(find "$KITTY_DIR" -maxdepth 1 -type l -name "*.py" -print0 2>/dev/null)

  # Symlink each kitten *.py to the top-level config dir
  for f in "$src"/*.py; do
    [ -e "$f" ] || continue
    local name dst
    name="$(basename "$f")"
    dst="$KITTY_DIR/$name"
    if [ -L "$dst" ] || [ ! -e "$dst" ]; then
      ln -sfn "$f" "$dst"
    else
      echo "WARNING: $dst exists as a real file; skipping kitten symlink"
    fi
  done

  # Legacy cleanup: remove old kittens/ subdir symlinks from <= 0.0.5
  if [ -d "$KITTY_DIR/kittens" ]; then
    while IFS= read -r -d '' link; do
      local target
      target="$(readlink "$link")"
      case "$target" in
        "$SCRIPT_DIR"/kittens/*) rm "$link" ;;
      esac
    done < <(find "$KITTY_DIR/kittens" -maxdepth 1 -type l -print0 2>/dev/null)
    # Remove the dir if it's now empty
    rmdir "$KITTY_DIR/kittens" 2>/dev/null || true
  fi
}

echo "==> Syncing themes/"
sync_dir themes

echo "==> Syncing kittens"
sync_kittens

# --- Manage BEGIN_KITTY_CONFIG block in kitty.conf ---
manage_kitty_config_block() {
  local block_content="${CONFIG_BEGIN}
include ${SCRIPT_DIR}/base.conf
${CONFIG_END}"

  if [ ! -f "$KITTY_CONF" ]; then
    echo "==> Creating kitty.conf with kitty-config block"
    printf '%s\n' "$block_content" > "$KITTY_CONF"
    return
  fi

  if grep -qF "$CONFIG_BEGIN" "$KITTY_CONF"; then
    echo "==> Refreshing kitty-config block in kitty.conf"
    # Replace lines from CONFIG_BEGIN through CONFIG_END with new block
    awk -v begin="$CONFIG_BEGIN" -v end="$CONFIG_END" -v new="$block_content" '
      $0 == begin { in_block = 1; print new; next }
      in_block && $0 == end { in_block = 0; next }
      !in_block { print }
    ' "$KITTY_CONF" > "$KITTY_CONF.tmp" && mv "$KITTY_CONF.tmp" "$KITTY_CONF"
  else
    echo "==> Prepending kitty-config block to kitty.conf"
    printf '%s\n\n' "$block_content" | cat - "$KITTY_CONF" > "$KITTY_CONF.tmp"
    mv "$KITTY_CONF.tmp" "$KITTY_CONF"
  fi
}

manage_kitty_config_block

# --- Bootstrap theme on first install only ---
if [ ! -e "$CURRENT_THEME" ]; then
  echo "==> Seeding current-theme.conf from Japanesque"
  cp "$DEFAULT_THEME_FILE" "$CURRENT_THEME"

  if ! grep -qF "$THEME_BEGIN" "$KITTY_CONF"; then
    echo "==> Adding kitty-theme block to kitty.conf"
    {
      echo
      echo "$THEME_BEGIN"
      echo "# Japanesque"
      echo "include current-theme.conf"
      echo "$THEME_END"
    } >> "$KITTY_CONF"
  fi
else
  echo "==> current-theme.conf already exists; leaving alone"
fi

# --- Reload running kitty instances (best effort) ---
if pgrep -x kitty >/dev/null 2>&1; then
  echo "==> Reloading running kitty instances"
  pkill -SIGUSR1 -x kitty 2>/dev/null || true
fi

echo "==> Done"
