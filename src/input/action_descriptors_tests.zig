//! Named input action descriptor tests.
//!
//! These tests cover map-scoped action introspection for tools, debug UI, and
//! future Luau type generation.

const std = @import("std");
const yuki2d = @import("../yuki2d.zig");

const input = yuki2d.input;

test "named action reader counts actions by map and kind" {
    var registry = input.ActionRegistry.init();

    const gameplay = try registry.addMap("gameplay");
    const ui = try registry.addMap("ui");

    _ = try registry.addDigital(gameplay, "player.jump");
    _ = try registry.addDigital(gameplay, "player.dash");
    _ = try registry.addAxis1(gameplay, "player.look_x");
    _ = try registry.addAxis2(gameplay, "player.move");

    _ = try registry.addDigital(ui, "ui.confirm");
    _ = try registry.addAxis2(ui, "ui.navigate");

    const gameplay_reader = input.NamedActionReader.init(&registry, gameplay);
    const ui_reader = input.NamedActionReader.init(&registry, ui);

    try std.testing.expectEqualStrings("gameplay", try gameplay_reader.mapName());
    try std.testing.expectEqual(@as(usize, 4), gameplay_reader.count());
    try std.testing.expectEqual(@as(usize, 2), gameplay_reader.digitalCount());
    try std.testing.expectEqual(@as(usize, 1), gameplay_reader.axis1Count());
    try std.testing.expectEqual(@as(usize, 1), gameplay_reader.axis2Count());

    try std.testing.expectEqualStrings("ui", try ui_reader.mapName());
    try std.testing.expectEqual(@as(usize, 2), ui_reader.count());
    try std.testing.expectEqual(@as(usize, 1), ui_reader.digitalCount());
    try std.testing.expectEqual(@as(usize, 0), ui_reader.axis1Count());
    try std.testing.expectEqual(@as(usize, 1), ui_reader.axis2Count());
}

test "named action reader finds descriptors by name" {
    var registry = input.ActionRegistry.init();

    const gameplay = try registry.addMap("gameplay");

    const jump = try registry.addDigital(gameplay, "player.jump");
    const look_x = try registry.addAxis1(gameplay, "player.look_x");
    const move = try registry.addAxis2(gameplay, "player.move");

    const reader = input.NamedActionReader.init(&registry, gameplay);

    const jump_action = reader.find("player.jump") orelse return error.ExpectedAction;
    const look_action = reader.find("player.look_x") orelse return error.ExpectedAction;
    const move_action = reader.find("player.move") orelse return error.ExpectedAction;

    try std.testing.expectEqual(input.ActionKind.digital, jump_action.kind());
    try std.testing.expectEqual(input.ActionKind.axis1, look_action.kind());
    try std.testing.expectEqual(input.ActionKind.axis2, move_action.kind());

    try std.testing.expectEqualStrings("player.jump", jump_action.name());
    try std.testing.expectEqualStrings("player.look_x", look_action.name());
    try std.testing.expectEqualStrings("player.move", move_action.name());

    switch (jump_action.actionRef()) {
        .digital => |item| try std.testing.expectEqual(jump.index, item.index),
        else => return error.ExpectedDigitalAction,
    }

    switch (look_action.actionRef()) {
        .axis1 => |item| try std.testing.expectEqual(look_x.index, item.index),
        else => return error.ExpectedAxis1Action,
    }

    switch (move_action.actionRef()) {
        .axis2 => |item| try std.testing.expectEqual(move.index, item.index),
        else => return error.ExpectedAxis2Action,
    }
}

test "named action reader iterates actions grouped by kind" {
    var registry = input.ActionRegistry.init();

    const gameplay = try registry.addMap("gameplay");
    const ui = try registry.addMap("ui");

    _ = try registry.addDigital(gameplay, "player.jump");
    _ = try registry.addAxis1(gameplay, "player.look_x");
    _ = try registry.addAxis2(gameplay, "player.move");

    _ = try registry.addDigital(ui, "ui.confirm");

    const reader = input.NamedActionReader.init(&registry, gameplay);
    var iterator = reader.iter();

    const first = iterator.next() orelse return error.ExpectedAction;
    try std.testing.expectEqual(input.ActionKind.digital, first.kind());
    try std.testing.expectEqualStrings("player.jump", first.name());

    const second = iterator.next() orelse return error.ExpectedAction;
    try std.testing.expectEqual(input.ActionKind.axis1, second.kind());
    try std.testing.expectEqualStrings("player.look_x", second.name());

    const third = iterator.next() orelse return error.ExpectedAction;
    try std.testing.expectEqual(input.ActionKind.axis2, third.kind());
    try std.testing.expectEqualStrings("player.move", third.name());

    try std.testing.expect(iterator.next() == null);

    iterator.reset();

    const after_reset = iterator.next() orelse return error.ExpectedAction;
    try std.testing.expectEqualStrings("player.jump", after_reset.name());
}

test "named action reader reports missing actions" {
    var registry = input.ActionRegistry.init();

    const gameplay = try registry.addMap("gameplay");
    _ = try registry.addDigital(gameplay, "player.jump");

    const reader = input.NamedActionReader.init(&registry, gameplay);

    try std.testing.expect(reader.contains("player.jump"));
    try std.testing.expect(!reader.contains("player.missing"));

    try std.testing.expectError(
        input.Error.UnknownActionName,
        reader.kindOf("player.missing"),
    );

    try std.testing.expectError(
        input.Error.UnknownActionName,
        reader.actionRef("player.missing"),
    );
}
