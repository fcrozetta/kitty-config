# kitty-config shell init.
# Sourced from ~/.zshrc (or .bashrc) by the BEGIN_KITTY_CONFIG_SHELL
# block managed by kitty-config-setup.
#
# Provides:
#   - kitten() wrapper so `kitten <name>` resolves <name>.py for
#     custom kittens shipped in ~/.config/kitty/. kitty's own resolver
#     requires the .py extension; this swallows that wart at the CLI.
#   - kitten command completion listing custom + common built-in kittens.

# --- Wrapper ---
kitten() {
  if [[ $# -ge 1 && "$1" != *.py && "$1" != */* ]] \
     && [[ -e "$HOME/.config/kitty/$1.py" ]]; then
    local first="$1"
    shift
    command kitten "$first.py" "$@"
  else
    command kitten "$@"
  fi
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
