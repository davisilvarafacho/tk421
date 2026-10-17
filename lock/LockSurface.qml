import Quickshell
import QtQuick
import QtQuick.Effects

import "../theme"

Item {
    id: root

    required property var session
    property string screenName: ""      // picks this output's screenshot (lock/capture.lua)

    // 0 = the desktop as it was (the screenshot, sharp), 1 = locked (dimmed a little)
    property real veil: 0
    property bool unlocking: false

    signal finished()

    Behavior on veil { NumberAnimation { duration: root.unlocking ? 320 : 1100; easing.type: Easing.OutExpo } }

    Rectangle {
        anchors.fill: parent
        color: Theme.imperial.bg
    }

    // The desktop just before locking. cache: false, or the next lock would show this one's picture.
    Image {
        id: shot
        anchors.fill: parent
        source: root.screenName !== "" ? "file://" + Quickshell.env("XDG_RUNTIME_DIR") + "/tk421-lock/" + root.screenName + ".png" : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        visible: false
    }

    // Fallback when there is no screenshot (grim failed or timed out): the Imperial wallpaper.
    Image {
        id: wallpaper
        anchors.fill: parent
        source: "file://" + Theme.wallpaper
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        source: shot.status === Image.Ready ? shot : wallpaper
        brightness: -0.25 * root.veil   // only a slight dimming, no blur: the desktop stays as it was
        autoPaddingEnabled: false
        visible: shot.status === Image.Ready || wallpaper.status === Image.Ready
    }

    LockCard {
        id: card

        anchors.centerIn: parent
        session: root.session
        onClosed: root.finished()
    }

    Connections {
        target: root.session

        function onGranted() {
            root.unlocking = true
            root.veil = 0
            card.close()
        }
    }

    Component.onCompleted: {
        veil = 1
        card.open()
    }
}
