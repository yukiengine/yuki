//! Input source name tests.
//!
//! These tests pin the string names that config files, debug tools, and future
//! Luau APIs can use when referring to physical input sources.

const std = @import("std");
const yuki2d = @import("../yuki2d.zig");

const input = yuki2d.input;

test "input source names expose stable keyboard key names" {
    try std.testing.expectEqualStrings("escape", input.keyName(.escape).?);
    try std.testing.expectEqualStrings("space", input.keyName(.space).?);
    try std.testing.expectEqualStrings("a", input.keyName(.a).?);
    try std.testing.expectEqualStrings("d", input.keyName(.d).?);
    try std.testing.expectEqualStrings("w", input.keyName(.w).?);
    try std.testing.expectEqualStrings("s", input.keyName(.s).?);
    try std.testing.expectEqualStrings("left", input.keyName(.left).?);
    try std.testing.expectEqualStrings("right", input.keyName(.right).?);
    try std.testing.expectEqualStrings("up", input.keyName(.up).?);
    try std.testing.expectEqualStrings("down", input.keyName(.down).?);
    try std.testing.expectEqualStrings("f1", input.keyName(.f1).?);

    try std.testing.expect(input.keyName(.count) == null);
}

test "input source names parse keyboard key names" {
    try std.testing.expectEqual(input.Key.escape, try input.parseKey("escape"));
    try std.testing.expectEqual(input.Key.space, try input.parseKey("space"));
    try std.testing.expectEqual(input.Key.r, try input.parseKey("r"));
    try std.testing.expectEqual(input.Key.q, try input.parseKey("q"));
    try std.testing.expectEqual(input.Key.e, try input.parseKey("e"));
    try std.testing.expectEqual(input.Key.left, try input.parseKey("left"));
    try std.testing.expectEqual(input.Key.right, try input.parseKey("right"));
    try std.testing.expectEqual(input.Key.up, try input.parseKey("up"));
    try std.testing.expectEqual(input.Key.down, try input.parseKey("down"));

    try std.testing.expect(input.isKeyName("space"));
    try std.testing.expect(!input.isKeyName("enter"));
    try std.testing.expect(input.findKey("missing") == null);
}

test "input source names reject unknown keyboard names" {
    try std.testing.expectError(
        error.UnknownKeyName,
        input.parseKey("enter"),
    );

    try std.testing.expectError(
        error.UnknownKeyName,
        input.parseKey("mouse.left"),
    );
}

test "input source names expose stable mouse button names" {
    try std.testing.expectEqualStrings("left", input.mouseButtonName(.left).?);
    try std.testing.expectEqualStrings("middle", input.mouseButtonName(.middle).?);
    try std.testing.expectEqualStrings("right", input.mouseButtonName(.right).?);
    try std.testing.expectEqualStrings("x1", input.mouseButtonName(.x1).?);
    try std.testing.expectEqualStrings("x2", input.mouseButtonName(.x2).?);

    try std.testing.expect(input.mouseButtonName(.count) == null);
}

test "input source names parse mouse button names" {
    try std.testing.expectEqual(input.MouseButton.left, try input.parseMouseButton("left"));
    try std.testing.expectEqual(input.MouseButton.middle, try input.parseMouseButton("middle"));
    try std.testing.expectEqual(input.MouseButton.right, try input.parseMouseButton("right"));
    try std.testing.expectEqual(input.MouseButton.x1, try input.parseMouseButton("x1"));
    try std.testing.expectEqual(input.MouseButton.x2, try input.parseMouseButton("x2"));

    try std.testing.expect(input.isMouseButtonName("left"));
    try std.testing.expect(!input.isMouseButtonName("space"));
    try std.testing.expect(input.findMouseButton("missing") == null);
}

test "input source names reject unknown mouse button names" {
    try std.testing.expectError(
        error.UnknownMouseButtonName,
        input.parseMouseButton("space"),
    );

    try std.testing.expectError(
        error.UnknownMouseButtonName,
        input.parseMouseButton("mouse.left"),
    );
}

test "input source names describe input source kinds" {
    try std.testing.expectEqualStrings("keyboard", input.sourceKindName(.keyboard));
    try std.testing.expectEqualStrings("mouse", input.sourceKindName(.mouse));
    try std.testing.expectEqualStrings("gamepad", input.sourceKindName(.gamepad));
}

test "input source names describe keyboard sources" {
    const source = input.InputSource.keyboard(.space);
    const name = input.sourceControlName(source) orelse return error.ExpectedSourceName;

    try std.testing.expect(name.isKeyboard());
    try std.testing.expect(!name.isMouse());
    try std.testing.expect(!name.isGamepad());
    try std.testing.expectEqualStrings("keyboard", name.device);
    try std.testing.expectEqualStrings("space", name.control);
}

test "input source names describe mouse button sources" {
    const source = input.InputSource.mouseButton(.left);
    const name = input.sourceControlName(source) orelse return error.ExpectedSourceName;

    try std.testing.expect(!name.isKeyboard());
    try std.testing.expect(name.isMouse());
    try std.testing.expect(!name.isGamepad());
    try std.testing.expectEqualStrings("mouse", name.device);
    try std.testing.expectEqualStrings("left", name.control);
}

test "input source names describe gamepad placeholder sources" {
    const source = input.InputSource.gamepad(0);
    const name = input.sourceControlName(source) orelse return error.ExpectedSourceName;

    try std.testing.expect(!name.isKeyboard());
    try std.testing.expect(!name.isMouse());
    try std.testing.expect(name.isGamepad());
    try std.testing.expectEqualStrings("gamepad", name.device);
    try std.testing.expectEqualStrings("device", name.control);
}

test "input source names return null for incomplete source metadata" {
    const missing_keyboard = input.InputSource{
        .kind = .keyboard,
    };

    const missing_mouse = input.InputSource{
        .kind = .mouse,
    };

    try std.testing.expect(input.sourceControlName(missing_keyboard) == null);
    try std.testing.expect(input.sourceControlName(missing_mouse) == null);
}

test "input source names compare source control names" {
    const first = input.sourceControlName(input.InputSource.keyboard(.space)) orelse {
        return error.ExpectedSourceName;
    };

    const second = input.sourceControlName(input.InputSource.keyboard(.space)) orelse {
        return error.ExpectedSourceName;
    };

    const third = input.sourceControlName(input.InputSource.keyboard(.escape)) orelse {
        return error.ExpectedSourceName;
    };

    const fourth = input.sourceControlName(input.InputSource.mouseButton(.left)) orelse {
        return error.ExpectedSourceName;
    };

    try std.testing.expect(input.sourceControlNameEql(first, second));
    try std.testing.expect(!input.sourceControlNameEql(first, third));
    try std.testing.expect(!input.sourceControlNameEql(first, fourth));
}

test "input source name tables stay in sync with current enum surface" {
    try std.testing.expectEqual(@as(usize, 14), input.key_names.len);
    try std.testing.expectEqual(@as(usize, 5), input.mouse_button_names.len);

    for (input.key_names) |entry| {
        try std.testing.expect(entry.key != .count);
        try std.testing.expect(entry.name.len > 0);
        try std.testing.expectEqual(entry.key, try input.parseKey(entry.name));
    }

    for (input.mouse_button_names) |entry| {
        try std.testing.expect(entry.button != .count);
        try std.testing.expect(entry.name.len > 0);
        try std.testing.expectEqual(entry.button, try input.parseMouseButton(entry.name));
    }
}
