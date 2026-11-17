import QtQuick
import QtTest
import "../../utils/scripts/displaylayout.js" as Layout

// Run with: QT_QPA_PLATFORM=offscreen qmltestrunner -input tests/qml (tests/test_display_layout.py does it)
TestCase {
    name: "DisplayLayout"

    function d(name, x, y, w, h) {
        return { name: name, x: x, y: y, w: w, h: h };
    }

    function test_logical_size_divides_by_scale_and_turns_sideways() {
        compare(Layout.logicalSize(2560, 1440, 1, 0), { w: 2560, h: 1440 });
        compare(Layout.logicalSize(3840, 2160, 2, 0), { w: 1920, h: 1080 });
        compare(Layout.logicalSize(1920, 1080, 1, 1), { w: 1080, h: 1920 });
        compare(Layout.logicalSize(1920, 1080, 1.5, 3), { w: 720, h: 1280 });
        compare(Layout.logicalSize(1920, 1080, 0, 0), { w: 1920, h: 1080 }); // a broken scale counts as 1
    }

    function test_touching_needs_a_shared_piece_of_edge() {
        verify(Layout.touches(d("a", 0, 0, 100, 100), d("b", 100, 50, 100, 100)));
        verify(Layout.touches(d("a", 0, 0, 100, 100), d("b", 20, 100, 50, 50)));
        verify(!Layout.touches(d("a", 0, 0, 100, 100), d("b", 100, 100, 100, 100))); // only a corner
        verify(!Layout.touches(d("a", 0, 0, 100, 100), d("b", 110, 0, 100, 100))); // a gap
    }

    function test_a_display_dropped_beside_another_lands_against_its_edge() {
        const list = [d("A", 0, 0, 2560, 1440), d("B", 4000, 300, 1920, 1080)];
        // B dropped a bit to the right of A, well below its top: it sits on A's right edge, at the height it was dropped
        const p = Layout.snap(list, 1, 2700, 600);
        compare(p.x, 2560);
        compare(p.y, 600);
        // Dropped near the line of A's bottom edge, it aligns with it
        const q = Layout.snap(list, 1, 2700, 300);
        compare(q.y, 1440 - 1080);
    }

    function test_close_to_the_top_it_aligns_with_it() {
        const list = [d("A", 0, 0, 2560, 1440), d("B", 0, 0, 1920, 1080)];
        const top = Layout.snap(list, 1, 2600, 90);
        compare(top.x, 2560);
        compare(top.y, 0);
        // Close to the bottom edges too
        compare(Layout.snap(list, 1, 2600, 1440 - 1080 - 40).y, 360);
    }

    function test_never_lands_on_top_of_another() {
        const list = [d("A", 0, 0, 1920, 1080), d("B", 1920, 0, 1920, 1080), d("C", 0, 0, 1920, 1080)];
        const p = Layout.snap(list, 2, 1900, 10); // dropped right over the seam of A and B
        const spot = d("C", p.x, p.y, 1920, 1080);
        verify(!Layout.overlaps(spot, list[0]));
        verify(!Layout.overlaps(spot, list[1]));
        verify(Layout.touches(spot, list[0]) || Layout.touches(spot, list[1]));
    }

    function test_keeps_a_minimum_of_shared_edge() {
        const list = [d("A", 0, 0, 1920, 1080), d("B", 0, 0, 1920, 1080)];
        // Dropped almost below A's bottom right corner: it still shares at least 64 px with A
        const p = Layout.snap(list, 1, 1910, 1075);
        const spot = d("B", p.x, p.y, 1920, 1080);
        verify(Layout.touches(spot, list[0]));
        const shared = Math.min(spot.y + spot.h, 1080) - Math.max(spot.y, 0);
        const sharedX = Math.min(spot.x + spot.w, 1920) - Math.max(spot.x, 0);
        verify(shared >= 64 || sharedX >= 64);
    }

    function test_taking_the_middle_display_away_joins_the_others() {
        // A | B | C in a row; B is dragged below C: A must not stay alone
        const list = [d("A", 0, 0, 1920, 1080), d("B", 1920, 0, 1920, 1080), d("C", 3840, 0, 1920, 1080)];
        const out = Layout.drop(list, 1, 3840, 1100);
        compare(Layout.groups(out, 1).length, 1);
        for (let i = 0; i < out.length; i++)
            for (let j = i + 1; j < out.length; j++)
                verify(!Layout.overlaps(out[i], out[j]), `${out[i].name} and ${out[j].name} overlap`);
    }

    function test_drop_starts_the_arrangement_at_zero() {
        const list = [d("A", 0, 0, 1920, 1080), d("B", 1920, 0, 1920, 1080)];
        const out = Layout.drop(list, 1, -1920, 0); // B goes to the left of A
        const b = Layout.bounds(out);
        compare(b.x, 0);
        compare(b.y, 0);
        compare(out[1].x, 0);
        compare(out[0].x, 1920);
    }

    function test_numbering_goes_left_to_right_then_top_to_bottom() {
        const list = [d("DP-2", 2560, 0, 1920, 1080), d("DP-1", 0, 0, 2560, 1440), d("HDMI-A-1", 2560, 1080, 1920, 1080)];
        compare(Layout.numbering(list), { "DP-1": 1, "DP-2": 2, "HDMI-A-1": 3 });
    }

    function test_same_positions_compares_by_name() {
        const a = [d("A", 0, 0, 10, 10), d("B", 10, 0, 10, 10)];
        verify(Layout.samePositions(a, [d("B", 10, 0, 10, 10), d("A", 0, 0, 10, 10)]));
        verify(!Layout.samePositions(a, [d("A", 0, 0, 10, 10), d("B", 10, 5, 10, 10)]));
        compare(Layout.positionString(1920.4, -0.2), "1920x0");
    }

    function test_a_single_display_stays_where_it_is() {
        const alone = Layout.snap([d("A", 0, 0, 100, 100)], 0, 37, 12);
        compare(alone.x, 37);
        compare(alone.y, 12);
        compare(Layout.drop([d("A", 50, 50, 100, 100)], 0, 37, 12)[0].x, 0);
    }
}
