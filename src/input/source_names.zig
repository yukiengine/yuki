//! Stable names for physical input sources.
//!
//! This module is the string boundary for keyboard and mouse controls. Runtime
//! code should keep using enums, while config files, debug tools, and future
//! Luau bindings can use stable strings such as "space", "a", or "mouse.left".

const std = @import("std");
const types = @import("types.zig");
const events_mod = @import("events.zig");

/// Keyboard key enum used by the input layer.
pub const Key = types.Key;

/// Mouse button enum used by the input layer.
pub const MouseButton = types.MouseButton;

/// Backend-neutral input source metadata.
pub const InputSource = events_mod.InputSource;

/// Kind of backend-neutral input source.
pub const InputSourceKind = events_mod.InputSourceKind;

/// Errors returned by strict source-name parsers.
pub const Error = error{
    UnknownKeyName,
    UnknownMouseButtonName,
};

/// One stable string name for a keyboard key.
pub const KeyName = struct {
    key: Key,
    name: []const u8,
};

/// One stable string name for a mouse button.
pub const MouseButtonName = struct {
    button: MouseButton,
    name: []const u8,
};

/// Human-readable source name split into device and control parts.
pub const SourceControlName = struct {
    device: []const u8,
    control: []const u8,

    /// Returns true when this name refers to a keyboard control.
    pub fn isKeyboard(self: SourceControlName) bool {
        return std.mem.eql(u8, self.device, "keyboard");
    }

    /// Returns true when this name refers to a mouse control.
    pub fn isMouse(self: SourceControlName) bool {
        return std.mem.eql(u8, self.device, "mouse");
    }

    /// Returns true when this name refers to a gamepad placeholder.
    pub fn isGamepad(self: SourceControlName) bool {
        return std.mem.eql(u8, self.device, "gamepad");
    }
};

/// Stable keyboard key names accepted by config/script-facing APIs.
pub const key_names = [_]KeyName{
    .{ .key = .escape, .name = "escape" },
    .{ .key = .space, .name = "space" },
    .{ .key = .r, .name = "r" },

    .{ .key = .a, .name = "a" },
    .{ .key = .d, .name = "d" },
    .{ .key = .w, .name = "w" },
    .{ .key = .s, .name = "s" },

    .{ .key = .q, .name = "q" },
    .{ .key = .e, .name = "e" },

    .{ .key = .left, .name = "left" },
    .{ .key = .right, .name = "right" },
    .{ .key = .up, .name = "up" },
    .{ .key = .down, .name = "down" },

    .{ .key = .f1, .name = "f1" },
};

/// Stable mouse button names accepted by config/script-facing APIs.
pub const mouse_button_names = [_]MouseButtonName{
    .{ .button = .left, .name = "left" },
    .{ .button = .middle, .name = "middle" },
    .{ .button = .right, .name = "right" },
    .{ .button = .x1, .name = "x1" },
    .{ .button = .x2, .name = "x2" },
};

/// Returns the stable string name for a keyboard key.
pub fn keyName(key: Key) ?[]const u8 {
    for (key_names) |entry| {
        if (entry.key == key) return entry.name;
    }

    return null;
}

/// Returns the stable string name for a keyboard key or asserts for invalid keys.
pub fn keyNameAssert(key: Key) []const u8 {
    return keyName(key) orelse unreachable;
}

/// Finds a keyboard key by stable string name.
pub fn findKey(name: []const u8) ?Key {
    for (key_names) |entry| {
        if (std.mem.eql(u8, entry.name, name)) return entry.key;
    }

    return null;
}

/// Parses a keyboard key by stable string name.
pub fn parseKey(name: []const u8) Error!Key {
    return findKey(name) orelse Error.UnknownKeyName;
}

/// Returns true when a stable keyboard key name is known.
pub fn isKeyName(name: []const u8) bool {
    return findKey(name) != null;
}

/// Returns the stable string name for a mouse button.
pub fn mouseButtonName(button: MouseButton) ?[]const u8 {
    for (mouse_button_names) |entry| {
        if (entry.button == button) return entry.name;
    }

    return null;
}

/// Returns the stable string name for a mouse button or asserts for invalid buttons.
pub fn mouseButtonNameAssert(button: MouseButton) []const u8 {
    return mouseButtonName(button) orelse unreachable;
}

/// Finds a mouse button by stable string name.
pub fn findMouseButton(name: []const u8) ?MouseButton {
    for (mouse_button_names) |entry| {
        if (std.mem.eql(u8, entry.name, name)) return entry.button;
    }

    return null;
}

/// Parses a mouse button by stable string name.
pub fn parseMouseButton(name: []const u8) Error!MouseButton {
    return findMouseButton(name) orelse Error.UnknownMouseButtonName;
}

/// Returns true when a stable mouse button name is known.
pub fn isMouseButtonName(name: []const u8) bool {
    return findMouseButton(name) != null;
}

/// Returns a stable name for an input source kind.
pub fn sourceKindName(kind: InputSourceKind) []const u8 {
    return switch (kind) {
        .keyboard => "keyboard",
        .mouse => "mouse",
        .gamepad => "gamepad",
    };
}

/// Returns a stable source control name when the source has enough metadata.
pub fn sourceControlName(source: InputSource) ?SourceControlName {
    return switch (source.kind) {
        .keyboard => {
            const key = source.key orelse return null;
            const name = keyName(key) orelse return null;

            return .{
                .device = "keyboard",
                .control = name,
            };
        },
        .mouse => {
            const button = source.mouse_button orelse return null;
            const name = mouseButtonName(button) orelse return null;

            return .{
                .device = "mouse",
                .control = name,
            };
        },
        .gamepad => .{
            .device = "gamepad",
            .control = "device",
        },
    };
}

/// Returns true when two source control names have the same device and control.
pub fn sourceControlNameEql(left: SourceControlName, right: SourceControlName) bool {
    return std.mem.eql(u8, left.device, right.device) and
        std.mem.eql(u8, left.control, right.control);
}
