# Agenda (Google Calendar via secret iCal link)

Read-only. The island shows the events of the selected day; `sync.py` fetches them every 15 minutes.
The Python part is a `uv` project (`pyproject.toml` + `uv.lock`); `uv` installs the dependencies into `agenda/.venv` by itself.

## What is the iCal link?
iCal (`.ics`) is the standard format calendars use to exchange events. Google Calendar can give you a **private web address** that returns your calendar's events as plain text in that format. `sync.py` reads that address; it needs no Google login and cannot change anything in your calendar. **Anyone who has the address can read your whole calendar**, so treat it like a password.

## Setup
1. Google Calendar (on the web) → ⚙ Settings → in the left list, click your calendar → **Integrate calendar** → copy **Secret address in iCal format**.
2. From the project folder: `install -m 600 agenda/agenda.example.toml agenda/agenda.toml`, then `nvim agenda/agenda.toml` and replace the placeholder link. Never paste the link into a chat or a shell command.
3. Test: `cd agenda && uv run sync.py --check` (prints event counts, never the link; the first run installs the dependencies).
4. The island picks the data up on the next sync, or run `qs ipc -p <repo>/shell.qml call agenda sync`.

## Troubleshooting
- Island says **Calendar not set up** → `sync.py` exited with a config error; run `cd agenda && uv run sync.py --check`.
- Island says **Offline** → the last fetch failed, or the script could not start or crashed (for example `uv` is missing); old events stay visible. Run the same `--check` command to see why.
- New events take hours to appear → normal: Google updates the iCal feed slowly.
- Link leaked → Google Calendar settings → **Reset** next to the secret address, then update `agenda.toml`.

## Files
`pyproject.toml` / `uv.lock` (uv project), `sync.py` (script), `agenda.toml` (secret, git-ignored), `cache/agenda.json` (git-ignored), `.venv/` (git-ignored), `tests/`.
Run the tests with: `cd agenda && uv run pytest tests -q`.
