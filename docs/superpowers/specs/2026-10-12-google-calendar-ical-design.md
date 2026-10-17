# Google Calendar (iCal) integration — Design

## Goal

Show the user's Google Calendar events in the Dynamic Island agenda (`island/AgendaPane.qml`), reading Google's **secret iCal address** with a small Python script. Read-only. No OAuth, no Google Cloud project.

Success: opening the island shows today's real events, the calendar grid shows a dot on days that have events, month navigation works across a few months, and a network failure never breaks the island.

## Decisions (defaults chosen; change any of them before implementation)

| Decision | Value |
|---|---|
| Access method | Secret iCal URL (Google Calendar → Settings → the calendar → *Integrate calendar* → *Secret address in iCal format*) |
| Language / runner | `uv` project in `agenda/` (`pyproject.toml` + `uv.lock`, dependencies in `agenda/.venv`), run by `uv run --quiet --project agenda agenda/sync.py` (no system install) |
| Dependencies | `icalendar`, `recurring-ical-events`; HTTP via stdlib `urllib` |
| Sync interval | Every 15 min, plus once at Quickshell startup |
| Event window | 45 days back to 120 days forward (covers month navigation) |
| Calendars | One or more URLs, merged into one list, one accent colour |
| Secret storage | `agenda/agenda.toml` inside this project, mode `0600`, **git-ignored** (a committed `agenda/agenda.example.toml` shows the format) |
| Cache file | `agenda/cache/agenda.json` inside this project, mode `0600`, git-ignored |

## Architecture

```
Google (HTTPS .ics) ──> agenda/sync.py ──> agenda/cache/agenda.json ──> services/Agenda.qml ──> island/*
                         (uv, every 15 min)      (atomic write)              (FileView + Process)
```

- **Sync is separate from display.** The script only produces the JSON file. QML only reads the file. A broken network, a slow feed or a crashed script cannot freeze the shell.
- **Contract is the JSON file**, so the script and the QML can be built and tested independently.

### Files

- Create `agenda/sync.py` — the sync script — and `agenda/pyproject.toml` + `agenda/uv.lock` (the uv project that lists its dependencies).
- Create `agenda/tests/test_sync.py` and `agenda/tests/fixtures/*.ics`.
- Modify `services/Agenda.qml` — load the cache, run the script, expose status.
- Modify `island/AgendaPane.qml` — empty/offline messages only. The list and calendar dots already work from `Agenda.events`.
- Create `agenda/agenda.example.toml` (placeholder, committed) and `.gitignore` entries for `agenda/agenda.toml` and `agenda/cache/` (the `.gitignore` already exists).
- User copies the example to `agenda/agenda.toml` and pastes the real link (documented below).

## Config: `agenda/agenda.toml`

```toml
[[calendar]]
name = "Pessoal"
url  = "https://calendar.google.com/calendar/ical/<id>/private-<secret>/basic.ics"

# [[calendar]] blocks can be repeated for more calendars.

[sync]            # optional
back_days    = 45
forward_days = 120
```

- The script refuses to run (exit 2) if the file is readable by group/other. Fix: `chmod 600 agenda/agenda.toml`.
- The file sits inside the repository, so it **must** stay in `.gitignore`. The script also refuses to run if `git check-ignore` says the config or the cache would be tracked (skipped when the project is not a git checkout).
- URLs must be `https://`. Anything else is a config error.

## Output contract: `agenda/cache/agenda.json`

```json
{
  "version": 1,
  "generated_at": "2026-10-12T14:30:00-03:00",
  "window": { "from": "2026-08-28", "to": "2027-02-09" },
  "calendars": [ { "name": "Pessoal", "ok": true, "error": null } ],
  "events": [
    { "date": "2026-10-12", "allday": false, "time": "10:00",
      "title": "Daily", "sub": "Google Meet · 30 min", "calendar": "Pessoal" }
  ]
}
```

`events` items match what `Agenda.eventsOn()` already consumes (`date`, `allday`, `time`, `title`, `sub`), plus `calendar`.

### Event rules

- **Time zones:** timed events are converted to the machine's local zone (`America/Sao_Paulo`) with `zoneinfo`; floating times are treated as local.
- **All-day:** iCal `DATE` values; the end date is exclusive. A multi-day all-day event produces one entry per covered date, `allday: true`, `sub: "Day i of n"`.
- **Timed events** appear on their start date only, `time` = local `HH:mm`.
- **Recurrence:** expanded with `recurring-ical-events` (RRULE, EXDATE, RECURRENCE-ID overrides) inside the window.
- **Skipped:** `STATUS:CANCELLED`.
- **Title:** `SUMMARY`, or `"(No title)"` if empty.
- **`sub`:** parts joined by ` · `: place, then duration. Place = `Google Meet` if the event has a Meet link (`X-GOOGLE-CONFERENCE` or `meet.google.com` in description/location), else the first line of `LOCATION` cut to 40 characters. Duration for timed events, e.g. `30 min`, `1 h`, `1 h 30`. All-day single-day events use the calendar name if there is no location.
- **Order:** the QML sorts (all-day first, then by `time`); the script also emits them sorted.

## `agenda/sync.py` behaviour

- Fetch each URL with `urllib`: HTTPS only, 20 s timeout, 20 MB size cap, redirects limited.
- Parse, expand, normalise, then write the JSON **atomically** (temp file in the same directory, `chmod 600`, `os.replace`).
- **Per-calendar failure:** keep that calendar's events from the previous cache, mark it `ok: false` with a short error. Other calendars update normally.
- **Total failure:** leave the existing cache untouched and exit 3.
- Flags: `--check` (validate config, fetch, print counts, write nothing), `--stdout` (print JSON instead of writing).
- Exit codes: `0` ok, `2` config error, `3` all fetches failed.
- **The URL is a secret.** Never print it. Logs and errors show only the calendar name and the host.

## QML side

`services/Agenda.qml` (singleton):

- `FileView` on `agenda/cache/agenda.json` (path resolved from the QML file location) with `watchChanges`, parses to `events`, `calendars`, `generatedAt`.
- `Process` runs `uv run --quiet --project <repo>/agenda <repo>/agenda/sync.py`, started by a 15-minute `Timer` (and at startup). Never two at once (`running` guard). The first island open also triggers a sync if the cache is older than 5 minutes.
- Exposes `status`: `"ok"`, `"stale"` (last sync failed, showing old data), `"unconfigured"` (no config file), `"error"`.
- `eventsOn(d)` / `hasEvents(d)` keep their current signatures, so `CalendarPane` and `AgendaPane` need no logic changes.

UI (copy in English, like the rest of the system):

- Agenda header count area shows `Offline` (muted) when `status` is `stale` or `error`.
- Empty list text: `No events` normally, `Calendar not set up` when `unconfigured`.

## Security and privacy

- The secret iCal URL gives **read access to the whole calendar** to anyone who has it. It lives only in the `0600`, git-ignored config file; it is never logged, committed or passed on a command line (read from the file by the script).
- The cache holds event titles and places, so it is `0600` too.
- Events are shown on the island only, **not** on the lock screen.
- If the link leaks: in Google Calendar settings use *Reset* next to the secret address, then update the config.

## Testing

- **Python (`pytest`, run with `uv run --with pytest …`)** on fixture `.ics` files:
  - plain timed event, with and without location / Meet link
  - all-day event; multi-day all-day event (one entry per day)
  - weekly recurrence with an `EXDATE` and a `RECURRENCE-ID` override
  - UTC and `TZID` events converted to `America/Sao_Paulo`, including an event around a DST change
  - cancelled event skipped; missing `SUMMARY`
  - config with open file permissions rejected; non-HTTPS URL rejected
  - config or cache not git-ignored in a git checkout rejected
  - a local `http.server` for fetch success, timeout, 404 and oversize; per-calendar failure keeps old events; total failure leaves the cache unchanged
  - the URL never appears in output or error text
- **QML (manual):** place a hand-written `agenda.json` in the cache path and check the dots, the agenda, the overflow fade, `Offline` and `Calendar not set up`; then run with a real config.

## Known limitations

- **Google's iCal feed is slow to update.** Changes made in Google Calendar can take hours to appear in the secret-address feed, regardless of the 15-minute sync. This is the main downside of this method. If it becomes a problem, the upgrade path is OAuth with the Calendar API, with the same JSON contract so the QML does not change.
- Declined invitations cannot be told apart from accepted ones in this feed, so they appear too.
- Read-only: no creating or editing events, no reminders or notifications.
- Colours per calendar are not supported in v1 (all use the accent colour).

## Out of scope

OAuth and the Calendar API, writing events, notifications and alarms, attendee responses, showing events on the lock screen, per-calendar colours.
