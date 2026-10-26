# yazi-config

A deliberately small [Yazi](https://github.com/sxyazi/yazi) setup: stock keybindings,
a wider preview pane, three extra bindings, and the shell/dependency plumbing that
makes Yazi feel like part of the shell instead of an app you visit.

The point is **not** to ship a 400-line dotfiles config. Everything here exists
because it changed how the file manager actually gets used day to day.

Tested on macOS (Apple Silicon), Yazi **26.9.1**.

## Install

```sh
git clone https://github.com/varvaruc/yazi-config.git
cd yazi-config
./install.sh
```

`install.sh` copies the three TOMLs into `${XDG_CONFIG_HOME:-~/.config}/yazi`
(backing up anything it overwrites), then runs `ya pkg install` to fetch the
plugins pinned in `package.toml`. It does **not** touch your shell rc — it prints
the snippet to paste instead.

Then open a new shell and start with `y`, not `yazi` (see below).

## Dependencies

```sh
brew install yazi fd ripgrep fzf zoxide chafa ffmpeg poppler sevenzip jq
```

| Package | Unlocks |
| --- | --- |
| `fd` | `s` — recursive filename search |
| `ripgrep` | `S` — recursive content search |
| `fzf` | `z` — fuzzy jump to any file/dir |
| `zoxide` | `Z` — jump to any directory you've visited (`z` in the shell too) |
| `chafa` | image previews in terminals without a graphics protocol |
| `ffmpeg`/`ffprobe` | video previews and thumbnail seeking |
| `poppler` (`pdftoppm`) | PDF previews |
| `sevenzip` (`7zz`) | archive previews (and extracting on paste) |
| `jq` | pretty-printed JSON previews |

Yazi's own `d` (trash) works natively on macOS — no dependency needed.

## What's in here

| File | Purpose |
| --- | --- |
| `config/yazi.toml` | pane ratio, hidden files, `mtime` linemode, preview size cap |
| `config/keymap.toml` | 3 additions on top of the stock keymap |
| `config/package.toml` | plugin pins (`smart-enter`, `jump-to-char`, `git`) |
| `config/theme.toml` | selects the `tokyo-night` flavor |
| `install.sh` | idempotent installer |

### Config choices, and why

```toml
[mgr]
ratio = [1, 4, 5]      # parent : current : preview — file list gets the space
show_hidden = true     # `.` still toggles it
linemode = "mtime"     # timestamps visible by default; `m` + letter switches live

[preview]
max_width = 1600       # stop ffmpeg decoding 6000px images for a 400px pane
max_height = 1000
```

### Keymap additions

| Key | Action |
| --- | --- |
| `<Enter>` | enter dirs, open files (`smart-enter`); `l` stays "enter directory only" |
| `F` | vim-style jump: press `F`, then the first character of the filename |
| `m` `g` | switch the linemode column to git status (`git` plugin) |

`linemode = "mtime"` and `m` `g` conflict in the sense that only one is active at a
time — that's the point, `m` + a letter is a live switch: `m s` size, `m m` mtime,
`m p` permissions, `m o` owner, `m n` none.

## Theme

[`tokyo-night.yazi`](https://github.com/BennyOe/tokyo-night.yazi) by BennyOe, wired up in
`theme.toml`:

```toml
[flavor]
dark = "tokyo-night"
```

It has to be cloned by hand, and this is the one genuinely annoying part:

```sh
git clone --depth 1 https://github.com/BennyOe/tokyo-night.yazi.git \
  ~/.config/yazi/flavors/tokyo-night.yazi
```

`ya pkg add BennyOe/tokyo-night.yazi` **fails** with
`Package name must be in kebab-case`, because the repo name contains a dot. The same
error kills a manual entry in `package.toml`, so this flavor cannot be pinned there —
`install.sh` clones it instead, and it is updated with `git -C … pull` rather than
`ya pkg upgrade`.

Other flavors from `yazi-rs/flavors` *do* work through the package manager, since they
are subpackages with clean names:

```sh
ya pkg add yazi-rs/flavors:catppuccin-mocha   # then: dark = "catppuccin-mocha"
```

## The shell wrapper

A TUI child process cannot change the parent shell's working directory. Yazi writes
its exit dir to a file; a shell function reads it and `cd`s. Without this, quitting
Yazi dumps you back where you started, which is the main reason people conclude
"Yazi isn't useful".

```zsh
function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	command yazi "$@" --cwd-file="$tmp"
	IFS= read -r -d '' cwd < "$tmp"
	[ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd"
	command rm -f -- "$tmp"
}
```

`Q` (instead of `q`) quits **without** writing the cwd — use it when you were only
peeking at another directory.

## Keys worth memorising

Stock Yazi bindings, in rough order of value:

| Key | Action |
| --- | --- |
| `~` | help overlay, filterable, context-aware — the answer to "what was that key" |
| `j`/`k` `h`/`l` | move / up a level / enter |
| `H`/`L` | back / forward through visited dirs (browser-style) |
| `Space` | select and advance — builds a selection set |
| `v` | visual selection mode |
| `<C-a>` / `<C-r>` | select all / invert |
| `y` `x` `p` / `P` | copy / cut / paste / paste-overwrite |
| `d` / `D` | trash / delete permanently |
| `r` | rename, cursor placed before the extension |
| `a` / `A` | create file (end with `/` for a dir) / bulk create |
| `.` | toggle hidden files |
| `/` `f` | find in listing / live filter |
| `s` `S` | recursive search by name (fd) / by content (rg) |
| `z` `Z` | fzf jump / zoxide jump |
| `Tab` | spot: preview full-screen, `Tab` again to return |
| `J`/`K` | scroll the preview |
| `,` + letter | sort (`m` mtime, `s` size, `a` alpha, `e` extension) |
| `c c` / `c f` / `c d` | copy path / filename / dir path |
| `;` / `:` | shell command, async / blocking; `$@` = selected files |
| `w` | task manager — copies/deletes are async |
| `t t` / `1`–`9` / `[` `]` | new tab / switch / cycle |
| `g h` `g c` `g d` `g <Space>` | home / config / Downloads / jump to typed path |
| `g t` | browse the trash |
| `-` `_` `<C-->` | symlink absolute / relative / hardlink the yanked file |

Two habits that produce most of the speed-up: build a selection with `Space`/`v`
before acting, and reach for `s`/`S` instead of `find`/`grep` when you intend to
*act* on the results (search hits stay real file entries).

## zoxide: why `Z` says "no history"

Zoxide never scans the disk. It records directories you `cd` into from a shell that
has `eval "$(zoxide init zsh)"` loaded — so on a fresh install the database is empty
and `Z` has nothing to search.

The init registers a `chpwd` hook, so it fills itself as you work. To make it useful
immediately, seed it:

```sh
zoxide add ~/path/to/project
zoxide add -s 5 ~/path/to/favourite   # -s = extra score, ranks higher
zoxide query --list                   # what it knows
zoxide remove ~/path/to/junk
```

Two gotchas:

- **`$HOME` is excluded by default** — `z ~` will never work, and home won't appear
  in Yazi's `Z` list. Use `g h` inside Yazi for home.
- The DB lives at `~/Library/Application Support/zoxide/db.zo` on macOS
  (`$XDG_DATA_HOME/zoxide/db.zo` on Linux), not in `~/.local/share`.

## Troubleshooting

**Images are blocky.** `chafa` gives block-art everywhere and is a fallback. Yazi uses
the native graphics protocol automatically in Ghostty/kitty/WezTerm (and iTerm2's
inline images), so pixel-perfect previews need no config. If Yazi can't detect the
terminal, lower expectations rather than fight it.

**A key errors after installing these plugins.** The plugins track Yazi's `HEAD`, not
releases. After upgrading Yazi, run `ya pkg upgrade`. If a plugin needs an unreleased
API it will error only when its key is pressed — `ya pkg delete yazi-rs/plugins:<name>`
removes it. `full-border` is a known example: its current HEAD wants Yazi ≥ 26.10.

**The theme looks half-default.** A flavor is a snapshot of Yazi's theme schema. Keys
added to Yazi after the flavor's last commit silently fall back to defaults. Tokyo Night
was last touched Jan 2026; refresh it with
`git -C ~/.config/yazi/flavors/tokyo-night.yazi pull` and restart Yazi.

**`jq` resolves to `/usr/bin/jq`.** macOS ships one; Homebrew's is shadowed when
`/usr/bin` comes earlier in `PATH`. Harmless for previews. Fix by moving
`eval "$(brew shellenv)"` above the system paths.

**Yazi refuses to start from a script / non-interactive shell** with
`Inappropriate ioctl for device` — it needs a real tty and a real window size. That's
expected; it is not a config problem.

**Nothing changed after editing the config.** Yazi reads config at launch only, and
`ya` commands (`ya pkg …`) act on the config dir — restart Yazi, not the shell.

## Updating

```sh
brew upgrade yazi
ya pkg upgrade
git -C ~/.config/yazi/flavors/tokyo-night.yazi pull   # flavor is manual, see above
```
