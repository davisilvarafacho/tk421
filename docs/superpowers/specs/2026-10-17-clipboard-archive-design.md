# Clipboard archive — Design

## Goal

Replace `cliphist list | fuzzel --dmenu | cliphist decode | wl-copy` (`SUPER+H`) with a Quickshell card in the launcher's look. Approved prototype: `prototypes/clipboard/index.html`.

Success: `SUPER+H` opens a searchable list of the last 50 clipboard records; `Enter` puts the record back on the clipboard, `Ctrl+Enter` also pastes it into the window that had focus; `Del` removes a record; text previews under the list, image previews beside it.

## Decisions

| Decision | Value | Why |
|---|---|---|
| Store | Unchanged: `cliphist` with its two `wl-paste --watch` user services | Already running, 563 records. The shell only reads |
| Surface | Fullscreen overlay `PanelWindow` (namespace `tk421-clipboard`, exclusive keyboard while open), card at 18% height, 560 px wide, 880 px while an image is selected | Same as the launcher; approved |
| Palette | Graphite and steel only | Launcher rule: no hue |
| Records shown | 50 newest that match; empty query keeps `cliphist` order (newest first) | Launcher's `Fuzzy.js` ranks, but sorts an empty query alphabetically, so the order is done in `clipboard/logic.js` |
| Enter | Put the record back (`cliphist decode id | wl-copy`), close | Same as today |
| Ctrl+Enter | Same, then `wtype` pastes: `Ctrl+Shift+V` when the focused window is a terminal (ghostty, kitty, alacritty, foot, wezterm), `Ctrl+V` otherwise | Terminals do not paste with `Ctrl+V` |
| Del | Remove the record (`cliphist delete`), only when the text cursor is at the end of the query (otherwise it edits the query) | Del must still work as a text key |
| Previews | Text: first 4000 bytes through `cliphist decode`, 5 lines, plain text. Image: decoded to `$XDG_RUNTIME_DIR/tk421-clipboard/<id>.bin` (tmpfs, gone at logout), shown beside the list and as a 22 px thumbnail in its row | Images can be private: they never touch the project directory or disk |
| Content safety | Everything copied is rendered with `textFormat: Text.PlainText` (names through `Fuzzy.markup`, which escapes) | Same rule as the other shell UI: clipboard text comes from strangers' pages |
| Secrets | Not masked. Visible like in `fuzzel` today | User kept the default |
| Feedback | Island HUD pill `ARCHIVE` + `copied` / `pasted` / `purged` | Same voice as the other HUD pills |
| Not included | Pinning, masking, sync, editing records | YAGNI |

## Files

- Create `clipboard/ClipboardCard.qml` (window, IPC `clipboard` target: `toggle`, `open`, `close`, `isOpen`), `clipboard/ClipImage.qml`, `clipboard/logic.js`, `clipboard/paste.lua` (Lua, the user's language of choice; `logic.js` stays JavaScript because QML only runs JS), `tests/qml/tst_cliplogic.qml`.
- Modify `shell.qml` (instantiate the card), `hypr/hyprland.lua` (`SUPER+H` calls the IPC, `fuzzel` remains the fallback; blur rule gets `clipboard`), `CLAUDE.md`.

## Labels

Search placeholder `SEARCH THE ARCHIVE`; counter `N RECORDS`; empty `NO RECORDS` / "The archive is empty."; no match `NO MATCH`; record header `RECORD 04`; row tags `TEXT`, `LINK`, `CODE`, `PNG · 1920×1080`.
