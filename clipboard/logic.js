.pragma library
.import "../launcher/Fuzzy.js" as Fuzzy

// Pure rules of the clipboard archive. Records come from `cliphist list`: one "id<TAB>preview" per line, newest first.

var LIMIT = 50
var TEXT_BYTES = 4000

var BINARY = /^\[\[ binary data (\d+(?:\.\d+)? \S+) (\w+) (\d+)x(\d+) \]\]$/
var LINK = /^(https?:\/\/|www\.)\S+$/i
var CODE = /(=>|&&|\|\||[{};]|\$\(|^(sudo|git|npm|pnpm|cd|ls|cat|pacman|paru|systemctl|docker|ssh|curl)\s)/

// Control and bidirectional override/isolate characters never reach the screen; newline and tab stay.
function clean(text) {
    return String(text === undefined || text === null ? "" : text)
        .replace(/[\u0000-\u0008\u000B-\u001F\u007F-\u009F‪-‮⁦-⁩]/g, "")
}

// text: the whole stdout of `cliphist list`.
function parseList(text) {
    var out = []
    var lines = String(text || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
        var tab = lines[i].indexOf("\t")
        if (tab < 1)
            continue
        var id = parseInt(lines[i].slice(0, tab), 10)
        if (isNaN(id))
            continue
        out.push(record(id, lines[i].slice(tab + 1)))
    }
    return out
}

function record(id, preview) {
    var p = clean(preview).replace(/\s+/g, " ").trim()
    var img = BINARY.exec(p)
    if (img) {
        var fmt = img[2].toUpperCase()
        return { id: id, kind: "image", preview: p, name: "Image " + fmt,
                 meta: fmt + " · " + img[3] + "×" + img[4], size: img[1] }
    }
    var kind = LINK.test(p) ? "link" : CODE.test(p) ? "code" : "text"
    return { id: id, kind: kind, preview: p, name: p, meta: kind.toUpperCase(), size: "" }
}

// Newest first when there is no query; otherwise best match first. Returns [{ rec, name, idx }].
function rank(records, query, limit) {
    var q = String(query || "").trim()
    var out = []
    for (var i = 0; i < records.length; i++) {
        var m = Fuzzy.match(records[i].name, q)
        if (m)
            out.push({ rec: records[i], name: records[i].name, idx: m.idx, score: m.score, order: i })
    }
    if (q)
        out.sort(function (a, b) { return (b.score - a.score) || (a.order - b.order) })
    return out.slice(0, limit === undefined ? LIMIT : limit)
}

// Preview text: cleaned, at most `lines` lines.
function previewText(text, lines) {
    var parts = clean(text).replace(/\r/g, "").split("\n")
    return parts.slice(0, lines).join("\n")
}

function recordLabel(n) {
    return String(n).padStart(2, "0")
}
