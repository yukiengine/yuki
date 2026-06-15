//! Input action registry tests.
//!
//! These tests cover named action maps and typed action name lookup before the
//! runtime starts binding those names to physical input.

const std = @import("std");
const yuki2d = @import("../yuki2d.zig");

const input = yuki2d.input;
const ActionKind = input.ActionKind;
const ActionMapId = input.ActionMapId;
const ActionRegistry = input.ActionRegistry;
const ActionRef = input.ActionRef;
const Axis1ActionId = input.Axis1ActionId;
const Axis2ActionId = input.Axis2ActionId;
const DigitalActionId = input.DigitalActionId;
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

test "action registry returns map metadata by handle" {
    var registry = ActionRegistry.init();

    const gameplay = try registry.addMap("gameplay");
    const ui = try registry.addMap("ui");

    const gameplay_info = registry.mapInfo(gameplay) orelse return error.ExpectedMap;
    const ui_info = registry.mapInfo(ui) orelse return error.ExpectedMap;

    try std.testing.expect(gameplay_info.id.eql(gameplay));
    try std.testing.expect(ui_info.id.eql(ui));
    try std.testing.expectEqualStrings("gameplay", gameplay_info.name);
    try std.testing.expectEqualStrings("ui", ui_info.name);
    try std.testing.expectEqualStrings("gameplay", registry.mapName(gameplay).?);
    try std.testing.expectEqualStrings("ui", registry.mapName(ui).?);

    const missing = ActionMapId.fromIndex(15);
    try std.testing.expect(registry.mapInfo(missing) == null);
    try std.testing.expect(registry.mapName(missing) == null);
}

test "action registry returns typed action metadata by handle" {
    var registry = ActionRegistry.init();
    const gameplay = try registry.addMap("gameplay");

    const jump = try registry.addDigital(gameplay, "player.jump");
    const move_x = try registry.addAxis1(gameplay, "player.move_x");
    const move = try registry.addAxis2(gameplay, "player.move");

    const jump_info = registry.digitalInfo(jump) orelse return error.ExpectedAction;
    const move_x_info = registry.axis1Info(move_x) orelse return error.ExpectedAction;
    const move_info = registry.axis2Info(move) orelse return error.ExpectedAction;

    try std.testing.expectEqual(jump.index, jump_info.id.index);
    try std.testing.expectEqual(move_x.index, move_x_info.id.index);
    try std.testing.expectEqual(move.index, move_info.id.index);

    try std.testing.expect(jump_info.map.eql(gameplay));
    try std.testing.expect(move_x_info.map.eql(gameplay));
    try std.testing.expect(move_info.map.eql(gameplay));

    try std.testing.expectEqualStrings("player.jump", jump_info.name);
    try std.testing.expectEqualStrings("player.move_x", move_x_info.name);
    try std.testing.expectEqualStrings("player.move", move_info.name);
}

test "action registry returns descriptors for any action ref" {
    var registry = ActionRegistry.init();
    const gameplay = try registry.addMap("gameplay");

    const jump = try registry.addDigital(gameplay, "player.jump");
    const move_x = try registry.addAxis1(gameplay, "player.move_x");
    const move = try registry.addAxis2(gameplay, "player.move");

    const jump_ref = ActionRef{ .digital = jump };
    const move_x_ref = ActionRef{ .axis1 = move_x };
    const move_ref = ActionRef{ .axis2 = move };

    const jump_info = registry.actionInfo(jump_ref) orelse return error.ExpectedAction;
    const move_x_info = registry.actionInfo(move_x_ref) orelse return error.ExpectedAction;
    const move_info = registry.actionInfo(move_ref) orelse return error.ExpectedAction;

    try std.testing.expectEqual(ActionKind.digital, jump_info.kind());
    try std.testing.expectEqual(ActionKind.axis1, move_x_info.kind());
    try std.testing.expectEqual(ActionKind.axis2, move_info.kind());

    try std.testing.expectEqualStrings("player.jump", jump_info.name());
    try std.testing.expectEqualStrings("player.move_x", move_x_info.name());
    try std.testing.expectEqualStrings("player.move", move_info.name());

    try std.testing.expect(jump_info.map().eql(gameplay));
    try std.testing.expect(move_x_info.map().eql(gameplay));
    try std.testing.expect(move_info.map().eql(gameplay));
}

test "action registry exposes action names from refs" {
    var registry = ActionRegistry.init();
    const gameplay = try registry.addMap("gameplay");

    const jump = try registry.addDigital(gameplay, "player.jump");
    const move = try registry.addAxis2(gameplay, "player.move");

    const jump_ref = ActionRef{ .digital = jump };
    const move_ref = ActionRef{ .axis2 = move };

    try std.testing.expectEqualStrings("player.jump", registry.actionName(jump_ref).?);
    try std.testing.expectEqualStrings("player.move", registry.actionName(move_ref).?);

    const missing_ref = ActionRef{ .digital = DigitalActionId.fromIndex(63) };
    try std.testing.expect(registry.actionName(missing_ref) == null);
}

test "action registry checks action ownership by map" {
    var registry = ActionRegistry.init();

    const gameplay = try registry.addMap("gameplay");
    const ui = try registry.addMap("ui");

    const jump = try registry.addDigital(gameplay, "player.jump");
    const confirm = try registry.addDigital(ui, "confirm");

    const jump_ref = ActionRef{ .digital = jump };
    const confirm_ref = ActionRef{ .digital = confirm };

    try std.testing.expect(registry.hasAction(jump_ref));
    try std.testing.expect(registry.hasAction(confirm_ref));

    try std.testing.expect(registry.actionBelongsToMap(gameplay, jump_ref));
    try std.testing.expect(!registry.actionBelongsToMap(ui, jump_ref));

    try std.testing.expect(registry.actionBelongsToMap(ui, confirm_ref));
    try std.testing.expect(!registry.actionBelongsToMap(gameplay, confirm_ref));
}

test "action registry returns null for missing action handles" {
    var registry = ActionRegistry.init();
    const gameplay = try registry.addMap("gameplay");

    _ = try registry.addDigital(gameplay, "player.jump");
    _ = try registry.addAxis1(gameplay, "player.move_x");
    _ = try registry.addAxis2(gameplay, "player.move");

    const missing_digital = DigitalActionId.fromIndex(63);
    const missing_axis1 = Axis1ActionId.fromIndex(31);
    const missing_axis2 = Axis2ActionId.fromIndex(31);

    const missing_digital_ref = ActionRef{ .digital = missing_digital };
    const missing_axis1_ref = ActionRef{ .axis1 = missing_axis1 };
    const missing_axis2_ref = ActionRef{ .axis2 = missing_axis2 };

    try std.testing.expect(registry.digitalInfo(missing_digital) == null);
    try std.testing.expect(registry.axis1Info(missing_axis1) == null);
    try std.testing.expect(registry.axis2Info(missing_axis2) == null);

    try std.testing.expect(registry.actionInfo(missing_digital_ref) == null);
    try std.testing.expect(registry.actionInfo(missing_axis1_ref) == null);
    try std.testing.expect(registry.actionInfo(missing_axis2_ref) == null);

    try std.testing.expect(!registry.hasAction(missing_digital_ref));
    try std.testing.expect(!registry.actionBelongsToMap(gameplay, missing_digital_ref));
}
