pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Basike Ba-KEY391 (cable, 258a:019d): lighting, the side glow and the screen shown at boot. The keyboard is driven by
// tools/ba_key391.py in the basike-keyboard project: `led status --json` reads the state, and `set` writes several
// settings at once under a lock and answers with the new state. Reads happen at start and while the keyboard panel is
// open; writes go through a queue, one at a time. Panel: dropdown/KeyboardPanel.qml.
Singleton {
    id: root

    readonly property string script: "/home/tk421/Development/basike-keyboard/tools/ba_key391.py"

    property bool online: false
    property bool writing: false
    property string error: ""

    // The state as the keyboard reports it. Brightness, speed and colour belong to the current effect.
    property int effect: 15
    property string effectName: ""
    property bool effectHasSpeed: true
    property bool effectHasBrightness: true
    property bool effectHasColor: true
    property int bright: 5          // step 0..6 (raw 0, 4, ..., 24)
    property int speed: 4           // 0..4
    property int color: 0           // 0..6 palette, 7 rainbow
    property int sideMode: 0        // 0..4
    property int sideLevel: 4       // 0..4
    property int boot: 2            // 1 home, 2 GIF

    property var queue: []

    // Images for the screen (GIF, JPG, PNG, WebP): the files of gifDir, one send at a time (the keyboard is busy while one runs).
    readonly property string gifDir: "/home/tk421/Pictures/Keyboard"
    property var gifNames: []
    property string gifSelected: ""
    property bool sending: false
    property string sendingName: ""
    property int sentFrame: 0
    property int sentFrames: 0
    property int sentPage: 0
    property int sentPages: 0
    property string gifError: ""
    property string gifSent: ""      // name of the last GIF sent in full

    function listGifs() {
        if (!gifLister.running)
            gifLister.running = true
    }

    function selectGif(name) {
        gifSelected = name
    }

    function sendGif(name) {
        if (sending || name === "")
            return
        if (readProc.running || writeProc.running) {
            gifError = "wait for the keyboard to finish writing"
            return
        }
        gifError = ""
        gifSent = ""
        sentFrame = 0
        sentFrames = 0
        sentPage = 0
        sentPages = 0
        sendingName = name
        sending = true
        gifProc.command = ["python3", root.script, "screen", "send", gifDir + "/" + name, "--yes", "--progress"]
        gifProc.running = true
    }

    function cancelGif() {
        gifProc.running = false
    }

    // One line of the sender's progress: a page, or the end of the GIF.
    function gifLine(line) {
        let d
        try {
            d = JSON.parse(line)
        } catch (e) {
            return
        }
        if (d.done === true) {
            gifSent = sendingName
        } else if (d.page !== undefined) {
            sentFrame = d.frame
            sentFrames = d.frames
            sentPage = d.page
            sentPages = d.pages
        }
    }

    function apply(d) {
        effect = d.effect
        effectName = d.effect_name
        const slot = d.slots.find(s => s.hw === d.effect)
        if (slot) {
            bright = Math.min(6, Math.round(slot.brightness_raw / 4))
            speed = slot.speed
            color = slot.color
            effectHasSpeed = slot.options.speed
            effectHasBrightness = slot.options.brightness
            effectHasColor = slot.options.color
        }
        sideMode = d.side_light_mode
        sideLevel = d.side_light_level
        boot = d.screen_boot
        online = true
        error = ""
    }

    function refresh() {
        if (writing || readProc.running || sending)
            return
        readProc.running = true
    }

    // Each call queues its arguments; the answer to the last write is the state that is shown.
    function set(args) {
        const last = queue.length > 0 ? queue[queue.length - 1] : null
        // a run of the same setting (wheel steps) only needs its last value
        queue = last !== null && last[0] === args[0] ? queue.slice(0, -1).concat([args]) : queue.concat([args])
        pump()
    }

    function pump() {
        if (writeProc.running || sending || queue.length === 0)
            return
        writeProc.command = ["python3", root.script, "set"].concat(queue[0])
        queue = queue.slice(1)
        writing = true
        writeProc.running = true
    }

    // The UI shows the new value at once; the keyboard's answer then replaces it.
    function setEffect(hw) {
        effect = hw
        set(["--effect", String(hw)])
    }

    function setBright(step) {
        bright = step
        set(["--brightness", String(step)])
    }

    function setSpeed(value) {
        speed = value
        set(["--speed", String(value)])
    }

    function setColor(index) {
        color = index
        set(["--color", String(index)])
    }

    function setSideMode(mode) {
        sideMode = mode
        set(["--side-mode", String(mode)])
    }

    function setSideLevel(level) {
        sideLevel = level
        set(["--side-level", String(level)])
    }

    function setBoot(screen) {
        boot = screen
        set(["--boot", String(screen)])
    }

    Component.onCompleted: {
        refresh()
        listGifs()
    }

    Process {
        id: readProc

        command: ["python3", root.script, "led", "status", "--json"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.apply(JSON.parse(text))
                } catch (e) {
                    root.online = false
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: root.error = text.trim()
        }

        onExited: exitCode => {
            if (exitCode !== 0)
                root.online = false
        }
    }

    Process {
        id: writeProc

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text)
                    root.apply(d)
                    if (!d.ok)
                        root.error = "gravação não confirmada pelo teclado"
                } catch (e) {
                    root.error = "resposta inválida do teclado"
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "")
                    root.error = text.trim()
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0)
                root.online = false
            root.writing = root.queue.length > 0
            root.pump()
        }
    }

    Process {
        id: gifLister

        command: ["find", root.gifDir, "-maxdepth", "1", "-type", "f", "(", "-iname", "*.gif", "-o", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.png", "-o", "-iname", "*.webp", ")", "-printf", "%f\\n"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.gifNames = text.split("\n").filter(n => n !== "").sort()
                if (root.gifNames.indexOf(root.gifSelected) < 0)
                    root.gifSelected = root.gifNames.length > 0 ? root.gifNames[0] : ""
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                root.gifNames = []
                root.gifSelected = ""
            }
        }
    }

    Process {
        id: gifProc

        stdout: SplitParser {
            onRead: data => root.gifLine(data)
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "")
                    root.gifError = text.trim()
            }
        }

        onExited: exitCode => {
            root.sending = false
            if (exitCode !== 0 && root.gifError === "")
                root.gifError = "send interrupted"
            root.refresh()
            root.pump()
        }
    }
}
