//! Named input binding descriptors.
//!
//! Runtime action maps store compact bindings: enum keys, enum mouse buttons,
//! and typed action handles. That is the right hot-path representation, but
//! tools, debug UI, generated docs, and future Luau APIs need stable names.
//!
//! This module is the read-only bridge from runtime bindings back to
//! author-facing names. It does not mutate maps and does not add strings to the
//! runtime input path.

const std = @import("std");
const types = @import("types.zig");
const registry_mod = @import("registry.zig");
const action_map_mod = @import("action_map.zig");
const bindings_mod = @import("bindings.zig");
const source_names_mod = @import("source_names.zig");

/// Handle to a named action map.
pub const ActionMapId = types.ActionMapId;

/// Handle to a digital action.
pub const DigitalActionId = types.DigitalActionId;

/// Handle to a 1D axis action.
pub const Axis1ActionId = types.Axis1ActionId;

/// Handle to a 2D axis action.
pub const Axis2ActionId = types.Axis2ActionId;

/// Keyboard key enum used by runtime bindings.
pub const Key = types.Key;

/// Mouse button enum used by runtime bindings.
pub const MouseButton = types.MouseButton;

/// Named action registry used to resolve action handles.
pub const ActionRegistry = registry_mod.ActionRegistry;

/// Runtime action map containing compact bindings.
pub const ActionMap = action_map_mod.ActionMap;

/// Runtime binding union.
pub const Binding = bindings_mod.Binding;

/// Kind of named binding descriptor.
pub const NamedBindingKind = enum(u8) {
    digital_key,
    mouse_button,
    axis1_keys,
    axis2_keys,
};

/// Named descriptor for one keyboard-to-digital binding.
pub const NamedDigitalKeyBinding = struct {
    map: ActionMapId,
    map_name: []const u8,
    action: DigitalActionId,
    action_name: []const u8,
    key: Key,
    key_name: []const u8,
};

/// Named descriptor for one mouse-button-to-digital binding.
pub const NamedMouseButtonBinding = struct {
    map: ActionMapId,
    map_name: []const u8,
    action: DigitalActionId,
    action_name: []const u8,
    button: MouseButton,
    button_name: []const u8,
};

/// Named descriptor for one keyboard-to-1D-axis binding.
pub const NamedAxis1KeyBinding = struct {
    map: ActionMapId,
    map_name: []const u8,
    action: Axis1ActionId,
    action_name: []const u8,
    negative: Key,
    positive: Key,
    negative_name: []const u8,
    positive_name: []const u8,
};

/// Named descriptor for one keyboard-to-2D-axis binding.
pub const NamedAxis2KeyBinding = struct {
    map: ActionMapId,
    map_name: []const u8,
    action: Axis2ActionId,
    action_name: []const u8,
    left: Key,
    right: Key,
    up: Key,
    down: Key,
    left_name: []const u8,
    right_name: []const u8,
    up_name: []const u8,
    down_name: []const u8,
};

/// Tool-facing descriptor for any runtime input binding.
pub const NamedBinding = union(NamedBindingKind) {
    digital_key: NamedDigitalKeyBinding,
    mouse_button: NamedMouseButtonBinding,
    axis1_keys: NamedAxis1KeyBinding,
    axis2_keys: NamedAxis2KeyBinding,

    /// Returns the binding descriptor kind.
    pub fn kind(self: NamedBinding) NamedBindingKind {
        return switch (self) {
            .digital_key => .digital_key,
            .mouse_button => .mouse_button,
            .axis1_keys => .axis1_keys,
            .axis2_keys => .axis2_keys,
        };
    }

    /// Returns the map name shared by all named binding descriptors.
    pub fn mapName(self: NamedBinding) []const u8 {
        return switch (self) {
            .digital_key => |item| item.map_name,
            .mouse_button => |item| item.map_name,
            .axis1_keys => |item| item.map_name,
            .axis2_keys => |item| item.map_name,
        };
    }

    /// Returns the action name targeted by this binding.
    pub fn actionName(self: NamedBinding) []const u8 {
        return switch (self) {
            .digital_key => |item| item.action_name,
            .mouse_button => |item| item.action_name,
            .axis1_keys => |item| item.action_name,
            .axis2_keys => |item| item.action_name,
        };
    }

    /// Returns true when this descriptor targets the provided action name.
    pub fn targetsAction(self: NamedBinding, action_name: []const u8) bool {
        return std.mem.eql(u8, self.actionName(), action_name);
    }
};

/// Read-only descriptor view over one action map.
pub const NamedBindingReader = struct {
    registry: *const ActionRegistry,
    map: ActionMapId,
    action_map: *const ActionMap,

    /// Creates a named binding reader for one runtime action map.
    pub fn init(
        registry: *const ActionRegistry,
        map: ActionMapId,
        action_map: *const ActionMap,
    ) NamedBindingReader {
        return .{
            .registry = registry,
            .map = map,
            .action_map = action_map,
        };
    }

    /// Returns the number of raw bindings in the action map.
    pub fn count(self: NamedBindingReader) usize {
        return self.action_map.items().len;
    }

    /// Returns true when the action map has no raw bindings.
    pub fn isEmpty(self: NamedBindingReader) bool {
        return self.count() == 0;
    }

    /// Returns a forward-only iterator over named binding descriptors.
    pub fn iter(self: NamedBindingReader) NamedBindingIterator {
        return NamedBindingIterator.init(self);
    }

    /// Describes one raw binding when it belongs to this reader's map.
    pub fn describe(self: NamedBindingReader, binding: Binding) ?NamedBinding {
        return switch (binding) {
            .digital_key => |item| self.describeDigitalKey(item),
            .mouse_button => |item| self.describeMouseButton(item),
            .axis1_keys => |item| self.describeAxis1Keys(item),
            .axis2_keys => |item| self.describeAxis2Keys(item),
        };
    }

    /// Returns the first binding descriptor for an action name.
    pub fn firstForAction(self: NamedBindingReader, action_name: []const u8) ?NamedBinding {
        var iterator = self.iter();

        while (iterator.next()) |binding| {
            if (binding.targetsAction(action_name)) return binding;
        }

        return null;
    }

    /// Counts named binding descriptors for an action name.
    pub fn countForAction(self: NamedBindingReader, action_name: []const u8) usize {
        var result: usize = 0;
        var iterator = self.iter();

        while (iterator.next()) |binding| {
            if (binding.targetsAction(action_name)) result += 1;
        }

        return result;
    }

    /// Describes a keyboard-to-digital binding.
    fn describeDigitalKey(
        self: NamedBindingReader,
        binding: bindings_mod.DigitalKeyBinding,
    ) ?NamedBinding {
        const map_name = self.registry.mapName(self.map) orelse return null;
        const action = self.registry.digitalInfo(binding.action) orelse return null;
        if (!action.map.eql(self.map)) return null;

        const key_name = source_names_mod.keyName(binding.key) orelse return null;

        return .{
            .digital_key = .{
                .map = self.map,
                .map_name = map_name,
                .action = binding.action,
                .action_name = action.name,
                .key = binding.key,
                .key_name = key_name,
            },
        };
    }

    /// Describes a mouse-button-to-digital binding.
    fn describeMouseButton(
        self: NamedBindingReader,
        binding: bindings_mod.MouseButtonBinding,
    ) ?NamedBinding {
        const map_name = self.registry.mapName(self.map) orelse return null;
        const action = self.registry.digitalInfo(binding.action) orelse return null;
        if (!action.map.eql(self.map)) return null;

        const button_name = source_names_mod.mouseButtonName(binding.button) orelse return null;

        return .{
            .mouse_button = .{
                .map = self.map,
                .map_name = map_name,
                .action = binding.action,
                .action_name = action.name,
                .button = binding.button,
                .button_name = button_name,
            },
        };
    }

    /// Describes a keyboard-to-1D-axis binding.
    fn describeAxis1Keys(
        self: NamedBindingReader,
        binding: bindings_mod.Axis1KeyBinding,
    ) ?NamedBinding {
        const map_name = self.registry.mapName(self.map) orelse return null;
        const action = self.registry.axis1Info(binding.action) orelse return null;
        if (!action.map.eql(self.map)) return null;

        const negative_name = source_names_mod.keyName(binding.negative) orelse return null;
        const positive_name = source_names_mod.keyName(binding.positive) orelse return null;

        return .{
            .axis1_keys = .{
                .map = self.map,
                .map_name = map_name,
                .action = binding.action,
                .action_name = action.name,
                .negative = binding.negative,
                .positive = binding.positive,
                .negative_name = negative_name,
                .positive_name = positive_name,
            },
        };
    }

    /// Describes a keyboard-to-2D-axis binding.
    fn describeAxis2Keys(
        self: NamedBindingReader,
        binding: bindings_mod.Axis2KeyBinding,
    ) ?NamedBinding {
        const map_name = self.registry.mapName(self.map) orelse return null;
        const action = self.registry.axis2Info(binding.action) orelse return null;
        if (!action.map.eql(self.map)) return null;

        const left_name = source_names_mod.keyName(binding.left) orelse return null;
        const right_name = source_names_mod.keyName(binding.right) orelse return null;
        const up_name = source_names_mod.keyName(binding.up) orelse return null;
        const down_name = source_names_mod.keyName(binding.down) orelse return null;

        return .{
            .axis2_keys = .{
                .map = self.map,
                .map_name = map_name,
                .action = binding.action,
                .action_name = action.name,
                .left = binding.left,
                .right = binding.right,
                .up = binding.up,
                .down = binding.down,
                .left_name = left_name,
                .right_name = right_name,
                .up_name = up_name,
                .down_name = down_name,
            },
        };
    }
};

/// Forward-only iterator over named binding descriptors.
pub const NamedBindingIterator = struct {
    reader: NamedBindingReader,
    index: usize,

    /// Creates an iterator from a named binding reader.
    pub fn init(reader: NamedBindingReader) NamedBindingIterator {
        return .{
            .reader = reader,
            .index = 0,
        };
    }

    /// Returns the next describable binding, skipping invalid foreign entries.
    pub fn next(self: *NamedBindingIterator) ?NamedBinding {
        const items = self.reader.action_map.items();

        while (self.index < items.len) {
            const binding = items[self.index];
            self.index += 1;

            if (self.reader.describe(binding)) |named| return named;
        }

        return null;
    }

    /// Restarts iteration from the first binding.
    pub fn reset(self: *NamedBindingIterator) void {
        self.index = 0;
    }
};
