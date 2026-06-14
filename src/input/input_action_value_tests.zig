//! Input typed action value tests.
//!
//! These tests cover the new digital, axis1, and axis2 value API that action
//! maps will resolve into.

const std = @import("std");
const yuki2d = @import("../yuki2d.zig");

const input = yuki2d.input;

const Axis1ActionId = input.Axis1ActionId;
const Axis2ActionId = input.Axis2ActionId;
const DigitalActionId = input.DigitalActionId;
const State = input.State;
const Vector2 = input.Vector2;

test "digital action API preserves edge state" {
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

test "axis1 action stores value previous value and changed edge" {
    const move_x = Axis1ActionId.fromIndex(0);
    var state = State.init();

    try std.testing.expectEqual(@as(f32, 0.0), state.axis1(move_x));
    try std.testing.expectEqual(@as(f32, 0.0), state.axis1Previous(move_x));
    try std.testing.expect(!state.axis1Changed(move_x));

    state.setAxis1(move_x, 1.0);
    try std.testing.expectEqual(@as(f32, 1.0), state.axis1(move_x));
    try std.testing.expectEqual(@as(f32, 0.0), state.axis1Previous(move_x));
    try std.testing.expect(state.axis1Changed(move_x));

    state.beginFrame();
    try std.testing.expectEqual(@as(f32, 1.0), state.axis1(move_x));
    try std.testing.expectEqual(@as(f32, 1.0), state.axis1Previous(move_x));
    try std.testing.expect(!state.axis1Changed(move_x));
}

test "axis2 action stores vector value previous value and changed edge" {
    const move = Axis2ActionId.fromIndex(0);
    var state = State.init();

    state.setAxis2(move, Vector2.xy(1.0, -1.0));

    const value = state.axis2(move);
    const previous = state.axis2Previous(move);

    try std.testing.expectEqual(@as(f32, 1.0), value.x);
    try std.testing.expectEqual(@as(f32, -1.0), value.y);
    try std.testing.expectEqual(@as(f32, 0.0), previous.x);
    try std.testing.expectEqual(@as(f32, 0.0), previous.y);
    try std.testing.expect(state.axis2Changed(move));

    state.beginFrame();
    try std.testing.expect(!state.axis2Changed(move));
}

test "digital action pairs can produce typed axes" {
    const left = DigitalActionId.fromIndex(0);
    const right = DigitalActionId.fromIndex(1);
    const up = DigitalActionId.fromIndex(2);
    const down = DigitalActionId.fromIndex(3);

    var state = State.init();

    state.setDigitalDown(right, true);
    state.setDigitalDown(up, true);

    try std.testing.expectEqual(@as(f32, 1.0), state.digitalAxis1(left, right));

    const move = state.digitalAxis2(left, right, up, down);
    try std.testing.expectEqual(@as(f32, 1.0), move.x);
    try std.testing.expectEqual(@as(f32, -1.0), move.y);
}

test "release all neutralizes typed action values" {
    const jump = DigitalActionId.fromIndex(0);
    const throttle = Axis1ActionId.fromIndex(0);
    const move = Axis2ActionId.fromIndex(0);

    var state = State.init();

    state.setDigitalDown(jump, true);
    state.setAxis1(throttle, 0.75);
    state.setAxis2(move, Vector2.xy(-1.0, 1.0));

    state.beginFrame();
    state.releaseAll();

    const move_value = state.axis2(move);

    try std.testing.expect(!state.digitalDown(jump));
    try std.testing.expect(state.digitalReleased(jump));
    try std.testing.expectEqual(@as(f32, 0.0), state.axis1(throttle));
    try std.testing.expect(state.axis1Changed(throttle));
    try std.testing.expectEqual(@as(f32, 0.0), move_value.x);
    try std.testing.expectEqual(@as(f32, 0.0), move_value.y);
    try std.testing.expect(state.axis2Changed(move));
}
