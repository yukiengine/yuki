//! Input frame facade tests.
//!
//! These tests cover the read-only frame API that game-facing code should use
//! instead of reading raw input state and event queues directly.

const std = @import("std");
const yuki2d = @import("yuki2d.zig");

const input = yuki2d.input;
const input_frame = yuki2d.input_frame;

const ActionMapId = input.ActionMapId;
const Axis1ActionId = input.Axis1ActionId;
const Axis2ActionId = input.Axis2ActionId;
const DigitalActionId = input.DigitalActionId;
const Frame = input_frame.Frame;
const InputEventQueue = input.InputEventQueue;
const State = input.State;
const Vector2 = input.Vector2;

test "input frame exposes polling state" {
    const jump = DigitalActionId.fromIndex(0);
    const move_x = Axis1ActionId.fromIndex(0);
    const move = Axis2ActionId.fromIndex(0);

    var state = State.init();
    var events = InputEventQueue.init();

    state.setDigitalDown(jump, true);
    state.setAxis1(move_x, -1.0);
    state.setAxis2(move, Vector2.xy(1.0, -1.0));
    state.setMousePosition(Vector2.xy(32.0, 48.0));
    state.setMouseButton(.left, true, Vector2.xy(32.0, 48.0));

    const frame = Frame.init(&state, events.items());

    try std.testing.expect(frame.digitalDown(jump));
    try std.testing.expect(frame.digitalPressed(jump));
    try std.testing.expectEqual(@as(f32, -1.0), frame.axis1(move_x));
    try std.testing.expectEqual(@as(f32, 1.0), frame.axis2(move).x);
    try std.testing.expectEqual(@as(f32, -1.0), frame.axis2(move).y);
    try std.testing.expectEqual(@as(f32, 32.0), frame.mousePosition().x);
    try std.testing.expectEqual(@as(f32, 48.0), frame.mousePosition().y);
    try std.testing.expect(frame.mouseButtonDown(.left));
}

test "input frame exposes digital axis helpers" {
    const left = DigitalActionId.fromIndex(0);
    const right = DigitalActionId.fromIndex(1);
    const up = DigitalActionId.fromIndex(2);
    const down = DigitalActionId.fromIndex(3);

    var state = State.init();
    var events = InputEventQueue.init();

    state.setDigitalDown(right, true);
    state.setDigitalDown(up, true);

    const frame = Frame.init(&state, events.items());
    const move = frame.digitalAxis2(left, right, up, down);

    try std.testing.expectEqual(@as(f32, 1.0), frame.digitalAxis1(left, right));
    try std.testing.expectEqual(@as(f32, 1.0), move.x);
    try std.testing.expectEqual(@as(f32, -1.0), move.y);
}

test "input frame iterates events in order" {
    const gameplay = ActionMapId.fromIndex(0);
    const jump = DigitalActionId.fromIndex(0);

    var state = State.init();
    var events = InputEventQueue.init();

    events.pushActionPressed(gameplay, jump, input.InputSource.keyboard(.space));
    events.pushMouseMoved(Vector2.xy(10.0, 20.0), Vector2.xy(10.0, 20.0));
    events.pushMouseScrolled(Vector2.xy(0.0, 1.0), Vector2.xy(10.0, 20.0));

    const frame = Frame.init(&state, events.items());

    try std.testing.expectEqual(@as(usize, 3), frame.eventCount());
    try std.testing.expect(!frame.hasNoEvents());

    var iter = frame.iter();

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

test "input frame finds action events" {
    const gameplay = ActionMapId.fromIndex(0);
    const ui = ActionMapId.fromIndex(1);
    const jump = DigitalActionId.fromIndex(0);
    const confirm = DigitalActionId.fromIndex(1);

    var state = State.init();
    var events = InputEventQueue.init();

    events.pushActionPressed(gameplay, jump, input.InputSource.keyboard(.space));
    events.pushActionPressed(ui, confirm, input.InputSource.keyboard(.e));
    events.pushActionReleased(gameplay, jump, input.InputSource.keyboard(.space));

    const frame = Frame.init(&state, events.items());

    const jump_pressed = frame.firstActionPressed(jump) orelse return error.ExpectedJumpPressed;
    try std.testing.expect(jump_pressed.map.eql(gameplay));
    try std.testing.expectEqual(jump.index, jump_pressed.action.index);

    const confirm_pressed = frame.firstMapActionPressed(ui, confirm) orelse return error.ExpectedConfirmPressed;
    try std.testing.expect(confirm_pressed.map.eql(ui));
    try std.testing.expectEqual(confirm.index, confirm_pressed.action.index);

    const jump_released = frame.firstMapActionReleased(gameplay, jump) orelse return error.ExpectedJumpReleased;
    try std.testing.expect(jump_released.map.eql(gameplay));
    try std.testing.expectEqual(jump.index, jump_released.action.index);

    try std.testing.expect(frame.firstMapActionPressed(gameplay, confirm) == null);
}

test "input frame finds axis change events" {
    const gameplay = ActionMapId.fromIndex(0);
    const move_x = Axis1ActionId.fromIndex(0);
    const move = Axis2ActionId.fromIndex(0);

    var state = State.init();
    var events = InputEventQueue.init();

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

    const frame = Frame.init(&state, events.items());

    const axis1_event = frame.firstAxis1Changed(move_x) orelse return error.ExpectedAxis1Event;
    try std.testing.expect(axis1_event.map.eql(gameplay));
    try std.testing.expectEqual(@as(f32, 0.0), axis1_event.previous);
    try std.testing.expectEqual(@as(f32, 1.0), axis1_event.value);

    const axis2_event = frame.firstAxis2Changed(move) orelse return error.ExpectedAxis2Event;
    try std.testing.expect(axis2_event.map.eql(gameplay));
    try std.testing.expectEqual(@as(f32, 0.0), axis2_event.previous.x);
    try std.testing.expectEqual(@as(f32, 0.0), axis2_event.previous.y);
    try std.testing.expectEqual(@as(f32, 1.0), axis2_event.value.x);
    try std.testing.expectEqual(@as(f32, -1.0), axis2_event.value.y);
}

test "input frame finds mouse events" {
    var state = State.init();
    var events = InputEventQueue.init();

    events.pushMouseMoved(Vector2.xy(20.0, 30.0), Vector2.xy(5.0, -2.0));
    events.pushMouseButtonPressed(.left, Vector2.xy(20.0, 30.0));
    events.pushMouseScrolled(Vector2.xy(0.0, -1.0), Vector2.xy(20.0, 30.0));
    events.pushMouseButtonReleased(.left, Vector2.xy(20.0, 30.0));

    const frame = Frame.init(&state, events.items());

    const moved = frame.firstMouseMoved() orelse return error.ExpectedMouseMoved;
    try std.testing.expectEqual(@as(f32, 20.0), moved.position.x);
    try std.testing.expectEqual(@as(f32, 30.0), moved.position.y);
    try std.testing.expectEqual(@as(f32, 5.0), moved.delta.x);
    try std.testing.expectEqual(@as(f32, -2.0), moved.delta.y);

    const pressed = frame.firstMouseButtonPressed(.left) orelse return error.ExpectedMousePressed;
    try std.testing.expectEqual(input.MouseButton.left, pressed.button);

    const scrolled = frame.firstMouseScrolled() orelse return error.ExpectedMouseScrolled;
    try std.testing.expectEqual(@as(f32, 0.0), scrolled.wheel.x);
    try std.testing.expectEqual(@as(f32, -1.0), scrolled.wheel.y);

    const released = frame.firstMouseButtonReleased(.left) orelse return error.ExpectedMouseReleased;
    try std.testing.expectEqual(input.MouseButton.left, released.button);

    try std.testing.expect(frame.firstMouseButtonPressed(.right) == null);
}
