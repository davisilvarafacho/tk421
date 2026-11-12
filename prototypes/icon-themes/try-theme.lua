#!/usr/bin/env lua
-- Try an icon theme live on the whole desktop, then go back.
--   lua try-theme.lua list           installed candidates
--   lua try-theme.lua <Theme>        GTK apps (gsettings) + the shell (restarted with QS_ICON_THEME)
--   lua try-theme.lua reset          back to the theme saved on the first switch (Adwaita today)
-- The shell is restarted through Hyprland (hl.dsp.exec_cmd), so it keeps Hyprland's environment.
-- HyprFM: icon_theme in ~/.config/hyprfm/config.toml. Apps that are already open only pick up a new icon theme after they restart.

local SHELL = "/home/tk421/.config/quickshell/shell.qml"
local STATE = (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/tk421-icon-trial"
local CANDIDATES = { "Monotile-Circle-Dark", "Monotile-Squircle-Dark", "MonochromeIcons", "FullIcon-Light", "TK421-Concept", "candy-icons" }

local function sh(cmd)
  local p = io.popen(cmd .. " 2>/dev/null")
  local out = p:read("a")
  p:close()
  return (out:gsub("%s+$", ""))
end

local function quote(s) return "'" .. s:gsub("'", "'\\''") .. "'" end

local function installed(name)
  local home = os.getenv("HOME")
  for _, dir in ipairs({ home .. "/.local/share/icons/", "/usr/share/icons/" }) do
    local f = io.open(dir .. name .. "/index.theme")
    if f then f:close() return true end
  end
  return false
end

local function current() return (sh("gsettings get org.gnome.desktop.interface icon-theme"):gsub("'", "")) end

local function saved()
  local f = io.open(STATE)
  if not f then return nil end
  local v = f:read("l")
  f:close()
  return v
end

-- HyprFM reads its own icon theme from ~/.config/hyprfm/config.toml (applies on its next start).
local HYPRFM = os.getenv("HOME") .. "/.config/hyprfm/config.toml"
local function set_hyprfm(theme)
  local f = io.open(HYPRFM)
  if not f then return end
  local text = f:read("a")
  f:close()
  local new, n = text:gsub('\nicon_theme = "[^"\n]*"', '\nicon_theme = "' .. theme .. '"', 1)
  if n == 1 then
    f = assert(io.open(HYPRFM, "w"))
    f:write(new)
    f:close()
  end
end

local function restart_shell(theme)
  os.execute("qs kill -p " .. quote(SHELL) .. " >/dev/null 2>&1")
  local cmd = (theme and ("QS_ICON_THEME=" .. theme .. " ") or "") .. "quickshell -p " .. SHELL
  os.execute("hyprctl dispatch " .. quote('hl.dsp.exec_cmd("' .. cmd .. '")') .. " >/dev/null")
end

local arg1 = arg[1]
if not arg1 or arg1 == "list" then
  print("current: " .. current() .. (saved() and ("   (saved original: " .. saved() .. ")") or ""))
  for _, t in ipairs(CANDIDATES) do print((installed(t) and "  ok   " or "  --   ") .. t) end
elseif arg1 == "reset" then
  local orig = saved() or "Adwaita"
  os.execute("gsettings set org.gnome.desktop.interface icon-theme " .. quote(orig))
  set_hyprfm(orig)
  restart_shell(nil)
  os.remove(STATE)
  print("icon theme back to " .. orig)
else
  if not installed(arg1) then
    io.stderr:write("not installed: " .. arg1 .. "\n")
    os.exit(1)
  end
  if not saved() then
    local f = assert(io.open(STATE, "w"))
    f:write(current(), "\n")
    f:close()
  end
  os.execute("gsettings set org.gnome.desktop.interface icon-theme " .. quote(arg1))
  set_hyprfm(arg1)
  restart_shell(arg1)
  print("icon theme: " .. arg1 .. "   (lua try-theme.lua reset to go back)")
end
