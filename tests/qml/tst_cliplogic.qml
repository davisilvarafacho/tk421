import QtQuick
import QtTest

import "../../clipboard/logic.js" as Logic

TestCase {
    name: "ClipboardLogic"

    function test_parseList_reads_id_and_preview() {
        const r = Logic.parseList("12\thello world\n11\tsecond\n")
        compare(r.length, 2)
        compare(r[0].id, 12)
        compare(r[0].preview, "hello world")
        compare(r[1].id, 11)
    }

    function test_parseList_skips_bad_lines() {
        compare(Logic.parseList("\nnot a record\nabc\tx\n5\tok").length, 1)
        compare(Logic.parseList("").length, 0)
        compare(Logic.parseList(null).length, 0)
    }

    function test_parseList_keeps_tabs_inside_the_preview() {
        const r = Logic.parseList("7\ta\tb")
        compare(r[0].preview, "a b")
    }

    function test_image_record() {
        const r = Logic.record(3, "[[ binary data 97 KiB png 508x284 ]]")
        compare(r.kind, "image")
        compare(r.meta, "PNG · 508×284")
        compare(r.size, "97 KiB")
    }

    function test_link_record() {
        compare(Logic.record(1, "https://doc.qt.io/qt-6/x.html").kind, "link")
        compare(Logic.record(1, "www.example.com/a").kind, "link")
        compare(Logic.record(1, "see https://example.com").kind, "text")
    }

    function test_code_record() {
        compare(Logic.record(1, "pacman -Syu && paru -Sua").kind, "code")
        compare(Logic.record(1, "const x = a.map(e => e.id)").kind, "code")
        compare(Logic.record(1, "git status").kind, "code")
        compare(Logic.record(1, "Reunião amanhã às 10:00").kind, "text")
    }

    function test_clean_strips_control_and_bidi() {
        compare(Logic.record(1, "a‮b\u0000c").preview, "abc")
    }

    function test_rank_without_query_keeps_newest_first() {
        const recs = Logic.parseList("3\tbanana\n2\tapple\n1\tcherry")
        const r = Logic.rank(recs, "", 50)
        compare(r.map(x => x.rec.id).join(","), "3,2,1")
    }

    function test_rank_with_query_filters_and_orders_by_score() {
        const recs = Logic.parseList("3\tmy git notes\n2\tgit\n1\tcherry")
        const r = Logic.rank(recs, "git", 50)
        compare(r.length, 2)
        compare(r[0].rec.id, 2)
    }

    function test_rank_honours_the_limit() {
        let text = ""
        for (let i = 100; i > 0; i--)
            text += i + "\tentry " + i + "\n"
        compare(Logic.rank(Logic.parseList(text), "", 50).length, 50)
        compare(Logic.rank(Logic.parseList(text), "").length, 50)
    }

    function test_images_are_found_by_name() {
        const recs = Logic.parseList("2\t[[ binary data 1 KiB png 2x2 ]]\n1\ttext")
        compare(Logic.rank(recs, "image", 50).length, 1)
    }

    function test_previewText_limits_lines() {
        compare(Logic.previewText("a\nb\nc\nd", 2), "a\nb")
        compare(Logic.previewText("a\r\nb", 5), "a\nb")
    }
}
