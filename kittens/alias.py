"""
alias.py — manage zsh aliases in a dedicated file, kept separate from
user-authored aliases in ~/.zshrc.

Invoke from a shell:

    kitten alias add gs 'git status'    # create or overwrite
    kitten alias rm gs                  # remove
    kitten alias list                   # print managed alias lines

Aliases live in ~/.config/kitty/aliases.zsh, created on first add and
sourced by shell-init.sh. The shell-init kitten() wrapper re-sources the
file after each successful add/rm so the current shell picks up changes
(a child process cannot mutate the parent shell). Non-alias lines in the
file are preserved; only `alias ` lines are managed.
"""

import os
import re
import sys
import tempfile

ALIASES_FILE = os.path.expanduser("~/.config/kitty/aliases.zsh")

HEADER = [
    "# Managed by kitty-config `kitten alias`.",
    "# Alias lines are owned by the kitten; other lines are preserved.",
]

NAME_RE = re.compile(r"^[A-Za-z0-9_.-]+$")
ALIAS_LINE_RE = re.compile(r"^alias ([A-Za-z0-9_.-]+)=(.*)$")


def valid_name(name):
    return bool(NAME_RE.match(name))


def valid_value(value):
    return "\n" not in value and "\r" not in value


def zsh_quote(value):
    return "'" + value.replace("'", "'\\''") + "'"


def _alias_name(line):
    m = ALIAS_LINE_RE.match(line)
    return m.group(1) if m else None


def alias_lines(lines):
    return [ln for ln in lines if _alias_name(ln)]


def upsert_lines(lines, name, value):
    """Insert or replace `alias name=...`. Returns (new_lines, old_rhs)."""
    new_line = "alias %s=%s" % (name, zsh_quote(value))
    old_rhs = None
    out = []
    replaced = False
    for ln in lines:
        if _alias_name(ln) == name:
            if not replaced:
                old_rhs = ALIAS_LINE_RE.match(ln).group(2)
                out.append(new_line)
                replaced = True
            # drop duplicates
            continue
        out.append(ln)
    if replaced:
        return out, old_rhs

    # New alias: insert before the first alias line whose name sorts
    # greater; otherwise after the last alias line; otherwise append.
    insert_at = None
    last_alias = None
    for i, ln in enumerate(out):
        existing = _alias_name(ln)
        if existing is None:
            continue
        last_alias = i
        if insert_at is None and existing > name:
            insert_at = i
    if insert_at is None:
        insert_at = len(out) if last_alias is None else last_alias + 1
    out.insert(insert_at, new_line)
    return out, None


def remove_lines(lines, name):
    """Remove every `alias name=...` line. Returns (new_lines, found)."""
    out = [ln for ln in lines if _alias_name(ln) != name]
    return out, len(out) != len(lines)


def _read_lines(path):
    if not os.path.exists(path):
        return None
    with open(path, "r", encoding="utf-8") as f:
        return f.read().splitlines()


def _write_lines(path, lines):
    # Atomic: tmp file in the same directory, then rename.
    d = os.path.dirname(path)
    os.makedirs(d, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=d, prefix=".aliases-")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write("\n".join(lines) + "\n")
        os.replace(tmp, path)
    except BaseException:
        os.unlink(tmp)
        raise


def _die(msg):
    print("kitten alias: %s" % msg, file=sys.stderr)
    raise SystemExit(1)


def _usage():
    _die("usage: kitten alias add <name> <value> | rm <name> | list")


def main(args):
    cmd = args[1] if len(args) > 1 else None

    if cmd == "list":
        lines = _read_lines(ALIASES_FILE)
        for ln in alias_lines(lines or []):
            print(ln)
        return ""

    if cmd == "add":
        if len(args) != 4:
            _usage()
        name, value = args[2], args[3]
        if not valid_name(name):
            _die("invalid alias name: %r" % name)
        if not valid_value(value):
            _die("alias value must be a single line")
        lines = _read_lines(ALIASES_FILE)
        new_file = lines is None
        lines, old_rhs = upsert_lines(lines or [], name, value)
        if new_file:
            lines = HEADER + lines
        _write_lines(ALIASES_FILE, lines)
        if old_rhs is not None:
            print("%s: %s → %s" % (name, old_rhs, zsh_quote(value)))
        else:
            print("%s: %s" % (name, zsh_quote(value)))
        return ""

    if cmd == "rm":
        if len(args) != 3:
            _usage()
        name = args[2]
        lines = _read_lines(ALIASES_FILE)
        if lines is None:
            _die("no aliases file yet (%s)" % ALIASES_FILE)
        lines, found = remove_lines(lines, name)
        if not found:
            _die("no such alias: %s" % name)
        _write_lines(ALIASES_FILE, lines)
        print("removed %s" % name)
        return ""

    _usage()


def handle_result(args, response, target_window_id, boss):
    # Called after main() returns. Nothing to do for a print-only kitten.
    pass


if __name__ == "__main__":
    main(sys.argv)
