.pragma library

// Material Symbols Sharp icon table. `name` is what code uses; `glyph` is the
// ligature the font turns into one icon. Defaults: weight 300, fill 0, scale 1.
// FILL is never a state signal: only the exceptions below set it.
// Virtual names (mic_muted, radio_checked) map to another glyph.

var DEFAULT = { weight: 300, fill: 0, scale: 1, slash: false }

var PLAIN = [
    "volume_up", "volume_off", "mic", "bluetooth", "notifications", "notifications_paused",
    "keyboard", "lock", "lock_open", "bedtime", "logout", "restart_alt", "arrow_forward",
    "refresh", "calendar_today", "music_note", "chevron_left", "chevron_right", "expand_more",
    "check", "close", "headphones", "videocam", "tv", "speaker", "mouse", "smartphone",
    "sports_esports", "content_paste", "content_copy", "delete", "link", "code",
    "description", "auto_awesome", "wallpaper", "calculate", "web_asset", "add", "keep", "keep_off"
]

var EXCEPTIONS = {
    "mic_muted":          { glyph: "mic", slash: true },
    "lan":                { scale: 0.94 },
    "wifi":               { weight: 200 },
    "wifi_off":           { weight: 200 },
    "power_settings_new": { scale: 0.94 },
    "play_arrow":         { fill: 1, scale: 1.07 },
    "pause":              { fill: 1 },
    "skip_previous":      { fill: 1 },
    "skip_next":          { fill: 1 },
    "radio_checked":      { glyph: "circle", fill: 1, scale: 0.6 }
}

function has(o, k) {
    return Object.prototype.hasOwnProperty.call(o, k)
}

function build(name, over) {
    return {
        glyph: has(over, "glyph") ? over.glyph : name,
        weight: has(over, "weight") ? over.weight : DEFAULT.weight,
        fill: has(over, "fill") ? over.fill : DEFAULT.fill,
        scale: has(over, "scale") ? over.scale : DEFAULT.scale,
        slash: has(over, "slash") ? over.slash : DEFAULT.slash
    }
}

// {glyph, weight, fill, scale, slash}, or null for an unknown name
// (including undefined, empty and any string with a private-use character).
function resolve(name) {
    if (typeof name !== "string" || name === "")
        return null
    if (has(EXCEPTIONS, name))
        return build(name, EXCEPTIONS[name])
    if (PLAIN.indexOf(name) >= 0)
        return build(name, {})
    return null
}

function known() {
    return PLAIN.concat(Object.keys(EXCEPTIONS))
}
