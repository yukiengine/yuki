//! Named input map view tests.
//!
//! These tests cover the map-scoped facade intended for future script/debug API
//! use. The view should combine state, events, bindings, and context without
//! becoming a second owner of input behavior.

const std = @import("std");
const yuki2d = @import("../yuki2d.zig");

const input = yuki2d.input;

test "named input map view exposes state events and bindings" {
    var builder = input.InputSessionBuilder.init();

    const gameplay = try builder.addMap("gameplay");

    _ = try builder.addDigital("gameplay", "player.jump");
    _ = try builder.addDigital("gameplay", "pointer.select");
    _ = try builder.addAxis2("gameplay", "player.move");

    try builder.bindDigitalKeyName("gameplay", "player.jump", "space");
    try builder.bindMouseButtonName("gameplay", "pointer.select", "left");
    try builder.bindAxis2KeyNames("gameplay", "player.move", "a", "d", "w", "s");
    try builder.bindAxis2KeyNames("gameplay", "player.move", "left", "right", "up", "down");

    try builder.activateMap("gameplay");

    var session = try builder.build();

    try session.applyKey(.space, true, false);
    try session.applyKey(.d, true, false);
    try session.applyMouseButton(.left, true, input.Vector2.xy(42.0, 24.0));

    const view = try session.namedMapViewByName("gameplay");

    try std.testing.expect(view.mapId().eql(gameplay));
    try std.testing.expectEqualStrings("gameplay", try view.mapName());
    try std.testing.expect(view.isActive());
    try std.testing.expect(view.canProcess());

    try std.testing.expect(try view.digitalDown("player.jump"));
    try std.testing.expect(try view.digitalPressed("player.jump"));
    try std.testing.expect(try view.digitalDown("pointer.select"));
    try std.testing.expect(try view.digitalPressed("pointer.select"));

    const move = try view.axis2("player.move");
    try std.testing.expectEqual(@as(f32, 1.0), move.x);
    try std.testing.expectEqual(@as(f32, 0.0), move.y);
    try std.testing.expect(try view.axis2Changed("player.move"));

    try std.testing.expectEqual(@as(usize, 4), view.bindingCount());
    try std.testing.expectEqual(@as(usize, 1), try view.bindingCountForAction("player.jump"));
    try std.testing.expectEqual(@as(usize, 1), try view.bindingCountForAction("pointer.select"));
    try std.testing.expectEqual(@as(usize, 2), try view.bindingCountForAction("player.move"));

    const jump_event = try view.firstActionPressed("player.jump") orelse {
        return error.ExpectedJumpPressed;
    };
    try std.testing.expectEqualStrings("gameplay", jump_event.map_name);
    try std.testing.expectEqualStrings("player.jump", jump_event.action_name);
    try std.testing.expectEqual(input.InputSourceKind.keyboard, jump_event.source.kind);
    try std.testing.expectEqual(input.Key.space, jump_event.source.key.?);

    const select_event = try view.firstActionPressed("pointer.select") orelse {
        return error.ExpectedSelectPressed;
    };
    try std.testing.expectEqualStrings("pointer.select", select_event.action_name);
    try std.testing.expectEqual(input.InputSourceKind.mouse, select_event.source.kind);
    try std.testing.expectEqual(input.MouseButton.left, select_event.source.mouse_button.?);

    const move_event = try view.firstAxis2Changed("player.move") orelse {
        return error.ExpectedMoveChanged;
    };
    try std.testing.expectEqualStrings("player.move", move_event.action_name);
    try std.testing.expectEqual(@as(f32, 0.0), move_event.previous.x);
    try std.testing.expectEqual(@as(f32, 0.0), move_event.previous.y);
    try std.testing.expectEqual(@as(f32, 1.0), move_event.value.x);
    try std.testing.expectEqual(@as(f32, 0.0), move_event.value.y);
}

test "named input map view reports active and blocked maps" {
    var builder = input.InputSessionBuilder.init();

    const gameplay = try builder.addMap("gameplay");
    const pause = try builder.addMap("pause");

    _ = try builder.addDigital("gameplay", "player.jump");
    _ = try builder.addDigital("pause", "ui.confirm");

    try builder.bindDigitalKeyName("gameplay", "player.jump", "space");
    try builder.bindDigitalKeyName("pause", "ui.confirm", "space");

    try builder.activateMap("gameplay");
    try builder.activateMapOptions("pause", input.ActiveMapOptions.modal(100));

    const session = try builder.build();

    const gameplay_view = try session.namedMapView(gameplay);
    const pause_view = try session.namedMapView(pause);

    try std.testing.expect(gameplay_view.isActive());
    try std.testing.expect(!gameplay_view.canProcess());

    try std.testing.expect(pause_view.isActive());
    try std.testing.expect(pause_view.canProcess());

    const pause_entry = pause_view.activeEntry() orelse return error.ExpectedActiveMap;
    try std.testing.expectEqualStrings("pause", pause_entry.map_name);
    try std.testing.expect(pause_entry.isBlocking());
    try std.testing.expect(pause_entry.canProcess());

    const gameplay_entry = gameplay_view.activeEntry() orelse return error.ExpectedActiveMap;
    try std.testing.expectEqualStrings("gameplay", gameplay_entry.map_name);
    try std.testing.expect(!gameplay_entry.canProcess());
}

test "named input map view validates unknown maps and actions" {
    var builder = input.InputSessionBuilder.init();

    _ = try builder.addMap("gameplay");
    _ = try builder.addDigital("gameplay", "player.jump");

    try builder.bindDigitalKeyName("gameplay", "player.jump", "space");
    try builder.activateMap("gameplay");

    var session = try builder.build();
    const view = try session.namedMapViewByName("gameplay");

    try std.testing.expectError(
        input.Error.UnknownActionMap,
        session.namedMapView(input.ActionMapId.fromIndex(15)),
    );

    try std.testing.expectError(
        input.Error.UnknownActionMap,
        session.namedMapViewByName("missing"),
    );

    try std.testing.expectError(
        input.Error.UnknownActionName,
        view.digitalPressed("player.missing"),
    );

    try std.testing.expectError(
        input.Error.UnknownActionName,
        view.bindingCountForAction("player.missing"),
    );
}

test "named input map view exposes pointer state and pointer events" {
    var builder = input.InputSessionBuilder.init();

    _ = try builder.addMap("gameplay");
    _ = try builder.addDigital("gameplay", "pointer.select");

    try builder.bindMouseButtonName("gameplay", "pointer.select", "left");
    try builder.activateMap("gameplay");

    var session = try builder.build();

    session.applyMouseMotion(input.Vector2.xy(10.0, 20.0));
    try session.applyMouseButton(.left, true, input.Vector2.xy(10.0, 20.0));
    session.applyMouseWheel(
        input.Vector2.xy(0.0, -1.0),
        input.Vector2.xy(10.0, 20.0),
    );

    const view = try session.namedMapViewByName("gameplay");

    try std.testing.expectEqual(@as(f32, 10.0), view.mousePosition().x);
    try std.testing.expectEqual(@as(f32, 20.0), view.mousePosition().y);
    try std.testing.expectEqual(@as(f32, 10.0), view.mouseDelta().x);
    try std.testing.expectEqual(@as(f32, 20.0), view.mouseDelta().y);
    try std.testing.expectEqual(@as(f32, 0.0), view.mouseWheel().x);
    try std.testing.expectEqual(@as(f32, -1.0), view.mouseWheel().y);

    try std.testing.expect(view.mouseInsideSurface());
    try std.testing.expect(view.mouseButtonDown(.left));
    try std.testing.expect(view.mouseButtonPressed(.left));
    try std.testing.expect(!view.mouseButtonReleased(.left));

    const moved = view.firstMouseMoved() orelse return error.ExpectedMouseMoved;
    try std.testing.expectEqual(@as(f32, 10.0), moved.position.x);
    try std.testing.expectEqual(@as(f32, 20.0), moved.position.y);
    try std.testing.expectEqual(@as(f32, 10.0), moved.delta.x);
    try std.testing.expectEqual(@as(f32, 20.0), moved.delta.y);

    const pressed = view.firstMouseButtonPressed(.left) orelse {
        return error.ExpectedMouseButtonPressed;
    };
    try std.testing.expectEqual(input.MouseButton.left, pressed.button);
    try std.testing.expectEqual(input.InputSourceKind.mouse, pressed.source.kind);
    try std.testing.expectEqual(input.MouseButton.left, pressed.source.mouse_button.?);

    const scrolled = view.firstMouseScrolled() orelse return error.ExpectedMouseScrolled;
    try std.testing.expectEqual(@as(f32, 0.0), scrolled.wheel.x);
    try std.testing.expectEqual(@as(f32, -1.0), scrolled.wheel.y);
}
