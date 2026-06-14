//! Input session builder tests.
//!
//! These tests cover setup-time named map/action/binding construction that
//! builds an owned InputSession for runtime use.

const std = @import("std");
const yuki2d = @import("../yuki2d.zig");

const input = yuki2d.input;

const ActiveMapOptions = input.ActiveMapOptions;
const InputSessionBuilder = input.InputSessionBuilder;
const Vector2 = input.Vector2;

test "input session builder creates active digital gameplay session" {
    var builder = InputSessionBuilder.init();

    const gameplay = try builder.addMap("gameplay");
    const jump = try builder.addDigital("gameplay", "player.jump");

    try builder.bindDigitalKey("gameplay", "player.jump", .space);
    try builder.activateMap("gameplay");

    var session = try builder.build();

    try std.testing.expect(session.actionRegistry().hasMap(gameplay));
    try std.testing.expect(session.inputRouter().hasMap(gameplay));
    try std.testing.expect(session.activeContext().containsMap(gameplay));

    try session.applyKey(.space, true, false);

    try std.testing.expect(session.inputState().digitalDown(jump));

    const named = try session.namedFrameByName("gameplay");
    try std.testing.expect(try named.digitalPressed("player.jump"));
}

test "input session builder binds mouse digital actions" {
    var builder = InputSessionBuilder.init();

    _ = try builder.addMap("gameplay");
    _ = try builder.addDigital("gameplay", "pointer.select");

    try builder.bindMouseButton("gameplay", "pointer.select", .left);
    try builder.activateMap("gameplay");

    var session = try builder.build();

    try session.applyMouseButton(
        .left,
        true,
        Vector2.xy(32.0, 48.0),
    );

    const named = try session.namedFrameByName("gameplay");

    try std.testing.expect(try named.digitalDown("pointer.select"));
    try std.testing.expect(try named.hasActionPressed("pointer.select"));
    try std.testing.expectEqual(@as(f32, 32.0), session.inputState().mousePosition().x);
    try std.testing.expectEqual(@as(f32, 48.0), session.inputState().mousePosition().y);
}

test "input session builder binds axis actions" {
    var builder = InputSessionBuilder.init();

    _ = try builder.addMap("gameplay");
    const move_x = try builder.addAxis1("gameplay", "player.move_x");
    const move = try builder.addAxis2("gameplay", "player.move");

    try builder.bindAxis1Keys("gameplay", "player.move_x", .a, .d);
    try builder.bindAxis2Keys("gameplay", "player.move", .a, .d, .w, .s);
    try builder.activateMap("gameplay");

    var session = try builder.build();

    try session.applyKey(.d, true, false);
    try session.applyKey(.w, true, false);

    const move_value = session.inputState().axis2(move);
    const named = try session.namedFrameByName("gameplay");
    const named_move = try named.axis2("player.move");

    try std.testing.expectEqual(@as(f32, 1.0), session.inputState().axis1(move_x));
    try std.testing.expectEqual(@as(f32, 1.0), move_value.x);
    try std.testing.expectEqual(@as(f32, -1.0), move_value.y);
    try std.testing.expectEqual(@as(f32, 1.0), named_move.x);
    try std.testing.expectEqual(@as(f32, -1.0), named_move.y);
}

test "input session builder supports modal active maps" {
    var builder = InputSessionBuilder.init();

    const gameplay = try builder.addMap("gameplay");
    const pause = try builder.addMap("pause");

    const jump = try builder.addDigital("gameplay", "player.jump");
    const confirm = try builder.addDigital("pause", "ui.confirm");

    try builder.bindDigitalKey("gameplay", "player.jump", .space);
    try builder.bindDigitalKey("pause", "ui.confirm", .space);

    try builder.activateMap("gameplay");
    try builder.activateMapOptions("pause", ActiveMapOptions.modal(100));

    var session = try builder.build();

    try std.testing.expect(session.activeContext().canProcessMap(pause));
    try std.testing.expect(!session.activeContext().canProcessMap(gameplay));

    try session.applyKey(.space, true, false);

    try std.testing.expect(!session.inputState().digitalDown(jump));
    try std.testing.expect(session.inputState().digitalDown(confirm));

    const pause_frame = try session.namedFrameByName("pause");
    try std.testing.expect(try pause_frame.digitalPressed("ui.confirm"));
}

test "input session builder keeps setup counts" {
    var builder = InputSessionBuilder.init();

    _ = try builder.addMap("gameplay");
    _ = try builder.addMap("ui");

    _ = try builder.addDigital("gameplay", "player.jump");
    _ = try builder.addDigital("ui", "ui.confirm");

    try builder.activateMap("gameplay");

    try std.testing.expectEqual(@as(usize, 2), builder.mapCount());
    try std.testing.expectEqual(@as(usize, 1), builder.activeMapCount());
    try std.testing.expect(builder.registry().findMap("gameplay") != null);
    try std.testing.expect(builder.registry().findMap("ui") != null);
}

test "input session builder reports unknown map names" {
    var builder = InputSessionBuilder.init();

    try std.testing.expectError(
        input.Error.UnknownActionMap,
        builder.addDigital("missing", "player.jump"),
    );

    try std.testing.expectError(
        input.Error.UnknownActionMap,
        builder.bindDigitalKey("missing", "player.jump", .space),
    );

    try std.testing.expectError(
        input.Error.UnknownActionMap,
        builder.activateMap("missing"),
    );
}

test "input session builder reports unknown action names" {
    var builder = InputSessionBuilder.init();

    _ = try builder.addMap("gameplay");
    _ = try builder.addDigital("gameplay", "player.jump");
    _ = try builder.addAxis2("gameplay", "player.move");

    try std.testing.expectError(
        input.Error.UnknownActionName,
        builder.bindDigitalKey("gameplay", "player.missing", .space),
    );

    try std.testing.expectError(
        input.Error.UnknownActionName,
        builder.bindAxis1Keys("gameplay", "player.jump", .a, .d),
    );

    try std.testing.expectError(
        input.Error.UnknownActionName,
        builder.bindMouseButton("gameplay", "player.move", .left),
    );
}
