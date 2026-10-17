#!/bin/sh
# Tests for wallpaper/restore.sh in --print mode, so awww is never called. Run: sh tests/wallpaper-restore.sh
here=$(cd "$(dirname "$0")/.." && pwd)
script="$here/wallpaper/restore.sh"
default=/home/tk421/Projects/tk421/theme-engine/collections/star-wars/imperial-destroyer/wallpaper.png
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0

expect() {   # name, wanted, got
    if [ "$2" = "$3" ]; then
        echo "ok   $1"
    else
        echo "FAIL $1: wanted [$2] got [$3]"
        fail=1
    fi
}

run() {      # state file
    WALLPAPER_STATE="$1" "$script" --print 2>/dev/null
}

img="$tmp/my wall #1.png"
: > "$img"
printf '{"path": "%s", "effect": "scan"}' "$img" > "$tmp/valid.json"
expect "valid state, awkward name"  "$img"     "$(run "$tmp/valid.json")"

printf '{"path": "%s/gone.png"}' "$tmp" > "$tmp/gone.json"
expect "saved file is gone"         "$default" "$(run "$tmp/gone.json")"

printf 'not json' > "$tmp/corrupt.json"
expect "corrupt state"              "$default" "$(run "$tmp/corrupt.json")"

printf '[]' > "$tmp/array.json"
expect "state is an array"          "$default" "$(run "$tmp/array.json")"

printf '{"path": 5}' > "$tmp/number.json"
expect "path is not a string"       "$default" "$(run "$tmp/number.json")"

printf '{"path": ""}' > "$tmp/empty.json"
expect "empty path"                 "$default" "$(run "$tmp/empty.json")"

expect "no state file"              "$default" "$(run "$tmp/none.json")"

exit $fail
