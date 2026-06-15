//! Input digital key and action edge tests.
//!
//! These tests use typed digital action handles directly. The old generic
//! `ActionId` compatibility name has been removed so the tests mirror the
//! current input API shape.

const std = @import("std");
const yuki2d = @import("../yuki2d.zig");

const input = yuki2d.input;

const DigitalActionId = input.DigitalActionId;
const State = input.State;

test "digital action pressed and released are one-frame edges" {
    const jump = DigitalActionId.fromIndex(0);
    var state = State.init();

    state.setDigitalDown(jump, true);
    try std.testing.expect(state.digitalDown(jump));
    try std.testing.expect(state.digitalPressed(jump));
    try std.testing.expect(!state.digitalReleased(jump));

    state.beginFrame();
    try std.testing.expect(state.digitalDown(jump));
    try std.testing.expect(!state.digitalPressed(jump));
    try std.testing.expect(!state.digitalReleased(jump));

    state.setDigitalDown(jump, false);
    try std.testing.expect(!state.digitalDown(jump));
    try std.testing.expect(!state.digitalPressed(jump));
    try std.testing.expect(state.digitalReleased(jump));
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

test "digital axis combines opposite digital actions" {
    const move_left = DigitalActionId.fromIndex(0);
    const move_right = DigitalActionId.fromIndex(1);
    var state = State.init();

    try std.testing.expectEqual(@as(f32, 0.0), state.digitalAxis1(move_left, move_right));

    state.setDigitalDown(move_left, true);
    try std.testing.expectEqual(@as(f32, -1.0), state.digitalAxis1(move_left, move_right));

    state.setDigitalDown(move_right, true);
    try std.testing.expectEqual(@as(f32, 0.0), state.digitalAxis1(move_left, move_right));

    state.setDigitalDown(move_left, false);
    try std.testing.expectEqual(@as(f32, 1.0), state.digitalAxis1(move_left, move_right));
}
