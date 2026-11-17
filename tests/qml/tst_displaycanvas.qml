import QtQuick
import QtTest
import "../../modules/nexus/common"

Item {
    id: host

    width: 720
    height: 320

    DisplayCanvas {
        id: canvas

        width: 680
        layout: [{ name: "DP-1", x: 0, y: 0, w: 2560, h: 1440 }, { name: "HDMI-A-1", x: 2560, y: 180, w: 1920, h: 1080 }]
        labels: ({ "DP-1": { number: "1", title: "MSI", detail: "2560×1440" }, "HDMI-A-1": { number: "2", title: "Dell", detail: "1920×1080" } })
        selected: "DP-1"
    }

    SignalSpy {
        id: picked

        target: canvas
        signalName: "picked"
    }

    SignalSpy {
        id: dropped

        target: canvas
        signalName: "dropped"
    }

    TestCase {
        name: "DisplayCanvas"
        when: windowShown

        function tile(name) {
            return findChild(canvas, `tile-${name}`);
        }

        function init() {
            picked.clear();
            dropped.clear();
            canvas.selected = "DP-1";
            canvas.layout = [{ name: "DP-1", x: 0, y: 0, w: 2560, h: 1440 }, { name: "HDMI-A-1", x: 2560, y: 180, w: 1920, h: 1080 }];
            // The tiles glide to their places: wait until they are there
            wait(300);
        }

        function centre(name) {
            const t = tile(name);
            return canvas.mapFromItem(t, t.width / 2, t.height / 2);
        }

        function test_draws_every_display_in_proportion_and_side_by_side() {
            const a = tile("DP-1");
            const b = tile("HDMI-A-1");
            verify(a && b);
            verify(a.width > 8 && b.width > 8);
            // 2560 against 1920 pixels wide
            fuzzyCompare((a.width + 4) / (b.width + 4), 2560 / 1920, 0.05);
            // B starts where A ends
            fuzzyCompare(b.x - a.x, a.width + 4, 1.0);
            verify(b.x + b.width <= canvas.width);
        }

        function test_the_canvas_height_follows_the_arrangement() {
            verify(canvas.implicitHeight >= canvas.minimumHeight);
            verify(canvas.implicitHeight <= canvas.maximumHeight);
        }

        function test_a_click_without_moving_picks_the_display() {
            const c = centre("HDMI-A-1");
            mouseClick(canvas, c.x, c.y, Qt.LeftButton);
            compare(picked.count, 1);
            compare(picked.signalArguments[0][0], "HDMI-A-1");
            compare(dropped.count, 0);
        }

        function test_dragging_reports_where_the_display_was_left() {
            const c = centre("HDMI-A-1");
            const k = canvas.view.k;
            mousePress(canvas, c.x, c.y, Qt.LeftButton);
            mouseMove(canvas, c.x - 40, c.y + 30, 10, Qt.LeftButton);
            mouseMove(canvas, c.x - 90, c.y + 60, 10, Qt.LeftButton);
            verify(canvas.dragName === "HDMI-A-1");
            verify(canvas.ghost !== null, "a ghost of where it would land shows while dragging");
            mouseRelease(canvas, c.x - 90, c.y + 60, Qt.LeftButton);
            compare(dropped.count, 1);
            compare(dropped.signalArguments[0][0], "HDMI-A-1");
            // Moved 90 px to the left and 60 down on the canvas: that many logical pixels over the scale
            fuzzyCompare(dropped.signalArguments[0][1], 2560 - 90 / k, 40);
            fuzzyCompare(dropped.signalArguments[0][2], 180 + 60 / k, 40);
            compare(picked.count, 0);
            compare(canvas.dragName, "");
        }

        function test_the_view_does_not_change_under_the_pointer_while_dragging() {
            const c = centre("HDMI-A-1");
            const before = canvas.view.k;
            mousePress(canvas, c.x, c.y, Qt.LeftButton);
            mouseMove(canvas, c.x + 50, c.y + 30, 10, Qt.LeftButton);
            canvas.layout = [{ name: "DP-1", x: 0, y: 0, w: 2560, h: 1440 }, { name: "HDMI-A-1", x: 6000, y: 180, w: 1920, h: 1080 }];
            compare(canvas.view.k, before);
            mouseRelease(canvas, c.x + 50, c.y + 30, Qt.LeftButton);
        }

        function test_the_selected_display_looks_selected() {
            compare(tile("DP-1").color, canvas.selectedColor);
            compare(tile("HDMI-A-1").color, canvas.tileColor);
            canvas.selected = "HDMI-A-1";
            compare(tile("HDMI-A-1").color, canvas.selectedColor);
        }

        function test_nothing_is_dragged_when_it_is_disabled() {
            canvas.enabled = false;
            const c = centre("HDMI-A-1");
            mousePress(canvas, c.x, c.y, Qt.LeftButton);
            mouseMove(canvas, c.x + 80, c.y + 60, 10, Qt.LeftButton);
            mouseRelease(canvas, c.x + 80, c.y + 60, Qt.LeftButton);
            compare(dropped.count, 0);
            canvas.enabled = true;
        }
    }
}
