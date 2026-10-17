.pragma library

// Pure rules for the system tray. Tested by tests/qml/tst_traylogic.qml.

// items: [{ id, passive, attention }]. The first `max` non-passive items are shown; the rest of the non-passive ones and
// every passive one go behind the chevron (arrival order kept). A passive item that asks for attention still lives there,
// but flags the chevron.
function partition(items, max) {
    var active = [], passive = []
    for (var i = 0; i < items.length; i++)
        (items[i].passive ? passive : active).push(items[i])

    var visible = active.slice(0, max)
    var overflow = active.slice(max).concat(passive)
    var attention = false
    for (var j = 0; j < overflow.length; j++)
        attention = attention || !!overflow[j].attention

    return { visible: visible, overflow: overflow, overflowAttention: attention }
}

// Text from apps (titles, tooltips, menu labels): no control or bidi-override characters, one line, trimmed, clipped
// without cutting an emoji in half.
function cleanLabel(text, max) {
    var s = (text === undefined || text === null) ? "" : String(text)
    s = s.replace(/[\u0000-\u0008\u000B-\u001F\u007F‪-‮⁦-⁩]/g, "")
    s = s.replace(/\s*\n\s*/g, " ").trim()
    if (s.length <= max)
        return s

    var end = max - 1
    var code = s.charCodeAt(end - 1)
    if (code >= 0xD800 && code <= 0xDBFF)
        end -= 1
    return s.slice(0, end) + "…"
}

// entries: [{ separator, text }]. At most `max`, never starting or ending on a separator, never two in a row.
function limitEntries(entries, max) {
    var out = []
    for (var i = 0; i < entries.length && out.length < max; i++) {
        var e = entries[i]
        if (e.separator && (out.length === 0 || out[out.length - 1].separator))
            continue
        out.push(e)
    }
    while (out.length > 0 && out[out.length - 1].separator)
        out.pop()
    return out
}
