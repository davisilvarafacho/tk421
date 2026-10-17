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


def test_load_config_rejects_the_placeholder_link(tmp_path):
    body = '[[calendar]]\nname = "Pessoal"\nurl = "https://calendar.google.com/calendar/ical/REPLACE_ME/basic.ics"\n'
    with pytest.raises(sync.ConfigError) as err:
        sync.load_config(write_toml(tmp_path / "a.toml", body))
    assert "replace the placeholder link" in str(err.value)


def test_load_config_missing_file(tmp_path):
    with pytest.raises(sync.ConfigError):
        sync.load_config(tmp_path / "nope.toml")


BAD_SHAPES = [
    (GOOD + '[sync]\nback_days = "abc"\n', "back_days"),
    (GOOD + "[sync]\nback_days = [1]\n", "back_days"),
    (GOOD + "[sync]\nforward_days = 1000000000\n", "forward_days"),
    (GOOD + "[sync]\nback_days = -1\n", "back_days"),
    (GOOD + "[sync]\nforward_days = 1.5\n", "forward_days"),
    (GOOD + "[sync]\nback_days = true\n", "back_days"),
    ('calendar = "x"\n', "calendar"),
    ('calendar = ["x"]\n', "calendar"),
    ("sync = 5\n" + GOOD, "sync"),
    ('[[calendar]]\nname = 5\nurl = "https://x.test/a.ics"\n', "name"),
    ("[[calendar]]\nname = 'x'\nurl = 5\n", "https"),
]


@pytest.mark.parametrize("body, fragment", BAD_SHAPES)
def test_load_config_wrong_shapes_raise_config_error(tmp_path, body, fragment):
    with pytest.raises(sync.ConfigError) as err:
        sync.load_config(write_toml(tmp_path / "a.toml", body))
    assert fragment in str(err.value)
    assert SECRET not in str(err.value)


@pytest.mark.parametrize("body, fragment", BAD_SHAPES)
def test_main_returns_2_for_wrong_shaped_config(tmp_path, capsys, body, fragment):
    cfg = write_toml(tmp_path / "agenda.toml", body)
    cache = tmp_path / "cache" / "agenda.json"
    assert sync.main(["--config", str(cfg), "--cache", str(cache), "--check"], fetcher=lambda u: ICS_OK, now=NOW) == 2
    captured = capsys.readouterr()
    assert fragment in captured.err and SECRET not in captured.out + captured.err


def test_load_config_accepts_boundary_values(tmp_path):
    cfg = sync.load_config(write_toml(tmp_path / "a.toml", GOOD + "[sync]\nback_days = 0\nforward_days = 3650\n"))
    assert (cfg.back_days, cfg.forward_days) == (0, 3650)


def test_load_config_non_utf8_file(tmp_path):
    path = tmp_path / "a.toml"
    path.write_bytes(b'[[calendar]]\nname = "\xff\xfe"\nurl = "https://x.test/a.ics"\n')
    os.chmod(path, 0o600)
    with pytest.raises(sync.ConfigError):
        sync.load_config(path)


def test_load_config_directory_and_unreadable_file(tmp_path):
    directory = tmp_path / "dir.toml"
    directory.mkdir(mode=0o700)
    with pytest.raises(sync.ConfigError):
        sync.load_config(directory)
    if os.geteuid() != 0:
        unreadable = write_toml(tmp_path / "locked.toml", GOOD, 0o200)
        with pytest.raises(sync.ConfigError):
            sync.load_config(unreadable)


def test_main_returns_2_for_non_utf8_and_directory_config(tmp_path):
    bad = tmp_path / "a.toml"
    bad.write_bytes(b"\xff\xfe\x00")
    os.chmod(bad, 0o600)
    directory = tmp_path / "dir.toml"
    directory.mkdir(mode=0o700)
    for target in (bad, directory):
        assert sync.main(["--config", str(target), "--cache", str(tmp_path / "c.json"), "--check"]) == 2


def git_repo(path: Path, gitignore: str = "") -> Path:
    path.mkdir()
    subprocess.run(["git", "init", "-q"], cwd=path, check=True)
    (path / ".gitignore").write_text(gitignore)
    return path


def test_ensure_not_tracked_checks_paths_whose_parent_does_not_exist(tmp_path, tmp_path_factory, monkeypatch):
    repo = git_repo(tmp_path / "repo")
    monkeypatch.chdir(tmp_path_factory.mktemp("elsewhere"))
    cache = repo / "cache" / "deeper" / "agenda.json"
    with pytest.raises(sync.ConfigError):
        sync.ensure_not_tracked([cache])
    (repo / ".gitignore").write_text("cache/\n")
    sync.ensure_not_tracked([cache])


def test_main_checks_the_cache_path_even_when_run_from_outside_the_repo(tmp_path, tmp_path_factory, monkeypatch):
    repo = git_repo(tmp_path / "repo", "agenda.toml\n")
    cfg = write_toml(repo / "agenda.toml", GOOD)
    cache = repo / "cache" / "agenda.json"
    monkeypatch.chdir(tmp_path_factory.mktemp("elsewhere"))
    args = ["--config", str(cfg), "--cache", str(cache)]
    assert sync.main(args, fetcher=lambda u: ICS_OK, now=NOW) == 2
    assert not cache.exists()
    (repo / ".gitignore").write_text("agenda.toml\ncache/\n")
    assert sync.main(args, fetcher=lambda u: ICS_OK, now=NOW) == 0
    assert cache.exists()


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
        if self.path.endswith("/redirect.ics"):
            self.send_response(302)
            self.send_header("Location", f"http://127.0.0.1:{self.server.server_address[1]}/{SECRET}/basic.ics")
            self.end_headers()
            return
        if self.path.endswith("/slow.ics"):
            time.sleep(1.0)
        if self.path.endswith("/trickle.ics"):
            self.send_response(200)
            self.send_header("Content-Length", "100000")
            self.end_headers()
            try:
                for _ in range(100):
                    self.wfile.write(b"x")
                    self.wfile.flush()
                    time.sleep(0.2)
            except OSError:
                pass
            return
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


def test_fetch_total_deadline_stops_a_trickling_server(server):
    started = time.monotonic()
    with pytest.raises(sync.FetchError) as err:
        sync.fetch_ics(f"{server}/trickle.ics", timeout=5, total_timeout=0.8)
    assert str(err.value) == "timeout"
    assert time.monotonic() - started < 3


@pytest.mark.parametrize("url", ["https://exa mple.com/a b.ics", "https://[::1/x.ics", "https://x.test:99999999/a.ics"])
def test_fetch_malformed_url_is_a_constant_bad_url_error(url):
    with pytest.raises(sync.FetchError) as err:
        sync.fetch_ics(url)
    assert str(err.value) == "bad url"


def test_fetch_refuses_redirect_to_non_https(server):
    with pytest.raises(sync.FetchError) as err:
        sync.fetch_ics(f"{server}/redirect.ics")
    assert "non-https" in str(err.value)
    assert SECRET not in str(err.value) and "127.0.0.1" not in str(err.value)


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


def test_run_sync_marks_a_calendar_with_a_bad_event_ok():
    bad = ICS_OK.replace("END:VCALENDAR\r\n", "BEGIN:VEVENT\r\nUID:b\r\nSUMMARY:no start\r\nEND:VEVENT\r\n"
                         "BEGIN:VEVENT\r\nUID:c\r\nDTSTART:20261012T130000Z\r\nRRULE:FREQ=SOMETIMES\r\nSUMMARY:x\r\nEND:VEVENT\r\n"
                         "END:VCALENDAR\r\n")
    out, failed = sync.run_sync(CONFIG, None, NOW, sync.LOCAL_TZ, fetcher=lambda url: bad)
    assert failed is False
    assert [c["ok"] for c in out["calendars"]] == [True, True]
    assert {e["title"] for e in out["events"]} == {"Daily"}


def test_a_web_page_instead_of_an_ics_feed_gets_a_clear_message_and_keeps_old_events():
    # Pasting the browser address of Google Calendar returns the HTML app, not an iCal feed.
    html = "<!doctype html><html><head><title>Google Calendar</title></head></html>"
    out, failed = sync.run_sync(CONFIG, previous_cache(), NOW, sync.LOCAL_TZ, fetcher=lambda url: html)
    assert failed is True
    errors = {c["error"] for c in out["calendars"]}
    assert errors == {"not an iCal feed: copy the 'Secret address in iCal format' from Google Calendar"}
    assert {e["title"] for e in out["events"]} == {"Old A", "Old B"}
    assert "http" not in json.dumps(out["calendars"])


def test_a_byte_order_mark_before_the_calendar_is_accepted():
    out, failed = sync.run_sync(CONFIG, None, NOW, sync.LOCAL_TZ, fetcher=lambda url: "\ufeff" + ICS_OK)
    assert failed is False and [c["ok"] for c in out["calendars"]] == [True, True]


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


@pytest.mark.parametrize("content", ["[1]", '{"events": null}', '{"events": [5]}', '{"events": {}}', '"x"', "{}"])
def test_read_cache_rejects_wrong_shapes(tmp_path, content):
    path = tmp_path / "c.json"
    path.write_text(content)
    assert sync.read_cache(path) is None


def test_read_cache_accepts_a_valid_cache(tmp_path):
    path = tmp_path / "c.json"
    data = {"version": 1, "events": previous_cache()["events"]}
    path.write_text(json.dumps(data))
    assert sync.read_cache(path) == data


@pytest.mark.parametrize("content", ["[1]", '{"events": null}', '{"events": [5]}'])
def test_corrupt_cache_is_treated_as_no_cache_by_main(tmp_path, content):
    cache = tmp_path / "cache" / "agenda.json"
    cache.parent.mkdir()
    cache.write_text(content)

    def b_fails(url):
        if "example.com" in url:
            raise sync.FetchError("timeout")
        return ICS_OK

    cfg = write_toml(tmp_path / "agenda.toml", GOOD)
    assert sync.main(["--config", str(cfg), "--cache", str(cache)], fetcher=b_fails, now=NOW) == 3
    assert sync.main(["--config", str(cfg), "--cache", str(cache)], fetcher=lambda u: ICS_OK, now=NOW) == 0
    assert json.loads(cache.read_text())["events"][0]["title"] == "Daily"


FULL_EVENT = {"date": "2026-10-12", "allday": False, "time": "09:00", "title": "Old", "sub": "", "calendar": "Pessoal"}
BAD_EVENTS = (
    [{k: v for k, v in FULL_EVENT.items() if k != key} for key in FULL_EVENT]
    + [{**FULL_EVENT, "date": 20261012}, {**FULL_EVENT, "title": None}, {**FULL_EVENT, "allday": 0}, {**FULL_EVENT, "allday": "no"}]
    + [{"calendar": "A"}]
)


@pytest.mark.parametrize("event", BAD_EVENTS)
def test_read_cache_rejects_events_that_break_the_contract(tmp_path, event):
    path = tmp_path / "c.json"
    path.write_text(json.dumps({"version": 1, "events": [event]}))
    assert sync.read_cache(path) is None


@pytest.mark.parametrize("event", BAD_EVENTS)
def test_main_self_heals_from_contract_breaking_cache(tmp_path, event):
    cache = tmp_path / "cache" / "agenda.json"
    cache.parent.mkdir()
    cache.write_text(json.dumps({"version": 1, "events": [event]}))
    cfg = write_toml(tmp_path / "agenda.toml", GOOD)

    def boom(url):
        raise sync.FetchError("timeout")

    args = ["--config", str(cfg), "--cache", str(cache)]
    assert sync.main(args, fetcher=boom, now=NOW) == 3
    assert sync.main(args, fetcher=lambda u: ICS_OK, now=NOW) == 0
    assert sync.read_cache(cache)["events"][0]["title"] == "Daily"


def test_run_sync_with_contract_breaking_previous_and_failing_calendar():
    def boom(url):
        raise sync.FetchError("timeout")

    out, failed = sync.run_sync(CONFIG, {"events": [{"calendar": "A"}]}, NOW, sync.LOCAL_TZ, fetcher=boom)
    assert failed is True and out["events"] == []


@pytest.mark.parametrize("previous", [[1], {"events": None}, {"events": [5]}])
def test_run_sync_tolerates_corrupt_previous(previous):
    def fetcher(url):
        if "b.test" in url:
            raise sync.FetchError("HTTP 500")
        return ICS_OK

    out, failed = sync.run_sync(CONFIG, previous, NOW, sync.LOCAL_TZ, fetcher=fetcher)
    assert failed is False and [e["calendar"] for e in out["events"]] == ["A"]


def test_write_cache_only_chmods_a_directory_it_created(tmp_path):
    existing = tmp_path / "existing"
    existing.mkdir()
    os.chmod(existing, 0o755)
    sync.write_cache(existing / "agenda.json", {"events": []})
    assert oct(existing.stat().st_mode & 0o777) == "0o755"

    sync.write_cache(tmp_path / "fresh" / "agenda.json", {"events": []})
    assert oct((tmp_path / "fresh").stat().st_mode & 0o777) == "0o700"


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
