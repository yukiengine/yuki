//! Demo input integration tests.
//!
//! These tests verify that the demo uses the new InputRouter path while keeping
//! the current gameplay controls behavior.

const std = @import("std");
const demo = @import("demo.zig");
const yuki2d = @import("yuki2d.zig");

const input = yuki2d.input;

test "demo controls install gameplay map in router" {
    const router = demo.Controls.defaultInputRouter();

    try std.testing.expect(router.hasMap(demo.Controls.gameplay_map));
    try std.testing.expect(router.activeContext().containsMap(demo.Controls.gameplay_map));
    try std.testing.expect(router.activeContext().canProcessMap(demo.Controls.gameplay_map));
}

test "demo controls route movement through input router" {
    const router = demo.Controls.defaultInputRouter();
    var state = input.State.init();

    try router.applyKey(&state, .d, true, false);
    try router.applyKey(&state, .w, true, false);

    const frame_input = demo.Input.fromState(&state);

    try std.testing.expectEqual(@as(f32, 1.0), frame_input.move_x);
    try std.testing.expectEqual(@as(f32, -1.0), frame_input.move_y);
}

test "demo controls keep opposite directions neutral" {
    const router = demo.Controls.defaultInputRouter();
    var state = input.State.init();

    try router.applyKey(&state, .a, true, false);
    try router.applyKey(&state, .d, true, false);

    const frame_input = demo.Input.fromState(&state);

    try std.testing.expectEqual(@as(f32, 0.0), frame_input.move_x);
}

test "demo controls expose one-frame action presses" {
    const router = demo.Controls.defaultInputRouter();
    var state = input.State.init();

    try router.applyKey(&state, .f1, true, false);

    var frame_input = demo.Input.fromState(&state);
    try std.testing.expect(frame_input.toggle_debug_pressed);

    state.beginFrame();

    frame_input = demo.Input.fromState(&state);
    try std.testing.expect(!frame_input.toggle_debug_pressed);
}

test "demo controls preserve compatibility input map" {
    var map = demo.Controls.defaultInputMap();
    var state = input.State.init();

    map.applyKey(&state, .space, true, false);

    const frame_input = demo.Input.fromState(&state);

    try std.testing.expect(frame_input.pause_animation_pressed);
}
