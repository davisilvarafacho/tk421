.pragma library

// Power actions of the bar menu and the commands they run. Pure: nothing here executes anything.
// Tested by tests/qml/tst_power.qml.
//
// Glyphs are Font Awesome codepoints from the Symbols Nerd Font.

var ACTIONS = [
    { id: "lock",     label: "Lock",      hint: "Super L", glyph: "", confirm: false, hud: "Locking",      gap: false },
    { id: "suspend",  label: "Suspend",   hint: "",        glyph: "", confirm: false, hud: "Suspending",   gap: false },
    { id: "logout",   label: "Log out",   hint: "",        glyph: "", confirm: true,  hud: "Logging out",  gap: true },
    { id: "reboot",   label: "Restart",   hint: "",        glyph: "", confirm: true,  hud: "Restarting",   gap: false },
    { id: "poweroff", label: "Power off", hint: "",        glyph: "", confirm: true,  hud: "Powering off", gap: false }
]

function isDestructive(id) {
    for (var i = 0; i < ACTIONS.length; i++) {
        if (ACTIONS[i].id === id)
            return ACTIONS[i].confirm
    }
    return false
}

function shellQuote(text) {
    return "'" + String(text).replace(/'/g, "'\\''") + "'"
}

// argv for an action, or null for an unknown id. Lock keeps the existing fallbacks (the Quickshell lock, then hyprlock);
// log out is the user's own command from hyprland.lua.
function commandFor(id, shellPath) {
    switch (id) {
    case "lock":
        return ["sh", "-c", "quickshell ipc -p " + shellQuote(shellPath) + " call lock lock || pidof hyprlock || hyprlock"]
    case "suspend":
        return ["systemctl", "suspend"]
    case "logout":
        return ["sh", "-c", "command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"]
    case "reboot":
        return ["systemctl", "reboot"]
    case "poweroff":
        return ["systemctl", "poweroff"]
    }
    return null
}
