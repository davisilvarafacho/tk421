.pragma library

// Pure helpers for the Claude usage widget (no QML types, so they can be run with plain node).

// Time left until `resetsAt` as "2 h 14 min", "38 min", "1 d 3 h", or "< 1 min". `now` is a ms timestamp.
function remaining(resetsAt, now) {
    const ms = new Date(resetsAt).getTime() - now
    if (isNaN(ms))
        return ""
    if (ms < 60 * 1000)
        return "< 1 min"

    const minutes = Math.floor(ms / 60000)
    const days = Math.floor(minutes / 1440)
    const hours = Math.floor((minutes % 1440) / 60)
    const mins = minutes % 60

    if (days > 0)
        return days + " d " + hours + " h"
    if (hours > 0)
        return hours + " h " + mins + " min"
    return mins + " min"
}

// "just now", "12 s ago", "3 min ago", "2 h ago". `at` and `now` are ms timestamps.
function ago(at, now) {
    const s = Math.max(0, Math.floor((now - at) / 1000))
    if (s < 5)
        return "just now"
    if (s < 60)
        return s + " s ago"
    if (s < 3600)
        return Math.floor(s / 60) + " min ago"
    return Math.floor(s / 3600) + " h ago"
}

// Human text for the error codes usage/fetch.py reports.
function errorText(code) {
    switch (code) {
    case "no_credentials":
        return "Claude Code credentials were not found. Sign in with Claude Code, then refresh."
    case "token_expired":
    case "unauthorized":
        return "Your Claude Code login expired. Open Claude Code once to renew it, then refresh."
    case "network":
        return "No connection to Anthropic. It will retry on its own."
    case "rate_limited":
        return "Too many requests. Try again in a few minutes."
    default:
        return "Could not read the plan limits."
    }
}
