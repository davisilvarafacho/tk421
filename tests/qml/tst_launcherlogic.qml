import QtQuick
import QtTest

import "../../launcher/logic.js" as L

TestCase {
    name: "LauncherLogic"

    function test_parse_modes() {
        compare(L.parse(""), { mode: "apps", body: "" })
        compare(L.parse("  vi "), { mode: "apps", body: "vi" })
        compare(L.parse("=12*7"), { mode: "calc", body: "12*7" })
        compare(L.parse("> lock"), { mode: "shell", body: "lock" })
        compare(L.parse("@gh"), { mode: "windows", body: "gh" })
        compare(L.parse(" =1"), { mode: "apps", body: "=1" })      // the prefix only counts as the first character
    }

    function test_togglePrefix() {
        compare(L.togglePrefix("vi", "="), "=vi")
        compare(L.togglePrefix("=vi", "="), "vi")
        compare(L.togglePrefix(">vi", "@"), "@vi")
    }

    function test_calc() {
        compare(L.calc("12*7+3"), 87)
        compare(L.calc("2^3^2"), 512)
        compare(L.calc("(1+2)*3"), 9)
        compare(L.calc("15% * 240"), 36)
        compare(L.calc("-4 + 10"), 6)
        compare(L.calc("1,5*2"), 3)
        compare(L.calc("6 × 7 ÷ 2"), 21)
        compare(L.calc("0.1+0.2"), 0.3)
        compare(L.calc(""), null)
        compare(L.calc("1+"), null)
        compare(L.calc("1/0"), null)
        compare(L.calc("alert(1)"), null)
        compare(L.calc("(1+2"), null)
    }

    function test_formatNumber() {
        compare(L.formatNumber(87), "87")
        compare(L.formatNumber(1234567.5), "1,234,567.5")
        compare(L.formatNumber(-0.25), "-0.25")
    }

    function test_ago() {
        const now = 1000000000000
        compare(L.ago(now - 30e3, now), "now")
        compare(L.ago(now - 12 * 60e3, now), "12m")
        compare(L.ago(now - 5 * 3600e3, now), "5h")
        compare(L.ago(now - 30 * 3600e3, now), "yesterday")
        compare(L.ago(now - 9 * 86400e3, now), "9d")
        compare(L.ago(0, now), "")
        compare(L.agoLong(now - 3 * 60e3, now), "3 min ago")
        compare(L.agoLong(now - 2 * 3600e3, now), "2 h ago")
        compare(L.agoLong(now - 4 * 86400e3, now), "4 days ago")
        compare(L.agoLong(now - 30e3, now), "just now")
        compare(L.agoLong(now - 30 * 3600e3, now), "yesterday")
    }

    function test_isoFor() {
        compare(L.isoFor(["System", "TerminalEmulator"]), "desktop")
        compare(L.isoFor(["Network", "WebBrowser"]), "cloud")
        compare(L.isoFor(["TextEditor", "Development", "IDE"]), "laptop")
        compare(L.isoFor(["Chat", "Network", "InstantMessaging"]), "speech")
        compare(L.isoFor(["Game"]), "pyramid")
        compare(L.isoFor(["Utility", "Development"]), "function-module")
        compare(L.isoFor([]), "cube")
        compare(L.isoFor(undefined), "cube")
    }

    function test_boost_breaks_ties_but_not_match_quality() {
        compare(L.boost(0), 0)
        verify(L.boost(400) > L.boost(10))
        verify(L.boost(10000) < 300)      // a heavy user never beats a substring match with a subsequence one
    }

    function test_frequent_and_recent() {
        const hist = { a: { hits: 5, last: 10 }, b: { hits: 9, last: 5 }, c: { hits: 1, last: 50 }, d: { hits: 2, last: 40 } }
        const ids = ["a", "b", "c", "d", "e"]
        compare(L.frequent(ids, hist, 2), ["b", "a"])
        compare(L.recent(ids, hist, ["b", "a"], 3), ["c", "d"])
        compare(L.frequent(ids, {}, 2), [])
    }

    function test_record() {
        const h = L.record({}, "vivaldi", 100)
        compare(h, { vivaldi: { hits: 1, last: 100 } })
        compare(L.record(h, "vivaldi", 200), { vivaldi: { hits: 2, last: 200 } })
        compare(L.record({ x: { hits: 1, last: 1 } }, "", 5), { x: { hits: 1, last: 1 } })
    }

    function test_commands_are_complete() {
        for (const c of L.COMMANDS) {
            verify(c.id && c.name && c.hint && c.text && c.icon && c.iso, c.id)
        }
        compare(L.COMMANDS.filter(c => c.asks).map(c => c.id), ["logout", "reboot", "poweroff"])
    }
}
