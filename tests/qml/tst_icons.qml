import QtQuick
import QtTest

import "../../theme/icons.js" as Icons
import "../../components"

TestCase {
    id: tc
    name: "Icons"
    when: windowShown
    width: 100
    height: 100

    Component {
        id: iconComp
        Icon {}
    }

    function test_resolveDefaults() {
        compare(JSON.stringify(Icons.resolve("volume_up")),
                JSON.stringify({ glyph: "volume_up", weight: 300, fill: 0, scale: 1, slash: false }))
    }

    function test_resolveExceptions() {
        compare(Icons.resolve("wifi").weight, 200)
        compare(Icons.resolve("wifi_off").weight, 200)
        const pa = Icons.resolve("play_arrow")
        compare(pa.fill, 1)
        compare(pa.scale, 1.07)
        compare(Icons.resolve("pause").fill, 1)
        compare(Icons.resolve("skip_previous").fill, 1)
        compare(Icons.resolve("skip_next").fill, 1)
        const mm = Icons.resolve("mic_muted")
        compare(mm.glyph, "mic")
        compare(mm.slash, true)
        compare(Icons.resolve("lan").scale, 0.94)
        compare(Icons.resolve("power_settings_new").scale, 0.94)
        const rc = Icons.resolve("radio_checked")
        compare(rc.glyph, "circle")
        compare(rc.fill, 1)
        compare(rc.scale, 0.6)
    }

    function test_resolveUnknown() {
        compare(Icons.resolve("nope"), null)
        compare(Icons.resolve(""), null)
        compare(Icons.resolve(undefined), null)
        compare(Icons.resolve(null), null)
        compare(Icons.resolve("\u{f057e}"), null)
        compare(Icons.resolve("volume_up\u{f057e}"), null)
    }

    function test_knownIsResolvable() {
        const names = Icons.known()
        verify(names.length > 40)
        for (const n of names)
            verify(Icons.resolve(n) !== null, n)
    }

    function test_ligatureForms() {
        const icon = createTemporaryObject(iconComp, tc, { name: "volume_up", size: 16 })
        verify(icon)
        verify(icon.ok)
        verify(icon.glyphWidth > 0)
        verify(icon.glyphWidth <= 16 * 1.5, "contentWidth " + icon.glyphWidth)
    }

    function test_unknownDrawsNothing() {
        ignoreWarning(/Icon: cannot draw nope/)
        const icon = createTemporaryObject(iconComp, tc, { name: "nope" })
        verify(icon)
        compare(icon.ok, false)
        compare(icon.glyphVisible, false)
    }

    function test_missingFontDrawsNothing() {
        ignoreWarning(/Icon: cannot draw volume_up/)
        const icon = createTemporaryObject(iconComp, tc,
            { name: "volume_up", family: "No Such Font 421" })
        verify(icon)
        compare(icon.ok, false)
        compare(icon.glyphVisible, false)
        wait(50)    // the warning is decided after layout settles
    }

    function test_nameChangeOnGoodFontDoesNotWarn() {
        failOnWarning(/Icon: cannot draw/)
        const icon = createTemporaryObject(iconComp, tc, { name: "", size: 16 })
        verify(icon)
        icon.name = "volume_up"
        wait(50)
        verify(icon.ok)
    }

    function test_unknownThenKnownDoesNotWarnForKnown() {
        ignoreWarning(/Icon: cannot draw nope/)
        const icon = createTemporaryObject(iconComp, tc, { name: "nope" })
        verify(icon)
        wait(50)
        failOnWarning(/Icon: cannot draw volume_up/)
        icon.name = "volume_up"
        wait(50)
        verify(icon.ok)
        icon.name = "nope"    // a second episode of the same name
        ignoreWarning(/Icon: cannot draw nope/)
        wait(50)
        compare(icon.ok, false)
    }

    function test_sizeChangeDoesNotWarn() {
        failOnWarning(/Icon: cannot draw/)
        const a = createTemporaryObject(iconComp, tc, { name: "keyboard", size: 24 })
        const b = createTemporaryObject(iconComp, tc, { name: "volume_up", size: 24 })
        verify(a && b)
        wait(20)
        a.size = 12
        b.size = 8
        wait(50)
        verify(a.ok)
        verify(b.ok)
    }

    function test_badGoodBadWarnsAgain() {
        const icon = createTemporaryObject(iconComp, tc,
            { name: "volume_up", family: "No Such Font 421" })
        verify(icon)
        ignoreWarning(/Icon: cannot draw volume_up/)
        wait(50)
        compare(icon.ok, false)
        icon.family = "Material Symbols Sharp"
        wait(50)
        verify(icon.ok)
        ignoreWarning(/Icon: cannot draw volume_up/)    // consumed only if a second warning comes
        icon.family = "No Such Font 421"
        wait(50)
        compare(icon.ok, false)
    }
}
