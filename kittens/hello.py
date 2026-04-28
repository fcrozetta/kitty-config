"""
hello.py — minimal example kitten shipped by kitty-config.

Invoke from a shell:

    kitten hello                # prints a greeting in the current window
    kitten hello Iris           # greets a specific name

Or bind to a key in your kitty.conf:

    map kitty_mod+h kitten hello

Custom kittens are just Python files in ~/.config/kitty/. kitty-config
ships them as symlinks at the top of that directory so `kitten <name>`
finds them, while the source files live in this formula's
kittens/ subdirectory inside pkgshare.
"""


def main(args):
    name = " ".join(args[1:]) if len(args) > 1 else "world"
    print(f"Hello, {name}, from kitty-config!")
    return ""


def handle_result(args, response, target_window_id, boss):
    # Called after main() returns. Nothing to do for a print-only kitten.
    pass
