---
title: Pre-Caelestia backup audit
author: Davisilvarafacho
date: 2026-10-25
branch: main
touches:
  - CLAUDE.md
  - TODO.md
  - bar/Bar.qml
  - bar/Toolbar.qml
  - bar/TrayCapsule.qml
  - dropdown/soundlogic.js
  - island/AgendaPane.qml
  - island/CalendarPane.qml
  - island/Island.qml
  - island/MediaPane.qml
---

## Decided
- Nothing was changed; this was a read-only audit of what to back up before installing Caelestia shell.
- Backup targets: ~/Development/quickshell (git, remote github davisilvarafacho/tk421, 14 modified + untracked files, 1 commit only), ~/.config/hypr (no git, Lua config), ~/Projects/tk421 (uncommitted docs/components), other ~/.config dirs (fish, ghostty, btop, fastfetch, cava, nvim, gtk-3.0).
- Suggested: commit+push the quickshell repo, tar the rest, install Caelestia with `qs -c caelestia` outside ~/.config/quickshell.

## Tried and ruled out
- Did not read the Caelestia installer itself; its behavior (clones into ~/.config/quickshell/caelestia, dotfiles use hyprland.conf) is from prior knowledge, unverified.

## Watch out
- ~/.config/quickshell is a symlink to ~/Development/quickshell, so an installer writing there lands inside the user's repo.
- Development/quickshell/hypr is a symlink back to ~/.config/hypr; hyprland.lua launches scripts via ~/.config/quickshell/hypr/.
- Hyprland config is Lua; Caelestia dots are .conf and would conflict.
- Token files in ~ must never be pushed or put in a repo.
