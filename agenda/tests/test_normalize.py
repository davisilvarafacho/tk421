import sys

from datetime import date
from pathlib import Path
from zoneinfo import ZoneInfo

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import sync  # noqa: E402

SP = ZoneInfo("America/Sao_Paulo")
NY = ZoneInfo("America/New_York")
WINDOW = (date(2026, 10, 1), date(2026, 10, 31))


def ics(*events: str) -> str:
    body = "".join(e.strip().replace("\n", "\r\n") + "\r\n" for e in events)
    return "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//test//EN\r\n" + body + "END:VCALENDAR\r\n"


def run(text, window=WINDOW, tz=SP, name="Pessoal"):
    return sync.normalize(text, name, window[0], window[1], tz)


def test_utc_event_is_converted_to_local_time():
    text = ics("""BEGIN:VEVENT
UID:a1
DTSTART:20261012T130000Z
DTEND:20261012T133000Z
SUMMARY:Daily
END:VEVENT""")
    assert run(text) == [{
        "date": "2026-10-12", "allday": False, "time": "10:00",
        "title": "Daily", "sub": "30 min", "calendar": "Pessoal",
    }]


def test_conversion_follows_dst_rules_of_the_zone():
    text = ics(
        """BEGIN:VEVENT
UID:a2
DTSTART:20260307T150000Z
DTEND:20260307T160000Z
SUMMARY:Before DST
END:VEVENT""",
        """BEGIN:VEVENT
UID:a3
DTSTART:20260308T150000Z
DTEND:20260308T160000Z
SUMMARY:After DST
END:VEVENT""",
    )
    got = run(text, window=(date(2026, 3, 1), date(2026, 3, 31)), tz=NY)
    assert [(e["title"], e["time"]) for e in got] == [("Before DST", "10:00"), ("After DST", "11:00")]


def test_floating_time_is_treated_as_local():
    text = ics("""BEGIN:VEVENT
UID:a4
DTSTART:20261012T090000
DTEND:20261012T100000
SUMMARY:Floating
END:VEVENT""")
    assert run(text)[0]["time"] == "09:00"


def test_all_day_single_day_uses_calendar_name_as_sub():
    text = ics("""BEGIN:VEVENT
UID:b1
DTSTART;VALUE=DATE:20261012
DTEND;VALUE=DATE:20261013
SUMMARY:Feriado
END:VEVENT""")
    assert run(text) == [{
        "date": "2026-10-12", "allday": True, "time": "All day",
        "title": "Feriado", "sub": "Pessoal", "calendar": "Pessoal",
    }]


def test_multi_day_all_day_has_one_entry_per_day_and_exclusive_end():
    text = ics("""BEGIN:VEVENT
UID:b2
DTSTART;VALUE=DATE:20261012
DTEND;VALUE=DATE:20261015
SUMMARY:Viagem
END:VEVENT""")
    got = run(text)
    assert [(e["date"], e["sub"]) for e in got] == [
        ("2026-10-12", "Day 1 of 3"), ("2026-10-13", "Day 2 of 3"), ("2026-10-14", "Day 3 of 3"),
    ]
    assert all(e["allday"] for e in got)


def test_weekly_recurrence_respects_exdate_and_moved_occurrence():
    text = ics(
        """BEGIN:VEVENT
UID:r1
DTSTART;TZID=America/Sao_Paulo:20261005T100000
DTEND;TZID=America/Sao_Paulo:20261005T103000
RRULE:FREQ=WEEKLY;BYDAY=MO
EXDATE;TZID=America/Sao_Paulo:20261019T100000
SUMMARY:Daily
END:VEVENT""",
        """BEGIN:VEVENT
UID:r1
RECURRENCE-ID;TZID=America/Sao_Paulo:20261026T100000
DTSTART;TZID=America/Sao_Paulo:20261026T110000
DTEND;TZID=America/Sao_Paulo:20261026T113000
SUMMARY:Daily (moved)
END:VEVENT""",
    )
    got = run(text)
    assert [(e["date"], e["time"], e["title"]) for e in got] == [
        ("2026-10-05", "10:00", "Daily"),
        ("2026-10-12", "10:00", "Daily"),
        ("2026-10-26", "11:00", "Daily (moved)"),
    ]


def test_cancelled_event_is_skipped_and_missing_title_gets_placeholder():
    text = ics(
        """BEGIN:VEVENT
UID:c1
DTSTART:20261012T130000Z
DTEND:20261012T140000Z
STATUS:CANCELLED
SUMMARY:Gone
END:VEVENT""",
        """BEGIN:VEVENT
UID:c2
DTSTART:20261012T150000Z
DTEND:20261012T160000Z
END:VEVENT""",
    )
    got = run(text)
    assert [e["title"] for e in got] == ["(No title)"]


def test_sub_uses_meet_link_location_and_duration_formats():
    text = ics(
        """BEGIN:VEVENT
UID:d1
DTSTART:20261012T130000Z
DTEND:20261012T143000Z
DESCRIPTION:Join at https://meet.google.com/abc-defg-hij
SUMMARY:Planning
END:VEVENT""",
        """BEGIN:VEVENT
UID:d2
DTSTART:20261012T170000Z
DTEND:20261012T180000Z
LOCATION:Clínica Centro - Av. Paulista 1000\\, sala 12 - São Paulo - SP
SUMMARY:Dentista
END:VEVENT""",
    )
    got = {e["title"]: e["sub"] for e in run(text)}
    assert got["Planning"] == "Google Meet · 1 h 30"
    assert got["Dentista"].startswith("Clínica Centro")
    assert got["Dentista"].endswith("… · 1 h")
    assert len(got["Dentista"].split(" · ")[0]) <= 40


def test_events_outside_the_window_are_excluded_and_order_is_all_day_first_then_time():
    text = ics(
        """BEGIN:VEVENT
UID:e1
DTSTART:20261012T190000Z
DTEND:20261012T200000Z
SUMMARY:Late
END:VEVENT""",
        """BEGIN:VEVENT
UID:e2
DTSTART:20261012T120000Z
DTEND:20261012T130000Z
SUMMARY:Early
END:VEVENT""",
        """BEGIN:VEVENT
UID:e3
DTSTART;VALUE=DATE:20261012
DTEND;VALUE=DATE:20261013
SUMMARY:All day
END:VEVENT""",
        """BEGIN:VEVENT
UID:e4
DTSTART:20261201T120000Z
DTEND:20261201T130000Z
SUMMARY:Far future
END:VEVENT""",
    )
    assert [e["title"] for e in run(text)] == ["All day", "Early", "Late"]


def test_timed_events_near_local_midnight_are_judged_in_local_time():
    text = ics(
        """BEGIN:VEVENT
UID:f1
DTSTART:20261101T010000Z
DTEND:20261101T020000Z
SUMMARY:Last night of October
END:VEVENT""",
        """BEGIN:VEVENT
UID:f2
DTSTART:20261001T010000Z
DTEND:20261001T020000Z
SUMMARY:Last night of September
END:VEVENT""",
    )
    got = [(e["date"], e["time"], e["title"]) for e in run(text)]
    assert got == [("2026-10-31", "22:00", "Last night of October")]


# ------------------------------------------------ hostile / odd events

BAD_RRULE = """BEGIN:VEVENT
UID:bad1
DTSTART:20261012T130000Z
DTEND:20261012T133000Z
RRULE:FREQ=SOMETIMES
SUMMARY:Bad rule
END:VEVENT"""

BAD_DTSTART = """BEGIN:VEVENT
UID:bad2
DTSTART:2026101X
SUMMARY:Bad start
END:VEVENT"""

NO_DTSTART = """BEGIN:VEVENT
UID:bad3
SUMMARY:No start
END:VEVENT"""

GOOD_EVENT = """BEGIN:VEVENT
UID:good
DTSTART:20261012T130000Z
DTEND:20261012T133000Z
SUMMARY:Survivor
END:VEVENT"""


@pytest.mark.parametrize("bad", [BAD_RRULE, BAD_DTSTART, NO_DTSTART], ids=["rrule", "dtstart", "missing-dtstart"])
def test_one_bad_event_does_not_sink_the_calendar(bad):
    assert [e["title"] for e in run(ics(bad, GOOD_EVENT))] == ["Survivor"]


def test_all_kinds_of_bad_event_together_keep_the_good_one():
    assert [e["title"] for e in run(ics(BAD_RRULE, BAD_DTSTART, NO_DTSTART, GOOD_EVENT))] == ["Survivor"]


def test_titles_and_places_collapse_whitespace():
    text = ics("""BEGIN:VEVENT
UID:ws
DTSTART:20261012T130000Z
DTEND:20261012T133000Z
SUMMARY:Line one\\nLine	two   end
LOCATION:Room  12	B
END:VEVENT""")
    [event] = run(text)
    assert event["title"] == "Line one Line two end"
    assert event["sub"] == "Room 12 B · 30 min"
