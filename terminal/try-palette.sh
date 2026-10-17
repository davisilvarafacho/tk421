#!/bin/sh
# Opens ONE separate Ghostty process with the Imperial Graphite theme. Nothing in ~/.config/ghostty is read for the theme
# or changed: the --theme flag overrides it for this window only, and the process dies with the window.
#
#   terminal/try-palette.sh              preview screen (swatches, ls, git diff, status)
#   terminal/try-palette.sh --shell      a normal fish shell with the palette, to use it for real for a while
#   terminal/try-palette.sh --fastfetch  fastfetch with the palette (its colours come from the ANSI palette)
#   terminal/try-palette.sh <theme>      another theme file, to compare (e.g. terminal/TK421-Imperial-Steel)

here=$(cd "$(dirname "$0")" && pwd)
theme="$here/TK421-Imperial-Graphite"
mode=preview
for arg in "$@"; do
    case "$arg" in
        --shell) mode=shell ;;
        --fastfetch) mode=fastfetch ;;
        *) theme="$arg" ;;
    esac
done

# Ghostty reads a relative --theme as a theme *name*, so resolve a file argument to an absolute path.
case "$theme" in
    /*) ;;
    *) theme="$(cd "$(dirname "$theme")" && pwd)/$(basename "$theme")" ;;
esac

# --gtk-single-instance=false: a second `ghostty` would otherwise hand the window to the running process and keep its
# config. --class: a distinct app id, so Hyprland rules and D-Bus activation do not mix it with the main Ghostty.
if [ "$mode" = shell ]; then
    exec ghostty --gtk-single-instance=false --class=com.tk421.palette --title="Palette: $(basename "$theme")" --theme="$theme"
fi
if [ "$mode" = fastfetch ]; then
    exec ghostty --gtk-single-instance=false --class=com.tk421.palette --title="Palette: $(basename "$theme")" --theme="$theme" \
        -e sh -c "fastfetch; printf '\n  press Enter to close '; read _"
fi
exec ghostty --gtk-single-instance=false --class=com.tk421.palette --title="Palette: $(basename "$theme")" --theme="$theme" \
    --window-width=70 --window-height=30 \
    -e sh -c "sh '$here/palette-preview.sh'; printf '  press Enter to close '; read _"
