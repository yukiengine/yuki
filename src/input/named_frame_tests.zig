//! Named input frame tests.
//!
//! These tests cover name-based frame queries that future Luau bindings can
//! mirror while the runtime keeps handle-based state internally.

const std = @import("std");
const yuki2d = @import("../yuki2d.zig");

const input = yuki2d.input;
const input_frame = yuki2d.input_frame;

const ActionRegistry = input.ActionRegistry;
const InputEventQueue = input.InputEventQueue;
const NamedFrame = input.NamedFrame;
const State = input.State;
const Vector2 = input.Vector2;

test "named input frame resolves map names" {
    var registry = ActionRegistry.init();
    const gameplay = try registry.addMap("gameplay");

    var state = State.init();
    var events = InputEventQueue.init();

    const named = try NamedFrame.fromMapName(
        &registry,
        "gameplay",
        &state,
        events.items(),
    );

    try std.testing.expect(named.mapId().eql(gameplay));

    try std.testing.expectError(
        input.Error.UnknownActionMap,
        NamedFrame.fromMapName(&registry, "missing", &state, events.items()),
    );
}

test "named input frame reads digital action state" {
    var registry = ActionRegistry.init();
    const gameplay = try registry.addMap("gameplay");
    const jump = try registry.addDigital(gameplay, "player.jump");

    var state = State.init();
    var events = InputEventQueue.init();

    state.setDigitalDown(jump, true);

    const named = NamedFrame.init(&registry, gameplay, &state, events.items());

    try std.testing.expect(try named.digitalDown("player.jump"));
    try std.testing.expect(try named.digitalPressed("player.jump"));
    try std.testing.expect(!try named.digitalReleased("player.jump"));

    state.beginFrame();
    state.setDigitalDown(jump, false);

    const released = NamedFrame.init(&registry, gameplay, &state, events.items());

    try std.testing.expect(!try released.digitalDown("player.jump"));
    try std.testing.expect(!try released.digitalPressed("player.jump"));
    try std.testing.expect(try released.digitalReleased("player.jump"));
}

test "named input frame reads axis action state" {
    var registry = ActionRegistry.init();
    const gameplay = try registry.addMap("gameplay");
    const move_x = try registry.addAxis1(gameplay, "player.move_x");
    const move = try registry.addAxis2(gameplay, "player.move");

    var state = State.init();
    var events = InputEventQueue.init();

    state.setAxis1(move_x, -1.0);
    state.setAxis2(move, Vector2.xy(1.0, -1.0));

    const named = NamedFrame.init(&registry, gameplay, &state, events.items());
    const move_value = try named.axis2("player.move");

    try std.testing.expectEqual(@as(f32, -1.0), try named.axis1("player.move_x"));
    try std.testing.expect(try named.axis1Changed("player.move_x"));
    try std.testing.expectEqual(@as(f32, 1.0), move_value.x);
    try std.testing.expectEqual(@as(f32, -1.0), move_value.y);
    try std.testing.expect(try named.axis2Changed("player.move"));
}

test "named input frame finds action events in its own map" {
    var registry = ActionRegistry.init();

    const gameplay = try registry.addMap("gameplay");
    const ui = try registry.addMap("ui");

    const jump = try registry.addDigital(gameplay, "confirm");
    const ui_confirm = try registry.addDigital(ui, "confirm");

    var state = State.init();
    var events = InputEventQueue.init();

    events.pushActionPressed(ui, ui_confirm, input.InputSource.keyboard(.e));
    events.pushActionPressed(gameplay, jump, input.InputSource.keyboard(.space));
    events.pushActionReleased(gameplay, jump, input.InputSource.keyboard(.space));

    const gameplay_frame = NamedFrame.init(&registry, gameplay, &state, events.items());

    const pressed = try gameplay_frame.firstActionPressed("confirm") orelse return error.ExpectedPressed;
    try std.testing.expect(pressed.map.eql(gameplay));
    try std.testing.expectEqual(jump.index, pressed.action.index);

    const released = try gameplay_frame.firstActionReleased("confirm") orelse return error.ExpectedReleased;
    try std.testing.expect(released.map.eql(gameplay));
    try std.testing.expectEqual(jump.index, released.action.index);

    try std.testing.expect(try gameplay_frame.hasActionPressed("confirm"));
    try std.testing.expect(try gameplay_frame.hasActionReleased("confirm"));
}

test "named input frame finds axis events in its own map" {
    var registry = ActionRegistry.init();

    const gameplay = try registry.addMap("gameplay");
    const ui = try registry.addMap("ui");

    const move_x = try registry.addAxis1(gameplay, "move_x");
    const ui_scroll = try registry.addAxis1(ui, "move_x");
    const move = try registry.addAxis2(gameplay, "move");

    var state = State.init();
    var events = InputEventQueue.init();

    events.pushAxis1Changed(
        ui,
        ui_scroll,
        0.0,
        -1.0,
        input.InputSource.keyboard(.q),
    );

    events.pushAxis1Changed(
        gameplay,
        move_x,
        0.0,
        1.0,
        input.InputSource.keyboard(.d),
    );

    events.pushAxis2Changed(
        gameplay,
        move,
        Vector2.xy(0.0, 0.0),
        Vector2.xy(1.0, -1.0),
        input.InputSource.keyboard(.w),
    );

    const named = NamedFrame.init(&registry, gameplay, &state, events.items());

    const axis1_event = try named.firstAxis1Changed("move_x") orelse return error.ExpectedAxis1;
    try std.testing.expect(axis1_event.map.eql(gameplay));
    try std.testing.expectEqual(@as(f32, 1.0), axis1_event.value);

    const axis2_event = try named.firstAxis2Changed("move") orelse return error.ExpectedAxis2;
    try std.testing.expect(axis2_event.map.eql(gameplay));
    try std.testing.expectEqual(@as(f32, 1.0), axis2_event.value.x);
    try std.testing.expectEqual(@as(f32, -1.0), axis2_event.value.y);
}

test "named input frame reports unknown action names" {
    var registry = ActionRegistry.init();
    const gameplay = try registry.addMap("gameplay");
    _ = try registry.addDigital(gameplay, "player.jump");

    var state = State.init();
    var events = InputEventQueue.init();

    const named = NamedFrame.init(&registry, gameplay, &state, events.items());

    try std.testing.expectError(
        input.Error.UnknownActionName,
        named.digitalDown("player.missing"),
    );

    try std.testing.expectError(
        input.Error.UnknownActionName,
        named.axis1("player.jump"),
    );
}

test "input frame can create a named frame view" {
    var registry = ActionRegistry.init();
    const gameplay = try registry.addMap("gameplay");
    const jump = try registry.addDigital(gameplay, "player.jump");

    var state = State.init();
    var events = InputEventQueue.init();

    state.setDigitalDown(jump, true);

    const frame = input_frame.Frame.init(&state, events.items());
    const named = frame.named(&registry, gameplay);

    try std.testing.expect(try named.digitalDown("player.jump"));
}
