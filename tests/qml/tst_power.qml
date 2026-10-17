import QtQuick
import QtTest

import "../../dropdown/power.js" as Power

TestCase {
    name: "PowerLogic"

    function ids() {
        return Power.ACTIONS.map(a => a.id)
    }

    function test_actions_are_in_menu_order() {
        compare(ids().join(","), "lock,suspend,logout,reboot,poweroff")
    }

    function test_only_logout_reboot_poweroff_are_destructive() {
        compare(Power.isDestructive("lock"), false)
        compare(Power.isDestructive("suspend"), false)
        compare(Power.isDestructive("logout"), true)
        compare(Power.isDestructive("reboot"), true)
        compare(Power.isDestructive("poweroff"), true)
        compare(Power.isDestructive("nope"), false)
    }

    function test_actions_carry_the_flags_the_ui_needs() {
        for (const a of Power.ACTIONS) {
            compare(a.confirm, Power.isDestructive(a.id), a.id)
            verify(a.label.length > 0, a.id)
            verify(a.glyph.length > 0, a.id)
            verify(a.hud.length > 0, a.id)
        }
        compare(Power.ACTIONS[0].hint, "Super L")
        compare(Power.ACTIONS[2].gap, true)               // 8 px gap before "Log out"
        compare(Power.ACTIONS[1].gap, false)
    }

    function test_systemctl_commands() {
        compare(JSON.stringify(Power.commandFor("suspend", "/x/shell.qml")), '["systemctl","suspend"]')
        compare(JSON.stringify(Power.commandFor("reboot", "/x/shell.qml")), '["systemctl","reboot"]')
        compare(JSON.stringify(Power.commandFor("poweroff", "/x/shell.qml")), '["systemctl","poweroff"]')
    }

    function test_logout_uses_the_users_own_command() {
        const c = Power.commandFor("logout", "/x/shell.qml")
        compare(c[0], "sh")
        compare(c[1], "-c")
        compare(c[2], "command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'")
    }

    function test_lock_goes_through_the_quickshell_ipc_with_fallbacks() {
        const c = Power.commandFor("lock", "/home/tk421/Development/quickshell/shell.qml")
        compare(c[0], "sh")
        compare(c[2], "quickshell ipc -p '/home/tk421/Development/quickshell/shell.qml' call lock lock || pidof hyprlock || hyprlock")
    }

    function test_shell_path_is_quoted_safely() {
        const c = Power.commandFor("lock", "/a b/it's/shell.qml")
        verify(c[2].indexOf("-p '/a b/it'\\''s/shell.qml' call lock lock") >= 0, c[2])
    }

    function test_unknown_action_has_no_command() {
        compare(Power.commandFor("hibernate", "/x"), null)
        compare(Power.commandFor("", "/x"), null)
        compare(Power.commandFor(undefined, "/x"), null)
    }
}
