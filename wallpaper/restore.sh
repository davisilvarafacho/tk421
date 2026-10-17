#!/bin/sh
# Paints the wallpaper saved by the picker (wallpaper/state.json), or the default one when there is no usable state.
# Run at login by hypr/hyprland.lua once awww-daemon is up. `restore.sh --print` only prints the path it would paint.
dir=$(cd "$(dirname "$0")" && pwd)
state=${WALLPAPER_STATE:-$dir/state.json}
default=/home/tk421/Projects/tk421/theme-engine/collections/star-wars/imperial-destroyer/wallpaper.png

path=$(jq -r 'if (.path | type) == "string" then .path else empty end' "$state" 2>/dev/null)
if [ -z "$path" ] || [ ! -f "$path" ]; then
    path=$default
fi

if [ "$1" = "--print" ]; then
    printf '%s\n' "$path"
    exit 0
fi

exec /usr/bin/awww img --transition-type none "$path"
