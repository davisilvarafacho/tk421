"""Sync Google Calendar secret-iCal feeds into agenda/cache/agenda.json.

Never print, log or embed a calendar URL in an error: it is a secret.
"""

from __future__ import annotations

import argparse
import http.client
import json
import os
import subprocess
import sys
import tempfile
import time
import tomllib
import urllib.error
import urllib.request
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from pathlib import Path
from urllib.parse import urlparse
from zoneinfo import ZoneInfo

import icalendar
import recurring_ical_events

HERE = Path(__file__).resolve().parent
DEFAULT_CONFIG = HERE / "agenda.toml"
DEFAULT_CACHE = HERE / "cache" / "agenda.json"
LOCAL_TZ = ZoneInfo("America/Sao_Paulo")
MAX_BYTES = 20 * 1024 * 1024
MAX_DAYS = 3650
TOTAL_TIMEOUT = 60
CHUNK = 64 * 1024


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


def squash(value) -> str:
    """Event text is shown on a single line: collapse every run of whitespace (newlines, tabs) to one space."""
    return " ".join(str(value or "").split())


def place_text(component) -> str:
    """'Google Meet' if the event has a Meet link, else the first line of LOCATION (max 40 chars)."""
    location = str(component.get("LOCATION", "") or "").strip()
    description = str(component.get("DESCRIPTION", "") or "")
    if component.get("X-GOOGLE-CONFERENCE") or "meet.google.com" in f"{location} {description}":
        return "Google Meet"
    first = squash(location.splitlines()[0]) if location else ""
    return first if len(first) <= 40 else first[:39] + "…"


def _event_rows(comp, calendar_name: str, start: date, end: date, tz: ZoneInfo) -> list[dict]:
    if comp.name != "VEVENT":
        return []
    if str(comp.get("STATUS", "")).upper() == "CANCELLED":
        return []

    title = squash(comp.get("SUMMARY", "")) or "(No title)"
    place = place_text(comp)
    dtstart = comp.get("DTSTART").dt
    rows: list[dict] = []

    if isinstance(dtstart, datetime):
        began = to_local(dtstart, tz)
        if not (start <= began.date() <= end):
            return []
        finished = comp.end
        minutes = 0
        if isinstance(finished, datetime):
            minutes = int((to_local(finished, tz) - began).total_seconds() // 60)
        parts = [place, duration_text(minutes) if minutes > 0 else ""]
        rows.append({
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
            rows.append({
                "date": day.isoformat(), "allday": True, "time": "All day",
                "title": title, "sub": sub, "calendar": calendar_name,
            })
    return rows


def normalize(ics_text: str, calendar_name: str, start: date, end: date, tz: ZoneInfo) -> list[dict]:
    calendar = icalendar.Calendar.from_ical(ics_text)
    # An event without DTSTART cannot be placed (and makes the expansion raise): drop it up front.
    for sub in list(calendar.subcomponents):
        if sub.name == "VEVENT" and sub.get("DTSTART") is None:
            calendar.subcomponents.remove(sub)
    events: list[dict] = []

    window = recurring_ical_events.of(calendar, skip_bad_series=True).between(
        start - timedelta(days=1), end + timedelta(days=2)
    )
    for comp in window:
        try:  # one odd event must never sink the whole calendar
            events.extend(_event_rows(comp, calendar_name, start, end, tz))
        except Exception:
            continue

    events.sort(key=lambda e: (not e["allday"], e["time"], e["title"]))
    return events


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


def _days(table: dict, key: str, default: int) -> int:
    value = table.get(key, default)
    if isinstance(value, bool) or not isinstance(value, int) or not 0 <= value <= MAX_DAYS:
        raise ConfigError(f"[sync] {key} must be a whole number of days between 0 and {MAX_DAYS}")
    return value


def load_config(path: Path) -> Config:
    try:
        mode = path.stat().st_mode
    except FileNotFoundError:
        raise ConfigError(f"config not found: {path.name} (copy agenda.example.toml)") from None
    except OSError:
        raise ConfigError(f"cannot read {path.name}") from None
    if mode & 0o077:
        raise ConfigError(f"{path.name} is readable by other users; run: chmod 600 {path.name}")

    try:
        with path.open("rb") as handle:
            raw = tomllib.load(handle)
    except tomllib.TOMLDecodeError as exc:
        raise ConfigError(f"{path.name} is not valid TOML: {exc}") from None
    except UnicodeDecodeError:
        raise ConfigError(f"{path.name} is not valid UTF-8") from None
    except OSError:
        raise ConfigError(f"cannot read {path.name}") from None

    entries = raw.get("calendar", [])
    if not isinstance(entries, list) or not all(isinstance(e, dict) for e in entries):
        raise ConfigError("calendar must be a list of [[calendar]] tables")
    sync_cfg = raw.get("sync", {})
    if not isinstance(sync_cfg, dict):
        raise ConfigError("sync must be a [sync] table")

    calendars = []
    for entry in entries:
        name, url = entry.get("name", ""), entry.get("url", "")
        if not isinstance(name, str) or not name.strip():
            raise ConfigError("every [[calendar]] needs a non-empty name")
        if not isinstance(url, str) or not url.strip().startswith("https://"):
            raise ConfigError(f'calendar "{name.strip()}": url must start with https://')
        if "REPLACE_ME" in url:
            raise ConfigError(f'calendar "{name.strip()}": replace the placeholder link in the config')
        calendars.append(Calendar(name.strip(), url.strip()))
    if not calendars:
        raise ConfigError("no [[calendar]] entries found")

    return Config(calendars, _days(sync_cfg, "back_days", 45), _days(sync_cfg, "forward_days", 120))


def ensure_not_tracked(paths: list[Path]) -> None:
    """Refuse to run if git would track a secret/cache file. Silently skipped outside a git checkout."""
    for path in paths:
        path = path.absolute()
        base = path.parent
        while not base.exists() and base != base.parent:
            base = base.parent  # first run: the cache directory may not exist yet
        try:
            result = subprocess.run(
                ["git", "check-ignore", "-q", "--", str(path)],
                cwd=base,
                capture_output=True,
            )
        except FileNotFoundError:
            return
        if result.returncode == 1:
            raise ConfigError(f"{path.name} is not git-ignored; add it to .gitignore first")


class _FewRedirects(urllib.request.HTTPRedirectHandler):
    max_redirections = 3

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        if urlparse(newurl).scheme != "https":
            raise FetchError("redirect to non-https")
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def fetch_ics(url: str, timeout: float = 20, max_bytes: int = MAX_BYTES, total_timeout: float = TOTAL_TIMEOUT) -> str:
    """Download the feed. `timeout` is per socket operation; `total_timeout` bounds the whole download."""
    deadline = time.monotonic() + total_timeout
    try:
        if any(ch.isspace() or ord(ch) < 32 for ch in url):
            raise ValueError
        urlparse(url).port  # raises ValueError for a malformed port or bracket
        opener = urllib.request.build_opener(_FewRedirects)
        request = urllib.request.Request(url, headers={"User-Agent": "tk421-agenda/1"})
        chunks: list[bytes] = []
        size = 0
        with opener.open(request, timeout=timeout) as response:
            while True:
                if time.monotonic() > deadline:
                    raise FetchError("timeout")
                chunk = response.read1(CHUNK)
                if not chunk:
                    break
                chunks.append(chunk)
                size += len(chunk)
                if size > max_bytes:
                    raise FetchError("response too large")
        data = b"".join(chunks)
    except FetchError:
        raise
    except urllib.error.HTTPError as exc:
        raise FetchError(f"HTTP {exc.code}") from None
    except TimeoutError:
        raise FetchError("timeout") from None
    except urllib.error.URLError as exc:
        reason = exc.reason
        raise FetchError("timeout" if isinstance(reason, TimeoutError) or "timed out" in str(reason) else "network error") from None
    except (ValueError, http.client.HTTPException):
        raise FetchError("bad url") from None
    except OSError:
        raise FetchError("network error") from None
    return data.decode("utf-8", "replace")


_EVENT_STR_KEYS = ("date", "time", "title", "sub", "calendar")


def _valid_event(event) -> bool:
    return (
        isinstance(event, dict)
        and all(isinstance(event.get(key), str) for key in _EVENT_STR_KEYS)
        and isinstance(event.get("allday"), bool)
    )


def _valid_cache(data) -> bool:
    return isinstance(data, dict) and isinstance(data.get("events"), list) and all(_valid_event(e) for e in data["events"])


def read_cache(path: Path) -> dict | None:
    """The previous cache, or None when it is missing, unreadable, corrupt or of the wrong shape."""
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None
    return data if _valid_cache(data) else None


def write_cache(path: Path, data: dict) -> None:
    created = not path.parent.exists()
    path.parent.mkdir(parents=True, exist_ok=True)
    if created:  # never change the mode of a directory we did not create
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
    old_events = previous["events"] if _valid_cache(previous) else []

    events: list[dict] = []
    statuses: list[dict] = []
    for cal in config.calendars:
        try:
            text = fetcher(cal.url).lstrip("\ufeff \t\r\n")
            if not text.startswith("BEGIN:VCALENDAR"):
                raise FetchError("not an iCal feed: copy the 'Secret address in iCal format' from Google Calendar")
            events.extend(normalize(text, cal.name, start, end, tz))
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
