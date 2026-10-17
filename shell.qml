import Quickshell
import QtQuick
import "bar"
import "clipboard"
import "dropdown"
import "island"
import "launcher"
import "lock"
import "notifications"
import "resources"
import "usage"
import "wallpaper"
import "services"

ShellRoot {
    // Referencing the service starts its D-Bus notification server with the shell, not on first use.
    property bool notificationsActive: Notifications.active

    // Same for the dropdown and power services (their IPC handlers live there).
    property bool dropdownActive: Dropdown.active && Power.active && Net.active && Bt.active && Sound.active

    // The resource history (CPU / RAM / GPU graphs) starts with the shell.
    property bool resourcesActive: Resources.active

    // The wallpaper model (folder, state, IPC) starts with the shell.
    property bool wallpaperActive: Wallpaper.active

    SystemStats {
        id: systemStats
    }

    Bar {}
    DropdownHost {}
    Island {}
    Launcher {}
    ClipboardCard {}
    ResourcePanel {}
    NotificationCenter {}
    UsageCard {}
    WallpaperStage {}
    WallpaperPicker {}
    Lock {}
}
