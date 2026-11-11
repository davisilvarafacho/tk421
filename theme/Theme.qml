pragma Singleton
import QtQuick

QtObject {
    id: root

    readonly property color background: "#CC111418"
    readonly property color border: "#39414D"
    readonly property color text: "#E8E6E3"
    readonly property color muted: "#858B95"
    readonly property string fontFamily: "Geist"
    readonly property string iconFont: "Symbols Nerd Font Mono"
    // The shell process may predate the font install (Qt reads the font list at start): FontLoader registers the file at runtime.
    readonly property FontLoader symbolsLoader: FontLoader { source: "file:///usr/share/fonts/TTF/MaterialSymbolsSharp%5BFILL,GRAD,opsz,wght%5D.ttf" }
    readonly property string symbolsFont: symbolsLoader.status === FontLoader.Ready ? symbolsLoader.font.family : "Material Symbols Sharp"
    readonly property var iconSize: ({ bar: 16, panel: 16, hero: 24 })
    readonly property string displayFont: "Orbitron"
    readonly property string monoFont: "Monaspace Neon"

    readonly property string wallpaper: "/home/tk421/Projects/tk421/theme-engine/collections/star-wars/imperial-destroyer/wallpaper.png"

    // Imperial Destroyer profile (tk421/TK421.md, section 24). Used by the lock screen.
    readonly property QtObject imperial: QtObject {
        readonly property color bg: "#050505"
        readonly property color surface: "#0C0B0D"
        readonly property color surfaceAlt: "#1A1A21"
        readonly property color text: "#E8E6E3"
        readonly property color muted: "#8E8B88"
        readonly property color accent: "#506A9B"
        readonly property color accentDim: "#29384F"
        readonly property color danger: "#A14D55"
        readonly property color dangerText: "#D9808A"
        readonly property color border: "#3F3E44"
    }
}
