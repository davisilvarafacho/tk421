# Google Calendar (iCal) Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show the user's Google Calendar events (read from the secret iCal URL) in the Dynamic Island agenda.

**Architecture:** `agenda/sync.py` (a `uv run --script` Python script) fetches the iCal feeds, expands recurrences, normalises events and writes `agenda/cache/agenda.json` atomically. `services/Agenda.qml` watches that file, runs the script every 15 minutes, and feeds the existing island UI. Sync and display only meet at the JSON file.

**Tech Stack:** Python 3.12+ (machine has 3.14), `uv` (at `~/.local/bin/uv`), `icalendar>=6`, `recurring-ical-events>=3`, stdlib `urllib`/`tomllib`, pytest; Quickshell 0.3.2 QML (`FileView`, `Process`, `IpcHandler`).

**Spec:** `docs/superpowers/specs/2026-10-12-google-calendar-ical-design.md`

## Global Constraints

- Everything lives inside the project: config `agenda/agenda.toml` (mode `0600`), cache `agenda/cache/agenda.json` (mode `0600`). Both are already in the root `.gitignore`. Nothing under `~/.config` or `~/.cache`.
- The secret iCal URL is **never** printed, logged, put in an error message, committed, or passed on a command line. Output may show the calendar name and at most the host.
- HTTPS only (config validation); fetch timeout 20 s; response cap 20 MB; at most 3 redirects.
- Window: 45 days back to 120 days forward (config `[sync]` may override). Local zone is `America/Sao_Paulo`; convert with `zoneinfo`, never with fixed offsets.
- JSON contract (`version: 1`): events carry `date` (`YYYY-MM-DD`), `allday` (bool), `time` (`HH:mm`, or `"All day"` for all-day), `title`, `sub`, `calendar`.
- Exit codes: `0` ok, `2` config error, `3` all fetches failed (cache left untouched).
- UI copy is English. Event titles come from the calendar as-is (Portuguese is fine).
- The repository has **no commits** yet. Do **not** run `git commit`/`git add` unless the user asks; a task's checkpoint is "its tests pass". Reviewers read files directly, not a git diff.
- Run QML checks against the running Quickshell: `qs ipc -p /home/tk421/Development/quickshell/shell.qml call <target> <fn>`, logs via `qs log -p /home/tk421/Development/quickshell/shell.qml`. The shell hot-reloads on file changes. Never trigger the real lock screen (`lock lock`) while testing.

## Review Focus

- A multi-day all-day event must appear once per covered day and **not** on its exclusive end date (pinned in Task 1).
- Recurring events with an `EXDATE` and a moved occurrence (`RECURRENCE-ID`) must show the right days and times (pinned in Task 1).
- The secret URL must not leak through error text, `--check` output or logs (pinned in Task 2).
- One failing calendar must keep its previous events and not wipe the others; all calendars failing must leave the cache byte-for-byte unchanged (pinned in Task 2).
- A malformed or hostile feed (garbage text, oversize body, slow server) must become a per-calendar error, never a crash or a hang (pinned in Task 2). A corrupt cache file must not crash the shell (pinned in Task 3).

## File Structure

| File | Responsibility |
|---|---|
| `agenda/sync.py` | Normalisation (Task 1); config, fetch, sync, cache, CLI (Task 2) |
| `agenda/tests/test_normalize.py` | Task 1 tests |
| `agenda/tests/test_sync.py` | Task 2 tests |
| `agenda/agenda.example.toml` | Committed-style example config (no secret) |
| `agenda/README.md` | Setup and troubleshooting (Task 3) |
| `services/Agenda.qml` | Loads cache, runs the script, exposes `events`, `status` (Task 3) |
| `island/AgendaPane.qml` | Offline / not-set-up messages (Task 3) |
| `island/Island.qml` | Triggers a refresh when the card opens (Task 3) |

---

### Task 1: Event normalisation

**Files:**
- Create: `agenda/sync.py` (normalisation part only)
- Create: `agenda/tests/test_normalize.py`

**Interfaces:**
- Produces:
  - `normalize(ics_text: str, calendar_name: str, start: date, end: date, tz: ZoneInfo) -> list[dict]` — events (dicts with the contract keys) whose date lies in `[start, end]` inclusive, sorted all-day first, then by `time`, then `title`.
  - `duration_text(minutes: int) -> str`, `place_text(component) -> str`, `to_local(dt: datetime, tz: ZoneInfo) -> datetime`.

- [ ] **Step 1: Create the script header and an import-only skeleton so tests can import it**

Create `agenda/sync.py`:

```python
#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = ["icalendar>=6", "recurring-ical-events>=3"]
# ///
"""Sync Google Calendar secret-iCal feeds into agenda/cache/agenda.json.

Never print, log or embed a calendar URL in an error: it is a secret.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import tempfile
import tomllib
import urllib.error
import urllib.request
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from pathlib import Path
from zoneinfo import ZoneInfo

import icalendar
import recurring_ical_events

HERE = Path(__file__).resolve().parent
DEFAULT_CONFIG = HERE / "agenda.toml"
DEFAULT_CACHE = HERE / "cache" / "agenda.json"
LOCAL_TZ = ZoneInfo("America/Sao_Paulo")
MAX_BYTES = 20 * 1024 * 1024
```

- [ ] **Step 2: Write the failing tests**

Create `agenda/tests/test_normalize.py`:

```python
import sys
from datetime import date
from pathlib import Path
from zoneinfo import ZoneInfo

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
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `cd /home/tk421/Development/quickshell/agenda && uv run --with pytest --with icalendar --with recurring-ical-events pytest tests/test_normalize.py -v`
Expected: collection succeeds, every test FAILS with `AttributeError: module 'sync' has no attribute 'normalize'`.

- [ ] **Step 4: Implement the normalisation**

Append to `agenda/sync.py`:

```python
def to_local(dt: datetime, tz: ZoneInfo) -> datetime:
    """Aware datetimes are converted; floating (naive) ones are taken as already local."""
    if dt.tzinfo is None:
        return dt.replace(tzinfo=tz)
    return dt.astimezone(tz)


def duration_text(minutes: int) -> str:
    if minutes < 60:
        return f"{minutes} min"
    hours, rest = divmod(minutes, 60)
    return f"{hours} h" if rest == 0 else f"{hours} h {rest:02d}"


def place_text(component) -> str:
    """'Google Meet' if the event has a Meet link, else the first line of LOCATION (max 40 chars)."""
    location = str(component.get("LOCATION", "") or "").strip()
    description = str(component.get("DESCRIPTION", "") or "")
    if component.get("X-GOOGLE-CONFERENCE") or "meet.google.com" in f"{location} {description}":
        return "Google Meet"
    first = location.splitlines()[0].strip() if location else ""
    return first if len(first) <= 40 else first[:39] + "…"


def normalize(ics_text: str, calendar_name: str, start: date, end: date, tz: ZoneInfo) -> list[dict]:
    calendar = icalendar.Calendar.from_ical(ics_text)
    events: list[dict] = []

    for comp in recurring_ical_events.of(calendar).between(start, end + timedelta(days=1)):
        if comp.name != "VEVENT":
            continue
        if str(comp.get("STATUS", "")).upper() == "CANCELLED":
            continue

        title = str(comp.get("SUMMARY", "")).strip() or "(No title)"
        place = place_text(comp)
        dtstart = comp.get("DTSTART").dt

        if isinstance(dtstart, datetime):
            began = to_local(dtstart, tz)
            if not (start <= began.date() <= end):
                continue
            finished = comp.end
            minutes = 0
            if isinstance(finished, datetime):
                minutes = int((to_local(finished, tz) - began).total_seconds() // 60)
            parts = [place, duration_text(minutes) if minutes > 0 else ""]
            events.append({
                "date": began.date().isoformat(), "allday": False, "time": began.strftime("%H:%M"),
                "title": title, "sub": " · ".join(p for p in parts if p), "calendar": calendar_name,
            })
        else:  # DATE value: all-day, end is exclusive
            last = comp.end
            days = max(1, (last - dtstart).days)
            for i in range(days):
                day = dtstart + timedelta(days=i)
                if not (start <= day <= end):
                    continue
                if days > 1:
                    sub = " · ".join(p for p in (f"Day {i + 1} of {days}", place) if p)
                else:
                    sub = place or calendar_name
                events.append({
                    "date": day.isoformat(), "allday": True, "time": "All day",
                    "title": title, "sub": sub, "calendar": calendar_name,
                })

    events.sort(key=lambda e: (not e["allday"], e["time"], e["title"]))
    return events
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `cd /home/tk421/Development/quickshell/agenda && uv run --with pytest --with icalendar --with recurring-ical-events pytest tests/test_normalize.py -v`
Expected: all 9 tests PASS. If one fails on `comp.end` for a recurring instance, print `comp.get("DTEND")` and use it directly (the contract and tests above do not change).

---

### Task 2: Config, fetch, sync, cache, CLI

**Files:**
- Modify: `agenda/sync.py` (append)
- Create: `agenda/tests/test_sync.py`
- Create: `agenda/agenda.example.toml`

**Interfaces:**
- Consumes: `normalize(...)`, `LOCAL_TZ`, `MAX_BYTES`, `DEFAULT_CONFIG`, `DEFAULT_CACHE` from Task 1.
- Produces:
  - `class ConfigError(Exception)`, `class FetchError(Exception)`
  - `@dataclass Calendar(name: str, url: str)`, `@dataclass Config(calendars: list[Calendar], back_days: int = 45, forward_days: int = 120)`
  - `load_config(path: Path) -> Config`
  - `ensure_not_tracked(paths: list[Path]) -> None` (raises `ConfigError`)
  - `fetch_ics(url: str, timeout: float = 20, max_bytes: int = MAX_BYTES) -> str`
  - `redact_url(url: str) -> str` (host + `/…` + last 4 chars)
  - `read_cache(path: Path) -> dict | None`, `write_cache(path: Path, data: dict) -> None`
  - `run_sync(config: Config, previous: dict | None, now: datetime, tz: ZoneInfo, fetcher=fetch_ics) -> tuple[dict, bool]` — returns `(output_json, all_failed)`
  - `main(argv: list[str], fetcher=fetch_ics, now: datetime | None = None) -> int`
  - CLI flags: `--config PATH`, `--cache PATH`, `--check`, `--stdout`.

- [ ] **Step 1: Create the example config**

Create `agenda/agenda.example.toml`:

```toml
# Copy to agenda/agenda.toml, paste your link, then: chmod 600 agenda/agenda.toml
# Link: Google Calendar -> Settings -> (your calendar) -> Integrate calendar -> "Secret address in iCal format".
# Anyone with this link can read the whole calendar. Never commit or share it.

[[calendar]]
name = "Pessoal"
url  = "https://calendar.google.com/calendar/ical/REPLACE_ME/private-REPLACE_ME/basic.ics"

# Repeat [[calendar]] for more calendars.

[sync]            # optional
back_days    = 45
forward_days = 120
```

- [ ] **Step 2: Write the failing tests**

Create `agenda/tests/test_sync.py`:

```python
import http.server
import json
import os
import subprocess
import sys
import threading
import time
from datetime import datetime
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import sync  # noqa: E402

SECRET = "SECRET-TOKEN-9f3a1c"
NOW = datetime(2026, 10, 12, 14, 0, tzinfo=sync.LOCAL_TZ)

ICS_OK = (
    "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//t//EN\r\n"
    "BEGIN:VEVENT\r\nUID:x1\r\nDTSTART:20261012T130000Z\r\nDTEND:20261012T133000Z\r\nSUMMARY:Daily\r\nEND:VEVENT\r\n"
    "END:VCALENDAR\r\n"
)


# ---------------------------------------------------------------- config

def write_toml(path: Path, body: str, mode: int = 0o600) -> Path:
    path.write_text(body)
    os.chmod(path, mode)
    return path


GOOD = f'[[calendar]]\nname = "Pessoal"\nurl = "https://example.com/{SECRET}/basic.ics"\n'


def test_load_config_reads_calendars_and_defaults(tmp_path):
    cfg = sync.load_config(write_toml(tmp_path / "agenda.toml", GOOD))
    assert [(c.name, c.url) for c in cfg.calendars] == [("Pessoal", f"https://example.com/{SECRET}/basic.ics")]
    assert (cfg.back_days, cfg.forward_days) == (45, 120)


def test_load_config_honours_sync_overrides(tmp_path):
    cfg = sync.load_config(write_toml(tmp_path / "a.toml", GOOD + "[sync]\nback_days = 10\nforward_days = 20\n"))
    assert (cfg.back_days, cfg.forward_days) == (10, 20)


@pytest.mark.parametrize("body, mode, fragment", [
    (GOOD, 0o644, "chmod 600"),
    (GOOD.replace("https://", "http://"), 0o600, "https"),
    ("", 0o600, "calendar"),
    ('[[calendar]]\nname = ""\nurl = "https://x.test/a.ics"\n', 0o600, "name"),
])
def test_load_config_rejects_bad_files(tmp_path, body, mode, fragment):
    with pytest.raises(sync.ConfigError) as err:
        sync.load_config(write_toml(tmp_path / "a.toml", body, mode))
    assert fragment in str(err.value)
    assert SECRET not in str(err.value)


def test_load_config_missing_file(tmp_path):
    with pytest.raises(sync.ConfigError):
        sync.load_config(tmp_path / "nope.toml")


def test_ensure_not_tracked_rejects_files_git_would_track(tmp_path):
    subprocess.run(["git", "init", "-q"], cwd=tmp_path, check=True)
    secret = tmp_path / "agenda.toml"
    secret.write_text("x")
    with pytest.raises(sync.ConfigError):
        sync.ensure_not_tracked([secret])
    (tmp_path / ".gitignore").write_text("agenda.toml\n")
    sync.ensure_not_tracked([secret])          # now ignored: no error


def test_ensure_not_tracked_is_skipped_outside_a_git_checkout(tmp_path):
    f = tmp_path / "agenda.toml"
    f.write_text("x")
    sync.ensure_not_tracked([f])               # not a repo: no error


# ----------------------------------------------------------------- fetch

class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_GET(self):
        if self.path.endswith("/slow.ics"):
            time.sleep(1.0)
        if self.path.endswith("/missing.ics"):
            self.send_response(404)
            self.end_headers()
            return
        body = b"x" * 5000 if self.path.endswith("/big.ics") else ICS_OK.encode()
        self.send_response(200)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


@pytest.fixture
def server():
    srv = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    yield f"http://127.0.0.1:{srv.server_address[1]}/{SECRET}"
    srv.shutdown()


def test_fetch_returns_body(server):
    assert "SUMMARY:Daily" in sync.fetch_ics(f"{server}/basic.ics")


@pytest.mark.parametrize("path, fragment", [("missing.ics", "404"), ("slow.ics", "timeout")])
def test_fetch_errors_are_short_and_never_contain_the_url(server, path, fragment):
    with pytest.raises(sync.FetchError) as err:
        sync.fetch_ics(f"{server}/{path}", timeout=0.3)
    assert fragment in str(err.value)
    assert SECRET not in str(err.value) and "127.0.0.1" not in str(err.value)


def test_fetch_rejects_oversize_body(server):
    with pytest.raises(sync.FetchError) as err:
        sync.fetch_ics(f"{server}/big.ics", max_bytes=1000)
    assert "large" in str(err.value)


def test_redact_url_hides_the_secret():
    out = sync.redact_url(f"https://calendar.google.com/calendar/ical/{SECRET}/basic.ics")
    assert out.startswith("calendar.google.com") and SECRET not in out


# ------------------------------------------------------------- run_sync

CONFIG = sync.Config(calendars=[sync.Calendar("A", "https://a.test/1.ics"), sync.Calendar("B", "https://b.test/2.ics")])


def previous_cache():
    return {"events": [
        {"date": "2026-10-12", "allday": False, "time": "09:00", "title": "Old B", "sub": "", "calendar": "B"},
        {"date": "2026-10-12", "allday": False, "time": "08:00", "title": "Old A", "sub": "", "calendar": "A"},
    ]}


def test_run_sync_merges_calendars_and_reports_ok():
    out, failed = sync.run_sync(CONFIG, None, NOW, sync.LOCAL_TZ, fetcher=lambda url: ICS_OK)
    assert failed is False
    assert out["version"] == 1 and out["window"] == {"from": "2026-08-28", "to": "2027-02-09"}
    assert [c["ok"] for c in out["calendars"]] == [True, True]
    assert [e["calendar"] for e in out["events"]] == ["A", "B"]


def test_failed_calendar_keeps_its_previous_events_and_others_update():
    def fetcher(url):
        if "b.test" in url:
            raise sync.FetchError("HTTP 500")
        return ICS_OK

    out, failed = sync.run_sync(CONFIG, previous_cache(), NOW, sync.LOCAL_TZ, fetcher=fetcher)
    assert failed is False
    assert [c["ok"] for c in out["calendars"]] == [True, False]
    assert out["calendars"][1]["error"] == "HTTP 500"
    titles = {e["calendar"]: e["title"] for e in out["events"]}
    assert titles == {"A": "Daily", "B": "Old B"}


def test_garbage_feed_becomes_a_calendar_error_not_a_crash():
    out, failed = sync.run_sync(CONFIG, previous_cache(), NOW, sync.LOCAL_TZ, fetcher=lambda url: "this is not ics")
    assert failed is True
    assert all(c["ok"] is False for c in out["calendars"])
    assert {e["title"] for e in out["events"]} == {"Old A", "Old B"}


def test_run_sync_errors_never_contain_the_url():
    def fetcher(url):
        raise sync.FetchError("network error")

    out, _ = sync.run_sync(CONFIG, None, NOW, sync.LOCAL_TZ, fetcher=fetcher)
    assert "a.test" not in json.dumps(out) and "b.test" not in json.dumps(out)


# ----------------------------------------------------------------- cache

def test_write_cache_is_atomic_and_private(tmp_path):
    path = tmp_path / "cache" / "agenda.json"
    sync.write_cache(path, {"version": 1, "events": []})
    assert json.loads(path.read_text()) == {"version": 1, "events": []}
    assert oct(path.stat().st_mode & 0o777) == "0o600"
    assert [p.name for p in path.parent.iterdir()] == ["agenda.json"]


def test_read_cache_returns_none_for_missing_or_corrupt(tmp_path):
    assert sync.read_cache(tmp_path / "nope.json") is None
    bad = tmp_path / "bad.json"
    bad.write_text("{not json")
    assert sync.read_cache(bad) is None


# ------------------------------------------------------------------- CLI

def cli(tmp_path, *flags, toml=GOOD, fetcher=lambda url: ICS_OK):
    cfg = write_toml(tmp_path / "agenda.toml", toml)
    cache = tmp_path / "cache" / "agenda.json"
    code = sync.main(["--config", str(cfg), "--cache", str(cache), *flags], fetcher=fetcher, now=NOW)
    return code, cache


def test_cli_writes_cache(tmp_path):
    code, cache = cli(tmp_path)
    assert code == 0 and json.loads(cache.read_text())["events"][0]["title"] == "Daily"


def test_cli_stdout_prints_json_and_writes_nothing(tmp_path, capsys):
    code, cache = cli(tmp_path, "--stdout")
    assert code == 0 and not cache.exists()
    assert json.loads(capsys.readouterr().out)["version"] == 1


def test_cli_check_prints_counts_and_hides_the_url(tmp_path, capsys):
    code, cache = cli(tmp_path, "--check")
    captured = capsys.readouterr()
    assert code == 0 and not cache.exists()
    assert "Pessoal" in captured.out and SECRET not in captured.out + captured.err


def test_cli_config_error_exits_2_without_leaking(tmp_path, capsys):
    code, cache = cli(tmp_path, toml=GOOD.replace("https://", "http://"))
    captured = capsys.readouterr()
    assert code == 2 and not cache.exists()
    assert SECRET not in captured.out + captured.err


def test_cli_all_failed_exits_3_and_leaves_cache_untouched(tmp_path, capsys):
    cache = tmp_path / "cache" / "agenda.json"
    sync.write_cache(cache, {"version": 1, "events": [{"title": "keep"}]})
    before = cache.read_bytes()

    def boom(url):
        raise sync.FetchError("timeout")

    code, _ = cli(tmp_path, fetcher=boom)
    captured = capsys.readouterr()
    assert code == 3 and cache.read_bytes() == before
    assert SECRET not in captured.out + captured.err
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `cd /home/tk421/Development/quickshell/agenda && uv run --with pytest --with icalendar --with recurring-ical-events pytest tests/test_sync.py -v`
Expected: FAIL with `AttributeError: module 'sync' has no attribute 'ConfigError'` (or similar) on every test.

- [ ] **Step 4: Implement config, fetch, sync, cache and CLI**

Append to `agenda/sync.py`:

```python
class ConfigError(Exception):
    pass


class FetchError(Exception):
    pass


@dataclass
class Calendar:
    name: str
    url: str


@dataclass
class Config:
    calendars: list[Calendar]
    back_days: int = 45
    forward_days: int = 120


def load_config(path: Path) -> Config:
    try:
        mode = path.stat().st_mode
    except FileNotFoundError:
        raise ConfigError(f"config not found: {path.name} (copy agenda.example.toml)") from None
    if mode & 0o077:
        raise ConfigError(f"{path.name} is readable by other users; run: chmod 600 {path.name}")

    try:
        with path.open("rb") as handle:
            raw = tomllib.load(handle)
    except tomllib.TOMLDecodeError as exc:
        raise ConfigError(f"{path.name} is not valid TOML: {exc}") from None

    calendars = []
    for entry in raw.get("calendar", []):
        name = str(entry.get("name", "")).strip()
        url = str(entry.get("url", "")).strip()
        if not name:
            raise ConfigError("every [[calendar]] needs a non-empty name")
        if not url.startswith("https://"):
            raise ConfigError(f'calendar "{name}": url must start with https://')
        calendars.append(Calendar(name, url))
    if not calendars:
        raise ConfigError("no [[calendar]] entries found")

    sync_cfg = raw.get("sync", {})
    return Config(calendars, int(sync_cfg.get("back_days", 45)), int(sync_cfg.get("forward_days", 120)))


def ensure_not_tracked(paths: list[Path]) -> None:
    """Refuse to run if git would track a secret/cache file. Silently skipped outside a git checkout."""
    for path in paths:
        try:
            result = subprocess.run(
                ["git", "check-ignore", "-q", "--", str(path)],
                cwd=path.parent if path.parent.exists() else None,
                capture_output=True,
            )
        except FileNotFoundError:
            return
        if result.returncode == 1:
            raise ConfigError(f"{path.name} is not git-ignored; add it to .gitignore first")


class _FewRedirects(urllib.request.HTTPRedirectHandler):
    max_redirections = 3


def fetch_ics(url: str, timeout: float = 20, max_bytes: int = MAX_BYTES) -> str:
    opener = urllib.request.build_opener(_FewRedirects)
    request = urllib.request.Request(url, headers={"User-Agent": "tk421-agenda/1"})
    try:
        with opener.open(request, timeout=timeout) as response:
            data = response.read(max_bytes + 1)
    except urllib.error.HTTPError as exc:
        raise FetchError(f"HTTP {exc.code}") from None
    except TimeoutError:
        raise FetchError("timeout") from None
    except urllib.error.URLError as exc:
        reason = exc.reason
        raise FetchError("timeout" if isinstance(reason, TimeoutError) or "timed out" in str(reason) else "network error") from None
    except OSError:
        raise FetchError("network error") from None
    if len(data) > max_bytes:
        raise FetchError("response too large")
    return data.decode("utf-8", "replace")


def redact_url(url: str) -> str:
    host = urllib.request.urlparse(url).netloc
    return f"{host}/…{url[-4:]}"


def read_cache(path: Path) -> dict | None:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None


def write_cache(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    os.chmod(path.parent, 0o700)
    fd, tmp = tempfile.mkstemp(dir=path.parent, prefix=".agenda-", suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(data, handle, ensure_ascii=False, indent=2)
        os.chmod(tmp, 0o600)
        os.replace(tmp, path)
    except BaseException:
        Path(tmp).unlink(missing_ok=True)
        raise


def run_sync(config: Config, previous: dict | None, now: datetime, tz: ZoneInfo, fetcher=fetch_ics) -> tuple[dict, bool]:
    today = now.astimezone(tz).date()
    start = today - timedelta(days=config.back_days)
    end = today + timedelta(days=config.forward_days)
    old_events = (previous or {}).get("events", [])

    events: list[dict] = []
    statuses: list[dict] = []
    for cal in config.calendars:
        try:
            events.extend(normalize(fetcher(cal.url), cal.name, start, end, tz))
            statuses.append({"name": cal.name, "ok": True, "error": None})
        except FetchError as exc:
            statuses.append({"name": cal.name, "ok": False, "error": str(exc)})
            events.extend(e for e in old_events if e.get("calendar") == cal.name)
        except Exception as exc:  # malformed feed: never leak its content, only the error class
            statuses.append({"name": cal.name, "ok": False, "error": f"invalid feed ({type(exc).__name__})"})
            events.extend(e for e in old_events if e.get("calendar") == cal.name)

    events.sort(key=lambda e: (e["date"], not e["allday"], e["time"], e["title"]))
    output = {
        "version": 1,
        "generated_at": now.isoformat(timespec="seconds"),
        "window": {"from": start.isoformat(), "to": end.isoformat()},
        "calendars": statuses,
        "events": events,
    }
    return output, not any(s["ok"] for s in statuses)


def main(argv: list[str], fetcher=fetch_ics, now: datetime | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG)
    parser.add_argument("--cache", type=Path, default=DEFAULT_CACHE)
    parser.add_argument("--check", action="store_true", help="fetch and report counts; write nothing")
    parser.add_argument("--stdout", action="store_true", help="print the JSON instead of writing the cache")
    args = parser.parse_args(argv)

    try:
        config = load_config(args.config)
        if not (args.check or args.stdout):
            ensure_not_tracked([args.config, args.cache])
    except ConfigError as exc:
        print(f"config error: {exc}", file=sys.stderr)
        return 2

    now = now or datetime.now(LOCAL_TZ)
    output, all_failed = run_sync(config, read_cache(args.cache), now, LOCAL_TZ, fetcher)

    if args.check:
        for status in output["calendars"]:
            count = sum(1 for e in output["events"] if e["calendar"] == status["name"])
            print(f'{status["name"]}: {count} events ({"ok" if status["ok"] else status["error"]})')
        return 3 if all_failed else 0
    if all_failed:
        for status in output["calendars"]:
            print(f'{status["name"]}: {status["error"]}', file=sys.stderr)
        return 3
    if args.stdout:
        print(json.dumps(output, ensure_ascii=False, indent=2))
    else:
        write_cache(args.cache, output)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
```

- [ ] **Step 5: Run both test files to verify everything passes**

Run: `cd /home/tk421/Development/quickshell/agenda && uv run --with pytest --with icalendar --with recurring-ical-events pytest tests -v`
Expected: all tests PASS (Task 1's 9 plus Task 2's). If `test_ensure_not_tracked_*` fails because `git` prints different return codes, run `git check-ignore -q` by hand in a temp repo and adapt only the return-code handling (1 = not ignored; 128 = not a repo → skip).

- [ ] **Step 6: Smoke-test the script entry point and the missing-config path**

Run: `cd /home/tk421/Development/quickshell && ./agenda/sync.py --check; echo "exit=$?"`
Expected: stderr `config error: config not found: agenda.toml (copy agenda.example.toml)` and `exit=2` (uv installs the dependencies on the first run; that can take a few seconds).

---

### Task 3: Quickshell side

**Files:**
- Modify: `services/Agenda.qml` (replace)
- Modify: `island/AgendaPane.qml` (header count + empty text)
- Modify: `island/Island.qml` (refresh when the card opens)
- Create: `agenda/README.md`

**Interfaces:**
- Consumes: the JSON contract and exit codes from Task 2 (`agenda/sync.py`, `agenda/cache/agenda.json`).
- Produces: singleton `Agenda` with `events: var`, `status: string` (`"ok" | "stale" | "unconfigured" | "error"`), `eventsOn(d: date)`, `hasEvents(d: date)`, `sync()`, `refreshIfStale()`; IPC `qs ipc call agenda status` returning the status string.

- [ ] **Step 1: Replace `services/Agenda.qml`**

```qml
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Calendar events for the island agenda. Events come from agenda/cache/agenda.json, written by
// agenda/sync.py (Google Calendar secret iCal feed). Event shape:
// { date: "YYYY-MM-DD", allday: bool, time: "HH:mm", title: string, sub: string, calendar: string }
Singleton {
    id: root

    readonly property string dir: Qt.resolvedUrl("../agenda/").toString().replace("file://", "")
    readonly property string home: Quickshell.env("HOME")

    property var events: []
    property string generatedAt: ""

    // "ok" | "stale" (last sync failed, showing old data) | "unconfigured" (no/invalid config) | "error"
    property string status: "unconfigured"
    property double lastSyncStart: 0

    function pad(n) {
        return String(n).padStart(2, "0")
    }

    function dateKey(d) {
        return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate())
    }

    // All-day events first, then by start time.
    function eventsOn(d) {
        const key = dateKey(d)

        return events
            .filter(e => e.date === key)
            .sort((a, b) => (b.allday ? 1 : 0) - (a.allday ? 1 : 0) || String(a.time).localeCompare(String(b.time)))
    }

    function hasEvents(d) {
        return eventsOn(d).length > 0
    }

    function sync() {
        if (syncProcess.running)
            return

        lastSyncStart = Date.now()
        syncProcess.running = true
    }

    // Used when the island opens: sync only if the last attempt is older than 5 minutes.
    function refreshIfStale() {
        if (Date.now() - lastSyncStart > 5 * 60 * 1000)
            sync()
    }

    function apply(text) {
        try {
            const data = JSON.parse(text)

            if (Array.isArray(data.events)) {
                events = data.events
                generatedAt = data.generated_at || ""
            }
        } catch (e) {
            // Corrupt cache: keep whatever we already show.
        }
    }

    FileView {
        id: cache

        path: root.dir + "cache/agenda.json"
        watchChanges: true

        onFileChanged: reload()
        onLoaded: root.apply(text())
    }

    Process {
        id: syncProcess

        // PATH may lack ~/.local/bin when Quickshell is started from the Hyprland autostart.
        command: ["env", "PATH=" + root.home + "/.local/bin:" + Quickshell.env("PATH"),
                  "uv", "run", "--script", root.dir + "sync.py"]

        onExited: exitCode => {
            if (exitCode === 0)
                root.status = "ok"
            else if (exitCode === 2)
                root.status = "unconfigured"
            else if (exitCode === 3)
                root.status = root.events.length > 0 ? "stale" : "error"
            else
                root.status = "error"
        }
    }

    Timer {
        interval: 15 * 60 * 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.sync()
    }

    IpcHandler {
        target: "agenda"

        function status(): string {
            return root.status
        }

        function sync(): void {
            root.sync()
        }
    }
}
```

- [ ] **Step 2: Show offline / not-set-up messages in `island/AgendaPane.qml`**

In the header, replace the count `Text` block:

```qml
        Text {
            renderType: Text.CurveRendering
            anchors.right: parent.right
            text: root.list.length === 0 ? "" : root.list.length + (root.list.length === 1 ? " event" : " events")
            color: root.c.muted
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }
```

with:

```qml
        Text {
            renderType: Text.CurveRendering
            anchors.right: parent.right
            text: Agenda.status === "stale" || Agenda.status === "error" ? "Offline"
                : root.list.length === 0 ? ""
                : root.list.length + (root.list.length === 1 ? " event" : " events")
            color: root.c.muted
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }
```

and in the empty-state `Text` (the one with `text: "No events"`), change the text line to:

```qml
        text: Agenda.status === "unconfigured" ? "Calendar not set up" : "No events"
```

(If the header `Text` lacks `renderType: Text.CurveRendering` in the file, keep the file's existing lines and only change the `text:` expressions.)

- [ ] **Step 3: Refresh when the card opens in `island/Island.qml`**

In the existing `onOpenChanged` handler, change:

```qml
        if (open) {
            hud = false
        } else {
```

to:

```qml
        if (open) {
            hud = false
            Agenda.refreshIfStale()
        } else {
```

- [ ] **Step 4: Create `agenda/README.md`**

```markdown
# Agenda (Google Calendar via secret iCal link)

Read-only. The island shows today's events; `sync.py` fetches them every 15 minutes.

## Setup
1. Google Calendar → Settings → your calendar → **Integrate calendar** → copy **Secret address in iCal format**.
2. `cp agenda/agenda.example.toml agenda/agenda.toml`, paste the link, `chmod 600 agenda/agenda.toml`.
3. Test: `agenda/sync.py --check` (prints event counts, never the link).
4. The island picks the data up on the next sync (or run `qs ipc -p <repo>/shell.qml call agenda sync`).

## Troubleshooting
- Island says **Calendar not set up** → `sync.py` exited with a config error; run `agenda/sync.py --check`.
- Island says **Offline** → the last fetch failed; old events stay visible.
- New events take hours to appear → normal: Google updates the iCal feed slowly.
- Link leaked → Google Calendar settings → **Reset** next to the secret address, then update `agenda.toml`.

## Files
`sync.py` (script), `agenda.toml` (secret, git-ignored), `cache/agenda.json` (git-ignored), `tests/` (`uv run --with pytest --with icalendar --with recurring-ical-events pytest agenda/tests`).
```

- [ ] **Step 5: Verify — no config (the "not set up" path)**

Run:
```bash
cd /home/tk421/Development/quickshell && ls agenda/agenda.toml 2>&1 | head -1
sleep 6; qs ipc -p $PWD/shell.qml call agenda status
qs log -p $PWD/shell.qml 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | awk '/Reloading configuration/{b=""} {b=b $0 "\n"} END{printf "%s", b}' | grep -cE "WARN|ERROR"
```
Expected: `ls` reports the file does not exist; status prints `unconfigured`; the warning/error count is `0`. Then open the island (`qs ipc -p $PWD/shell.qml call island toggle`), grab only the card area with `grim -g "906,4 748x424" /tmp/claude-1000/-home-tk421-Development-quickshell/18794bd0-d998-4ea1-8fcb-5d87b0439450/scratchpad/agenda-unconfigured.png`, close it again with the same toggle command, and confirm the right column says "Calendar not set up".

- [ ] **Step 6: Verify — cached events are shown, a corrupt cache is ignored**

Run:
```bash
cd /home/tk421/Development/quickshell && mkdir -p agenda/cache && python3 - <<'EOF'
import json, datetime
t = datetime.date.today().isoformat()
ev = [{"date": t, "allday": i == 0, "time": "All day" if i == 0 else f"{8+i:02d}:00",
       "title": f"Teste {i+1}", "sub": "fixture", "calendar": "Pessoal"} for i in range(8)]
json.dump({"version": 1, "generated_at": t, "calendars": [], "events": ev}, open("agenda/cache/agenda.json", "w"))
EOF
sleep 2
qs ipc -p $PWD/shell.qml call island toggle; sleep 1.6
grim -g "906,4 748x424" /tmp/claude-1000/-home-tk421-Development-quickshell/18794bd0-d998-4ea1-8fcb-5d87b0439450/scratchpad/agenda-cache.png
qs ipc -p $PWD/shell.qml call island toggle
echo '{not json' > agenda/cache/agenda.json; sleep 2
qs log -p $PWD/shell.qml 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | awk '/Reloading configuration/{b=""} {b=b $0 "\n"} END{printf "%s", b}' | grep -cE "WARN|ERROR"
```
Expected: the screenshot shows "Teste 1 … " in the agenda with the overflow fade (8 events) and a dot on today in the grid; after corrupting the file the shell logs `0` warnings/errors and keeps the events already loaded. Finally delete the fixture: `rm agenda/cache/agenda.json`.

- [ ] **Step 7: Verify — the "Offline" (stale) path with an unreachable HTTPS host**

Run:
```bash
cd /home/tk421/Development/quickshell && python3 - <<'EOF'
import json, datetime, os
t = datetime.date.today().isoformat()
os.makedirs("agenda/cache", exist_ok=True)
json.dump({"version": 1, "generated_at": t, "calendars": [], "events": [
    {"date": t, "allday": False, "time": "10:00", "title": "Cached event", "sub": "fixture", "calendar": "Pessoal"}]},
    open("agenda/cache/agenda.json", "w"))
open("agenda/agenda.toml", "w").write('[[calendar]]\nname = "Pessoal"\nurl = "https://127.0.0.1:9/unreachable.ics"\n')
os.chmod("agenda/agenda.toml", 0o600)
EOF
sleep 2; qs ipc -p $PWD/shell.qml call agenda sync; sleep 8
qs ipc -p $PWD/shell.qml call agenda status
```
Expected: status prints `stale`; open the island and the agenda header shows `Offline` with "Cached event" still listed. Cleanup: `rm agenda/agenda.toml agenda/cache/agenda.json`.

- [ ] **Step 8: Final check**

Run: `cd /home/tk421/Development/quickshell && ls agenda agenda/tests && git check-ignore -v agenda/agenda.toml agenda/cache/agenda.json && qs log -p $PWD/shell.qml 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | awk '/Reloading configuration/{b=""} {b=b $0 "\n"} END{printf "%s", b}' | grep -cE "WARN|ERROR"`
Expected: `agenda.example.toml README.md sync.py tests`, both paths reported as ignored, and `0` warnings/errors. The last acceptance step (a real calendar) is done by the user with their own link, following `agenda/README.md`.

---

## Self-Review

- **Spec coverage:** secret-iCal fetch, `uv` PEP 723 script, deps, 15-min sync + startup sync + refresh on island open (Task 3), window 45/120 (Task 2), project-local config/cache + git-ignore refusal (Task 2 `ensure_not_tracked`), JSON contract (Tasks 1–2), time zones / all-day / multi-day / recurrence / cancelled / title / `sub` rules (Task 1), per-calendar and total failure behaviour, atomic `0600` writes, `--check`/`--stdout`, exit codes 2/3, redirects ≤ 3, 20 s/20 MB limits (Task 2), URL never printed (tests in Task 2), QML `FileView`+`Process`+status, "Offline" and "Calendar not set up" (Task 3). Not built on purpose (spec "out of scope"): OAuth, writing, notifications, lock-screen events, per-calendar colours.
- **Placeholders:** none; every step has code or an exact command.
- **Type consistency:** `normalize`/`run_sync`/`main` signatures, `Calendar`/`Config` fields, `status` values and exit codes match across Tasks 1–3 and the spec.
- **Review Focus:** each of the five lines is pinned by a named test or a verification step (multi-day exclusive end; EXDATE + RECURRENCE-ID; URL redaction tests; failed-calendar and all-failed tests; garbage-feed, oversize and timeout tests; corrupt-cache QML step).
