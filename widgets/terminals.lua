-- Terminal widgets of the desktop-widget workspace: btop and lavat in their own Ghostty processes.
-- Each gets its own window class; the "tk421-widget-*" window rules in hypr/hyprland.lua float it, size and place it
-- next to the QML widgets (widgets/DesktopWidgets.qml) and send it to workspace 6 without switching there.
-- Idempotent: a widget whose class already has a window is skipped. Run from `hyprland.start`.
--   lua widgets/terminals.lua            open the missing ones
--   lua widgets/terminals.lua --dry-run  print the commands instead

local dir = "/home/tk421/.config/quickshell/widgets"
local dry = arg[1] == "--dry-run"

-- Ghostty: own process (a class is per process), opaque ink, no decorations, the panels' inner padding.
local function ghostty(class, fontSize, padX, command)
	return table.concat({
		"ghostty",
		"--gtk-single-instance=false",
		"--class=" .. class,
		"--background=#000000",
		"--background-opacity=1",
		"--window-decoration=none",
		"--window-padding-x=" .. padX,
		"--window-padding-y=12",
		"--font-size=" .. fontSize,
		"--confirm-close-surface=false",
		"-e",
		command,
	}, " ")
end

local widgets = {
	-- btop needs 80 columns: font 7 with 10 px padding fits them in the 540 px window
	{ class = "com.tk421.widget.btop", font = 7, pad = 10, command = "btop --config " .. dir .. "/btop.conf" },
	-- gradient mode (-k is the core, -c the rim): bright steel core fading to graphite, slow, eight small balls (the window is only ~55x17 cells)
	{ class = "com.tk421.widget.lavat", font = 8, pad = 14, command = "lavat -g -c 2C2C33 -k E8E6E3 -s 2 -r 2 -b 8" },
}

local function read(cmd)
	local p = io.popen(cmd)
	if not p then
		return ""
	end
	local out = p:read("*a") or ""
	p:close()
	return out
end

local clients = read("hyprctl clients -j 2>/dev/null")

for _, w in ipairs(widgets) do
	local pattern = '"class":%s*"' .. w.class:gsub("%.", "%%.") .. '"'
	if clients:find(pattern) then
		print("skip " .. w.class .. " (already open)")
	else
		local cmd = ghostty(w.class, w.font, w.pad, w.command)
		if dry then
			print(cmd)
		else
			os.execute("setsid -f " .. cmd .. " >/dev/null 2>&1")
			print("open " .. w.class)
		end
	end
end
