import QtQuick
import QtTest

import "../../wallpaper/logic.js" as WP

TestCase {
    name: "WallpaperLogic"

    // ---- folder listing ----
    function test_isImage_by_extension_and_hidden() {
        compare(WP.isImage("a.png"), true)
        compare(WP.isImage("A.JPG"), true)
        compare(WP.isImage("a.jpeg"), true)
        compare(WP.isImage("a.webp"), true)
        compare(WP.isImage("a.gif"), true)
        compare(WP.isImage("clip.mp4"), false)
        compare(WP.isImage(".hidden.png"), false)
        compare(WP.isImage("png"), false)
        compare(WP.isImage(""), false)
        compare(WP.isImage(undefined), false)
    }

    function test_listImages_filters_and_sorts_case_insensitively() {
        compare(WP.listImages(["b.png", "A.jpg", "c.mp4", "a.png", ".x.png", ""]), ["A.jpg", "a.png", "b.png"])
        compare(WP.listImages([]), [])
        compare(WP.listImages(null), [])
    }

    function test_withApplied_always_shows_the_applied_wallpaper() {
        compare(WP.withApplied(["/w/a.png", "/w/b.png"], "/w/b.png"), ["/w/a.png", "/w/b.png"])
        compare(WP.withApplied(["/w/a.png"], "/elsewhere/d.png"), ["/elsewhere/d.png", "/w/a.png"])
        compare(WP.withApplied([], "/elsewhere/d.png"), ["/elsewhere/d.png"])
        compare(WP.withApplied(["/w/a.png"], ""), ["/w/a.png"])
        compare(WP.withApplied([], ""), [])
    }

    // ---- wrap-around and plates ----
    function test_offset_wraps_to_the_nearest_side() {
        compare(WP.offset(0, 0, 9), 0)
        compare(WP.offset(1, 0, 9), 1)
        compare(WP.offset(8, 0, 9), -1)
        compare(WP.offset(4, 0, 9), 4)
        compare(WP.offset(5, 0, 9), -4)
        compare(WP.offset(0, 8, 9), 1)
    }

    function test_offset_with_few_images() {
        compare(WP.offset(0, 0, 1), 0)                 // one image: it is the selection, no neighbour
        compare(WP.offset(1, 0, 2), -1)                // two images: the other one appears once
        compare(WP.offset(0, 1, 2), -1)
        compare(WP.offset(1, 0, 3), 1)
        compare(WP.offset(2, 0, 3), -1)
        compare(WP.offset(0, 0, 0), 0)                 // empty folder
    }

    function test_slot_by_distance() {
        compare(WP.slot(0), { x: 0, scale: 1, opacity: 1 })
        compare(WP.slot(1), { x: 310, scale: 0.6, opacity: 0.95 })
        compare(WP.slot(-1), { x: -310, scale: 0.6, opacity: 0.95 })
        compare(WP.slot(2), { x: 505, scale: 0.4, opacity: 0.5 })
        compare(WP.slot(-3), { x: -700, scale: 0.3, opacity: 0 })   // parked, invisible
        compare(WP.slot(7), { x: 700, scale: 0.3, opacity: 0 })
    }

    function test_isNear_keeps_only_close_plates_decoded() {
        compare(WP.isNear(0), true)
        compare(WP.isNear(-3), true)
        compare(WP.isNear(3), true)
        compare(WP.isNear(4), false)
        compare(WP.isNear(-4), false)
    }

    function test_stepIndex_wraps_and_survives_empty() {
        compare(WP.stepIndex(8, 1, 9), 0)
        compare(WP.stepIndex(0, -1, 9), 8)
        compare(WP.stepIndex(3, 0, 9), 3)
        compare(WP.stepIndex(12, 0, 9), 3)
        compare(WP.stepIndex(0, 1, 1), 0)
        compare(WP.stepIndex(0, 1, 0), 0)
    }

    function test_lampIndex_tracks_the_selection_when_there_are_too_many() {
        compare(WP.lampIndex(3, 9, 24), 3)
        compare(WP.lampIndex(0, 48, 24), 0)
        compare(WP.lampIndex(47, 48, 24), 23)
        compare(WP.lampIndex(24, 48, 24), 12)
    }

    // ---- effects ----
    function test_stepEffect_cycles_and_recovers_from_unknown_ids() {
        compare(WP.stepEffect("laser", 1), "hyperspace")
        compare(WP.stepEffect("scan", 1), "laser")
        compare(WP.stepEffect("laser", -1), "scan")
        compare(WP.stepEffect("bogus", 1), "hyperspace")
    }

    function test_isEffect() {
        compare(WP.isEffect("doors"), true)
        compare(WP.isEffect("nope"), false)
        compare(WP.isEffect(undefined), false)
    }

    function test_duration() {
        compare(WP.duration("laser", false), 1000)
        compare(WP.duration("hyperspace", false), 1200)
        compare(WP.duration("doors", false), 1000)
        compare(WP.duration("scan", false), 900)
        compare(WP.duration("scan", true), 260)
        compare(WP.duration("bogus", false), 1000)
    }

    function test_labels() {
        compare(WP.LABELS.laser, "SUPERLASER")
        compare(WP.LABELS.hyperspace, "HYPERSPACE")
        compare(WP.LABELS.doors, "BLAST DOORS")
        compare(WP.LABELS.scan, "TACTICAL SCAN")
    }

    // ---- names and URLs (they come from outside) ----
    function test_displayName_cleans_the_file_name() {
        compare(WP.displayName("/x/stormtrooper-oled_4k.jpg"), "stormtrooper oled 4k")
        compare(WP.displayName("/x/My Wall #1.png"), "My Wall #1")
        compare(WP.displayName("/x/wall [4k].png"), "wall [4k]")
        compare(WP.displayName("/x/a‮b‏c.png"), "abc")          // bidi overrides removed
        compare(WP.displayName("/x/a\u0007b\u001bc.png"), "abc")          // control characters removed
        compare(WP.displayName("/x/.png"), "UNTITLED")
        compare(WP.displayName("/x/é.png"), "é")
    }

    function test_displayName_is_at_most_40_characters() {
        var long = WP.displayName("/x/" + new Array(80).join("a") + ".png")
        compare(long.length, 40)
        compare(long.charAt(39), "…")
        compare(WP.displayName("/x/" + new Array(41).join("b") + ".png").length, 40)   // exactly 40: untouched
    }

    function test_fileUrl_escapes_what_a_url_cannot_carry() {
        compare(WP.fileUrl("/a b/c#d%e.png"), "file:///a%20b/c%23d%25e.png")
        compare(WP.fileUrl("/é.png"), "file:///%C3%A9.png")
        compare(WP.fileUrl("/w/wall [4k].png"), "file:///w/wall%20%5B4k%5D.png")
        compare(WP.fileUrl("/home/u/Pictures/a.jpg"), "file:///home/u/Pictures/a.jpg")
    }

    // ---- awww ----
    function test_awwwArgs() {
        compare(WP.awwwArgs("/w/a b.png"), ["awww", "img", "--transition-type", "none", "/w/a b.png"])
    }

    function test_parseAwwwQuery() {
        compare(WP.parseAwwwQuery(": DP-1: 2560x1080, scale: 1, currently displaying: image: /home/u/Pictures/Wallpapers/a.jpg\n"), "/home/u/Pictures/Wallpapers/a.jpg")
        compare(WP.parseAwwwQuery(": DP-1: 2560x1080, scale: 1, currently displaying: image: /w/my wall.png"), "/w/my wall.png")
        compare(WP.parseAwwwQuery(": DP-1: 2560x1080, scale: 1, currently displaying: color: 000000"), "")
        compare(WP.parseAwwwQuery(""), "")
        compare(WP.parseAwwwQuery(undefined), "")
    }

    // ---- state file ----
    function test_parseState_valid() {
        compare(WP.parseState('{"path":"/w/a.png","effect":"scan"}'), { path: "/w/a.png", effect: "scan" })
    }

    function test_parseState_falls_back_on_anything_wrong() {
        compare(WP.parseState(""), { path: "", effect: "laser" })
        compare(WP.parseState("not json"), { path: "", effect: "laser" })
        compare(WP.parseState("[]"), { path: "", effect: "laser" })
        compare(WP.parseState("null"), { path: "", effect: "laser" })
        compare(WP.parseState('{"path":5,"effect":"warp"}'), { path: "", effect: "laser" })
        compare(WP.parseState('{"path":"/w/a.png"}'), { path: "/w/a.png", effect: "laser" })
    }

    function test_serializeState_round_trips() {
        compare(WP.parseState(WP.serializeState("/w/a b.png", "doors")), { path: "/w/a b.png", effect: "doors" })
        compare(WP.parseState(WP.serializeState("/w/a.png", "bogus")), { path: "/w/a.png", effect: "laser" })
    }

    function test_needsApply_only_when_the_selection_differs() {
        compare(WP.needsApply("/w/a.png", "/w/b.png"), true)
        compare(WP.needsApply("/w/a.png", "/w/a.png"), false)
        compare(WP.needsApply("/w/a.png", ""), false)
        compare(WP.needsApply("", "/w/b.png"), true)
    }

    // ---- the effect button: direction of the label animation, mouse wheel ----
    function test_effectDirection_follows_the_cycle() {
        compare(WP.effectDirection("laser", "hyperspace"), 1)
        compare(WP.effectDirection("scan", "laser"), 1)               // wraps forward
        compare(WP.effectDirection("hyperspace", "laser"), -1)
        compare(WP.effectDirection("laser", "scan"), -1)              // wraps backward
        compare(WP.effectDirection("nope", "laser"), 1)
    }

    function test_wheelStep_turns_a_full_notch_into_one_step() {
        compare(WP.wheelStep(0, -120), { steps: 1, acc: 0 })          // scrolling down goes forward
        compare(WP.wheelStep(0, 120), { steps: -1, acc: 0 })
        compare(WP.wheelStep(0, -360), { steps: 3, acc: 0 })
        compare(WP.wheelStep(0, 0), { steps: 0, acc: 0 })
    }

    function test_wheelStep_accumulates_small_touchpad_deltas() {
        compare(WP.wheelStep(0, -60), { steps: 0, acc: -60 })
        compare(WP.wheelStep(-60, -60), { steps: 1, acc: 0 })
        compare(WP.wheelStep(50, -200), { steps: 1, acc: -30 })
        compare(WP.wheelStep(0, -40, 40), { steps: 1, acc: 0 })       // custom notch
    }

    // ---- which wallpaper is on screen at start ----
    function test_chooseApplied_waits_for_awww_before_trusting_the_stored_path() {
        compare(WP.chooseApplied("", "/w/a.png", false), "")               // awww has not answered yet: decide nothing
        compare(WP.chooseApplied("/w/q.png", "/w/a.png", false), "")
        compare(WP.chooseApplied("/w/q.png", "/w/a.png", true), "/w/q.png")   // awww's own answer wins
        compare(WP.chooseApplied("", "/w/a.png", true), "/w/a.png")           // daemon silent: the stored path is the fallback
        compare(WP.chooseApplied("", "", true), "")
    }

    // ---- easings and clamp ----
    function test_clamp() {
        compare(WP.clamp(2), 1)
        compare(WP.clamp(-1), 0)
        compare(WP.clamp(0.4), 0.4)
        compare(WP.clamp(5, 0, 10), 5)
        compare(WP.clamp(-5, 0, 10), 0)
    }

    function test_easings_start_at_0_and_end_at_1() {
        var fns = [WP.easeInCubic, WP.easeOutCubic, WP.easeOutQuart, WP.easeOutExpo, WP.easeInOutCubic, WP.easeInOutQuart]
        for (var i = 0; i < fns.length; i++) {
            fuzzyCompare(fns[i](0), 0, 0.001)
            fuzzyCompare(fns[i](1), 1, 0.001)
        }
        fuzzyCompare(WP.easeInOutCubic(0.5), 0.5, 0.001)
        fuzzyCompare(WP.easeInOutQuart(0.5), 0.5, 0.001)
        verify(WP.easeOutQuart(0.5) > 0.5)
        verify(WP.easeInCubic(0.5) < 0.5)
    }
}
