//! Input action registry tests.
//!
//! These tests cover named action maps and typed action name lookup before the
//! runtime starts binding those names to physical input.

const std = @import("std");
const yuki2d = @import("yuki2d.zig");

const input = yuki2d.input;

const ActionKind = input.ActionKind;
const ActionMapId = input.ActionMapId;
const ActionRegistry = input.ActionRegistry;
const Error = input.Error;

test "action registry adds and finds maps" {
    var registry = ActionRegistry.init();

    const gameplay = try registry.addMap("gameplay");
    const ui = try registry.addMap("ui");

    try std.testing.expectEqual(@as(usize, 2), registry.mapCount());
    try std.testing.expect(registry.hasMap(gameplay));
    try std.testing.expect(registry.hasMap(ui));
    try std.testing.expect(registry.findMap("gameplay").?.eql(gameplay));
    try std.testing.expect(registry.findMap("ui").?.eql(ui));
    try std.testing.expect(registry.findMap("missing") == null);
}

test "action registry rejects duplicate map names" {
    var registry = ActionRegistry.init();

    _ = try registry.addMap("gameplay");

    try std.testing.expectError(
        Error.DuplicateActionMapName,
        registry.addMap("gameplay"),
    );
}

test "action registry adds typed actions to a map" {
    var registry = ActionRegistry.init();
    const gameplay = try registry.addMap("gameplay");

    const jump = try registry.addDigital(gameplay, "player.jump");
    const move_x = try registry.addAxis1(gameplay, "player.move_x");
    const move = try registry.addAxis2(gameplay, "player.move");

    try std.testing.expectEqual(@as(usize, 1), registry.digitalCount());
    try std.testing.expectEqual(@as(usize, 1), registry.axis1Count());
    try std.testing.expectEqual(@as(usize, 1), registry.axis2Count());

    try std.testing.expectEqual(jump.index, registry.findDigital(gameplay, "player.jump").?.index);
    try std.testing.expectEqual(move_x.index, registry.findAxis1(gameplay, "player.move_x").?.index);
    try std.testing.expectEqual(move.index, registry.findAxis2(gameplay, "player.move").?.index);
}

test "action registry keeps action names scoped to their map" {
    var registry = ActionRegistry.init();

    const gameplay = try registry.addMap("gameplay");
    const ui = try registry.addMap("ui");

    const gameplay_confirm = try registry.addDigital(gameplay, "confirm");
    const ui_confirm = try registry.addDigital(ui, "confirm");

    try std.testing.expect(gameplay_confirm.index != ui_confirm.index);
    try std.testing.expectEqual(gameplay_confirm.index, registry.findDigital(gameplay, "confirm").?.index);
    try std.testing.expectEqual(ui_confirm.index, registry.findDigital(ui, "confirm").?.index);
}

test "action registry rejects duplicate action names inside one map" {
    var registry = ActionRegistry.init();
    const gameplay = try registry.addMap("gameplay");

    _ = try registry.addDigital(gameplay, "player.move");

    try std.testing.expectError(
        Error.DuplicateActionName,
        registry.addAxis2(gameplay, "player.move"),
    );
}

test "action registry rejects actions for unknown maps" {
    var registry = ActionRegistry.init();
    const missing = ActionMapId.fromIndex(0);

    try std.testing.expectError(
        Error.UnknownActionMap,
        registry.addDigital(missing, "player.jump"),
    );
}

test "action registry finds any action with kind information" {
    var registry = ActionRegistry.init();
    const gameplay = try registry.addMap("gameplay");

    _ = try registry.addDigital(gameplay, "player.jump");
    _ = try registry.addAxis1(gameplay, "player.move_x");
    _ = try registry.addAxis2(gameplay, "player.move");

    const jump = registry.findAction(gameplay, "player.jump") orelse return error.ExpectedAction;
    const move_x = registry.findAction(gameplay, "player.move_x") orelse return error.ExpectedAction;
    const move = registry.findAction(gameplay, "player.move") orelse return error.ExpectedAction;

    try std.testing.expectEqual(ActionKind.digital, jump.kind());
    try std.testing.expectEqual(ActionKind.axis1, move_x.kind());
    try std.testing.expectEqual(ActionKind.axis2, move.kind());

    try std.testing.expect(registry.findAction(gameplay, "missing") == null);
}
