//! Named input event reader tests.
//!
//! These tests cover the script-facing event bridge. Raw input events are still
//! handle-based, but this reader resolves them into stable map/action names.

const std = @import("std");
const yuki2d = @import("../yuki2d.zig");

const input = yuki2d.input;

test "named event reader describes digital action events" {
    var registry = input.ActionRegistry.init();
    const gameplay = try registry.addMap("gameplay");
    const jump = try registry.addDigital(gameplay, "player.jump");

    var events = input.InputEventQueue.init();
    events.pushActionPressed(gameplay, jump, input.InputSource.keyboard(.space));
    events.pushActionReleased(gameplay, jump, input.InputSource.keyboard(.space));

    const reader = input.NamedEventReader.init(&registry, gameplay, events.items());

    var iterator = reader.iter();

    const pressed = iterator.next() orelse return error.ExpectedNamedEvent;
    switch (pressed) {
        .action_pressed => |event| {
            try std.testing.expect(event.map.eql(gameplay));
            try std.testing.expectEqual(jump.index, event.action.index);
            try std.testing.expectEqualStrings("gameplay", event.map_name);
            try std.testing.expectEqualStrings("player.jump", event.action_name);
            try std.testing.expectEqual(input.InputSourceKind.keyboard, event.source.kind);
            try std.testing.expectEqual(input.Key.space, event.source.key.?);
        },
        else => return error.ExpectedActionPressed,
    }

    const released = iterator.next() orelse return error.ExpectedNamedEvent;
    switch (released) {
        .action_released => |event| {
            try std.testing.expect(event.map.eql(gameplay));
            try std.testing.expectEqual(jump.index, event.action.index);
            try std.testing.expectEqualStrings("gameplay", event.map_name);
            try std.testing.expectEqualStrings("player.jump", event.action_name);
        },
        else => return error.ExpectedActionReleased,
    }

    try std.testing.expect(iterator.next() == null);
}

test "named event reader describes axis events" {
    var registry = input.ActionRegistry.init();
    const gameplay = try registry.addMap("gameplay");
    const look = try registry.addAxis1(gameplay, "camera.look_x");
    const move = try registry.addAxis2(gameplay, "player.move");

    var events = input.InputEventQueue.init();
    events.pushAxis1Changed(
        gameplay,
        look,
        0.0,
        1.0,
        input.InputSource.keyboard(.d),
    );
    events.pushAxis2Changed(
        gameplay,
        move,
        input.Vector2.xy(0.0, 0.0),
        input.Vector2.xy(1.0, -1.0),
        input.InputSource.keyboard(.w),
    );

    const reader = input.NamedEventReader.init(&registry, gameplay, events.items());

    const look_event = reader.firstAxis1Changed("camera.look_x") orelse {
        return error.ExpectedAxis1Changed;
    };
    try std.testing.expectEqual(look.index, look_event.action.index);
    try std.testing.expectEqualStrings("gameplay", look_event.map_name);
    try std.testing.expectEqualStrings("camera.look_x", look_event.action_name);
    try std.testing.expectEqual(@as(f32, 0.0), look_event.previous);
    try std.testing.expectEqual(@as(f32, 1.0), look_event.value);

    const move_event = reader.firstAxis2Changed("player.move") orelse {
        return error.ExpectedAxis2Changed;
    };
    try std.testing.expectEqual(move.index, move_event.action.index);
    try std.testing.expectEqualStrings("gameplay", move_event.map_name);
    try std.testing.expectEqualStrings("player.move", move_event.action_name);
    try std.testing.expectEqual(@as(f32, 0.0), move_event.previous.x);
    try std.testing.expectEqual(@as(f32, 0.0), move_event.previous.y);
    try std.testing.expectEqual(@as(f32, 1.0), move_event.value.x);
    try std.testing.expectEqual(@as(f32, -1.0), move_event.value.y);
}

test "named event reader skips action events from other maps" {
    var registry = input.ActionRegistry.init();

    const gameplay = try registry.addMap("gameplay");
    const ui = try registry.addMap("ui");

    const jump = try registry.addDigital(gameplay, "player.jump");
    const confirm = try registry.addDigital(ui, "confirm");

    var events = input.InputEventQueue.init();
    events.pushActionPressed(ui, confirm, input.InputSource.keyboard(.space));
    events.pushActionPressed(gameplay, jump, input.InputSource.keyboard(.space));

    const reader = input.NamedEventReader.init(&registry, gameplay, events.items());

    var iterator = reader.iter();
    const first = iterator.next() orelse return error.ExpectedNamedEvent;

    switch (first) {
        .action_pressed => |event| {
            try std.testing.expect(event.map.eql(gameplay));
            try std.testing.expectEqualStrings("player.jump", event.action_name);
        },
        else => return error.ExpectedActionPressed,
    }

    try std.testing.expect(iterator.next() == null);
}

test "named event reader keeps pointer events visible" {
    var registry = input.ActionRegistry.init();
    const gameplay = try registry.addMap("gameplay");

    var events = input.InputEventQueue.init();
    events.pushMouseMoved(input.Vector2.xy(10.0, 20.0), input.Vector2.xy(1.0, -2.0));
    events.pushMouseButtonPressed(.left, input.Vector2.xy(10.0, 20.0));
    events.pushMouseScrolled(input.Vector2.xy(0.0, 1.0), input.Vector2.xy(10.0, 20.0));

    const reader = input.NamedEventReader.init(&registry, gameplay, events.items());

    var iterator = reader.iter();

    const moved = iterator.next() orelse return error.ExpectedNamedEvent;
    switch (moved) {
        .mouse_moved => |event| {
            try std.testing.expectEqual(@as(f32, 10.0), event.position.x);
            try std.testing.expectEqual(@as(f32, 20.0), event.position.y);
            try std.testing.expectEqual(@as(f32, 1.0), event.delta.x);
            try std.testing.expectEqual(@as(f32, -2.0), event.delta.y);
        },
        else => return error.ExpectedMouseMoved,
    }

    const pressed = iterator.next() orelse return error.ExpectedNamedEvent;
    switch (pressed) {
        .mouse_button_pressed => |event| {
            try std.testing.expectEqual(input.MouseButton.left, event.button);
            try std.testing.expectEqual(@as(f32, 10.0), event.position.x);
            try std.testing.expectEqual(@as(f32, 20.0), event.position.y);
        },
        else => return error.ExpectedMouseButtonPressed,
    }

    const scrolled = iterator.next() orelse return error.ExpectedNamedEvent;
    switch (scrolled) {
        .mouse_scrolled => |event| {
            try std.testing.expectEqual(@as(f32, 0.0), event.wheel.x);
            try std.testing.expectEqual(@as(f32, 1.0), event.wheel.y);
        },
        else => return error.ExpectedMouseScrolled,
    }

    try std.testing.expect(iterator.next() == null);
}

test "named frame exposes named event reader" {
    var registry = input.ActionRegistry.init();
    const gameplay = try registry.addMap("gameplay");
    const jump = try registry.addDigital(gameplay, "player.jump");

    var state = input.State.init();
    var events = input.InputEventQueue.init();

    state.setDigitalDown(jump, true);
    events.pushActionPressed(gameplay, jump, input.InputSource.keyboard(.space));

    const frame = input.NamedFrame.init(&registry, gameplay, &state, events.items());
    const reader = frame.namedReader();

    const event = reader.firstActionPressed("player.jump") orelse {
        return error.ExpectedActionPressed;
    };

    try std.testing.expect(event.map.eql(gameplay));
    try std.testing.expectEqualStrings("gameplay", event.map_name);
    try std.testing.expectEqualStrings("player.jump", event.action_name);
}
