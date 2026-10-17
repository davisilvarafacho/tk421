#!/usr/bin/env python3
"""Plan limits of the signed-in Claude Code account, as one line of JSON on stdout.

Reads the OAuth access token Claude Code keeps in ~/.claude/.credentials.json and asks the (undocumented)
usage endpoint for the 5 h session and 7 d week utilisation, the same numbers `/usage` shows.

- The token is only ever sent to api.anthropic.com. It is never printed, logged or written anywhere.
- It never refreshes the token: the refresh token rotates, and doing it here could sign Claude Code out.
  An expired token is reported as `token_expired`; opening Claude Code renews it.
- Always exits 0. Failures are `{"ok": false, "error": "<code>"}` so the shell can show OFFLINE.
"""
import json
import os
import sys
import time
import urllib.error
import urllib.request

CREDENTIALS = os.path.expanduser("~/.claude/.credentials.json")
URL = "https://api.anthropic.com/api/oauth/usage"
TIMEOUT = 15


def _entry(raw):
    """One limit window -> {percent, resetsAt}, or None when the account has no such window."""
    if not isinstance(raw, dict) or raw.get("utilization") is None:
        return None
    percent = max(0, min(100, round(float(raw["utilization"]))))
    return {"percent": percent, "resetsAt": raw.get("resets_at")}


def normalize(payload, plan=None, now=None):
    """API payload -> the shape the Quickshell service reads."""
    return {
        "ok": True,
        "plan": plan,
        "session": _entry(payload.get("five_hour")),
        "week": _entry(payload.get("seven_day")),
        "fetchedAt": int(now if now is not None else time.time()),
    }


def fail(code):
    return {"ok": False, "error": code}


def fetch():
    try:
        with open(CREDENTIALS) as f:
            oauth = json.load(f)["claudeAiOauth"]
        token = oauth["accessToken"]
    except (OSError, ValueError, KeyError, TypeError):
        return fail("no_credentials")

    expires = oauth.get("expiresAt")  # milliseconds since the epoch
    if isinstance(expires, (int, float)) and expires / 1000 < time.time():
        return fail("token_expired")

    request = urllib.request.Request(
        URL,
        headers={
            "Authorization": "Bearer " + token,
            "anthropic-beta": "oauth-2025-04-20",
            "User-Agent": "tk421-quickshell/0.1",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
            payload = json.load(response)
    except urllib.error.HTTPError as e:
        if e.code in (401, 403):
            return fail("unauthorized")
        if e.code == 429:
            return fail("rate_limited")
        return fail("http_%d" % e.code)
    except (urllib.error.URLError, TimeoutError, OSError):
        return fail("network")
    except ValueError:
        return fail("bad_response")

    if not isinstance(payload, dict):
        return fail("bad_response")
    return normalize(payload, oauth.get("subscriptionType"))


if __name__ == "__main__":
    sys.stdout.write(json.dumps(fetch()) + "\n")
