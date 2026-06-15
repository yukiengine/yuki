//! Input action map tests.
//!
//! These tests cover the current `ActionMap` API directly. The old `InputMap`
//! alias and generic `ActionId` name are gone; digital bindings now use
//! `DigitalActionId` explicitly.

const std = @import("std");
const yuki2d = @import("../yuki2d.zig");

const input = yuki2d.input;

const ActionMap = input.ActionMap;
const DigitalActionId = input.DigitalActionId;
const State = input.State;

test "action map derives digital actions from keys" {
    const jump = DigitalActionId.fromIndex(0);

    var map = ActionMap.init();
    try map.bindDigitalKey(.space, jump);

    var state = State.init();

    map.applyKey(&state, .space, true, false);
    try std.testing.expect(state.isKeyDown(.space));
    try std.testing.expect(state.wasKeyPressed(.space));
    try std.testing.expect(state.digitalDown(jump));
    try std.testing.expect(state.digitalPressed(jump));

    state.beginFrame();

    map.applyKey(&state, .space, false, false);
    try std.testing.expect(!state.isKeyDown(.space));
    try std.testing.expect(state.wasKeyReleased(.space));
    try std.testing.expect(!state.digitalDown(jump));
    try std.testing.expect(state.digitalReleased(jump));
}

test "action map aliases stay down until every bound key is released" {
    const move_left = DigitalActionId.fromIndex(0);

    var map = ActionMap.init();
    try map.bindDigitalKey(.a, move_left);
    try map.bindDigitalKey(.left, move_left);

    var state = State.init();

    map.applyKey(&state, .a, true, false);
    try std.testing.expect(state.digitalDown(move_left));
    try std.testing.expect(state.digitalPressed(move_left));

    state.beginFrame();

    map.applyKey(&state, .left, true, false);
    try std.testing.expect(state.digitalDown(move_left));
    try std.testing.expect(!state.digitalPressed(move_left));

    state.beginFrame();

    map.applyKey(&state, .a, false, false);
    try std.testing.expect(!state.isKeyDown(.a));
    try std.testing.expect(state.isKeyDown(.left));
    try std.testing.expect(state.digitalDown(move_left));
    try std.testing.expect(!state.digitalReleased(move_left));

    state.beginFrame();

    map.applyKey(&state, .left, false, false);
    try std.testing.expect(!state.digitalDown(move_left));
    try std.testing.expect(state.digitalReleased(move_left));
}

test "action map ignores repeated key down events" {
    const pause = DigitalActionId.fromIndex(0);

    var map = ActionMap.init();
    try map.bindDigitalKey(.space, pause);

    var state = State.init();

    map.applyKey(&state, .space, true, false);
    try std.testing.expect(state.digitalPressed(pause));

    state.beginFrame();

    map.applyKey(&state, .space, true, true);
    try std.testing.expect(state.isKeyDown(.space));
    try std.testing.expect(state.digitalDown(pause));
    try std.testing.expect(!state.wasKeyPressed(.space));
    try std.testing.expect(!state.digitalPressed(pause));
}

test "release all clears keys and digital actions" {
    const move_left = DigitalActionId.fromIndex(0);
    const pause = DigitalActionId.fromIndex(1);

    var map = ActionMap.init();
    try map.bindDigitalKey(.a, move_left);
    try map.bindDigitalKey(.space, pause);

    var state = State.init();

    map.applyKey(&state, .a, true, false);
    map.applyKey(&state, .space, true, false);

    try std.testing.expect(state.digitalDown(move_left));
    try std.testing.expect(state.digitalDown(pause));

    state.releaseAll();

    try std.testing.expect(!state.isKeyDown(.a));
    try std.testing.expect(!state.isKeyDown(.space));
    try std.testing.expect(!state.digitalDown(move_left));
    try std.testing.expect(!state.digitalDown(pause));
    try std.testing.expect(state.wasKeyReleased(.a));
    try std.testing.expect(state.digitalReleased(move_left));
}
