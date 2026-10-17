.pragma library

// Substring match first, then subsequence. Contiguous runs and word starts rank higher, shorter names win ties.
// Returns { score, idx } (idx = matched character positions) or null.
function match(name, query) {
    if (!query)
        return { score: 0, idx: [] }

    const n = name.toLowerCase()
    const q = query.toLowerCase()

    const at = n.indexOf(q)
    if (at !== -1) {
        const idx = []
        for (let i = 0; i < q.length; i++)
            idx.push(at + i)
        return { score: 1000 - at * 4 - n.length, idx: idx }
    }

    const idx = []
    let from = 0
    let score = 0
    let prev = -2
    for (let k = 0; k < q.length; k++) {
        const i = n.indexOf(q[k], from)
        if (i === -1)
            return null
        score += (i === prev + 1 ? 8 : 0) + (i === 0 || n[i - 1] === " " ? 6 : 0) - (i - from)
        idx.push(i)
        prev = i
        from = i + 1
    }
    return { score: 400 + score - n.length, idx: idx }
}

// apps: DesktopEntry list. Empty query lists everything alphabetically.
function rank(apps, query, limit) {
    const q = query.trim()
    const out = []
    for (const a of apps) {
        const m = match(a.name, q)
        if (m)
            out.push({ entry: a, name: a.name, score: m.score, idx: m.idx })
    }
    out.sort(q
        ? (x, y) => (y.score - x.score) || x.name.localeCompare(y.name)
        : (x, y) => x.name.localeCompare(y.name))
    return out.slice(0, limit)
}

function escape(s) {
    return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
}

// StyledText markup: matched characters bold and coloured. Always escaped, names come from outside.
function markup(name, idx, color) {
    if (!idx.length)
        return escape(name)

    const hit = {}
    for (const i of idx)
        hit[i] = true

    let out = ""
    let open = false
    for (let i = 0; i < name.length; i++) {
        if (hit[i] && !open) {
            out += "<font color=\"" + color + "\"><b>"
            open = true
        } else if (!hit[i] && open) {
            out += "</b></font>"
            open = false
        }
        out += escape(name[i])
    }
    return open ? out + "</b></font>" : out
}

// Monogram for the icon tile: two words -> their initials, one word -> first two letters.
function initials(name) {
    const words = name.trim().split(/\s+/).filter(w => w.length > 0)
    if (words.length === 0)
        return ""
    if (words.length === 1)
        return words[0][0].toUpperCase() + (words[0][1] || "").toLowerCase()
    return (words[0][0] + words[1][0]).toUpperCase()
}
