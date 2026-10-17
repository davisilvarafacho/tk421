import QtQuick
import Quickshell.Services.Pam

// Authentication state shared by every lock surface. In mock mode (dev preview)
// it never touches PAM; the password "preview" is accepted.
QtObject {
    id: root

    property bool mock: false
    property string status: "locked"   // locked | verifying | denied | authorized
    property string message: ""
    property bool messageIsError: false
    property int failed: 0
    property date lockedSince: new Date()
    property string pending: ""
    property string lockNotice: ""   // set when pam_faillock reports the account is locked

    signal granted()

    function reset() {
        status = "locked"
        message = ""
        messageIsError = false
        failed = 0
        pending = ""
        lockedSince = new Date()
    }

    function submit(password) {
        if (status === "verifying" || status === "authorized" || password.length === 0)
            return

        status = "verifying"
        message = "Verifying…"
        messageIsError = false
        pending = password
        lockNotice = ""

        if (mock) {
            mockTimer.restart()
            return
        }
        pam.abort()
        pam.start()
    }

    function clearError() {
        if (status === "denied") {
            status = "locked"
            message = ""
            messageIsError = false
        }
    }

    function accept() {
        status = "authorized"
        message = ""
        failed = 0
        pending = ""
        granted()
    }

    // PAM informational messages (e.g. pam_faillock: "The account is locked due to 3 failed logins.",
    // "(10 minutes left to unlock)"). Keep the reason so the UI can show it instead of a generic failure.
    function collectNotice(text) {
        if (/locked/i.test(text) && lockNotice === "")
            lockNotice = "Account locked."
        const left = text.match(/\((.+?) left/)
        if (left && lockNotice !== "")
            lockNotice = "Account locked. Try again in " + left[1].replace(/ to unlock$/, "") + "."
    }

    function deny(text) {
        const locked = lockNotice !== ""
        if (!locked)
            failed += 1
        status = "denied"
        messageIsError = true
        message = locked ? lockNotice
                : failed >= 3 ? "Unauthorized. TK-421, why aren't you at your post?" : text
        pending = ""
    }

    property Timer mockTimer: Timer {
        interval: 650
        onTriggered: root.pending === "preview" ? root.accept() : root.deny("Authentication failed. Try again.")
    }

    // /etc/pam.d/hyprlock includes the system login stack.
    property PamContext pam: PamContext {
        config: "hyprlock"

        onPamMessage: {
            if (responseRequired)
                respond(root.pending)
            else if (message.length > 0)
                root.collectNotice(message)
        }

        onCompleted: result => {
            if (result === PamResult.Success)
                root.accept()
            else if (result === PamResult.MaxTries)
                root.deny("Too many attempts. Wait and try again.")
            else if (result === PamResult.Failed)
                root.deny("Authentication failed. Try again.")
            else
                root.deny("Authentication error.")
        }

        onError: root.deny("Authentication error.")
    }
}
