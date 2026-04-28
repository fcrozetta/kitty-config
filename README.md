# kitty-config

Personal [kitty](https://sw.kovidgoyal.net/kitty/) terminal configuration,
distributed via Homebrew. macOS only.

## Prerequisite

Install kitty via the
[official installer](https://sw.kovidgoyal.net/kitty/binary/). This formula
does **not** install kitty itself.

Other dependencies (fonts) are installed by `kitty-config-setup`, not by
the formula — see [Dependencies](#dependencies) below.

## Installation

```bash
brew install fcrozetta/tools/kitty-config
kitty-config-setup
```

`brew install` installs all dependencies declared in the formula's
`depends_on`. It cannot write outside its prefix, so it does **not** wire
up `~/.config/kitty/`.

`kitty-config-setup` does the rest:

- Inserts a managed `BEGIN_KITTY_CONFIG` block at the top of
  `~/.config/kitty/kitty.conf` that includes this formula's `base.conf`.
  Your existing `kitty.conf` content is preserved.
- Creates `~/.config/kitty/themes/` and `~/.config/kitty/kittens/` if absent
  and symlinks each curated theme/kitten from the formula into them.
- On first install only: seeds `~/.config/kitty/current-theme.conf` from
  `themes/Japanesque.conf` and adds a `BEGIN_KITTY_THEME` block so the
  theme loads. After that, the theme is yours — `kitten themes` manages it.
- Sends `SIGUSR1` to running kitty instances to reload config.

> [!NOTE]
> `kitty-config-setup` is idempotent. Re-run it after every
> `brew upgrade` to pick up new themes, kittens, or `base.conf` changes.

### Upgrades

```bash
brew upgrade kitty-config
kitty-config-setup
```

### Uninstall

```bash
kitty-config-uninstall
brew uninstall kitty-config
brew autoremove
```

`kitty-config-uninstall` removes only what this formula added:

- The `BEGIN_KITTY_CONFIG` block from `kitty.conf`.
- Symlinks in `themes/` and `kittens/` that point into the formula's prefix.

It does **not** touch your `current-theme.conf`, the `BEGIN_KITTY_THEME`
block (managed by `kitten themes`), your own files in `themes/` or
`kittens/`, or any other content in `kitty.conf`.

### Dependencies

The formula itself only declares `depends_on :macos`. Cask deps are
installed by `kitty-config-setup` at user level (`brew install --cask
…`), because declaring casks in a formula is unreliable across
Homebrew versions.

| Tool                       | Purpose                | Installed by         |
| -------------------------- | ---------------------- | -------------------- |
| kitty                      | Terminal emulator      | you (manually)       |
| font-fira-code-nerd-font   | Default font           | `kitty-config-setup` |

## Layout

After `kitty-config-setup`, your config dir looks like:

```
~/.config/kitty/
├── kitty.conf            # yours, with our managed block at the top
├── current-theme.conf    # yours, seeded once on first install
├── hello.py              → symlink → $pkgshare/kittens/hello.py
├── (other shipped kittens, also at top level)
├── themes/
│   ├── Japanesque.conf   → symlink → $pkgshare/themes/Japanesque.conf
│   └── (your themes)
└── (your own kittens go directly here as *.py)
```

Kittens live at the top of `~/.config/kitty/` (not in a subfolder)
because that's where kitty's resolver looks. Run any shipped kitten by
its filename:

```bash
kitten hello              # runs hello.py
kitten hello Iris         # passes args
```

## Customization

Add per-machine overrides to your `~/.config/kitty/kitty.conf` *below* the
`BEGIN_KITTY_CONFIG` block:

```conf
# BEGIN_KITTY_CONFIG
include /opt/homebrew/share/kitty-config/base.conf
# END_KITTY_CONFIG

# Your overrides here — last-write-wins
font_size 16.0
map cmd+shift+t toggle_layout stack
```

Custom themes you want curated → add `themes/<Name>.conf` to this repo and
tag a release. Custom kittens → add to `kittens/` and tag.

## Releasing

Push a tag matching `<major>.<minor>.<patch>`:

```bash
git tag 0.1.0
git push origin 0.1.0
```

The release workflow creates a GitHub release, generates the Homebrew
formula, and opens a PR on
[`fcrozetta/homebrew-tools`](https://github.com/fcrozetta/homebrew-tools)
bumping `Formula/kitty-config.rb`.
