//! Input digital key and action edge tests.
//!
//! These tests use the public Yuki2D facade so they exercise the same surface
//! that future Luau bindings should mirror.

const std = @import("std");
const yuki2d = @import("../yuki2d.zig");

const input = yuki2d.input;

const ActionId = input.ActionId;
const State = input.State;

test "action pressed and released are one-frame edges" {
    const jump = ActionId.fromIndex(0);
    var state = State.init();

    state.setActionDown(jump, true);
    try std.testing.expect(state.isActionDown(jump));
    try std.testing.expect(state.actionWasPressed(jump));
    try std.testing.expect(!state.actionWasReleased(jump));

    state.beginFrame();
    try std.testing.expect(state.isActionDown(jump));
    try std.testing.expect(!state.actionWasPressed(jump));
    try std.testing.expect(!state.actionWasReleased(jump));

    state.setActionDown(jump, false);
    try std.testing.expect(!state.isActionDown(jump));
    try std.testing.expect(!state.actionWasPressed(jump));
    try std.testing.expect(state.actionWasReleased(jump));
}

test "key pressed and released are one-frame edges" {
    var state = State.init();

    state.setKey(.space, true);
    try std.testing.expect(state.isKeyDown(.space));
    try std.testing.expect(state.wasKeyPressed(.space));
    try std.testing.expect(!state.wasKeyReleased(.space));

    state.beginFrame();

    state.setKey(.space, false);
    try std.testing.expect(!state.isKeyDown(.space));
    try std.testing.expect(state.wasKeyReleased(.space));
}

test "axis combines opposite actions" {
    const move_left = ActionId.fromIndex(0);
    const move_right = ActionId.fromIndex(1);
    var state = State.init();

    try std.testing.expectEqual(@as(i32, 0), state.axis(move_left, move_right));

    state.setActionDown(move_left, true);
    try std.testing.expectEqual(@as(i32, -1), state.axis(move_left, move_right));

    state.setActionDown(move_right, true);
    try std.testing.expectEqual(@as(i32, 0), state.axis(move_left, move_right));

    state.setActionDown(move_left, false);
    try std.testing.expectEqual(@as(i32, 1), state.axis(move_left, move_right));
}
