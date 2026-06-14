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

test "demo controls bind mouse button to select action" {
    const router = demo.Controls.defaultInputRouter();

    var state = input.State.init();
    var events = input.InputEventQueue.init();

    try router.applyMouseButtonWithEvents(
        &state,
        &events,
        .left,
        true,
        input.Vector2.xy(24.0, 32.0),
    );

    const frame_input = demo.Input.fromFrame(yuki2d.input_frame.Frame.init(
        &state,
        events.items(),
    ));

    try std.testing.expect(frame_input.select_down);
    try std.testing.expect(frame_input.select_pressed);
    try std.testing.expect(!frame_input.select_released);
    try std.testing.expectEqual(@as(f32, 24.0), frame_input.mouse_screen.x);
    try std.testing.expectEqual(@as(f32, 32.0), frame_input.mouse_screen.y);
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

    var frame_input = demo.Input.fromState(&state);
    try std.testing.expect(frame_input.pause_animation_pressed);

    state.beginFrame();

    map.applyMouseButton(
        &state,
        .left,
        true,
        input.Vector2.xy(0.0, 0.0),
    );

    frame_input = demo.Input.fromState(&state);
    try std.testing.expect(frame_input.select_pressed);
}

test "demo select action release is one-frame input" {
    const router = demo.Controls.defaultInputRouter();

    var state = input.State.init();
    var events = input.InputEventQueue.init();

    try router.applyMouseButtonWithEvents(
        &state,
        &events,
        .left,
        true,
        input.Vector2.xy(0.0, 0.0),
    );

    state.beginFrame();
    events.beginFrame();

    try router.applyMouseButtonWithEvents(
        &state,
        &events,
        .left,
        false,
        input.Vector2.xy(0.0, 0.0),
    );

    var frame_input = demo.Input.fromFrame(yuki2d.input_frame.Frame.init(
        &state,
        events.items(),
    ));

    try std.testing.expect(!frame_input.select_down);
    try std.testing.expect(!frame_input.select_pressed);
    try std.testing.expect(frame_input.select_released);

    state.beginFrame();
    events.beginFrame();

    frame_input = demo.Input.fromFrame(yuki2d.input_frame.Frame.init(
        &state,
        events.items(),
    ));

    try std.testing.expect(!frame_input.select_down);
    try std.testing.expect(!frame_input.select_pressed);
    try std.testing.expect(!frame_input.select_released);
}
