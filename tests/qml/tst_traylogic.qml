import QtQuick
import QtTest

import "../../bar/trayLogic.js" as Tray

TestCase {
    name: "TrayLogic"

    function mk(spec) {                       // "a" active, "p" passive, "!" needs attention (e.g. "a!p")
        const out = []
        let id = 0
        for (let i = 0; i < spec.length; i++) {
            const ch = spec[i]
            if (ch === "!") { out[out.length - 1].attention = true; continue }
            out.push({ id: "i" + (id++), passive: ch === "p", attention: false })
        }
        return out
    }

    function ids(list) {
        return list.map(i => i.id).join(",")
    }

    // ---- partition ----
    function test_partition_empty() {
        const r = Tray.partition([], 3)
        compare(r.visible.length, 0)
        compare(r.overflow.length, 0)
        compare(r.overflowAttention, false)
    }

    function test_partition_fits() {
        const r = Tray.partition(mk("aaa"), 3)
        compare(ids(r.visible), "i0,i1,i2")
        compare(r.overflow.length, 0)
    }

    function test_partition_overflow_keeps_order() {
        const r = Tray.partition(mk("aaaaa"), 3)
        compare(ids(r.visible), "i0,i1,i2")
        compare(ids(r.overflow), "i3,i4")
    }

    function test_passive_items_always_go_behind_the_chevron() {
        const r = Tray.partition(mk("apa"), 3)
        compare(ids(r.visible), "i0,i2")
        compare(ids(r.overflow), "i1")
    }

    function test_overflow_lists_extra_active_before_passive() {
        const r = Tray.partition(mk("papaaa"), 2)
        compare(ids(r.visible), "i1,i3")
        compare(ids(r.overflow), "i4,i5,i0,i2")
    }

    function test_overflow_attention_flag() {
        compare(Tray.partition(mk("aaaa!"), 3).overflowAttention, true)
        compare(Tray.partition(mk("a!aa"), 3).overflowAttention, false)
        compare(Tray.partition(mk("aap!"), 3).overflowAttention, true)          // a passive item that asks for attention
    }

    // ---- cleanLabel ----
    function test_cleanLabel_basic() {
        compare(Tray.cleanLabel("Discord", 40), "Discord")
        compare(Tray.cleanLabel("", 40), "")
        compare(Tray.cleanLabel(null, 40), "")
        compare(Tray.cleanLabel(undefined, 40), "")
    }

    function test_cleanLabel_removes_control_and_bidi_characters() {
        compare(Tray.cleanLabel("a\u202Eb\u0000c\u2066d", 40), "abcd")
    }

    function test_cleanLabel_collapses_newlines_and_trims() {
        compare(Tray.cleanLabel("  one\n\ntwo  ", 40), "one two")
    }

    function test_cleanLabel_clips_without_splitting_an_emoji() {
        const e = "\uD83D\uDE00"
        compare(Tray.cleanLabel(e + e + e, 4), e + "\u2026")
        compare(Tray.cleanLabel("abcdefghij", 5), "abcd\u2026")
    }

    // ---- limitEntries ----
    function sep() { return { separator: true } }
    function ent(t) { return { separator: false, text: t } }
    function shape(list) { return list.map(e => e.separator ? "-" : e.text).join(",") }

    function test_limitEntries_drops_edge_and_double_separators() {
        compare(shape(Tray.limitEntries([sep(), ent("a"), sep(), sep(), ent("b"), sep()], 40)), "a,-,b")
    }

    function test_limitEntries_only_separators_is_empty() {
        compare(Tray.limitEntries([sep(), sep()], 40).length, 0)
    }

    function test_limitEntries_caps_the_count() {
        const many = []
        for (let i = 0; i < 100; i++)
            many.push(ent("e" + i))
        compare(Tray.limitEntries(many, 40).length, 40)
    }

    function test_limitEntries_cap_never_ends_on_a_separator() {
        const l = [ent("a"), sep(), ent("b"), sep(), ent("c")]
        compare(shape(Tray.limitEntries(l, 2)), "a")                              // "a,-" would end on a separator
    }

    // ---- overrideFor ----
    function test_overrideFor_known_apps() {
        compare(Tray.overrideFor("spotify-client"), "spotify.svg")
        compare(Tray.overrideFor("TelegramDesktop"), "telegram.svg")
        compare(Tray.overrideFor("github-desktop"), "github.svg")
    }

    function test_overrideFor_unknown_or_missing_is_empty() {
        compare(Tray.overrideFor("unknown-app"), "")
        compare(Tray.overrideFor(""), "")
        compare(Tray.overrideFor(undefined), "")
        compare(Tray.overrideFor(null), "")
    }

    function test_overrideFor_ignores_inherited_object_keys() {
        compare(Tray.overrideFor("toString"), "")
        compare(Tray.overrideFor("__proto__"), "")
    }
}
