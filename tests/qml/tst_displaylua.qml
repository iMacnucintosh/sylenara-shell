import QtQuick
import QtTest
import "../../utils/scripts/displaylua.js" as Lua

TestCase {
    name: "DisplayLua"

    function rule(extra) {
        return Object.assign({ name: "DP-1", mode: "2560x1440@144", x: 0, y: 0, scale: 1, transform: 0, vrr: 2, mirror: null, disabled: false }, extra || {});
    }

    function test_block_writes_every_field_of_an_active_output() {
        const text = Lua.block(rule({ x: 1920, y: -180, scale: 1.25, transform: 1 }));
        verify(text.indexOf('output   = "DP-1"') >= 0);
        verify(text.indexOf('mode     = "2560x1440@144"') >= 0);
        verify(text.indexOf('position = "1920x-180"') >= 0);
        verify(text.indexOf("scale    = 1.25") >= 0);
        verify(text.indexOf("transform = 1") >= 0);
        verify(text.indexOf("vrr      = 2") >= 0);
        verify(text.indexOf("mirror") < 0);
        verify(text.indexOf("disabled") < 0);
    }

    function test_a_position_that_is_not_known_stays_auto() {
        verify(Lua.block(rule({ x: null, y: null })).indexOf('position = "auto"') >= 0);
    }

    function test_a_disabled_output_is_only_turned_off() {
        const text = Lua.block(rule({ disabled: true }));
        verify(text.indexOf("disabled = true") >= 0);
        verify(text.indexOf("mode") < 0);
        verify(text.indexOf("position") < 0);
    }

    function test_a_mirror_names_the_output_it_copies() {
        verify(Lua.block(rule({ name: "HDMI-A-1", mirror: "DP-1" })).indexOf('mirror   = "DP-1"') >= 0);
    }

    function test_parse_reads_back_what_block_wrote() {
        const rules = [rule({ x: 0, y: 0 }), rule({ name: "HDMI-A-1", mode: "1920x1080@60", x: 2560, y: 360, scale: 1.5, transform: 3, vrr: 0 }),
                       rule({ name: "eDP-1", disabled: true }), rule({ name: "DP-2", mirror: "DP-1" })];
        const text = "-- header\n\n" + rules.map(r => Lua.block(r)).join("\n");
        const back = Lua.parse(text);
        compare(back.length, 4);
        compare(back[1].name, "HDMI-A-1");
        compare(back[1].x, 2560);
        compare(back[1].y, 360);
        compare(back[1].scale, 1.5);
        compare(back[1].transform, 3);
        compare(back[1].vrr, 0);
        compare(back[2].disabled, true);
        compare(back[3].mirror, "DP-1");
        compare(back[0].mirror, null);
    }

    function test_parse_reads_the_old_files_that_only_had_auto_positions() {
        const old = 'hl.monitor({\n    output   = "DP-1",\n    mode     = "2560x1440@240",\n    position = "auto",\n    scale    = 1,\n    bitdepth = 8,\n    vrr      = 2,\n})\n';
        const back = Lua.parse(old);
        compare(back.length, 1);
        compare(back[0].x, null);
        compare(back[0].transform, 0);
        compare(back[0].vrr, 2);
        compare(back[0].disabled, false);
    }

    function test_names_with_quotes_survive() {
        const back = Lua.parse(Lua.block(rule({ name: 'Odd "one"' })));
        compare(back[0].name, 'Odd "one"');
    }

    function test_unplugged_keeps_only_outputs_that_are_not_there() {
        const text = Lua.block(rule()) + "\n" + Lua.block(rule({ name: "HDMI-A-1" }));
        const gone = Lua.unplugged(text, ["DP-1"]);
        compare(gone.length, 1);
        compare(gone[0].name, "HDMI-A-1");
    }

    function test_inline_is_one_line_for_hyprctl() {
        const line = Lua.inline(rule({ x: 10, y: 20 }));
        verify(line.indexOf("\n") < 0);
        verify(line.indexOf("hl.monitor({") === 0);
        verify(/\}\)$/.test(line));
        verify(line.indexOf('position = "10x20"') >= 0);
        // The line is itself a rule that can be read back
        compare(Lua.parse(line)[0].x, 10);
    }

    function test_mirror_needs_a_real_and_different_output() {
        const mons = [{ name: "DP-1", disabled: false, mirror: null }, { name: "DP-2", disabled: false, mirror: "DP-1" }, { name: "DP-3", disabled: true, mirror: null }];
        verify(Lua.validMirror("DP-2", "DP-1", mons));
        verify(!Lua.validMirror("DP-1", "DP-1", mons)); // itself
        verify(!Lua.validMirror("DP-1", "DP-2", mons)); // a mirror cannot be mirrored
        verify(!Lua.validMirror("DP-1", "DP-3", mons)); // an output that is off
        verify(!Lua.validMirror("DP-1", "DP-9", mons)); // not there
        verify(!Lua.validMirror("DP-1", "", mons));
    }
}
