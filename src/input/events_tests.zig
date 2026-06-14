//! Input event tests.
//!
//! These tests cover the frame-local input event queue and router event output.

const std = @import("std");
const yuki2d = @import("../yuki2d.zig");

const input = yuki2d.input;

const ActionMap = input.ActionMap;
const ActionMapId = input.ActionMapId;
const Axis1ActionId = input.Axis1ActionId;
const Axis2ActionId = input.Axis2ActionId;
const DigitalActionId = input.DigitalActionId;
const InputEventKind = input.InputEventKind;
const InputEventQueue = input.InputEventQueue;
const InputRouter = input.InputRouter;
const InputSourceKind = input.InputSourceKind;
const State = input.State;
const Vector2 = input.Vector2;

test "input event queue stores and clears events" {
    const gameplay = ActionMapId.fromIndex(0);
    const jump = DigitalActionId.fromIndex(0);

    var events = InputEventQueue.init();
    events.pushActionPressed(gameplay, jump, input.InputSource.keyboard(.space));

    try std.testing.expectEqual(@as(usize, 1), events.count());
    try std.testing.expect(!events.isEmpty());

    const item = events.items()[0];
    try std.testing.expectEqual(InputEventKind.action_pressed, item.kind());

    events.beginFrame();

    try std.testing.expectEqual(@as(usize, 0), events.count());
    try std.testing.expect(events.isEmpty());
}

test "input event queue tracks dropped events" {
    var events = InputEventQueue.init();

    var index: usize = 0;
    while (index < input.max_input_events + 1) : (index += 1) {
        events.pushMouseMoved(
            Vector2.xy(@floatFromInt(index), 0.0),
            Vector2.xy(1.0, 0.0),
        );
    }

    try std.testing.expectEqual(input.max_input_events, events.count());
    try std.testing.expectEqual(@as(usize, 1), events.droppedCount());
}

test "input router emits digital action press and release events" {
    const gameplay = ActionMapId.fromIndex(0);
    const jump = DigitalActionId.fromIndex(0);

    var map = ActionMap.init();
    try map.bindDigitalKey(.space, jump);

    var router = InputRouter.init();
    try router.putMap(gameplay, map);
    try router.pushMap(gameplay);

    var state = State.init();
    var events = InputEventQueue.init();

    try router.applyKeyWithEvents(&state, &events, .space, true, false);

    try std.testing.expect(state.digitalDown(jump));
    try std.testing.expectEqual(@as(usize, 1), events.count());

    switch (events.items()[0]) {
        .action_pressed => |event| {
            try std.testing.expect(event.map.eql(gameplay));
            try std.testing.expectEqual(jump.index, event.action.index);
            try std.testing.expectEqual(InputSourceKind.keyboard, event.source.kind);
            try std.testing.expectEqual(input.Key.space, event.source.key.?);
        },
        else => return error.ExpectedActionPressed,
    }

    state.beginFrame();
    events.beginFrame();

    try router.applyKeyWithEvents(&state, &events, .space, false, false);

    try std.testing.expect(!state.digitalDown(jump));
    try std.testing.expectEqual(@as(usize, 1), events.count());

    switch (events.items()[0]) {
        .action_released => |event| {
            try std.testing.expect(event.map.eql(gameplay));
            try std.testing.expectEqual(jump.index, event.action.index);
            try std.testing.expectEqual(InputSourceKind.keyboard, event.source.kind);
            try std.testing.expectEqual(input.Key.space, event.source.key.?);
        },
        else => return error.ExpectedActionReleased,
    }
}

test "input router emits axis1 changed events" {
    const gameplay = ActionMapId.fromIndex(0);
    const move_x = Axis1ActionId.fromIndex(0);

    var map = ActionMap.init();
    try map.bindAxis1Keys(.a, .d, move_x);

    var router = InputRouter.init();
    try router.putMap(gameplay, map);
    try router.pushMap(gameplay);

    var state = State.init();
    var events = InputEventQueue.init();

    try router.applyKeyWithEvents(&state, &events, .d, true, false);

    try std.testing.expectEqual(@as(f32, 1.0), state.axis1(move_x));
    try std.testing.expectEqual(@as(usize, 1), events.count());

    switch (events.items()[0]) {
        .axis1_changed => |event| {
            try std.testing.expect(event.map.eql(gameplay));
            try std.testing.expectEqual(move_x.index, event.action.index);
            try std.testing.expectEqual(@as(f32, 0.0), event.previous);
            try std.testing.expectEqual(@as(f32, 1.0), event.value);
        },
        else => return error.ExpectedAxis1Changed,
    }
}

test "input router emits axis2 changed events" {
    const gameplay = ActionMapId.fromIndex(0);
    const move = Axis2ActionId.fromIndex(0);

    var map = ActionMap.init();
    try map.bindAxis2Keys(.a, .d, .w, .s, move);

    var router = InputRouter.init();
    try router.putMap(gameplay, map);
    try router.pushMap(gameplay);

    var state = State.init();
    var events = InputEventQueue.init();

    try router.applyKeyWithEvents(&state, &events, .w, true, false);

    const value = state.axis2(move);
    try std.testing.expectEqual(@as(f32, 0.0), value.x);
    try std.testing.expectEqual(@as(f32, -1.0), value.y);
    try std.testing.expectEqual(@as(usize, 1), events.count());

    switch (events.items()[0]) {
        .axis2_changed => |event| {
            try std.testing.expect(event.map.eql(gameplay));
            try std.testing.expectEqual(move.index, event.action.index);
            try std.testing.expectEqual(@as(f32, 0.0), event.previous.x);
            try std.testing.expectEqual(@as(f32, 0.0), event.previous.y);
            try std.testing.expectEqual(@as(f32, 0.0), event.value.x);
            try std.testing.expectEqual(@as(f32, -1.0), event.value.y);
        },
        else => return error.ExpectedAxis2Changed,
    }
}

test "input router does not emit events for repeated key input" {
    const gameplay = ActionMapId.fromIndex(0);
    const jump = DigitalActionId.fromIndex(0);

    var map = ActionMap.init();
    try map.bindDigitalKey(.space, jump);

    var router = InputRouter.init();
    try router.putMap(gameplay, map);
    try router.pushMap(gameplay);

    var state = State.init();
    var events = InputEventQueue.init();

    try router.applyKeyWithEvents(&state, &events, .space, true, false);

    state.beginFrame();
    events.beginFrame();

    try router.applyKeyWithEvents(&state, &events, .space, true, true);

    try std.testing.expect(state.digitalDown(jump));
    try std.testing.expectEqual(@as(usize, 0), events.count());
}

test "input router respects blocking maps when emitting events" {
    const gameplay = ActionMapId.fromIndex(0);
    const pause_menu = ActionMapId.fromIndex(1);
    const jump = DigitalActionId.fromIndex(0);
    const confirm = DigitalActionId.fromIndex(1);

    var gameplay_map = ActionMap.init();
    try gameplay_map.bindDigitalKey(.space, jump);

    var pause_map = ActionMap.init();
    try pause_map.bindDigitalKey(.space, confirm);

    var router = InputRouter.init();
    try router.putMap(gameplay, gameplay_map);
    try router.putMap(pause_menu, pause_map);
    try router.pushMapOptions(gameplay, .{ .priority = 0 });
    try router.pushMapOptions(pause_menu, input.ActiveMapOptions.modal(100));

    var state = State.init();
    var events = InputEventQueue.init();

    try router.applyKeyWithEvents(&state, &events, .space, true, false);

    try std.testing.expect(!state.digitalDown(jump));
    try std.testing.expect(state.digitalDown(confirm));
    try std.testing.expectEqual(@as(usize, 1), events.count());

    switch (events.items()[0]) {
        .action_pressed => |event| {
            try std.testing.expect(event.map.eql(pause_menu));
            try std.testing.expectEqual(confirm.index, event.action.index);
        },
        else => return error.ExpectedActionPressed,
    }
}

test "input state emits mouse motion events" {
    var state = State.init();
    var events = InputEventQueue.init();

    state.setMousePositionWithEvents(
        &events,
        Vector2.xy(32.0, 48.0),
    );

    try std.testing.expectEqual(@as(f32, 32.0), state.mousePosition().x);
    try std.testing.expectEqual(@as(f32, 48.0), state.mousePosition().y);
    try std.testing.expectEqual(@as(f32, 32.0), state.mouseDelta().x);
    try std.testing.expectEqual(@as(f32, 48.0), state.mouseDelta().y);
    try std.testing.expect(state.isMouseInsideWindow());
    try std.testing.expectEqual(@as(usize, 1), events.count());

    switch (events.items()[0]) {
        .mouse_moved => |event| {
            try std.testing.expectEqual(@as(f32, 32.0), event.position.x);
            try std.testing.expectEqual(@as(f32, 48.0), event.position.y);
            try std.testing.expectEqual(@as(f32, 32.0), event.delta.x);
            try std.testing.expectEqual(@as(f32, 48.0), event.delta.y);
        },
        else => return error.ExpectedMouseMoved,
    }

    state.beginFrame();
    events.beginFrame();

    state.setMousePositionWithEvents(
        &events,
        Vector2.xy(40.0, 44.0),
    );

    try std.testing.expectEqual(@as(f32, 8.0), state.mouseDelta().x);
    try std.testing.expectEqual(@as(f32, -4.0), state.mouseDelta().y);
    try std.testing.expectEqual(@as(usize, 1), events.count());

    switch (events.items()[0]) {
        .mouse_moved => |event| {
            try std.testing.expectEqual(@as(f32, 40.0), event.position.x);
            try std.testing.expectEqual(@as(f32, 44.0), event.position.y);
            try std.testing.expectEqual(@as(f32, 8.0), event.delta.x);
            try std.testing.expectEqual(@as(f32, -4.0), event.delta.y);
        },
        else => return error.ExpectedMouseMoved,
    }
}

test "input state does not emit mouse motion when position is unchanged" {
    var state = State.init();
    var events = InputEventQueue.init();

    state.setMousePositionWithEvents(
        &events,
        Vector2.xy(0.0, 0.0),
    );

    try std.testing.expectEqual(@as(usize, 0), events.count());
    try std.testing.expect(state.isMouseInsideWindow());
}

test "input state emits mouse button press and release events" {
    var state = State.init();
    var events = InputEventQueue.init();

    state.setMouseButtonWithEvents(
        &events,
        .left,
        true,
        Vector2.xy(12.0, 24.0),
    );

    try std.testing.expect(state.isMouseButtonDown(.left));
    try std.testing.expect(state.wasMouseButtonPressed(.left));
    try std.testing.expectEqual(@as(usize, 2), events.count());

    switch (events.items()[0]) {
        .mouse_moved => |event| {
            try std.testing.expectEqual(@as(f32, 12.0), event.position.x);
            try std.testing.expectEqual(@as(f32, 24.0), event.position.y);
        },
        else => return error.ExpectedMouseMoved,
    }

    switch (events.items()[1]) {
        .mouse_button_pressed => |event| {
            try std.testing.expectEqual(input.MouseButton.left, event.button);
            try std.testing.expectEqual(@as(f32, 12.0), event.position.x);
            try std.testing.expectEqual(@as(f32, 24.0), event.position.y);
            try std.testing.expectEqual(InputSourceKind.mouse, event.source.kind);
            try std.testing.expectEqual(input.MouseButton.left, event.source.mouse_button.?);
        },
        else => return error.ExpectedMouseButtonPressed,
    }

    state.beginFrame();
    events.beginFrame();

    state.setMouseButtonWithEvents(
        &events,
        .left,
        false,
        Vector2.xy(12.0, 24.0),
    );

    try std.testing.expect(!state.isMouseButtonDown(.left));
    try std.testing.expect(state.wasMouseButtonReleased(.left));
    try std.testing.expectEqual(@as(usize, 1), events.count());

    switch (events.items()[0]) {
        .mouse_button_released => |event| {
            try std.testing.expectEqual(input.MouseButton.left, event.button);
            try std.testing.expectEqual(@as(f32, 12.0), event.position.x);
            try std.testing.expectEqual(@as(f32, 24.0), event.position.y);
            try std.testing.expectEqual(InputSourceKind.mouse, event.source.kind);
            try std.testing.expectEqual(input.MouseButton.left, event.source.mouse_button.?);
        },
        else => return error.ExpectedMouseButtonReleased,
    }
}

test "input state ignores duplicate mouse button edges" {
    var state = State.init();
    var events = InputEventQueue.init();

    state.setMouseButtonWithEvents(
        &events,
        .right,
        true,
        Vector2.xy(5.0, 6.0),
    );

    state.beginFrame();
    events.beginFrame();

    state.setMouseButtonWithEvents(
        &events,
        .right,
        true,
        Vector2.xy(5.0, 6.0),
    );

    try std.testing.expect(state.isMouseButtonDown(.right));
    try std.testing.expect(!state.wasMouseButtonPressed(.right));
    try std.testing.expectEqual(@as(usize, 0), events.count());
}

test "input state emits mouse wheel events" {
    var state = State.init();
    var events = InputEventQueue.init();

    state.setMousePosition(Vector2.xy(10.0, 10.0));
    state.beginFrame();

    state.addMouseWheelWithEvents(
        &events,
        Vector2.xy(0.0, 1.0),
        Vector2.xy(10.0, 10.0),
    );

    try std.testing.expectEqual(@as(f32, 0.0), state.mouseWheel().x);
    try std.testing.expectEqual(@as(f32, 1.0), state.mouseWheel().y);
    try std.testing.expectEqual(@as(usize, 1), events.count());

    switch (events.items()[0]) {
        .mouse_scrolled => |event| {
            try std.testing.expectEqual(@as(f32, 0.0), event.wheel.x);
            try std.testing.expectEqual(@as(f32, 1.0), event.wheel.y);
            try std.testing.expectEqual(@as(f32, 10.0), event.position.x);
            try std.testing.expectEqual(@as(f32, 10.0), event.position.y);
        },
        else => return error.ExpectedMouseScrolled,
    }
}

test "input state emits mouse motion before wheel when wheel event has new position" {
    var state = State.init();
    var events = InputEventQueue.init();

    state.setMousePosition(Vector2.xy(10.0, 10.0));
    state.beginFrame();

    state.addMouseWheelWithEvents(
        &events,
        Vector2.xy(-1.0, 2.0),
        Vector2.xy(14.0, 13.0),
    );

    try std.testing.expectEqual(@as(f32, 4.0), state.mouseDelta().x);
    try std.testing.expectEqual(@as(f32, 3.0), state.mouseDelta().y);
    try std.testing.expectEqual(@as(f32, -1.0), state.mouseWheel().x);
    try std.testing.expectEqual(@as(f32, 2.0), state.mouseWheel().y);
    try std.testing.expectEqual(@as(usize, 2), events.count());

    switch (events.items()[0]) {
        .mouse_moved => |event| {
            try std.testing.expectEqual(@as(f32, 14.0), event.position.x);
            try std.testing.expectEqual(@as(f32, 13.0), event.position.y);
            try std.testing.expectEqual(@as(f32, 4.0), event.delta.x);
            try std.testing.expectEqual(@as(f32, 3.0), event.delta.y);
        },
        else => return error.ExpectedMouseMoved,
    }

    switch (events.items()[1]) {
        .mouse_scrolled => |event| {
            try std.testing.expectEqual(@as(f32, -1.0), event.wheel.x);
            try std.testing.expectEqual(@as(f32, 2.0), event.wheel.y);
            try std.testing.expectEqual(@as(f32, 14.0), event.position.x);
            try std.testing.expectEqual(@as(f32, 13.0), event.position.y);
        },
        else => return error.ExpectedMouseScrolled,
    }
}

test "input router emits mouse button action events" {
    const gameplay = ActionMapId.fromIndex(0);
    const activate = DigitalActionId.fromIndex(0);

    var map = ActionMap.init();
    try map.bindMouseButton(.left, activate);

    var router = InputRouter.init();
    try router.putMap(gameplay, map);
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

    try std.testing.expect(state.isMouseButtonDown(.left));
    try std.testing.expect(state.digitalDown(activate));
    try std.testing.expectEqual(@as(usize, 2), events.count());

    switch (events.items()[0]) {
        .mouse_button_pressed => |event| {
            try std.testing.expectEqual(input.MouseButton.left, event.button);
            try std.testing.expectEqual(InputSourceKind.mouse, event.source.kind);
            try std.testing.expectEqual(input.MouseButton.left, event.source.mouse_button.?);
        },
        else => return error.ExpectedMouseButtonPressed,
    }

    switch (events.items()[1]) {
        .action_pressed => |event| {
            try std.testing.expect(event.map.eql(gameplay));
            try std.testing.expectEqual(activate.index, event.action.index);
            try std.testing.expectEqual(InputSourceKind.mouse, event.source.kind);
            try std.testing.expectEqual(input.MouseButton.left, event.source.mouse_button.?);
        },
        else => return error.ExpectedActionPressed,
    }

    state.beginFrame();
    events.beginFrame();

    try router.applyMouseButtonWithEvents(
        &state,
        &events,
        .left,
        false,
        Vector2.xy(0.0, 0.0),
    );

    try std.testing.expect(!state.isMouseButtonDown(.left));
    try std.testing.expect(!state.digitalDown(activate));
    try std.testing.expectEqual(@as(usize, 2), events.count());

    switch (events.items()[0]) {
        .mouse_button_released => |event| {
            try std.testing.expectEqual(input.MouseButton.left, event.button);
        },
        else => return error.ExpectedMouseButtonReleased,
    }

    switch (events.items()[1]) {
        .action_released => |event| {
            try std.testing.expect(event.map.eql(gameplay));
            try std.testing.expectEqual(activate.index, event.action.index);
            try std.testing.expectEqual(InputSourceKind.mouse, event.source.kind);
        },
        else => return error.ExpectedActionReleased,
    }
}
