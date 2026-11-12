import QtQuick
import QtTest

import "../../notifications/logic.js" as Logic

TestCase {
    name: "NotificationLogic"

    // Monday 12 Oct 2026, 14:00 local time.
    readonly property double now: new Date(2026, 9, 12, 14, 0, 0).getTime()

    function at(day, hour, minute) {
        return new Date(2026, 9, day, hour, minute, 0).getTime()
    }

    function policy(over) {
        const base = { centerOpen: false, islandOpen: false, dnd: false, urgency: "normal", transient: false }
        for (const k in over)
            base[k] = over[k]
        return Logic.arrivalPolicy(base)
    }

    // ---- clean / clip ----
    function test_clean_handles_null_and_undefined() {
        compare(Logic.clean(null), "")
        compare(Logic.clean(undefined), "")
    }

    function test_clean_strips_control_and_bidi_characters() {
        compare(Logic.clean("a‮b\u0000c⁦d⁩e"), "abcde")
    }

    function test_clean_keeps_newline_and_tab() {
        compare(Logic.clean("a\nb\tc"), "a\nb\tc")
    }

    function test_clip_short_text_unchanged() {
        compare(Logic.clip("hello", 10), "hello")
    }

    function test_clip_truncates_with_ellipsis() {
        compare(Logic.clip("abcdefghij", 5), "abcd…")
    }

    function test_clip_never_splits_surrogate_pair() {
        const e = "😀"                      // one emoji, two UTF-16 units
        compare(Logic.clip(e + e + e, 4), e + "…")
        compare(Logic.clip(e + e + e, 5), e + e + "…")
    }

    function test_clip_tiny_limit() {
        compare(Logic.clip("abc", 1), "…")
    }

    // ---- titleOf ----
    function test_titleOf_uses_summary() {
        compare(Logic.titleOf("Build finished", "Ghostty"), "Build finished")
    }

    function test_titleOf_falls_back_to_app_name() {
        compare(Logic.titleOf("", "Ghostty"), "Ghostty")
        compare(Logic.titleOf("  \n ", "Ghostty"), "Ghostty")
    }

    function test_titleOf_falls_back_to_generic() {
        compare(Logic.titleOf("", ""), "Notification")
        compare(Logic.titleOf(undefined, null), "Notification")
    }

    function test_titleOf_collapses_newlines() {
        compare(Logic.titleOf("one\n\ntwo", "x"), "one two")
    }

    function test_titleOf_clips_to_limit() {
        compare(Logic.titleOf("x".repeat(500), "a").length, Logic.LIMITS.summary)
    }

    // ---- iconSource ----
    function test_iconSource_none() {
        compare(Logic.iconSource("").kind, "none")
        compare(Logic.iconSource(undefined).kind, "none")
        compare(Logic.iconSource(null).kind, "none")
    }

    function test_iconSource_name() {
        compare(Logic.iconSource("firefox").kind, "name")
        compare(Logic.iconSource("org.mozilla.firefox").value, "org.mozilla.firefox")
        compare(Logic.iconSource("  firefox  ").value, "firefox")
    }

    function test_iconSource_absolute_path() {
        const s = Logic.iconSource("/usr/share/icons/x.png")
        compare(s.kind, "path")
        compare(s.value, "/usr/share/icons/x.png")
    }

    function test_iconSource_rejects_any_url_scheme() {
        const bad = ["http://evil/x.png", "https://evil/x.png", "file:///etc/passwd",
                     "data:image/png;base64,AAAA", "image://icon/x", "ftp://h/x"]
        for (let i = 0; i < bad.length; i++)
            compare(Logic.iconSource(bad[i]).kind, "none", bad[i])
    }

    // ---- pickActions ----
    function test_pickActions_null_is_empty() {
        compare(Logic.pickActions(null).length, 0)
        compare(Logic.pickActions(undefined).length, 0)
    }

    function test_pickActions_skips_default_and_blank() {
        const out = Logic.pickActions([
            { identifier: "default", text: "Open" },
            { identifier: "a", text: "   " },
            { identifier: "join", text: "Join" }
        ])
        compare(out.length, 1)
        compare(out[0].identifier, "join")
        compare(out[0].index, 2)                     // index into the original list, used to invoke it
    }

    function test_pickActions_limits_to_three() {
        const raw = []
        for (let i = 0; i < 6; i++)
            raw.push({ identifier: "a" + i, text: "A" + i })
        const out = Logic.pickActions(raw)
        compare(out.length, 3)
        compare(out[2].index, 2)
    }

    function test_pickActions_clips_text() {
        const out = Logic.pickActions([{ identifier: "a", text: "x".repeat(100) }])
        compare(out[0].text.length, Logic.LIMITS.actionText)
    }

    // ---- appLabel ----
    function test_appLabel_plain_app_keeps_its_name() {
        const l = Logic.appLabel("Ghostty", "com.mitchellh.ghostty", "Build finished")
        compare(l.name, "Ghostty")
        compare(l.asset, "")
    }

    function test_appLabel_claude_code_by_title() {
        const l = Logic.appLabel("", "com.mitchellh.ghostty", "Claude Code")
        compare(l.name, "Claude Code")
        compare(l.asset, "claude")
    }

    function test_appLabel_claude_by_app_name() {
        compare(Logic.appLabel("claude", "", "anything").asset, "claude")
    }

    function test_appLabel_a_title_that_merely_mentions_claude_is_not_claude_code() {
        compare(Logic.appLabel("Chat", "", "Is Claude Code any good?").asset, "")
    }

    function test_appLabel_empty_name_falls_back_to_the_desktop_entry_then_system() {
        compare(Logic.appLabel("", "org.kde.dolphin", "x").name, "dolphin")
        compare(Logic.appLabel("", "", "x").name, "System")
        compare(Logic.appLabel(null, undefined, "x").name, "System")
    }

    // ---- relativeTime ----
    function test_relativeTime_now() {
        compare(Logic.relativeTime(now - 10000, now), "NOW")
        compare(Logic.relativeTime(now - 44000, now), "NOW")
    }

    function test_relativeTime_future_timestamp_is_now() {
        compare(Logic.relativeTime(now + 600000, now), "NOW")
    }

    function test_relativeTime_minutes() {
        compare(Logic.relativeTime(now - 45000, now), "1M")
        compare(Logic.relativeTime(now - 38 * 60000, now), "38M")
        compare(Logic.relativeTime(now - 3599000, now), "59M")
    }

    function test_relativeTime_hours_today() {
        compare(Logic.relativeTime(now - 2 * 3600000, now), "2H")
        compare(Logic.relativeTime(at(12, 0, 0), now), "14H")
    }

    function test_relativeTime_before_today_is_clock_time() {
        compare(Logic.relativeTime(at(11, 21, 30), now), "21:30")
        compare(Logic.relativeTime(at(12, 0, 0) - 60000, now), "23:59")
    }

    // ---- dayLabel ----
    function test_dayLabel() {
        compare(Logic.dayLabel(at(12, 9, 0), now), "Today")
        compare(Logic.dayLabel(at(11, 21, 30), now), "Yesterday")
        compare(Logic.dayLabel(at(9, 12, 0), now), "Fri 9 Oct")
    }

    // ---- badgeText ----
    function test_badgeText() {
        compare(Logic.badgeText(0), "")
        compare(Logic.badgeText(-3), "")
        compare(Logic.badgeText(1), "1")
        compare(Logic.badgeText(9), "9")
        compare(Logic.badgeText(10), "9+")
        compare(Logic.badgeText(99), "9+")
    }

    // ---- arrivalPolicy (the table in the spec) ----
    function test_policy_normal() {
        const p = policy({})
        verify(p.toast); verify(p.ping); verify(p.history)
    }

    function test_policy_center_open_is_silent_but_kept() {
        const p = policy({ centerOpen: true })
        verify(!p.toast); verify(!p.ping); verify(p.history)
    }

    function test_policy_island_open_pings_without_popup() {
        const p = policy({ islandOpen: true })
        verify(!p.toast); verify(p.ping); verify(p.history)
    }

    function test_policy_low_is_history_only() {
        const p = policy({ urgency: "low" })
        verify(!p.toast); verify(!p.ping); verify(p.history)
    }

    function test_policy_low_never_pings_even_when_island_open() {
        verify(!policy({ urgency: "low", islandOpen: true }).ping)
    }

    function test_policy_dnd_mutes_normal_but_pings() {
        const p = policy({ dnd: true })
        verify(!p.toast); verify(p.ping); verify(p.history)
    }

    function test_policy_dnd_does_not_mute_critical() {
        const p = policy({ dnd: true, urgency: "critical" })
        verify(p.toast); verify(p.ping)
    }

    function test_policy_critical_still_yields_to_open_centre() {
        verify(!policy({ urgency: "critical", centerOpen: true }).toast)
    }

    function test_policy_transient_pops_but_is_not_kept() {
        const p = policy({ transient: true })
        verify(p.toast); verify(!p.history)
    }

    function test_policy_transient_under_dnd_vanishes() {
        const p = policy({ transient: true, dnd: true })
        verify(!p.toast); verify(!p.history)
    }

    // ---- conversations ----
    function note(label, summary, ts, critical) {
        return { label: label, appName: label, summary: summary, timestamp: ts, critical: critical === true }
    }

    function test_conversations_fold_same_app_and_title() {
        const a1 = note("Telegram", "jacaré", at(12, 13, 59))
        const b = note("Telegram", "# dev", at(12, 13, 58))
        const a2 = note("Telegram", "jacaré", at(12, 13, 50))
        const g = Logic.conversations([a1, b, a2], now)
        compare(g.length, 2)
        compare(g[0].entries.length, 2)
        verify(g[0].entries[0] === a1)
        verify(g[0].entries[1] === a2)
        compare(g[1].entries.length, 1)
    }

    function test_conversations_same_title_other_app_stays_apart() {
        const g = Logic.conversations([note("Telegram", "Ana", at(12, 13, 0)), note("Discord", "Ana", at(12, 12, 0))], now)
        compare(g.length, 2)
    }

    function test_conversations_critical_first() {
        const g = Logic.conversations([note("Chat", "new", at(12, 13, 59)), note("System", "Disk", at(12, 9, 0), true)], now)
        compare(g[0].key, "System\u0000Disk")
        compare(g[0].section, "Priority alpha")
        compare(g[1].section, "Today")
    }

    function test_conversations_sections() {
        const g = Logic.conversations([
            note("A", "x", at(12, 13, 0)), note("B", "y", at(12, 8, 0)), note("C", "z", at(11, 20, 0))
        ], now)
        verify(g[0].newSection); compare(g[0].section, "Today")
        verify(!g[1].newSection)
        verify(g[2].newSection); compare(g[2].section, "Yesterday")
    }

    function test_conversations_empty() {
        compare(Logic.conversations([], now).length, 0)
    }
}
