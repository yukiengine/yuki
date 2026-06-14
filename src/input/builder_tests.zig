//! Input action-map builder tests.
//!
//! These tests cover name-driven action-map construction on top of the compact
//! handle-based input runtime.

const std = @import("std");
const yuki2d = @import("../yuki2d.zig");

const input = yuki2d.input;

const ActionMapBuilder = input.ActionMapBuilder;
const ActionRegistry = input.ActionRegistry;
const Error = input.Error;
const InputRouter = input.InputRouter;
const InputEventQueue = input.InputEventQueue;
const State = input.State;
const Vector2 = input.Vector2;

test "action map builder binds named digital keyboard action" {
    var registry = ActionRegistry.init();
    const gameplay = try registry.addMap("gameplay");
    const jump = try registry.addDigital(gameplay, "player.jump");

    var builder = ActionMapBuilder.init(gameplay);
    try builder.bindDigitalKey(&registry, "player.jump", .space);

    const map = builder.build();

    var state = State.init();
    map.applyKey(&state, .space, true, false);

    try std.testing.expect(state.digitalDown(jump));
    try std.testing.expect(state.digitalPressed(jump));
}

test "action map builder binds named digital mouse action" {
    var registry = ActionRegistry.init();
    const gameplay = try registry.addMap("gameplay");
    const select = try registry.addDigital(gameplay, "player.select");

    var builder = ActionMapBuilder.init(gameplay);
    try builder.bindMouseButton(&registry, "player.select", .left);

    const map = builder.build();

    var state = State.init();
    map.applyMouseButton(&state, .left, true, Vector2.xy(12.0, 24.0));

    try std.testing.expect(state.isMouseButtonDown(.left));
    try std.testing.expect(state.digitalDown(select));
    try std.testing.expect(state.digitalPressed(select));
    try std.testing.expectEqual(@as(f32, 12.0), state.mousePosition().x);
    try std.testing.expectEqual(@as(f32, 24.0), state.mousePosition().y);
}

test "action map builder binds named axis actions" {
    var registry = ActionRegistry.init();
    const gameplay = try registry.addMap("gameplay");
    const move_x = try registry.addAxis1(gameplay, "player.move_x");
    const move = try registry.addAxis2(gameplay, "player.move");

    var builder = ActionMapBuilder.init(gameplay);
    try builder.bindAxis1Keys(&registry, "player.move_x", .a, .d);
    try builder.bindAxis2Keys(&registry, "player.move", .a, .d, .w, .s);

    const map = builder.build();

    var state = State.init();
    map.applyKey(&state, .d, true, false);
    map.applyKey(&state, .w, true, false);

    const move_value = state.axis2(move);

    try std.testing.expectEqual(@as(f32, 1.0), state.axis1(move_x));
    try std.testing.expectEqual(@as(f32, 1.0), move_value.x);
    try std.testing.expectEqual(@as(f32, -1.0), move_value.y);
}

test "action map builder resolves map names" {
    var registry = ActionRegistry.init();
    const gameplay = try registry.addMap("gameplay");
    const jump = try registry.addDigital(gameplay, "player.jump");

    var builder = try ActionMapBuilder.fromMapName(&registry, "gameplay");
    try builder.bindDigitalKey(&registry, "player.jump", .space);

    try std.testing.expect(builder.id().eql(gameplay));

    const map = builder.build();

    var state = State.init();
    map.applyKey(&state, .space, true, false);

    try std.testing.expect(state.digitalDown(jump));
}

test "action map builder installs maps into router" {
    var registry = ActionRegistry.init();
    const gameplay = try registry.addMap("gameplay");
    const jump = try registry.addDigital(gameplay, "player.jump");

    var builder = try ActionMapBuilder.fromMapName(&registry, "gameplay");
    try builder.bindDigitalKey(&registry, "player.jump", .space);

    var router = InputRouter.init();
    try builder.install(&router);
    try router.pushMap(gameplay);

    var state = State.init();
    try router.applyKey(&state, .space, true, false);

    try std.testing.expect(router.hasMap(gameplay));
    try std.testing.expect(state.digitalDown(jump));
}

test "action map builder routes named mouse actions through router events" {
    var registry = ActionRegistry.init();
    const gameplay = try registry.addMap("gameplay");
    const select = try registry.addDigital(gameplay, "player.select");

    var builder = try ActionMapBuilder.fromMapName(&registry, "gameplay");
    try builder.bindMouseButton(&registry, "player.select", .left);

    var router = InputRouter.init();
    try builder.install(&router);
    try router.pushMap(gameplay);

    var state = State.init();
    var events = InputEventQueue.init();

    try router.applyMouseButtonWithEvents(
        &state,
        &events,
        .left,
        true,
        Vector2.xy(0.0, 0.0),
    );

    try std.testing.expect(state.digitalDown(select));
    try std.testing.expectEqual(@as(usize, 2), events.count());

    switch (events.items()[1]) {
        .action_pressed => |event| {
            try std.testing.expect(event.map.eql(gameplay));
            try std.testing.expectEqual(select.index, event.action.index);
        },
        else => return error.ExpectedActionPressed,
    }
}

test "action map builder reports unknown map names" {
    var registry = ActionRegistry.init();

    try std.testing.expectError(
        Error.UnknownActionMap,
        ActionMapBuilder.fromMapName(&registry, "missing"),
    );
}

test "action map builder reports unknown action names" {
    var registry = ActionRegistry.init();
    const gameplay = try registry.addMap("gameplay");

    var builder = ActionMapBuilder.init(gameplay);

    try std.testing.expectError(
        Error.UnknownActionName,
        builder.bindDigitalKey(&registry, "missing", .space),
    );
}

test "action map builder reports wrong action kind as unknown name" {
    var registry = ActionRegistry.init();
    const gameplay = try registry.addMap("gameplay");

    _ = try registry.addAxis2(gameplay, "player.move");

    var builder = ActionMapBuilder.init(gameplay);

    try std.testing.expectError(
        Error.UnknownActionName,
        builder.bindDigitalKey(&registry, "player.move", .space),
    );
}
