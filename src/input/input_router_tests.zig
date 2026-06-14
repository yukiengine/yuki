//! Input router tests.
//!
//! These tests cover dispatching key events through installed action maps and
//! the active input context.

const std = @import("std");
const yuki2d = @import("../yuki2d.zig");

const input = yuki2d.input;

const ActionMap = input.ActionMap;
const ActionMapId = input.ActionMapId;
const ActionMapSet = input.ActionMapSet;
const ActiveMapOptions = input.ActiveMapOptions;
const Axis1ActionId = input.Axis1ActionId;
const Axis2ActionId = input.Axis2ActionId;
const DigitalActionId = input.DigitalActionId;
const Error = input.Error;
const InputRouter = input.InputRouter;
const State = input.State;

test "action map set stores and replaces maps" {
    const gameplay = ActionMapId.fromIndex(0);
    const jump = DigitalActionId.fromIndex(0);

    var first = ActionMap.init();
    try first.bindDigitalKey(.space, jump);

    var replacement = ActionMap.init();
    try replacement.bindDigitalKey(.e, jump);

    var set = ActionMapSet.init();
    try set.put(gameplay, first);
    try set.put(gameplay, replacement);

    try std.testing.expectEqual(@as(usize, 1), set.count());
    try std.testing.expect(set.contains(gameplay));

    var state = State.init();
    const stored = set.getConst(gameplay) orelse return error.ExpectedMap;

    stored.applyKey(&state, .space, true, false);
    try std.testing.expect(!state.digitalDown(jump));

    stored.applyKey(&state, .e, true, false);
    try std.testing.expect(state.digitalDown(jump));
}

test "action map set removes maps" {
    const gameplay = ActionMapId.fromIndex(0);
    const ui = ActionMapId.fromIndex(1);

    var set = ActionMapSet.init();
    try set.put(gameplay, ActionMap.init());
    try set.put(ui, ActionMap.init());

    try std.testing.expect(set.remove(gameplay));
    try std.testing.expect(!set.contains(gameplay));
    try std.testing.expect(set.contains(ui));
    try std.testing.expectEqual(@as(usize, 1), set.count());
    try std.testing.expect(!set.remove(gameplay));
}

test "input router requires maps before activation" {
    const gameplay = ActionMapId.fromIndex(0);

    var router = InputRouter.init();

    try std.testing.expectError(
        Error.UnknownActionMap,
        router.pushMap(gameplay),
    );
}

test "input router routes key events through one active map" {
    const gameplay = ActionMapId.fromIndex(0);
    const jump = DigitalActionId.fromIndex(0);

    var map = ActionMap.init();
    try map.bindDigitalKey(.space, jump);

    var router = InputRouter.init();
    try router.putMap(gameplay, map);
    try router.pushMap(gameplay);

    var state = State.init();

    try router.applyKey(&state, .space, true, false);
    try std.testing.expect(state.isKeyDown(.space));
    try std.testing.expect(state.digitalDown(jump));
    try std.testing.expect(state.digitalPressed(jump));

    state.beginFrame();

    try router.applyKey(&state, .space, false, false);
    try std.testing.expect(!state.isKeyDown(.space));
    try std.testing.expect(!state.digitalDown(jump));
    try std.testing.expect(state.digitalReleased(jump));
}

test "input router ignores inactive installed maps" {
    const gameplay = ActionMapId.fromIndex(0);
    const ui = ActionMapId.fromIndex(1);
    const jump = DigitalActionId.fromIndex(0);
    const confirm = DigitalActionId.fromIndex(1);

    var gameplay_map = ActionMap.init();
    try gameplay_map.bindDigitalKey(.space, jump);

    var ui_map = ActionMap.init();
    try ui_map.bindDigitalKey(.space, confirm);

    var router = InputRouter.init();
    try router.putMap(gameplay, gameplay_map);
    try router.putMap(ui, ui_map);
    try router.pushMap(gameplay);

    var state = State.init();

    try router.applyKey(&state, .space, true, false);
    try std.testing.expect(state.digitalDown(jump));
    try std.testing.expect(!state.digitalDown(confirm));
}

test "input router respects modal blocking maps" {
    const gameplay = ActionMapId.fromIndex(0);
    const pause_menu = ActionMapId.fromIndex(1);
    const move = Axis1ActionId.fromIndex(0);
    const menu_x = Axis1ActionId.fromIndex(1);

    var gameplay_map = ActionMap.init();
    try gameplay_map.bindAxis1Keys(.a, .d, move);

    var menu_map = ActionMap.init();
    try menu_map.bindAxis1Keys(.left, .right, menu_x);

    var router = InputRouter.init();
    try router.putMap(gameplay, gameplay_map);
    try router.putMap(pause_menu, menu_map);
    try router.pushMapOptions(gameplay, .{ .priority = 0 });
    try router.pushMapOptions(pause_menu, ActiveMapOptions.modal(100));

    var state = State.init();

    try router.applyKey(&state, .d, true, false);
    try std.testing.expectEqual(@as(f32, 0.0), state.axis1(move));
    try std.testing.expectEqual(@as(f32, 0.0), state.axis1(menu_x));

    try router.applyKey(&state, .right, true, false);
    try std.testing.expectEqual(@as(f32, 0.0), state.axis1(move));
    try std.testing.expectEqual(@as(f32, 1.0), state.axis1(menu_x));
}

test "input router lets higher priority non-blocking maps coexist" {
    const gameplay = ActionMapId.fromIndex(0);
    const debug = ActionMapId.fromIndex(1);
    const jump = DigitalActionId.fromIndex(0);
    const toggle_debug = DigitalActionId.fromIndex(1);

    var gameplay_map = ActionMap.init();
    try gameplay_map.bindDigitalKey(.space, jump);

    var debug_map = ActionMap.init();
    try debug_map.bindDigitalKey(.f1, toggle_debug);

    var router = InputRouter.init();
    try router.putMap(gameplay, gameplay_map);
    try router.putMap(debug, debug_map);
    try router.pushMapOptions(gameplay, .{ .priority = 0 });
    try router.pushMapOptions(debug, .{ .priority = 100, .blocking = false });

    var state = State.init();

    try router.applyKey(&state, .space, true, false);
    try router.applyKey(&state, .f1, true, false);

    try std.testing.expect(state.digitalDown(jump));
    try std.testing.expect(state.digitalDown(toggle_debug));
}

test "input router routes axis2 through active maps" {
    const gameplay = ActionMapId.fromIndex(0);
    const move = Axis2ActionId.fromIndex(0);

    var gameplay_map = ActionMap.init();
    try gameplay_map.bindAxis2Keys(.a, .d, .w, .s, move);

    var router = InputRouter.init();
    try router.putMap(gameplay, gameplay_map);
    try router.pushMap(gameplay);

    var state = State.init();

    try router.applyKey(&state, .d, true, false);
    try router.applyKey(&state, .w, true, false);

    const value = state.axis2(move);
    try std.testing.expectEqual(@as(f32, 1.0), value.x);
    try std.testing.expectEqual(@as(f32, -1.0), value.y);
}

test "input router can dispatch to all maps without context" {
    const gameplay = ActionMapId.fromIndex(0);
    const ui = ActionMapId.fromIndex(1);
    const jump = DigitalActionId.fromIndex(0);
    const confirm = DigitalActionId.fromIndex(1);

    var gameplay_map = ActionMap.init();
    try gameplay_map.bindDigitalKey(.space, jump);

    var ui_map = ActionMap.init();
    try ui_map.bindDigitalKey(.space, confirm);

    var router = InputRouter.init();
    try router.putMap(gameplay, gameplay_map);
    try router.putMap(ui, ui_map);

    var state = State.init();

    router.applyKeyToAllMaps(&state, .space, true, false);

    try std.testing.expect(state.digitalDown(jump));
    try std.testing.expect(state.digitalDown(confirm));
}
