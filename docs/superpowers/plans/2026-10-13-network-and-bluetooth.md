# Network and Bluetooth — Implementation Plan

> Execute inline (superpowers:executing-plans). Spec: `docs/superpowers/specs/2026-10-13-network-and-bluetooth-design.md`. Prototype: `prototypes/toolbar/index.html`.

**Goal:** Network and Bluetooth toolbar items and dropdown panels on top of the shared dropdown host.

**Architecture:** Two singletons (`Net`, `Bt`) turn the native modules into plain entries; two panels and two buttons render them; pure rules live in `dropdown/netlogic.js` (unit-tested).

## Global Constraints

- Same as `docs/superpowers/plans/2026-10-12-power-and-tray.md`: the shell is live and hot-reloads; other sessions edit shared files, so patch them with exact-match replacements that assert the count; write each new QML file once, lint first (`/usr/lib/qt6/bin/qmllint -I /usr/lib/qt6/qml <file>`); no commits; never overwrite `shell.qml`, `bar/Toolbar.qml`, `services/qmldir`, `services/Dropdown.qml`, `dropdown/DropdownHost.qml` (patch).
- **`Net.dryRun` and `Bt.dryRun` are `true` in code. Never disconnect the network or the user's Bluetooth devices for real.** Reads are real; actions only record. The one real action allowed in testing is a short Bluetooth scan.
- App-supplied text (SSIDs, device names): `textFormat: Text.PlainText`, cleaned with `cleanLabel` from `bar/trayLogic.js`.
- Ledger: `.superpowers/sdd/network-and-bluetooth/progress.md`. Tests: `QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml`. Log check: text after the last `Reloading configuration` line has no `WARN|ERROR` (ignore the Qt text-input warning).
- Glyphs (Symbols Nerd Font Mono, all present): ethernet `󰈀`, ethernet-off `󰈁`, wifi `󰖩`, wifi-off `󰖪`, bluetooth ``, headphones ``, keyboard ``, mouse `󰍽`, mobile ``, speaker ``, gamepad ``, lock ``, check ``.

## Review Focus

1. Docker bridges and veths must never become "the connection" (this machine has a dozen).
2. No Wi-Fi adapter and no Bluetooth adapter at all (`defaultAdapter` null) must not error.
3. A device or network that disappears while the panel is open.
4. SSIDs with control or bidi characters, empty SSIDs (hidden networks), very long device names.
5. `dryRun` must really block every mutating call.

---

### Task 1: `dropdown/netlogic.js` with tests

**Files:** create `dropdown/netlogic.js`, `tests/qml/tst_netlogic.qml`.

**Interfaces (produced):**
- `formatRate(bytesPerSec) -> string`: `<1000` "N B/s", `<1e6` "N KB/s" (rounded), `<1e9` "x.y MB/s", else "x.y GB/s"; negative or NaN → "0 B/s".
- `signalBars(strength) -> int`: 0 for ≤0, else `max(1, ceil(strength*4))`, capped at 4.
- `parseNetDev(text, iface) -> { rx, tx } | null`: the `/proc/net/dev` line of `iface` (rx bytes = field 0, tx bytes = field 8).
- `ipv4FromAddr(text) -> string`: first `inet a.b.c.d` of `ip -4 -o addr show` output, `""` if none.
- `primaryIndex(devices) -> int`: `devices = [{ wired, managed, connected }]`; managed+connected wired, else managed+connected wifi, else managed wired, else managed wifi, else -1. Unmanaged devices never win.
- `btGlyph(iconName) -> string` (headphone/headset → headphones, keyboard, mouse, phone, speaker/audio, gaming/joystick → gamepad, default bluetooth).
- `btSub(d) -> string`: `d = { state, pairing, paired, connected, battery }` → "Connecting…", "Disconnecting…", "Pairing…", "Connected · 82%" (percent only when known), "Connected", "Paired", "Not paired".
- `sortBtDevices(list)`: connected first, then by name case-insensitively; stable for equal names.
- `batteryPercent(value) -> int`: `-1` for NaN/negative/undefined; `value <= 1` → `round(value*100)`, else `round(value)`; capped at 100.
- `countConnected(list) -> int`.

- [ ] Write the tests (every function above, including: Docker-like unmanaged devices skipped by `primaryIndex`, no devices → -1, `parseNetDev` for a missing interface and with the real `/proc/net/dev` header lines, `ipv4FromAddr` with no address, `formatRate` boundaries 999/1000/999999/1000000, `batteryPercent` 0.82 / 82 / 1 / 100 / -1 / NaN).
- [ ] Run → fail (module missing). Implement. Run → pass. Ledger.

### Task 2: Services `Net` and `Bt`

**Files:** create `services/Net.qml`, `services/Bt.qml`; append two `singleton` lines to `services/qmldir`; patch `services/Dropdown.qml` (`panels` gets `"net"`, `"bt"`) and `shell.qml` (one line referencing `Net.active && Bt.active`).

**Interfaces (produced, used by Tasks 3):**
- `Net { active; mock; dryRun (true); mode ("eth"|"wifi"|"off"); connected; title; subtitle; ipv4; rxRate; txRate (bytes/s); hasWifi; wifiEnabled; wifi: [{ id, name, strength, secure, connected, known, busy }]; last; disconnect(); connect(); joinWifi(id, psk); toggleWifiNetwork(id) }` and IPC `net` (`status`, `setDryRun`, `setMock`, `disconnect`, `connect`, `list`).
- `Bt { active; mock; dryRun (true); available; powered; scanning; connectedCount; devices: [{ id, name, glyph, sub, connected, paired, busy, battery }]; nearby: [same]; last; setPowered(bool); scan(); toggle(id); pair(id) }` and IPC `bt` (`status`, `setDryRun`, `setMock`, `list`, `scan`, `power <bool>`).

- [ ] Write both (real data from `Networking`/`Bluetooth`, mock data when `mock`; `dryRun` only guards system changes; rates only sampled while `Dropdown.current === "net"`).
- [ ] Lint, register, patch, reload, log check.
- [ ] IPC checks with the real machine: `net status` shows Ethernet, the real `eno1` name and speed, an IPv4; Docker bridges not chosen; `bt status` shows the controller and 0 devices; mock on/off; every mutating call under `dryRun` only sets `last`.

### Task 3: Buttons, panels, host and toolbar wiring

**Files:** create `bar/NetworkButton.qml`, `bar/BluetoothButton.qml`, `dropdown/NetworkPanel.qml`, `dropdown/BluetoothPanel.qml`; patch `dropdown/DropdownHost.qml` (loader sources and width 320 for `net`/`bt`) and `bar/Toolbar.qml` (insert the two buttons after the usage chip).

- [ ] Write the files per the spec/prototype (light pass), lint, patch, reload.
- [ ] Visual checks with `grim -g` of exact rectangles: bar corner, network panel (real Ethernet), Bluetooth panel on and off, then the mocks (Wi-Fi list, password prompt, devices, nearby, battery).
- [ ] One real scan (`bt scan`) is allowed; report what appeared in general terms only.

### Task 4: Docs and regression

- [ ] `CLAUDE.md` (architecture, IPC, "dryRun" for network/bluetooth), `tk421/TK421.md` (§25/§39), full tests, log check, island regression capture, self-review, ledger.
- [ ] Ask the user before switching `Net.dryRun`/`Bt.dryRun` to `false`.
