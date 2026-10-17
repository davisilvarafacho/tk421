# Network and Bluetooth — Design

## Goal

The last two toolbar items, as approved in `prototypes/toolbar/index.html`, using Quickshell's native modules (`Quickshell.Networking` over NetworkManager, `Quickshell.Bluetooth` over BlueZ):

- **Network:** an icon showing the connection (Ethernet, Wi-Fi, none) and a dropdown with the current connection (name, link speed, IPv4, live down/up rates), Connect/Disconnect, and, when a Wi-Fi adapter exists, the available networks with a password prompt for secured ones.
- **Bluetooth:** an icon with the number of connected devices and a dropdown with an on/off switch, the paired devices (connect/disconnect, battery), Scan, and nearby devices to pair.

Both open in the shared dropdown window already used by power and the tray (`services/Dropdown`, `dropdown/DropdownHost`).

Success: the icons and panels reflect the real state (this machine: Ethernet `eno1` connected, no Wi-Fi adapter, a BlueZ controller with no paired device); actions call the right API; nothing an access point or device announces (names) can break or spoof the UI.

## Decisions

| Decision | Value | Why |
|---|---|---|
| Backends | `Quickshell.Networking`, `Quickshell.Bluetooth` | Native, no polling, no shelling out for state |
| Network device choice | NetworkManager-managed devices only (the Docker bridges and veths are not shown), preferring a connected Ethernet, then a connected Wi-Fi | This machine has a dozen virtual interfaces |
| Rates and IP | `/proc/net/dev` sampled every second **only while the panel is open**; IPv4 from `ip -4 -o addr show dev <name>` when the connection changes | The Networking module exposes neither |
| Wi-Fi | Supported (list, signal bars, padlock, connect, password via `connectWithPsk`, known networks reconnect without a prompt). Without an adapter the panel says "Wi-Fi · no adapter found on this machine" | Approved in the prototype; the machine has no adapter, so it is exercised with mock data |
| Bluetooth lists | "My devices" = paired or bonded, connected first, then by name; "Nearby" = discovered unpaired devices, shown while scanning or after a scan | Approved |
| Bar icons | Same light round icons as the bell; Bluetooth shows the number of connected devices in Orbitron (hidden at 0); off or disconnected states are dimmed | Approved |
| Safety default | `Net.dryRun` and `Bt.dryRun` are **true** until the user switches them off: cutting the Ethernet would also cut a remote session, and disconnecting Bluetooth devices is visible to the user | Same reason as `Power.dryRun` |
| Mock mode | `Net.mock` and `Bt.mock` (default false) feed the UI fake Wi-Fi networks and devices for visual checks, like `Media.mock` | There is no Wi-Fi adapter and no paired device to look at |

## Architecture

```
services/Net.qml        devices -> one primary connection, rates, IPv4, Wi-Fi entries, actions, dryRun, mock, IPC "net"
services/Bt.qml         adapter -> on/off, scan, device entries, actions, dryRun, mock, IPC "bt"
dropdown/netlogic.js    pure rules (unit-tested)
dropdown/NetworkPanel.qml, dropdown/BluetoothPanel.qml
bar/NetworkButton.qml, bar/BluetoothButton.qml
dropdown/DropdownHost.qml  + the two panels (width 320)
services/Dropdown.qml      + "net", "bt" in `panels`
bar/Toolbar.qml            order: usage chip, network, Bluetooth, bell, power
```

The panels read plain entry objects from the services (`{ id, name, ... , ref }`), never the native objects, so mock and real data take the same path.

### `dropdown/netlogic.js` (pure)

`formatRate(bytesPerSec)` ("0 B/s", "180 KB/s", "2.3 MB/s", "1.2 GB/s"), `signalBars(strength 0..1)` (0..4), `parseNetDev(text, iface)` → `{ rx, tx }` or `null`, `ipv4FromAddr(text)`, `primaryIndex(devices)`, `btGlyph(iconName)`, `btSub(device)`, `sortBtDevices(devices)`, `batteryPercent(value)`, `countConnected(devices)`.

## UI (from the prototype, light pass)

- **Network panel (320 px):** header "NETWORK" + state ("Connected" / "Not connected"). Current connection: icon, name, sub line (device and link speed). Rows IPv4, Down, Up (Orbitron digits, tabular). "Disconnect" / "Connect" as a borderless text button. Wi-Fi section "Available networks": rows with 4-bar signal, name, padlock for secured, "Connected" sub line and a dot for the current one; a secured unknown network expands an inline password field with a "JOIN" button; `Enter` joins, `Esc` closes the field. No adapter: the note line.
- **Bluetooth panel (320 px):** header "BLUETOOTH", "Scan" text button, switch. Off: "Bluetooth is off" empty state with "Turn on". On: "My devices" rows (glyph by device class, name, sub line "Connected · 82%" / "Paired" / "Connecting…", action on hover: Disconnect / Connect), "Nearby" section while scanning ("Searching…") and its results ("Pair" on hover), a note when the list is empty ("No paired devices. Press Scan.").
- All text from the network or devices (SSID, device name) is `PlainText`, cleaned with `Tray`'s `cleanLabel` (control and bidi characters out, limited to 40 characters).

## Safety and robustness

- `dryRun` blocks every action that changes the system: disconnect/connect/forget (network), switching the adapter, scan, connect/disconnect/pair (Bluetooth), joining Wi-Fi. Reading state is always real. In dry run the panel still responds and the action is recorded in `status()`.
- The Wi-Fi password is passed to `connectWithPsk` and never stored, logged or shown; the field is cleared after use.
- A device disappearing while the panel is open is dropped from the list without errors.

## Rollout

1. Build with both `dryRun = true`. Verify with the real Ethernet and Bluetooth controller (read-only), and with the mock for Wi-Fi and devices.
2. Scan is the one real action allowed in testing once, because it does not change anything the user relies on (the user is told).
3. With the user's go-ahead, set `Net.dryRun` and `Bt.dryRun` to `false`.

## Non-goals

VPN, hotspot, saved-network management beyond connect/disconnect, proxy, IP configuration, Bluetooth file transfer, audio-profile selection, trust/block toggles, multiple adapters.

## Acceptance criteria

1. The toolbar shows the network icon (Ethernet now), the Bluetooth icon with its count, the bell and power, in that order after the usage chip.
2. Each panel opens in the shared slot, closes like the others, and reflects the real state of this machine.
3. With `mock` on, the Wi-Fi list, the password prompt, devices, battery, Scan and Pair are all usable and match the prototype.
4. With `dryRun` on, no action changes the system and each is recorded.
5. Unit tests pass; no new `WARN`/`ERROR`; `CLAUDE.md` and `TK421.md` updated.
