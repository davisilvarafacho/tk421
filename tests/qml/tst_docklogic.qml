import QtQuick
import QtTest

import "../../dock/logic.js" as Logic

TestCase {
    name: "DockLogic"

    function test_parseStateDefaults() {
        const s = Logic.parseState("")
        compare(s.mode, "auto")
        compare(s.pinned, Logic.DEFAULT_PINNED)
        verify(s.pinned !== Logic.DEFAULT_PINNED, "a copy, not the shared default array")
    }

    function test_parseStateValues() {
        const s = Logic.parseState('{"pinned":["a","b","a","",3],"mode":"always"}')
        compare(s.pinned, ["a", "b"])
        compare(s.mode, "always")
        compare(Logic.parseState('{"mode":"sideways"}').mode, "auto")
        compare(Logic.parseState('{"pinned":[]}').pinned, [])
        compare(Logic.parseState("[1,2]").mode, "auto")
    }

    function test_roundTrip() {
        const s = Logic.parseState(Logic.serializeState(["x", "y"], "always"))
        compare(s.pinned, ["x", "y"])
        compare(s.mode, "always")
    }

    function test_ignored() {
        verify(Logic.ignored(""))
        verify(Logic.ignored(null))
        verify(Logic.ignored("com.tk421.widget.btop"))
        verify(!Logic.ignored("com.mitchellh.ghostty"))
    }

    function test_group() {
        const g = Logic.group(["term", "web", "files"], [
            { key: "web", ref: 1 }, { key: "obs", ref: 2 }, { key: "term", ref: 3 }, { key: "web", ref: 4 }, { key: "img", ref: 5 }
        ])
        compare(g.map(x => x.key), ["term", "web", "files", "obs", "img"])
        compare(g.map(x => x.pinned), [true, true, true, false, false])
        compare(g[1].wins, [1, 4])
        compare(g[2].wins, [])
        compare(g[3].wins, [2])
    }

    function test_togglePin() {
        compare(Logic.togglePin(["a", "b", "c"], "b"), ["a", "c"])
        compare(Logic.togglePin(["a"], "z"), ["a", "z"])
    }

    function test_magnify() {
        compare(Logic.magnify(0, 44, 2.4, 0.32), 1.32)
        compare(Logic.magnify(44 * 2.4, 44, 2.4, 0.32), 1)
        compare(Logic.magnify(500, 44, 2.4, 0.32), 1)
        fuzzyCompare(Logic.magnify(-44 * 1.2, 44, 2.4, 0.32), 1.16, 1e-9)
    }

    function test_nextWindow() {
        compare(Logic.nextWindow([]), -1)
        compare(Logic.nextWindow([false, false]), 0)
        compare(Logic.nextWindow([false, true]), 0)
        compare(Logic.nextWindow([true, false, false]), 1)
        compare(Logic.nextWindow([true]), 0)
    }

    function test_labels() {
        compare(Logic.windowCount(0), "Not running")
        compare(Logic.windowCount(1), "1 window")
        compare(Logic.windowCount(3), "3 windows")
        compare(Logic.closeLabel(1), "Close window")
        compare(Logic.closeLabel(2), "Close 2 windows")
    }
}
