.pragma library

// Pure rules of the resource panel (CPU / RAM / GPU hover card). Prototype: prototypes/resources/index.html

var SAMPLES = 60            // history length: one sample per second

function clamp(v) {
    return Math.max(0, Math.min(100, v))
}

function pushHistory(list, value, n) {
    var out = list.slice()
    out.push(value)
    while (out.length > (n || SAMPLES))
        out.shift()
    return out
}

// text: /proc/stat. prev: the `state` of the previous call, or null.
// Returns { cpu, cores: [percent per thread], state }. Without a previous sample every value is 0.
function parseCpuStat(text, prev) {
    var total = []
    var idle = []
    var lines = String(text).split("\n")

    for (var i = 0; i < lines.length; i++) {
        if (!/^cpu\d*\s/.test(lines[i]))
            continue
        var f = lines[i].trim().split(/\s+/).slice(1).map(Number)
        var sum = 0
        for (var k = 0; k < Math.min(f.length, 8); k++)         // user nice system idle iowait irq softirq steal (guest is already in user)
            sum += f[k]
        total.push(sum)
        idle.push((f[3] || 0) + (f[4] || 0))
    }

    var pct = []
    for (var j = 0; j < total.length; j++) {
        if (prev && prev.total[j] !== undefined) {
            var dt = total[j] - prev.total[j]
            var di = idle[j] - prev.idle[j]
            pct.push(dt > 0 ? clamp(100 * (dt - di) / dt) : 0)
        } else {
            pct.push(0)
        }
    }

    return { cpu: pct.length ? pct[0] : 0, cores: pct.slice(1), state: { total: total, idle: idle } }
}

// text: /proc/meminfo. Sizes in GiB. used = total - available; cache = buffers + page cache + reclaimable slab.
function parseMeminfo(text) {
    var kb = {}
    var re = /^(\w+):\s+(\d+)/gm
    var m
    while ((m = re.exec(String(text))) !== null)
        kb[m[1]] = Number(m[2])

    var gib = function (key) { return (kb[key] || 0) / 1048576 }
    var total = gib("MemTotal")
    if (total <= 0)
        return null

    var used = total - gib("MemAvailable")
    return {
        totalGiB: total,
        usedGiB: used,
        cacheGiB: gib("Buffers") + gib("Cached") + gib("SReclaimable"),
        freeGiB: gib("MemFree"),
        percent: clamp(100 * used / total)
    }
}

// text: the stdout of resources/sample.lua: "key value" lines and "top_cpu<TAB>name<TAB>value" / "top_mem<TAB>name<TAB>value".
function parseSample(text) {
    var out = { cpuName: "", gpuName: "", cpuTemp: -1, cpuMHz: 0, gpuTemp: -1, gpuPower: -1, gpuCap: -1, gpuFan: -1, topCpu: [], topMem: [] }
    var keys = { cpu_temp: "cpuTemp", cpu_mhz: "cpuMHz", gpu_temp: "gpuTemp", gpu_power: "gpuPower", gpu_cap: "gpuCap", gpu_fan: "gpuFan" }
    var lines = String(text).split("\n")

    for (var i = 0; i < lines.length; i++) {
        var parts = lines[i].split("\t")
        if ((parts[0] === "cpu_name" || parts[0] === "gpu_name") && parts.length === 2) {
            out[parts[0] === "cpu_name" ? "cpuName" : "gpuName"] = parts[1]
            continue
        }
        if (parts[0] === "top_cpu" || parts[0] === "top_mem") {
            var v = Number(parts[2])
            if (parts.length === 3 && isFinite(v))
                (parts[0] === "top_cpu" ? out.topCpu : out.topMem).push({ name: parts[1], value: v })
            continue
        }
        var kv = lines[i].split(" ")
        if (kv.length === 2 && keys[kv[0]] !== undefined && isFinite(Number(kv[1])))
            out[keys[kv[0]]] = Number(kv[1])
    }
    return out
}

// "Intel(R) Core(TM) i5-10400F CPU @ 2.90GHz" -> "i5-10400F"; "AMD Ryzen 7 5800X 8-Core Processor" -> "Ryzen 7 5800X".
function shortCpuName(raw) {
    return String(raw || "")
        .replace(/\((R|TM)\)/gi, "")
        .replace(/@.*$/, "")
        .replace(/\b\d+-Core\b/i, "")
        .replace(/\bwith Radeon Graphics\b/i, "")
        .replace(/\b(Intel|AMD|Core|CPU|Processor)\b/gi, "")
        .replace(/\s+/g, " ")
        .trim()
}

// The lspci description of the card, e.g. "Advanced Micro Devices, Inc. [AMD/ATI] Navi 33 [Radeon RX 7600/7600 XT/7600M XT] (rev c0)"
// -> "RX 7600": the first name inside the last bracket group, without the "Radeon " prefix.
function shortGpuName(raw) {
    var s = String(raw || "").replace(/\(rev [^)]*\)/i, "").trim()
    var groups = s.match(/\[[^\]]*\]/g)
    var name = groups ? groups[groups.length - 1].slice(1, -1).split("/")[0] : s
    return name.replace(/^Radeon\s+/i, "").replace(/\s+/g, " ").trim()
}

function gib(v, digits) {
    return v.toFixed(digits === undefined ? 1 : digits) + " GiB"
}
