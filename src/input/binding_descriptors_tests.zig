//! Named binding descriptor tests.
//!
//! These tests verify that compact runtime bindings can be inspected as stable
//! author-facing map, action, and source names without changing the runtime map.

const std = @import("std");
const yuki2d = @import("../yuki2d.zig");

const input = yuki2d.input;

test "named binding reader describes digital key bindings" {
    var registry = input.ActionRegistry.init();
    const gameplay = try registry.addMap("gameplay");
    const jump = try registry.addDigital(gameplay, "player.jump");

    var map = input.ActionMap.init();
    try map.bindDigitalKey(.space, jump);

    const reader = input.NamedBindingReader.init(&registry, gameplay, &map);

    const binding = reader.firstForAction("player.jump") orelse {
        return error.ExpectedBinding;
    };

    switch (binding) {
        .digital_key => |item| {
            try std.testing.expect(item.map.eql(gameplay));
            try std.testing.expectEqual(jump.index, item.action.index);
            try std.testing.expectEqual(input.Key.space, item.key);
            try std.testing.expectEqualStrings("gameplay", item.map_name);
            try std.testing.expectEqualStrings("player.jump", item.action_name);
            try std.testing.expectEqualStrings("space", item.key_name);
        },
        else => return error.ExpectedDigitalKeyBinding,
    }

    try std.testing.expectEqual(input.NamedBindingKind.digital_key, binding.kind());
    try std.testing.expectEqualStrings("gameplay", binding.mapName());
    try std.testing.expectEqualStrings("player.jump", binding.actionName());
}

test "named binding reader describes mouse button bindings" {
    var registry = input.ActionRegistry.init();
    const gameplay = try registry.addMap("gameplay");
    const select = try registry.addDigital(gameplay, "pointer.select");

    var map = input.ActionMap.init();
    try map.bindMouseButton(.left, select);

    const reader = input.NamedBindingReader.init(&registry, gameplay, &map);

    const binding = reader.firstForAction("pointer.select") orelse {
        return error.ExpectedBinding;
    };

    switch (binding) {
        .mouse_button => |item| {
            try std.testing.expect(item.map.eql(gameplay));
            try std.testing.expectEqual(select.index, item.action.index);
            try std.testing.expectEqual(input.MouseButton.left, item.button);
            try std.testing.expectEqualStrings("gameplay", item.map_name);
            try std.testing.expectEqualStrings("pointer.select", item.action_name);
            try std.testing.expectEqualStrings("left", item.button_name);
        },
        else => return error.ExpectedMouseButtonBinding,
    }
}

test "named binding reader describes axis key bindings" {
    var registry = input.ActionRegistry.init();
    const gameplay = try registry.addMap("gameplay");
    const move_x = try registry.addAxis1(gameplay, "player.move_x");
    const move = try registry.addAxis2(gameplay, "player.move");

    var map = input.ActionMap.init();
    try map.bindAxis1Keys(.a, .d, move_x);
    try map.bindAxis2Keys(.a, .d, .w, .s, move);

    const reader = input.NamedBindingReader.init(&registry, gameplay, &map);

    const axis1 = reader.firstForAction("player.move_x") orelse {
        return error.ExpectedBinding;
    };

    switch (axis1) {
        .axis1_keys => |item| {
            try std.testing.expectEqual(move_x.index, item.action.index);
            try std.testing.expectEqualStrings("player.move_x", item.action_name);
            try std.testing.expectEqualStrings("a", item.negative_name);
            try std.testing.expectEqualStrings("d", item.positive_name);
        },
        else => return error.ExpectedAxis1Binding,
    }

    const axis2 = reader.firstForAction("player.move") orelse {
        return error.ExpectedBinding;
    };

    switch (axis2) {
        .axis2_keys => |item| {
            try std.testing.expectEqual(move.index, item.action.index);
            try std.testing.expectEqualStrings("player.move", item.action_name);
            try std.testing.expectEqualStrings("a", item.left_name);
            try std.testing.expectEqualStrings("d", item.right_name);
            try std.testing.expectEqualStrings("w", item.up_name);
            try std.testing.expectEqualStrings("s", item.down_name);
        },
        else => return error.ExpectedAxis2Binding,
    }
}

test "named binding reader iterates describable bindings in order" {
    var registry = input.ActionRegistry.init();
    const gameplay = try registry.addMap("gameplay");

    const jump = try registry.addDigital(gameplay, "player.jump");
    const select = try registry.addDigital(gameplay, "pointer.select");
    const move = try registry.addAxis2(gameplay, "player.move");

    var map = input.ActionMap.init();
    try map.bindDigitalKey(.space, jump);
    try map.bindMouseButton(.left, select);
    try map.bindAxis2Keys(.a, .d, .w, .s, move);

    const reader = input.NamedBindingReader.init(&registry, gameplay, &map);
    var iterator = reader.iter();

    const first = iterator.next() orelse return error.ExpectedBinding;
    try std.testing.expectEqual(input.NamedBindingKind.digital_key, first.kind());
    try std.testing.expectEqualStrings("player.jump", first.actionName());

    const second = iterator.next() orelse return error.ExpectedBinding;
    try std.testing.expectEqual(input.NamedBindingKind.mouse_button, second.kind());
    try std.testing.expectEqualStrings("pointer.select", second.actionName());

    const third = iterator.next() orelse return error.ExpectedBinding;
    try std.testing.expectEqual(input.NamedBindingKind.axis2_keys, third.kind());
    try std.testing.expectEqualStrings("player.move", third.actionName());

    try std.testing.expect(iterator.next() == null);
}

test "named binding reader counts bindings for one action" {
    var registry = input.ActionRegistry.init();
    const gameplay = try registry.addMap("gameplay");
    const move = try registry.addAxis2(gameplay, "player.move");

    var map = input.ActionMap.init();
    try map.bindAxis2Keys(.a, .d, .w, .s, move);
    try map.bindAxis2Keys(.left, .right, .up, .down, move);

    const reader = input.NamedBindingReader.init(&registry, gameplay, &map);

    try std.testing.expectEqual(@as(usize, 2), reader.count());
    try std.testing.expectEqual(@as(usize, 2), reader.countForAction("player.move"));
    try std.testing.expectEqual(@as(usize, 0), reader.countForAction("player.jump"));
}

test "named binding reader skips bindings from another map" {
    var registry = input.ActionRegistry.init();

    const gameplay = try registry.addMap("gameplay");
    const ui = try registry.addMap("ui");

    const confirm = try registry.addDigital(ui, "ui.confirm");

    var map = input.ActionMap.init();
    try map.bindDigitalKey(.space, confirm);

    const reader = input.NamedBindingReader.init(&registry, gameplay, &map);

    try std.testing.expectEqual(@as(usize, 1), reader.count());
    try std.testing.expect(reader.firstForAction("ui.confirm") == null);

    var iterator = reader.iter();
    try std.testing.expect(iterator.next() == null);
}

test "named binding reader works with source-name-built action maps" {
    var registry = input.ActionRegistry.init();
    const gameplay = try registry.addMap("gameplay");

    _ = try registry.addDigital(gameplay, "player.jump");
    _ = try registry.addDigital(gameplay, "pointer.select");
    _ = try registry.addAxis2(gameplay, "player.move");

    var builder = input.ActionMapBuilder.init(gameplay);
    try builder.bindDigitalKeyName(&registry, "player.jump", "space");
    try builder.bindMouseButtonName(&registry, "pointer.select", "left");
    try builder.bindAxis2KeyNames(&registry, "player.move", "a", "d", "w", "s");
    try builder.bindAxis2KeyNames(&registry, "player.move", "left", "right", "up", "down");

    const map = builder.build();
    const reader = input.NamedBindingReader.init(&registry, gameplay, &map);

    try std.testing.expectEqual(@as(usize, 4), reader.count());
    try std.testing.expectEqual(@as(usize, 2), reader.countForAction("player.move"));

    const jump = reader.firstForAction("player.jump") orelse {
        return error.ExpectedBinding;
    };

    const select = reader.firstForAction("pointer.select") orelse {
        return error.ExpectedBinding;
    };

    try std.testing.expectEqual(input.NamedBindingKind.digital_key, jump.kind());
    try std.testing.expectEqual(input.NamedBindingKind.mouse_button, select.kind());
}
