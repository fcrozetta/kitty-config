"""
sophie.py — dispatch the `sophie` agent to a backend CLI.

Invoke from a shell (via the shell-init `sophie` function, which shadows
any `sophie` on PATH):

    sophie --claude              # claude --agent sophie
    sophie --hermes              # hermes -p sophie
    sophie                       # backend from $SOPHIE_DEFAULT, else claude
    sophie --claude -p 'status'  # extra args forward verbatim

Without the shell function, invoke it as:

    kitty +kitten sophie.py --claude

Not `kitten sophie.py`: the standalone `kitten` launcher scans every
argument for a builtin kitten name or unique abbreviation and hands the
run to that kitten instead, so `kitten sophie.py -p hi` runs `hints` and
`-p ssh` runs ssh. `kitty +kitten` parses arguments correctly.

The backend selector is recognised **only as the first argument**, so a
prompt may mention the words claude or hermes without being misrouted.
The selector is stripped; everything after it is passed through
untouched. This kitten does not translate between the two CLIs — the
backends differ (`claude 'hi'` is a prompt, `hermes -p sophie 'hi'`
treats 'hi' as a subcommand and fails; use `sophie --hermes -z 'hi'`).

main() replaces the process with the backend via execvp, so the backend
owns the tty directly and interactive sessions behave as if invoked by
hand.
"""

import os
import sys

BACKENDS = {
    "claude": ["claude", "--agent", "sophie"],
    "hermes": ["hermes", "-p", "sophie"],
}

FLAGS = {"--claude": "claude", "--hermes": "hermes"}

DEFAULT_BACKEND = "claude"
DEFAULT_ENV_VAR = "SOPHIE_DEFAULT"


class UsageError(Exception):
    """Bad selector or bad SOPHIE_DEFAULT — reported, never guessed around."""


def resolve(argv, env):
    """Map kitten args to the backend argv to exec.

    `argv` is the kitten's arguments *without* the leading script name.
    Returns the full command line as a list. Raises UsageError when the
    requested backend is not one we know.
    """
    if argv and argv[0] in FLAGS:
        return BACKENDS[FLAGS[argv[0]]] + list(argv[1:])

    # Anything else is the backend's business, including flags that only
    # look like a selector (--Claude). The backend reports those itself.
    name = env.get(DEFAULT_ENV_VAR, "").strip() or DEFAULT_BACKEND
    if name not in BACKENDS:
        raise UsageError(
            "%s=%r is not a known backend (want one of: %s)"
            % (DEFAULT_ENV_VAR, name, ", ".join(sorted(BACKENDS)))
        )
    return BACKENDS[name] + list(argv)


def _die(msg):
    print("sophie: %s" % msg, file=sys.stderr)
    raise SystemExit(1)


def main(args):
    # args[0] is the kitten name as kitty invoked it (e.g. "sophie.py").
    try:
        cmd = resolve(args[1:], os.environ)
    except UsageError as e:
        _die(str(e))

    try:
        os.execvp(cmd[0], cmd)
    except OSError as e:
        _die("cannot run %s: %s" % (cmd[0], e))


def handle_result(args, response, target_window_id, boss):
    # Unreachable in practice: main() execs and never returns. Kept for
    # parity with the other kittens and for kitty keybind invocation.
    pass


if __name__ == "__main__":
    main(sys.argv)
