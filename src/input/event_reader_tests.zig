//! Input event reader tests.
//!
//! These tests cover read-only event queries without depending on input state.

const std = @import("std");
const yuki2d = @import("../yuki2d.zig");

const input = yuki2d.input;

const ActionMapId = input.ActionMapId;
const Axis1ActionId = input.Axis1ActionId;
const Axis2ActionId = input.Axis2ActionId;
const DigitalActionId = input.DigitalActionId;
const EventReader = input.EventReader;
const InputEventQueue = input.InputEventQueue;
const Vector2 = input.Vector2;

test "input event reader exposes event count and emptiness" {
    var events = InputEventQueue.init();
    var reader = EventReader.init(events.items());

    try std.testing.expect(reader.isEmpty());
    try std.testing.expect(!reader.hasEvents());
    try std.testing.expectEqual(@as(usize, 0), reader.count());

    events.pushMouseMoved(Vector2.xy(10.0, 20.0), Vector2.xy(10.0, 20.0));
    reader = EventReader.init(events.items());

    try std.testing.expect(!reader.isEmpty());
    try std.testing.expect(reader.hasEvents());
    try std.testing.expectEqual(@as(usize, 1), reader.count());
}

test "input event reader iterates events in order" {
    const gameplay = ActionMapId.fromIndex(0);
    const jump = DigitalActionId.fromIndex(0);

    var events = InputEventQueue.init();

    events.pushActionPressed(gameplay, jump, input.InputSource.keyboard(.space));
    events.pushMouseMoved(Vector2.xy(4.0, 8.0), Vector2.xy(4.0, 8.0));
    events.pushMouseScrolled(Vector2.xy(0.0, -1.0), Vector2.xy(4.0, 8.0));

    const reader = EventReader.init(events.items());
    var iter = reader.iter();

    const first = iter.next() orelse return error.ExpectedFirstEvent;
    try std.testing.expectEqual(input.InputEventKind.action_pressed, first.kind());
    try std.testing.expectEqual(@as(usize, 2), iter.remainingCount());

    const second = iter.next() orelse return error.ExpectedSecondEvent;
    try std.testing.expectEqual(input.InputEventKind.mouse_moved, second.kind());
    try std.testing.expectEqual(@as(usize, 1), iter.remainingCount());

    const third = iter.next() orelse return error.ExpectedThirdEvent;
    try std.testing.expectEqual(input.InputEventKind.mouse_scrolled, third.kind());
    try std.testing.expectEqual(@as(usize, 0), iter.remainingCount());

    try std.testing.expect(iter.next() == null);

    iter.reset();
    try std.testing.expectEqual(@as(usize, 3), iter.remainingCount());
}

test "input event reader finds digital action transitions" {
    const gameplay = ActionMapId.fromIndex(0);
    const ui = ActionMapId.fromIndex(1);
    const jump = DigitalActionId.fromIndex(0);
    const confirm = DigitalActionId.fromIndex(1);

    var events = InputEventQueue.init();

    events.pushActionPressed(gameplay, jump, input.InputSource.keyboard(.space));
    events.pushActionPressed(ui, confirm, input.InputSource.keyboard(.e));
    events.pushActionReleased(gameplay, jump, input.InputSource.keyboard(.space));

    const reader = EventReader.init(events.items());

    const jump_pressed = reader.firstActionPressed(jump) orelse return error.ExpectedJumpPressed;
    try std.testing.expect(jump_pressed.map.eql(gameplay));
    try std.testing.expectEqual(jump.index, jump_pressed.action.index);

    const confirm_pressed = reader.firstMapActionPressed(ui, confirm) orelse return error.ExpectedConfirmPressed;
    try std.testing.expect(confirm_pressed.map.eql(ui));
    try std.testing.expectEqual(confirm.index, confirm_pressed.action.index);

    const jump_released = reader.firstMapActionReleased(gameplay, jump) orelse return error.ExpectedJumpReleased;
    try std.testing.expect(jump_released.map.eql(gameplay));
    try std.testing.expectEqual(jump.index, jump_released.action.index);

    try std.testing.expect(reader.hasActionPressed(jump));
    try std.testing.expect(reader.hasActionReleased(jump));
    try std.testing.expect(reader.firstMapActionPressed(gameplay, confirm) == null);
}

test "input event reader finds axis changes" {
    const gameplay = ActionMapId.fromIndex(0);
    const ui = ActionMapId.fromIndex(1);
    const move_x = Axis1ActionId.fromIndex(0);
    const scroll = Axis1ActionId.fromIndex(1);
    const move = Axis2ActionId.fromIndex(0);

    var events = InputEventQueue.init();

    events.pushAxis1Changed(
        gameplay,
        move_x,
        0.0,
        1.0,
        input.InputSource.keyboard(.d),
    );

    events.pushAxis1Changed(
        ui,
        scroll,
        0.0,
        -1.0,
        input.InputSource.keyboard(.q),
    );

    events.pushAxis2Changed(
        gameplay,
        move,
        Vector2.xy(0.0, 0.0),
        Vector2.xy(1.0, -1.0),
        input.InputSource.keyboard(.w),
    );

    const reader = EventReader.init(events.items());

    const axis1_event = reader.firstAxis1Changed(move_x) orelse return error.ExpectedAxis1Event;
    try std.testing.expect(axis1_event.map.eql(gameplay));
    try std.testing.expectEqual(@as(f32, 0.0), axis1_event.previous);
    try std.testing.expectEqual(@as(f32, 1.0), axis1_event.value);

    const ui_axis1_event = reader.firstMapAxis1Changed(ui, scroll) orelse return error.ExpectedUiAxis1Event;
    try std.testing.expect(ui_axis1_event.map.eql(ui));
    try std.testing.expectEqual(@as(f32, -1.0), ui_axis1_event.value);

    const axis2_event = reader.firstMapAxis2Changed(gameplay, move) orelse return error.ExpectedAxis2Event;
    try std.testing.expect(axis2_event.map.eql(gameplay));
    try std.testing.expectEqual(@as(f32, 0.0), axis2_event.previous.x);
    try std.testing.expectEqual(@as(f32, 0.0), axis2_event.previous.y);
    try std.testing.expectEqual(@as(f32, 1.0), axis2_event.value.x);
    try std.testing.expectEqual(@as(f32, -1.0), axis2_event.value.y);
}

test "input event reader finds mouse events" {
    var events = InputEventQueue.init();

    events.pushMouseMoved(Vector2.xy(20.0, 30.0), Vector2.xy(5.0, -2.0));
    events.pushMouseButtonPressed(.left, Vector2.xy(20.0, 30.0));
    events.pushMouseScrolled(Vector2.xy(0.0, -1.0), Vector2.xy(20.0, 30.0));
    events.pushMouseButtonReleased(.left, Vector2.xy(20.0, 30.0));

    const reader = EventReader.init(events.items());

    const moved = reader.firstMouseMoved() orelse return error.ExpectedMouseMoved;
    try std.testing.expectEqual(@as(f32, 20.0), moved.position.x);
    try std.testing.expectEqual(@as(f32, 30.0), moved.position.y);
    try std.testing.expectEqual(@as(f32, 5.0), moved.delta.x);
    try std.testing.expectEqual(@as(f32, -2.0), moved.delta.y);

    const pressed = reader.firstMouseButtonPressed(.left) orelse return error.ExpectedMousePressed;
    try std.testing.expectEqual(input.MouseButton.left, pressed.button);

    const scrolled = reader.firstMouseScrolled() orelse return error.ExpectedMouseScrolled;
    try std.testing.expectEqual(@as(f32, 0.0), scrolled.wheel.x);
    try std.testing.expectEqual(@as(f32, -1.0), scrolled.wheel.y);

    const released = reader.firstMouseButtonReleased(.left) orelse return error.ExpectedMouseReleased;
    try std.testing.expectEqual(input.MouseButton.left, released.button);

    try std.testing.expect(reader.firstMouseButtonPressed(.right) == null);
}
