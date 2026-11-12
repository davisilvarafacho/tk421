import QtQuick
import QtTest

import "../../widgets/logic.js" as Logic

TestCase {
    name: "WidgetLogic"

    // Thursday 12 November 2026, 14:32 local time
    readonly property double now: new Date(2026, 10, 12, 14, 32, 0).getTime()

    function test_isoWeek() {
        compare(Logic.isoWeek(new Date(2026, 10, 12)), 46)
        compare(Logic.isoWeek(new Date(2027, 0, 1)), 53)
        compare(Logic.isoWeek(new Date(2026, 0, 1)), 1)
    }

    function test_dateLine() {
        compare(Logic.dateLine(new Date(now)), "Thursday, 12 November")
    }

    function test_uptime() {
        compare(Logic.uptime(3 * 86400 + 14 * 3600 + 59), "up 3 d 14 h")
        compare(Logic.uptime(5 * 3600 + 12 * 60), "up 5 h 12 min")
        compare(Logic.uptime(7 * 60 + 30), "up 7 min")
    }

    function test_inMinutes() {
        compare(Logic.inMinutes(0.5), "now")
        compare(Logic.inMinutes(28), "in 28 min")
        compare(Logic.inMinutes(125), "in 2 h 5 min")
        compare(Logic.inMinutes(180), "in 3 h")
    }

    function ev(date, time, title, sub) {
        return { date: date, allday: time === "All day", time: time, title: title, sub: sub || "", calendar: "c" }
    }

    function test_agendaDays_marks_done_next_and_later() {
        const days = Logic.agendaDays([
            ev("2026-11-12", "19:00", "Gym"),
            ev("2026-11-12", "09:30", "Standup"),
            ev("2026-11-12", "15:00", "Review", "Meet"),
            ev("2026-11-13", "10:00", "Dentist"),
            ev("2026-11-13", "All day", "Birthday"),
            ev("2026-11-14", "10:00", "Later")
        ], now, 4)
        compare(days.length, 2)
        compare(days[0].label, "Today")
        compare(days[0].rows.map(r => r.state).join(","), "done,next,later")
        compare(days[0].rows[1].note, "in 28 min · Meet")
        compare(days[1].label, "Tomorrow")
        compare(days[1].rows.map(r => r.title).join(","), "Birthday,Dentist")
    }

    function test_agendaDays_drops_finished_events_first_when_capped() {
        const days = Logic.agendaDays([
            ev("2026-11-12", "08:00", "A"), ev("2026-11-12", "09:00", "B"), ev("2026-11-12", "10:00", "C"),
            ev("2026-11-12", "16:00", "D"), ev("2026-11-12", "17:00", "E")
        ], now, 3)
        compare(days[0].rows.map(r => r.title).join(","), "C,D,E")
    }

    function test_agendaDays_empty() {
        compare(Logic.agendaDays([], now, 4).length, 0)
        compare(Logic.agendaDays(null, now, 4).length, 0)
    }

    function test_weekCount() {
        compare(Logic.weekCount([ev("2026-11-12", "9:00", "a"), ev("2026-11-18", "9:00", "b"),
                                 ev("2026-11-19", "9:00", "c"), ev("2026-11-11", "9:00", "d")], now), 2)
    }

    function test_resetLabel() {
        compare(Logic.resetLabel(new Date(2026, 10, 12, 17, 10).toISOString(), now), "Resets at 17:10")
        compare(Logic.resetLabel(new Date(2026, 10, 13, 9, 0).toISOString(), now), "Resets tomorrow 09:00")
        compare(Logic.resetLabel(new Date(2026, 10, 16, 9, 0).toISOString(), now), "Resets Monday 09:00")
        compare(Logic.resetLabel("", now), "")
    }

    function test_clock() {
        compare(Logic.clock(72), "1:12")
        compare(Logic.clock(3723), "1:02:03")
        compare(Logic.clock(undefined), "0:00")
    }

    function test_parseDf_and_gbPair() {
        const d = Logic.parseDf("        Used         Size\n412000000000 931000000000\n")
        compare(d.used, 412000000000)
        compare(Logic.gbPair(d.used, d.size), "412 / 931 GB")
        compare(Logic.parseDf("garbage"), null)
    }

    function test_parseFrame() {
        compare(Logic.parseFrame("0;500;1000;2000;", 4, 1000).join(","), "0,0.5,1,1")
        compare(Logic.parseFrame("250;", 3, 1000).join(","), "0.25,0,0")
        compare(Logic.parseFrame("x;;", 2, 1000).join(","), "0,0")
    }

    function test_age() {
        compare(Logic.age(now - 10000, now), "now")
        compare(Logic.age(now - 4 * 60000, now), "4m")
        compare(Logic.age(now - 2 * 3600000, now), "2h")
    }
}
