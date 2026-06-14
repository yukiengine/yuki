//! Input action map binding tests.
//!
//! These tests cover typed key bindings that resolve into digital, axis1, and
//! axis2 action state.

const std = @import("std");
const yuki2d = @import("../yuki2d.zig");

const input = yuki2d.input;

const ActionMap = input.ActionMap;
const Axis1ActionId = input.Axis1ActionId;
const Axis2ActionId = input.Axis2ActionId;
const DigitalActionId = input.DigitalActionId;
const State = input.State;

test "action map binds keys to digital actions" {
    const jump = DigitalActionId.fromIndex(0);

    var map = ActionMap.init();
    try map.bindDigitalKey(.space, jump);

    var state = State.init();

    map.applyKey(&state, .space, true, false);
    try std.testing.expect(state.isKeyDown(.space));
    try std.testing.expect(state.digitalDown(jump));
    try std.testing.expect(state.digitalPressed(jump));

    state.beginFrame();

    map.applyKey(&state, .space, false, false);
    try std.testing.expect(!state.isKeyDown(.space));
    try std.testing.expect(!state.digitalDown(jump));
    try std.testing.expect(state.digitalReleased(jump));
}

test "action map keeps digital aliases down until all keys release" {
    const interact = DigitalActionId.fromIndex(0);

    var map = ActionMap.init();
    try map.bindDigitalKey(.space, interact);
    try map.bindDigitalKey(.e, interact);

    var state = State.init();

    map.applyKey(&state, .space, true, false);
    try std.testing.expect(state.digitalDown(interact));
    try std.testing.expect(state.digitalPressed(interact));

    state.beginFrame();

    map.applyKey(&state, .e, true, false);
    try std.testing.expect(state.digitalDown(interact));
    try std.testing.expect(!state.digitalPressed(interact));

    state.beginFrame();

    map.applyKey(&state, .space, false, false);
    try std.testing.expect(!state.isKeyDown(.space));
    try std.testing.expect(state.isKeyDown(.e));
    try std.testing.expect(state.digitalDown(interact));
    try std.testing.expect(!state.digitalReleased(interact));

    state.beginFrame();

    map.applyKey(&state, .e, false, false);
    try std.testing.expect(!state.digitalDown(interact));
    try std.testing.expect(state.digitalReleased(interact));
}

test "action map binds key pair to axis1 action" {
    const move_x = Axis1ActionId.fromIndex(0);

    var map = ActionMap.init();
    try map.bindAxis1Keys(.a, .d, move_x);

    var state = State.init();

    map.applyKey(&state, .d, true, false);
    try std.testing.expectEqual(@as(f32, 1.0), state.axis1(move_x));
    try std.testing.expect(state.axis1Changed(move_x));

    state.beginFrame();

    map.applyKey(&state, .a, true, false);
    try std.testing.expectEqual(@as(f32, 0.0), state.axis1(move_x));
    try std.testing.expect(state.axis1Changed(move_x));

    state.beginFrame();

    map.applyKey(&state, .d, false, false);
    try std.testing.expectEqual(@as(f32, -1.0), state.axis1(move_x));
    try std.testing.expect(state.axis1Changed(move_x));
}

test "action map clamps multiple axis1 bindings for same action" {
    const move_x = Axis1ActionId.fromIndex(0);

    var map = ActionMap.init();
    try map.bindAxis1Keys(.a, .d, move_x);
    try map.bindAxis1Keys(.left, .right, move_x);

    var state = State.init();

    map.applyKey(&state, .d, true, false);
    map.applyKey(&state, .right, true, false);

    try std.testing.expectEqual(@as(f32, 1.0), state.axis1(move_x));

    state.beginFrame();

    map.applyKey(&state, .d, false, false);
    try std.testing.expectEqual(@as(f32, 1.0), state.axis1(move_x));
    try std.testing.expect(!state.axis1Changed(move_x));

    map.applyKey(&state, .right, false, false);
    try std.testing.expectEqual(@as(f32, 0.0), state.axis1(move_x));
    try std.testing.expect(state.axis1Changed(move_x));
}

test "action map binds key cross to axis2 action" {
    const move = Axis2ActionId.fromIndex(0);

    var map = ActionMap.init();
    try map.bindAxis2Keys(.a, .d, .w, .s, move);

    var state = State.init();

    map.applyKey(&state, .d, true, false);
    map.applyKey(&state, .w, true, false);

    const value = state.axis2(move);
    try std.testing.expectEqual(@as(f32, 1.0), value.x);
    try std.testing.expectEqual(@as(f32, -1.0), value.y);
    try std.testing.expect(state.axis2Changed(move));

    state.beginFrame();

    map.applyKey(&state, .s, true, false);

    const neutral_y = state.axis2(move);
    try std.testing.expectEqual(@as(f32, 1.0), neutral_y.x);
    try std.testing.expectEqual(@as(f32, 0.0), neutral_y.y);
    try std.testing.expect(state.axis2Changed(move));
}

test "action map ignores repeated key events" {
    const move_x = Axis1ActionId.fromIndex(0);

    var map = ActionMap.init();
    try map.bindAxis1Keys(.a, .d, move_x);

    var state = State.init();

    map.applyKey(&state, .d, true, false);
    try std.testing.expectEqual(@as(f32, 1.0), state.axis1(move_x));
    try std.testing.expect(state.axis1Changed(move_x));

    state.beginFrame();

    map.applyKey(&state, .d, true, true);
    try std.testing.expectEqual(@as(f32, 1.0), state.axis1(move_x));
    try std.testing.expect(!state.wasKeyPressed(.d));
    try std.testing.expect(!state.axis1Changed(move_x));
}
