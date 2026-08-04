# kitty-config shell init.
# Sourced from ~/.zshrc (or .bashrc) by the BEGIN_KITTY_CONFIG_SHELL
# block managed by kitty-config-setup.
#
# Provides:
#   - kitten() wrapper so `kitten <name>` resolves <name>.py for
#     custom kittens shipped in ~/.config/kitty/. kitty's own resolver
#     requires the .py extension; this swallows that wart at the CLI.
#   - kitten command completion listing custom + common built-in kittens.
#   - managed aliases: sources ~/.config/kitty/aliases.zsh (written by
#     `kitten alias`) and re-sources it after add/rm so the current
#     shell picks up changes — the kitten runs as a child process and
#     cannot mutate this shell itself.
#   - sophie() front-end for the sophie kitten, which deliberately
#     shadows any `sophie` on PATH. A kitten cannot claim a bare command
#     name on its own; only a function or a PATH entry can.

# --- Managed aliases (kitten alias) ---
[ -r "$HOME/.config/kitty/aliases.zsh" ] && . "$HOME/.config/kitty/aliases.zsh"

# --- Wrapper ---
kitten() {
  if [[ "$1" == "alias" && -e "$HOME/.config/kitty/alias.py" ]]; then
    command kitten alias.py "${@:2}" || return $?
    # Apply to the current shell: unalias on rm, then re-source.
    if [[ "$2" == "rm" && -n "${3:-}" ]]; then
      unalias "$3" 2>/dev/null
    fi
    if [ -r "$HOME/.config/kitty/aliases.zsh" ]; then
      . "$HOME/.config/kitty/aliases.zsh"
    fi
    return 0
  elif [[ $# -ge 1 && "$1" != *.py && "$1" != */* ]] \
     && [[ -e "$HOME/.config/kitty/$1.py" ]]; then
    local first="$1"
    shift
    command kitten "$first.py" "$@"
  else
    command kitten "$@"
  fi
}

# --- sophie: shadow any PATH `sophie` with the sophie kitten ---
# Runs as a child (not exec) so it cannot replace this shell. The kitten
# then execs the backend, so the backend owns the tty directly.
#
# Uses `kitty +kitten`, NOT the standalone `kitten` launcher: `kitten`
# scans every argument for a builtin kitten name or unique abbreviation
# and hands the run to that kitten instead, so `kitten sophie.py -p hi`
# runs `hints` and `-p ssh` runs ssh. `kitty +kitten` parses correctly.
sophie() {
  if [ ! -e "$HOME/.config/kitty/sophie.py" ]; then
    printf 'sophie: kitten not installed; run kitty-config-setup\n' >&2
    return 1
  fi
  local kitty_bin
  kitty_bin="$(command -v kitty)"
  [ -n "$kitty_bin" ] || kitty_bin="/Applications/kitty.app/Contents/MacOS/kitty"
  if [ ! -x "$kitty_bin" ]; then
    printf 'sophie: kitty not found on PATH\n' >&2
    return 1
  fi
  "$kitty_bin" +kitten sophie.py "$@"
}

# --- Helper: list custom + built-in kitten names for completion ---
__kitty_config_list_kittens() {
  local f
  for f in "$HOME/.config/kitty/"*.py; do
    [ -e "$f" ] || continue
    local n="${f##*/}"
    printf '%s\n' "${n%.py}"
  done
  # Best-effort static list of common built-in kittens.
  printf '%s\n' \
    ask broadcast clipboard diff hyperlinked_grep icat \
    kitty_chat panel query_terminal show_key ssh themes \
    transfer unicode_input \
    | sort -u
}

# --- zsh completion ---
if [[ -n "$ZSH_VERSION" ]]; then
  _kitty_config_kitten_completion() {
    compadd $(__kitty_config_list_kittens)
  }
  compdef _kitty_config_kitten_completion kitten
fi

# --- bash completion ---
if [[ -n "$BASH_VERSION" ]]; then
  _kitty_config_kitten_complete() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    if [[ $COMP_CWORD -eq 1 ]]; then
      COMPREPLY=( $(compgen -W "$(__kitty_config_list_kittens)" -- "$cur") )
    fi
  }
  complete -F _kitty_config_kitten_complete kitten
fi
