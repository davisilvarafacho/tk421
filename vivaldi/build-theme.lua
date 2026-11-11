#!/usr/bin/env lua
-- Packs vivaldi/theme/ into the zip Vivaldi imports (Settings > Themes > Import): settings.json at the root of the
-- archive, nothing else. Usage: lua vivaldi/build-theme.lua   (from anywhere; paths are relative to this script)

local here = (arg[0]:match("^(.*)/[^/]*$") or ".")
local theme = here .. "/theme"
local dist = here .. "/dist"
local out = dist .. "/tk421-command-deck.zip"

local function sh(cmd)
    local ok = os.execute(cmd)
    if not ok then
        io.stderr:write("failed: " .. cmd .. "\n")
        os.exit(1)
    end
end

local function quote(s)
    return "'" .. s:gsub("'", "'\\''") .. "'"
end

-- A broken settings.json would import as a silent no-op, so check it parses first.
sh("python3 -I -c 'import json,sys; json.load(open(sys.argv[1]))' " .. quote(theme .. "/settings.json"))

sh("mkdir -p " .. quote(dist))
sh("rm -f " .. quote(out))
-- -j: store settings.json at the archive root, -X: no extra file attributes, -q: quiet.
sh("zip -jXq " .. quote(out) .. " " .. quote(theme .. "/settings.json"))
print(out)
