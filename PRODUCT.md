# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

<!-- The shell itself is Quickshell (QML) on Wayland. Every visual surface is prototyped first as static HTML in
prototypes/<feature>/ and then ported to QML, so the design work happens on the web platform. -->

## Users

One person: the owner of the workstation "TK-421" (Arch Linux + Hyprland), who uses this shell as their real desktop
all day. Keyboard-first: launcher, clipboard, wallpaper and notifications are summoned with SUPER chords dozens of times
a day, and most interactions last a second or two.

## Product Purpose

TK-421 is a personal desktop shell built on Quickshell 0.3.2: bar pills, a Dynamic Island (agenda, media, toasts),
lock screen, app launcher (SUPER+Space), clipboard archive, wallpaper picker, notification centre, toolbar dropdowns
and desktop widgets. It replaces off-the-shelf pieces (Hyprlauncher, swaync, hyprlock, fuzzel) with one coherent,
deeply customised system. Success is a desktop that is fast, precise, and feels like one designed object.

## Positioning

A single-owner shell where every surface is designed, prototyped and approved by its only user, then implemented on
their live machine. Nothing is generic: the identity (Imperial, TK-421) runs through every component.

## Operating Context

- Hyprland (Lua config), one main monitor, layer-shell overlays; Hyprland blurs selected namespaces.
- The running shell hot-reloads on save; the user's real desktop is the test bed.
- Data sources: freedesktop desktop entries, PipeWire, MPRIS, NetworkManager, BlueZ, cliphist, a Google Calendar iCal
  feed, Claude Code usage.

## Capabilities and Constraints

- QML/Qt Quick only at runtime: no web engine in the shell. HTML prototypes must be portable to QML (Rectangles,
  Text, Shapes, MultiEffect, Images; no CSS-only tricks that QML cannot reproduce).
- Fonts installed: Orbitron (display), Geist (UI), Material Symbols Sharp (icons, drawn through `components/Icon.qml`).
- Strings from outside (app names, notification text, event titles) are untrusted and rendered as plain text.
- Lean system: no fallback daemons kept around; build dependencies removed after use.

## Brand Commitments

- Name: TK-421. Visual direction "Imperial": cold, precise, controlled; source `tk421/TK421.md`, used as a guide while
  new surfaces follow the shell as it currently looks (rounded pills, opaque ink `Theme.imperial.ink`, faint hairline).
- Graphite and steel only for the launcher and terminal: no hue, the user rejected blue and red accents.
- Orbitron only for titles and wordmarks; Geist sentence case for everything else.
- Icons: one glyph, size and weight per icon across states; state is colour, never FILL.
- UI copy is English; conversation with the owner is Brazilian Portuguese.

## Evidence on Hand

- Prototypes and approved/rejected iterations under `prototypes/` (launcher `v1`–`v4` rejected, `index.html` current).
- Assets: `assets/deathstar.svg`, `assets/claude.svg`, monochrome tray icons in `assets/tray/`, wallpapers in
  `~/Pictures/Wallpapers`.
- No usage telemetry exists beyond what the shell itself records locally.

## Product Principles

1. Speed of the second-long interaction beats everything: open, type, act, gone.
2. One designed object: every surface speaks the same Imperial graphite language.
3. Prototype, approve, then build; the owner decides every visual change.
4. Local and private: no data leaves the machine unless a feature exists for that.

## Accessibility & Inclusion

Single sighted keyboard-and-mouse user. Keep text contrast readable on dark ground, respect reduced motion where a
surface animates, never rely on hue alone.
