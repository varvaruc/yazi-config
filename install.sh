#!/bin/sh
# Install this Yazi config into ${XDG_CONFIG_HOME:-~/.config}/yazi.
# Idempotent: existing files are backed up to <file>.bak before being replaced.
set -eu

here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cfg="${XDG_CONFIG_HOME:-$HOME/.config}/yazi"

mkdir -p "$cfg"

for f in yazi.toml keymap.toml package.toml theme.toml; do
	[ -f "$here/config/$f" ] || continue
	if [ -f "$cfg/$f" ] && ! cmp -s "$here/config/$f" "$cfg/$f"; then
		cp -- "$cfg/$f" "$cfg/$f.bak"
		printf 'backed up  %s -> %s.bak\n' "$cfg/$f" "$cfg/$f"
	fi
	cp -- "$here/config/$f" "$cfg/$f"
	printf 'installed  %s\n' "$cfg/$f"
done

if command -v ya >/dev/null 2>&1; then
	printf '\ninstalling plugins from package.toml...\n'
	(cd "$cfg" && ya pkg install) || printf 'warning: ya pkg install failed; run it manually in %s\n' "$cfg"
else
	printf '\nwarning: `ya` not found - skipping plugins (brew install yazi)\n'
fi

# Flavors cannot come from package.toml when the repo name contains a dot
# (`ya pkg` requires kebab-case), so the theme is cloned by hand.
if [ -f "$here/config/theme.toml" ] && [ ! -d "$cfg/flavors/tokyo-night.yazi" ]; then
	printf '\ncloning tokyo-night flavor...\n'
	mkdir -p "$cfg/flavors"
	git clone --depth 1 -q https://github.com/BennyOe/tokyo-night.yazi.git \
		"$cfg/flavors/tokyo-night.yazi" || printf 'warning: flavor clone failed\n'
fi

cat <<'EOF'

Add this to ~/.zshrc if you don't already have it:

  function y() {
  	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
  	command yazi "$@" --cwd-file="$tmp"
  	IFS= read -r -d '' cwd < "$tmp"
  	[ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd"
  	command rm -f -- "$tmp"
  }
  eval "$(zoxide init zsh)"

Then: source ~/.zshrc && y
EOF
