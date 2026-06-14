//! Input action map tests.
//!
//! These tests use the public Yuki2D facade so they exercise the same surface
//! that future Luau bindings should mirror.

const std = @import("std");
const yuki2d = @import("../yuki2d.zig");

const input = yuki2d.input;

const ActionId = input.ActionId;
const InputMap = input.InputMap;
const State = input.State;

test "input map derives actions from keys" {
    const jump = ActionId.fromIndex(0);

    var map = InputMap.init();
    try map.bind(.space, jump);

    var state = State.init();

    map.applyKey(&state, .space, true, false);
    try std.testing.expect(state.isKeyDown(.space));
    try std.testing.expect(state.wasKeyPressed(.space));
    try std.testing.expect(state.isActionDown(jump));
    try std.testing.expect(state.actionWasPressed(jump));

    state.beginFrame();

    map.applyKey(&state, .space, false, false);
    try std.testing.expect(!state.isKeyDown(.space));
    try std.testing.expect(state.wasKeyReleased(.space));
    try std.testing.expect(!state.isActionDown(jump));
    try std.testing.expect(state.actionWasReleased(jump));
}

test "input map aliases stay down until every bound key is released" {
    const move_left = ActionId.fromIndex(0);

    var map = InputMap.init();
    try map.bind(.a, move_left);
    try map.bind(.left, move_left);

    var state = State.init();

    map.applyKey(&state, .a, true, false);
    try std.testing.expect(state.isActionDown(move_left));
    try std.testing.expect(state.actionWasPressed(move_left));

    state.beginFrame();

    map.applyKey(&state, .left, true, false);
    try std.testing.expect(state.isActionDown(move_left));
    try std.testing.expect(!state.actionWasPressed(move_left));

    state.beginFrame();

    map.applyKey(&state, .a, false, false);
    try std.testing.expect(!state.isKeyDown(.a));
    try std.testing.expect(state.isKeyDown(.left));
    try std.testing.expect(state.isActionDown(move_left));
    try std.testing.expect(!state.actionWasReleased(move_left));

    state.beginFrame();

    map.applyKey(&state, .left, false, false);
    try std.testing.expect(!state.isActionDown(move_left));
    try std.testing.expect(state.actionWasReleased(move_left));
}

test "input map ignores repeated key down events" {
    const pause = ActionId.fromIndex(0);

    var map = InputMap.init();
    try map.bind(.space, pause);

    var state = State.init();

    map.applyKey(&state, .space, true, false);
    try std.testing.expect(state.actionWasPressed(pause));

    state.beginFrame();

    map.applyKey(&state, .space, true, true);
    try std.testing.expect(state.isKeyDown(.space));
    try std.testing.expect(state.isActionDown(pause));
    try std.testing.expect(!state.wasKeyPressed(.space));
    try std.testing.expect(!state.actionWasPressed(pause));
}

test "release all clears keys and actions" {
    const move_left = ActionId.fromIndex(0);
    const pause = ActionId.fromIndex(1);

    var map = InputMap.init();
    try map.bind(.a, move_left);
    try map.bind(.space, pause);

    var state = State.init();

    map.applyKey(&state, .a, true, false);
    map.applyKey(&state, .space, true, false);

    try std.testing.expect(state.isActionDown(move_left));
    try std.testing.expect(state.isActionDown(pause));

    state.releaseAll();

    try std.testing.expect(!state.isKeyDown(.a));
    try std.testing.expect(!state.isKeyDown(.space));
    try std.testing.expect(!state.isActionDown(move_left));
    try std.testing.expect(!state.isActionDown(pause));
    try std.testing.expect(state.wasKeyReleased(.a));
    try std.testing.expect(state.actionWasReleased(move_left));
}
