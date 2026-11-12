---
version: 1
slug: "launcher-launcher-qml"
primary_target: "launcher/Launcher.qml"
related_targets: ["prototypes/launcher/island.html"]
---

# Launcher (SUPER+Space)

Mode: operate. Owner-only, keyboard-first, opened dozens of times a day, open for one to three seconds.
Job: find and start an app, jump to an open window, run a shell command, or do a quick calculation.
Must stay: fuzzy ranking with escaped names, hover selects only on real pointer movement, Esc/Enter/arrows/Ctrl+N/P,
candy-grey icons with initials fallback, graphite and steel only, no hue.
Requested (2026-11-12): a more distinctive look, more context per app, frequent and recent first, prefix modes
(= calculate, > shell, @ windows), Isoflow used for one detail.

## Direction contract

THESIS: SUPER+Space grows the Dynamic Island itself into the launcher; it refuses the floating centred search card every launcher ships.
OWN-WORLD: the island's opaque ink silhouette with 10 px concave flares and 18 px bottom radius, faint white hairlines, surfaceAlt #1A1A21 selection at radius 14, Geist sentence case, Orbitron only for the clock and the TK-421 tag, candy-grey icons, greyscale Isoflow isometric objects.
STORY: the owner presses SUPER+Space, sees frequent and recent apps before typing, types two letters, reads what the selected thing is and does, and presses Enter; prefixes switch the list to calculations, commands or windows.
FIRST VIEWPORT: 820 x 456 island hanging from the top edge centre; a 60 px search row with the Death Star mark, input and three prefix chips; below, a 392 px ranked list (Frequent, then Recent) left and a detail pane right: isometric scene on top, icon, name, generic name, description, launch count and last use, the app's own actions; a quiet key-hint footer.
FORM: Island command, third of seven grounded structures; seed: none (unavailable).
SIGNATURE: the idle pill morphs into the launcher (one 520 ms ease-out), and the selected app's Isoflow object drops onto its plinth in the detail pane.
FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
