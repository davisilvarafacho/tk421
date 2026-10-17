#!/bin/sh
# Switches the terminal theme everywhere it is configured: Ghostty (config.ghostty) and fish (syntax colours).
# The theme files live in this directory and are referenced by path, so editing them here updates both.
#
#   terminal/set-theme.sh Mono        official: graphite greys only
#   terminal/set-theme.sh Mono-Red    the same greys plus Imperial red for errors
#
# Backups of the state before the first switch: ~/.config/ghostty/config.ghostty.bak, ~/.config/fish/fish_variables.bak.
# Tide and fastfetch use named ANSI colours, so they follow the palette without any change.

set -e
here=$(cd "$(dirname "$0")" && pwd)
variant=${1:-Mono}
name="TK421-Imperial-$variant"
[ -f "$here/$name" ] || { echo "unknown theme '$variant' (Mono | Mono-Red)" >&2; exit 1; }

cfg="$HOME/.config/ghostty/config.ghostty"
tmp=$(mktemp)
if grep -q '^theme *=' "$cfg"; then
    sed "s|^theme *=.*|theme = $here/$name|" "$cfg" > "$tmp"
else
    { printf 'theme = %s\n' "$here/$name"; cat "$cfg"; } > "$tmp"
fi
cat "$tmp" > "$cfg" && rm -f "$tmp"       # cat keeps the file's mode and inode

mkdir -p "$HOME/.config/fish/themes"
ln -sf "$here/$name.theme" "$HOME/.config/fish/themes/$name.theme"
# `theme save` makes it persistent (universal variables); it asks before overwriting the current colours.
echo y | fish -c "fish_config theme save '$name'" >/dev/null

echo "Ghostty: theme = $here/$name"
echo "fish:    $name (running shells pick it up; Ghostty applies it to new windows, or press ctrl+shift+, to reload)"
