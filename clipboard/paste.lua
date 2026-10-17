-- Ctrl+Enter in the clipboard archive: put cliphist record <id> back on the clipboard, then paste it into the window that had focus.
-- Terminals paste with Ctrl+Shift+V, everything else with Ctrl+V.
-- Run as: lua clipboard/paste.lua <id>

local id = arg[1]
if not id or not id:match("^%d+$") then
    io.stderr:write("usage: paste.lua <cliphist id>\n")
    os.exit(1)
end

-- id is digits only (checked above), so it is safe to put in a shell command.
if not os.execute("cliphist decode " .. id .. " | wl-copy") then
    os.exit(1)
end

os.execute("sleep 0.15")        -- the archive has closed and the focus has gone back to the window below

local hypr = io.popen("hyprctl activewindow -j")
local window = hypr:read("a")
hypr:close()
local class = (window:match('"class":%s*"([^"]*)"') or ""):lower()

local terminals = { "ghostty", "kitty", "alacritty", "foot", "wezterm" }
local keys = "wtype -M ctrl -k v -m ctrl"
for _, name in ipairs(terminals) do
    if class:find(name, 1, true) then
        keys = "wtype -M ctrl -M shift -k v -m shift -m ctrl"
        break
    end
end

os.execute(keys)
