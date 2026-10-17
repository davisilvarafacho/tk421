import Quickshell
import Quickshell.Io
import QtQuick

// A clipboard image record, decoded by `cliphist decode` into the runtime directory (tmpfs: private, gone at logout).
// The file is written under a temporary name and moved, so a second ClipImage for the same record never reads half a file.
Item {
    id: root

    property int recordId: -1
    property int fillMode: Image.PreserveAspectCrop
    property int decodeSize: 64         // the longest side the image is decoded to (a thumbnail needs far less than the preview)

    readonly property string dir: Quickshell.env("XDG_RUNTIME_DIR") + "/tk421-clipboard"
    readonly property string path: dir + "/" + recordId + ".bin"
    property bool ready: false

    Process {
        running: root.recordId >= 0
        command: ["sh", "-c",
            'mkdir -p "$1" && { [ -s "$2" ] || { cliphist decode "$3" > "$2.$$" && mv "$2.$$" "$2"; }; }',
            "_", root.dir, root.path, String(root.recordId)]
        onExited: code => root.ready = code === 0
    }

    Image {
        anchors.fill: parent
        source: root.ready ? "file://" + root.path : ""
        sourceSize: Qt.size(root.decodeSize, root.decodeSize)
        fillMode: root.fillMode
        asynchronous: true
        smooth: true
    }
}
