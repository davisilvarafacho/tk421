import QtQuick
import QtTest

import "../../resources/logic.js" as Logic

TestCase {
    name: "ResourceLogic"

    function test_pushHistory_keeps_the_newest_samples() {
        let h = []
        for (let i = 1; i <= 5; i++)
            h = Logic.pushHistory(h, i, 3)
        compare(h.join(","), "3,4,5")
    }

    function test_pushHistory_does_not_mutate_the_input() {
        const a = [1, 2]
        Logic.pushHistory(a, 3, 10)
        compare(a.length, 2)
    }

    function test_parseCpuStat_without_previous_sample_is_zero() {
        const r = Logic.parseCpuStat("cpu  100 0 100 800 0 0 0 0 0 0\ncpu0 50 0 50 400 0 0 0 0 0 0\ncpu1 50 0 50 400 0 0 0 0 0 0\n", null)
        compare(r.cpu, 0)
        compare(r.cores.length, 2)
    }

    function test_parseCpuStat_percentages_from_two_samples() {
        const a = Logic.parseCpuStat("cpu  100 0 100 800 0 0 0 0 0 0\ncpu0 100 0 100 800 0 0 0 0 0 0\n", null)
        // +100 busy, +100 idle in the second sample: 50% load
        const b = Logic.parseCpuStat("cpu  150 0 150 900 0 0 0 0 0 0\ncpu0 150 0 150 900 0 0 0 0 0 0\n", a.state)
        compare(b.cpu, 50)
        compare(b.cores[0], 50)
    }

    function test_parseCpuStat_counts_iowait_as_idle() {
        const a = Logic.parseCpuStat("cpu  0 0 0 0 0 0 0 0 0 0\n", null)
        const b = Logic.parseCpuStat("cpu  0 0 0 50 50 0 0 0 0 0\n", a.state)
        compare(b.cpu, 0)
    }

    function test_parseMeminfo() {
        const t = "MemTotal:       33554432 kB\nMemFree:         4194304 kB\nMemAvailable:   25165824 kB\nBuffers:          524288 kB\nCached:          8388608 kB\nSReclaimable:     524288 kB\n"
        const m = Logic.parseMeminfo(t)
        compare(m.totalGiB, 32)
        compare(m.usedGiB, 8)
        compare(m.freeGiB, 4)
        compare(m.cacheGiB, 9)
        compare(m.percent, 25)
    }

    function test_parseMeminfo_without_a_total_is_null() {
        compare(Logic.parseMeminfo("nothing here"), null)
    }

    function test_parseSample() {
        const s = Logic.parseSample("cpu_temp 52.5\ncpu_mhz 3090\ngpu_temp 50\ngpu_power 17\ngpu_cap 145\ngpu_fan 0\n"
            + "top_cpu\tfirefox\t12.4\ntop_cpu\tquickshell\t3.1\ntop_mem\tfirefox\t2.1\n")
        compare(s.cpuTemp, 52.5)
        compare(s.gpuPower, 17)
        compare(s.gpuCap, 145)
        compare(s.gpuFan, 0)
        compare(s.topCpu.length, 2)
        compare(s.topCpu[0].name, "firefox")
        compare(s.topMem[0].value, 2.1)
    }

    function test_parseSample_ignores_garbage_and_keeps_names_with_spaces() {
        const s = Logic.parseSample("cpu_temp abc\nnonsense\ntop_cpu\tIsolated Web Co\t7\ntop_cpu\tbad\n")
        compare(s.cpuTemp, -1)
        compare(s.topCpu.length, 1)
        compare(s.topCpu[0].name, "Isolated Web Co")
    }

    function test_parseSample_names() {
        const s = Logic.parseSample("cpu_name\tIntel(R) Core(TM) i5-10400F CPU @ 2.90GHz\ngpu_name\tNavi 33 [Radeon RX 7600]\n")
        compare(s.cpuName, "Intel(R) Core(TM) i5-10400F CPU @ 2.90GHz")
        compare(s.gpuName, "Navi 33 [Radeon RX 7600]")
    }

    function test_shortCpuName() {
        compare(Logic.shortCpuName("Intel(R) Core(TM) i5-10400F CPU @ 2.90GHz"), "i5-10400F")
        compare(Logic.shortCpuName("AMD Ryzen 7 5800X 8-Core Processor"), "Ryzen 7 5800X")
        compare(Logic.shortCpuName(""), "")
    }

    function test_shortGpuName() {
        compare(Logic.shortGpuName("Advanced Micro Devices, Inc. [AMD/ATI] Navi 33 [Radeon RX 7600/7600 XT/7600M XT/7600S/7700S/Radeon PRO W7600] (rev c0)"), "RX 7600")
        compare(Logic.shortGpuName("NVIDIA Corporation GA106 [GeForce RTX 3060] (rev a1)"), "GeForce RTX 3060")
        compare(Logic.shortGpuName("Some Vendor Unknown Card"), "Some Vendor Unknown Card")
        compare(Logic.shortGpuName(""), "")
    }

    function test_gib() {
        compare(Logic.gib(2.123), "2.1 GiB")
        compare(Logic.gib(2.123, 2), "2.12 GiB")
    }
}
