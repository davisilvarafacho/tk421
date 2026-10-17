
import QtQuick
import Quickshell.Io

Item {
    id: root

    visible: false
    width: 0
    height: 0

    property real cpuPercent: 0
    property real ramPercent: 0
    property real gpuPercent: 0
    property real vramPercent: 0

    property double previousTotal: 0
    property double previousIdle: 0
    property bool hasPreviousCpuSample: false

    FileView {
        id: cpuFile
        path: "/proc/stat"
        blockLoading: true
    }

    FileView {
        id: memoryFile
        path: "/proc/meminfo"
        blockLoading: true
    }

    FileView {
        id: gpuFile
        path: "/sys/class/drm/card1/device/gpu_busy_percent"
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

    function refresh() {
        cpuFile.reload()
        cpuFile.waitForJob()

        memoryFile.reload()
        memoryFile.waitForJob()

        gpuFile.reload()
        gpuFile.waitForJob()

        vramUsedFile.reload()
        vramUsedFile.waitForJob()

        vramTotalFile.reload()
        vramTotalFile.waitForJob()

        updateCpu()
        updateMemory()
        updateGpu()
    }

    function updateCpu() {
        var lines = cpuFile.text().split("\n")
        var fields = lines[0].trim().split(/\s+/)

        if (fields.length < 5)
            return

        var total = 0

        for (var i = 1; i < fields.length; i++)
            total += Number(fields[i])

        var idle = Number(fields[4]) + Number(fields[5] || 0)

        if (hasPreviousCpuSample) {
            var totalDelta = total - previousTotal
            var idleDelta = idle - previousIdle

            if (totalDelta > 0) {
                cpuPercent = Math.max(
                    0,
                    Math.min(
                        100,
                        100 * (totalDelta - idleDelta) / totalDelta
                    )
                )
            }
        }

        previousTotal = total
        previousIdle = idle
        hasPreviousCpuSample = true
    }

    function updateMemory() {
        var contents = memoryFile.text()

        var totalMatch = contents.match(/^MemTotal:\s+(\d+)/m)
        var availableMatch = contents.match(/^MemAvailable:\s+(\d+)/m)

        if (!totalMatch || !availableMatch)
            return

        var total = Number(totalMatch[1])
        var available = Number(availableMatch[1])

        if (total > 0)
            ramPercent = 100 * (total - available) / total
    }

    function updateGpu() {
        var gpu = Number(gpuFile.text().trim())
        var used = Number(vramUsedFile.text().trim())
        var total = Number(vramTotalFile.text().trim())

        if (Number.isFinite(gpu))
            gpuPercent = Math.max(0, Math.min(100, gpu))

        if (total > 0)
            vramPercent = 100 * used / total
        
    }

    Component.onCompleted: {
        refresh()
        refreshTimer.start()
    }

    Timer {
        id: refreshTimer
        interval: 1000
        repeat: true
        onTriggered: root.refresh()
    }
}
