//! Input mouse state tests.
//!
//! These tests use the public Yuki2D facade so they exercise the same surface
//! that future Luau bindings should mirror.

const std = @import("std");
const yuki2d = @import("../yuki2d.zig");

const input = yuki2d.input;

const State = input.State;
const Vector2 = yuki2d.Vector2;

test "mouse motion accumulates delta for one frame" {
    var state = State.init();

    state.setMousePosition(Vector2.xy(10.0, 20.0));
    state.setMousePosition(Vector2.xy(14.0, 18.0));

    try std.testing.expect(state.isMouseInsideWindow());
    try std.testing.expectEqual(@as(f32, 14.0), state.mousePosition().x);
    try std.testing.expectEqual(@as(f32, 18.0), state.mousePosition().y);
    try std.testing.expectEqual(@as(f32, 14.0), state.mouseDelta().x);
    try std.testing.expectEqual(@as(f32, 18.0), state.mouseDelta().y);

    state.beginFrame();

    try std.testing.expectEqual(@as(f32, 14.0), state.mousePosition().x);
    try std.testing.expectEqual(@as(f32, 18.0), state.mousePosition().y);
    try std.testing.expectEqual(@as(f32, 0.0), state.mouseDelta().x);
    try std.testing.expectEqual(@as(f32, 0.0), state.mouseDelta().y);
}

test "mouse wheel is frame local" {
    var state = State.init();

    state.addMouseWheel(
        Vector2.xy(0.0, 1.0),
        Vector2.xy(40.0, 50.0),
    );

    try std.testing.expectEqual(@as(f32, 0.0), state.mouseWheel().x);
    try std.testing.expectEqual(@as(f32, 1.0), state.mouseWheel().y);
    try std.testing.expectEqual(@as(f32, 40.0), state.mousePosition().x);
    try std.testing.expectEqual(@as(f32, 50.0), state.mousePosition().y);

    state.beginFrame();

    try std.testing.expectEqual(@as(f32, 0.0), state.mouseWheel().x);
    try std.testing.expectEqual(@as(f32, 0.0), state.mouseWheel().y);
}

test "mouse button pressed and released are one-frame edges" {
    var state = State.init();

    state.setMouseButton(.left, true, Vector2.xy(12.0, 18.0));

    try std.testing.expect(state.isMouseButtonDown(.left));
    try std.testing.expect(state.wasMouseButtonPressed(.left));
    try std.testing.expect(!state.wasMouseButtonReleased(.left));

    state.beginFrame();

    try std.testing.expect(state.isMouseButtonDown(.left));
    try std.testing.expect(!state.wasMouseButtonPressed(.left));

    state.setMouseButton(.left, false, Vector2.xy(12.0, 18.0));

    try std.testing.expect(!state.isMouseButtonDown(.left));
    try std.testing.expect(state.wasMouseButtonReleased(.left));
}

test "release all clears mouse buttons" {
    var state = State.init();

    state.setMouseButton(.right, true, Vector2.xy(1.0, 2.0));
    try std.testing.expect(state.isMouseButtonDown(.right));

    state.releaseAll();

    try std.testing.expect(!state.isMouseButtonDown(.right));
    try std.testing.expect(state.wasMouseButtonReleased(.right));
    try std.testing.expect(!state.isMouseInsideWindow());
}
