-- Lock screen backdrop: one screenshot per output, taken just before the session locks.
-- Run as: lua lock/capture.lua <dir> <output>...   (writes <dir>/<output>.png, dir is created with mode 700)
-- Exit status 0 only if every output was captured; the lock screen falls back to the wallpaper otherwise.

local dir = arg[1]

if not dir or not dir:match("^[%w%-_./]+$") then
    io.stderr:write("usage: capture.lua <dir> <output>...\n")
    os.exit(1)
end

-- dir and the output names only hold characters that are safe in a shell command (checked here).
os.execute("mkdir -p -m 700 " .. dir)

local ok = true
for i = 2, #arg do
    local name = arg[i]
    if name:match("^[%w%-_.:]+$") then
        if not os.execute("timeout 2 grim -o " .. name .. " " .. dir .. "/" .. name .. ".png") then
            ok = false
        end
    else
        ok = false
    end
end

os.exit(ok and 0 or 1)
