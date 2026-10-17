-- Detail sample for the resource panel (CPU / RAM / GPU hover card); run while the panel is open.
-- Prints "key value" lines (temperatures in °C, power in W, clock in MHz, fan in RPM) and the busiest processes as
-- "top_cpu<TAB>name<TAB>percent of one thread" and "top_mem<TAB>name<TAB>GiB". Parsed by resources/logic.js (parseSample).
-- Takes about 0.5 s: process CPU time is measured over that interval.
-- With `--names` it also prints the raw model names ("cpu_name<TAB>..." and "gpu_name<TAB>..."), which do not change.

local TOP = 3
local INTERVAL = 0.5
local PAGE = 4096

local function read(path)
    local f = io.open(path)
    if not f then return nil end
    local s = f:read("a")
    f:close()
    return s
end

local function number(path)
    local s = read(path)
    return s and tonumber(s:match("^%s*(-?%d+)"))
end

local function list(dir)
    local out = {}
    local p = io.popen('ls "' .. dir .. '" 2>/dev/null')
    for line in p:lines() do out[#out + 1] = line end
    p:close()
    return out
end

local function emit(key, value)
    if value then print(key .. " " .. string.format("%g", value)) end
end

if arg[1] == "--names" then
    local model = (read("/proc/cpuinfo") or ""):match("model name%s*:%s*([^\n]+)")
    if model then print("cpu_name\t" .. model) end
end

-- CPU: package temperature from coretemp (Intel) or k10temp (AMD), and the mean clock of all threads.
for _, hw in ipairs(list("/sys/class/hwmon")) do
    local dir = "/sys/class/hwmon/" .. hw
    local name = (read(dir .. "/name") or ""):gsub("%s+$", "")
    if name == "coretemp" or name == "k10temp" then
        local t = number(dir .. "/temp1_input")
        emit("cpu_temp", t and t / 1000)
        break
    end
end

local mhz, n = 0, 0
for v in (read("/proc/cpuinfo") or ""):gmatch("cpu MHz%s*:%s*([%d.]+)") do
    mhz = mhz + tonumber(v)
    n = n + 1
end
if n > 0 then emit("cpu_mhz", mhz / n) end

-- GPU: the first drm card that reports its own busy percentage (amdgpu).
for _, card in ipairs(list("/sys/class/drm")) do
    if card:match("^card%d+$") and read("/sys/class/drm/" .. card .. "/device/gpu_busy_percent") then
        if arg[1] == "--names" then
            -- the PCI slot is the name of the device's directory, e.g. 0000:03:00.0
            local slot = io.popen('basename "$(readlink -f /sys/class/drm/' .. card .. '/device)"'):read("l")
            local line = slot and slot:match("^%w+:(%x+:%x+%.%x)$") and io.popen("lspci -s " .. slot:match("^%w+:(.+)$")):read("l")
            local desc = line and line:match("^%S+ [^:]+: (.+)$")
            if desc then print("gpu_name\t" .. desc) end
        end

        local base = "/sys/class/drm/" .. card .. "/device/hwmon/"
        local hw = list(base)[1]
        if hw then
            local dir = base .. hw
            local temp = number(dir .. "/temp1_input")
            local power = number(dir .. "/power1_average") or number(dir .. "/power1_input")
            local cap = number(dir .. "/power1_cap")
            emit("gpu_temp", temp and temp / 1000)
            emit("gpu_power", power and power / 1e6)
            emit("gpu_cap", cap and cap / 1e6)
            emit("gpu_fan", number(dir .. "/fan1_input"))
        end
        break
    end
end

-- Processes: CPU time from /proc/<pid>/stat over INTERVAL, resident memory from statm. Grouped by command name.
local function uptime()
    return tonumber((read("/proc/uptime") or "0"):match("^([%d.]+)"))
end

local function snapshot()
    local out = {}
    for _, pid in ipairs(list("/proc")) do
        if pid:match("^%d+$") then
            local stat = read("/proc/" .. pid .. "/stat")
            if stat then
                local comm, rest = stat:match("^%d+ %((.*)%) (.*)$")      -- comm may hold spaces and parentheses
                if comm then
                    local fields = {}
                    for f in rest:gmatch("%S+") do fields[#fields + 1] = f end
                    out[pid] = { name = comm, ticks = (tonumber(fields[12]) or 0) + (tonumber(fields[13]) or 0) }
                end
            end
        end
    end
    return out
end

local clk = tonumber(io.popen("getconf CLK_TCK"):read("l")) or 100
local t0, before = uptime(), snapshot()
os.execute("sleep " .. INTERVAL)
local t1, after = uptime(), snapshot()
local dt = math.max(t1 - t0, 0.01)

local cpu, mem = {}, {}
for pid, now in pairs(after) do
    local was = before[pid]
    if was then
        cpu[now.name] = (cpu[now.name] or 0) + (now.ticks - was.ticks) / clk / dt * 100
    end
    local statm = read("/proc/" .. pid .. "/statm")
    local pages = statm and tonumber(statm:match("^%d+ (%d+)"))
    if pages and pages > 0 then
        mem[now.name] = (mem[now.name] or 0) + pages * PAGE / 2 ^ 30
    end
end

local function top(tbl, label, fmt)
    local rows = {}
    for name, v in pairs(tbl) do rows[#rows + 1] = { name = name, v = v } end
    table.sort(rows, function(a, b) return a.v > b.v end)
    for i = 1, math.min(TOP, #rows) do
        print(label .. "\t" .. rows[i].name:gsub("[%c\t]", " ") .. "\t" .. string.format(fmt, rows[i].v))
    end
end

top(cpu, "top_cpu", "%.1f")
top(mem, "top_mem", "%.2f")
