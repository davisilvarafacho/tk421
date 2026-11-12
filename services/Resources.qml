pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

import "../resources/logic.js" as Logic

// CPU / RAM / GPU numbers for the hover panel (resources/ResourcePanel.qml) and their 60 s history.
// The cheap numbers (load, memory, GPU busy, VRAM) are read every second, always, so the graphs are full when the panel opens.
// Temperatures, clock, power, fan and the busiest processes come from resources/sample.lua, only while the panel is open.
// The capsule's own numbers still come from SystemStats (components used by bar/Bar.qml).
Singleton {
    id: root

    // Referenced from shell.qml so the history starts with the shell.
    readonly property bool active: true

    // Hover state: the capsule (bar/Bar.qml) and the panel keep it open; it closes 180 ms after the pointer leaves both.
    property bool capsuleHovered: false
    property bool panelHovered: false
    property bool open: false
    property bool watched: false        // the desktop widgets are showing: keep the detail sample running too

    property real cpu: 0
    property var cores: []
    property real ram: 0
    property real ramTotalGiB: 0
    property real ramUsedGiB: 0
    property real ramCacheGiB: 0
    property real ramFreeGiB: 0
    property real gpu: 0
    property real vram: 0
    property real vramUsedGiB: 0
    property real vramTotalGiB: 0

    property var cpuHistory: Array(Logic.SAMPLES).fill(0)
    property var ramHistory: Array(Logic.SAMPLES).fill(0)
    property var gpuHistory: Array(Logic.SAMPLES).fill(0)

    property string cpuName: ""         // short model names, read once (sample.lua --names)
    property string gpuName: ""
    property real cpuTemp: -1
    property real cpuMHz: 0
    property real gpuTemp: -1
    property real gpuPower: -1
    property real gpuCap: -1
    property real gpuFan: -1
    property var topCpu: []             // [{ name, value }]: percent of one thread
    property var topMem: []             // [{ name, value }]: GiB resident

    property var cpuState: null

    onCapsuleHoveredChanged: settle()
    onPanelHoveredChanged: settle()

    function settle() {
        if (capsuleHovered || panelHovered) {
            closeTimer.stop()
            open = true
        } else {
            closeTimer.restart()
        }
    }

    function refresh() {
        statFile.reload()
        statFile.waitForJob()
        memFile.reload()
        memFile.waitForJob()
        gpuFile.reload()
        gpuFile.waitForJob()
        vramUsedFile.reload()
        vramUsedFile.waitForJob()
        vramTotalFile.reload()
        vramTotalFile.waitForJob()

        const c = Logic.parseCpuStat(statFile.text(), cpuState)
        cpuState = c.state
        cpu = c.cpu
        cores = c.cores
        cpuHistory = Logic.pushHistory(cpuHistory, c.cpu)

        const m = Logic.parseMeminfo(memFile.text())
        if (m) {
            ram = m.percent
            ramTotalGiB = m.totalGiB
            ramUsedGiB = m.usedGiB
            ramCacheGiB = m.cacheGiB
            ramFreeGiB = m.freeGiB
        }
        ramHistory = Logic.pushHistory(ramHistory, ram)

        const busy = Number(gpuFile.text().trim())
        if (Number.isFinite(busy))
            gpu = Math.max(0, Math.min(100, busy))
        const used = Number(vramUsedFile.text().trim())
        const total = Number(vramTotalFile.text().trim())
        if (total > 0) {
            vramUsedGiB = used / 1073741824
            vramTotalGiB = total / 1073741824
            vram = 100 * used / total
        }
        gpuHistory = Logic.pushHistory(gpuHistory, gpu)
    }

    function applySample(s) {
        if (s.cpuName !== "")
            cpuName = Logic.shortCpuName(s.cpuName)
        if (s.gpuName !== "")
            gpuName = Logic.shortGpuName(s.gpuName)
        cpuTemp = s.cpuTemp
        cpuMHz = s.cpuMHz
        gpuTemp = s.gpuTemp
        gpuPower = s.gpuPower
        gpuCap = s.gpuCap
        gpuFan = s.gpuFan
        topCpu = s.topCpu
        topMem = s.topMem
    }

    FileView {
        id: statFile
        path: "/proc/stat"
        blockLoading: true
    }

    FileView {
        id: memFile
        path: "/proc/meminfo"
        blockLoading: true
    }

    FileView {
        id: gpuFile
        path: "/sys/class/drm/card1/device/gpu_busy_percent"      // same card as SystemStats
        blockLoading: true
    }

    FileView {
        id: vramUsedFile
        path: "/sys/class/drm/card1/device/mem_info_vram_used"
        blockLoading: true
    }

    FileView {
        id: vramTotalFile
        path: "/sys/class/drm/card1/device/mem_info_vram_total"
        blockLoading: true
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Timer {
        id: closeTimer
        interval: 180
        onTriggered: root.open = false
    }

    // The detail sample takes about half a second, so a new one only starts when the last one has finished.
    Timer {
        interval: 2000
        repeat: true
        running: root.open || root.watched
        triggeredOnStart: true
        onTriggered: if (!sampler.running) sampler.running = true
    }

    Process {
        id: sampler

        // The model names never change: only the first samples ask for them.
        command: ["lua", Quickshell.shellPath("resources/sample.lua")].concat(root.cpuName === "" || root.gpuName === "" ? ["--names"] : [])

        stdout: StdioCollector {
            onStreamFinished: root.applySample(Logic.parseSample(text))
        }
    }
}
