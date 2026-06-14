//! Named input action registry.
//!
//! This module resolves author-facing action/map names into compact typed
//! handles used by hot-path input state, action maps, and future Luau bindings.

const std = @import("std");
const types = @import("types.zig");

pub const ActionRef = types.ActionRef;
pub const ActionMapId = types.ActionMapId;
pub const Axis1ActionId = types.Axis1ActionId;
pub const Axis2ActionId = types.Axis2ActionId;
pub const DigitalActionId = types.DigitalActionId;
pub const Error = types.Error;

pub const max_action_maps = types.max_action_maps;
pub const max_axis1_actions = types.max_axis1_actions;
pub const max_axis2_actions = types.max_axis2_actions;
pub const max_digital_actions = types.max_digital_actions;

/// Named action map entry stored in the registry.
pub const NamedActionMap = struct {
    id: ActionMapId,
    name: []const u8,
};

/// Named digital action entry stored in the registry.
pub const NamedDigitalAction = struct {
    id: DigitalActionId,
    map: ActionMapId,
    name: []const u8,
};

/// Named 1D axis action entry stored in the registry.
pub const NamedAxis1Action = struct {
    id: Axis1ActionId,
    map: ActionMapId,
    name: []const u8,
};

/// Named 2D axis action entry stored in the registry.
pub const NamedAxis2Action = struct {
    id: Axis2ActionId,
    map: ActionMapId,
    name: []const u8,
};

/// Registry that resolves authoring names into compact typed action handles.
pub const ActionRegistry = struct {
    maps: [max_action_maps]NamedActionMap,
    map_count: usize,
    digital_actions: [max_digital_actions]NamedDigitalAction,
    digital_count: usize,
    axis1_actions: [max_axis1_actions]NamedAxis1Action,
    axis1_count: usize,
    axis2_actions: [max_axis2_actions]NamedAxis2Action,
    axis2_count: usize,

    /// Creates an empty action registry.
    pub fn init() ActionRegistry {
        return .{
            .maps = undefined,
            .map_count = 0,
            .digital_actions = undefined,
            .digital_count = 0,
            .axis1_actions = undefined,
            .axis1_count = 0,
            .axis2_actions = undefined,
            .axis2_count = 0,
        };
    }

    /// Registers a named action map and returns its handle.
    pub fn addMap(self: *ActionRegistry, map_name: []const u8) !ActionMapId {
        std.debug.assert(map_name.len != 0);

        if (self.findMap(map_name) != null) {
            return Error.DuplicateActionMapName;
        }

        if (self.map_count == max_action_maps) {
            return Error.ActionMapRegistryFull;
        }

        const id = ActionMapId.fromIndex(@intCast(self.map_count));
        self.maps[self.map_count] = .{
            .id = id,
            .name = map_name,
        };
        self.map_count += 1;

        return id;
    }

    /// Returns a map handle by name.
    pub fn findMap(self: *const ActionRegistry, map_name: []const u8) ?ActionMapId {
        var index: usize = 0;
        while (index < self.map_count) : (index += 1) {
            const item = self.maps[index];
            if (std.mem.eql(u8, item.name, map_name)) return item.id;
        }

        return null;
    }

    /// Returns true when a map handle exists in the registry.
    pub fn hasMap(self: *const ActionRegistry, map: ActionMapId) bool {
        const index: usize = @intCast(map.index);
        return index < self.map_count and self.maps[index].id.eql(map);
    }

    /// Returns the number of registered maps.
    pub fn mapCount(self: *const ActionRegistry) usize {
        return self.map_count;
    }

    /// Registers a named digital action inside a map.
    pub fn addDigital(
        self: *ActionRegistry,
        map: ActionMapId,
        action_name: []const u8,
    ) !DigitalActionId {
        std.debug.assert(action_name.len != 0);

        try self.ensureMapExists(map);
        if (self.findAction(map, action_name) != null) {
            return Error.DuplicateActionName;
        }

        if (self.digital_count == max_digital_actions) {
            return Error.DigitalActionRegistryFull;
        }

        const id = DigitalActionId.fromIndex(@intCast(self.digital_count));
        self.digital_actions[self.digital_count] = .{
            .id = id,
            .map = map,
            .name = action_name,
        };
        self.digital_count += 1;

        return id;
    }

    /// Registers a named 1D axis action inside a map.
    pub fn addAxis1(
        self: *ActionRegistry,
        map: ActionMapId,
        action_name: []const u8,
    ) !Axis1ActionId {
        std.debug.assert(action_name.len != 0);

        try self.ensureMapExists(map);
        if (self.findAction(map, action_name) != null) {
            return Error.DuplicateActionName;
        }

        if (self.axis1_count == max_axis1_actions) {
            return Error.Axis1ActionRegistryFull;
        }

        const id = Axis1ActionId.fromIndex(@intCast(self.axis1_count));
        self.axis1_actions[self.axis1_count] = .{
            .id = id,
            .map = map,
            .name = action_name,
        };
        self.axis1_count += 1;

        return id;
    }

    /// Registers a named 2D axis action inside a map.
    pub fn addAxis2(
        self: *ActionRegistry,
        map: ActionMapId,
        action_name: []const u8,
    ) !Axis2ActionId {
        std.debug.assert(action_name.len != 0);

        try self.ensureMapExists(map);
        if (self.findAction(map, action_name) != null) {
            return Error.DuplicateActionName;
        }

        if (self.axis2_count == max_axis2_actions) {
            return Error.Axis2ActionRegistryFull;
        }

        const id = Axis2ActionId.fromIndex(@intCast(self.axis2_count));
        self.axis2_actions[self.axis2_count] = .{
            .id = id,
            .map = map,
            .name = action_name,
        };
        self.axis2_count += 1;

        return id;
    }

    /// Finds a digital action by map and name.
    pub fn findDigital(
        self: *const ActionRegistry,
        map: ActionMapId,
        action_name: []const u8,
    ) ?DigitalActionId {
        var index: usize = 0;
        while (index < self.digital_count) : (index += 1) {
            const item = self.digital_actions[index];
            if (!item.map.eql(map)) continue;
            if (std.mem.eql(u8, item.name, action_name)) return item.id;
        }

        return null;
    }

    /// Finds a 1D axis action by map and name.
    pub fn findAxis1(
        self: *const ActionRegistry,
        map: ActionMapId,
        action_name: []const u8,
    ) ?Axis1ActionId {
        var index: usize = 0;
        while (index < self.axis1_count) : (index += 1) {
            const item = self.axis1_actions[index];
            if (!item.map.eql(map)) continue;
            if (std.mem.eql(u8, item.name, action_name)) return item.id;
        }

        return null;
    }

    /// Finds a 2D axis action by map and name.
    pub fn findAxis2(
        self: *const ActionRegistry,
        map: ActionMapId,
        action_name: []const u8,
    ) ?Axis2ActionId {
        var index: usize = 0;
        while (index < self.axis2_count) : (index += 1) {
            const item = self.axis2_actions[index];
            if (!item.map.eql(map)) continue;
            if (std.mem.eql(u8, item.name, action_name)) return item.id;
        }

        return null;
    }

    /// Finds any typed action by map and name.
    pub fn findAction(
        self: *const ActionRegistry,
        map: ActionMapId,
        action_name: []const u8,
    ) ?ActionRef {
        if (self.findDigital(map, action_name)) |id| return .{ .digital = id };
        if (self.findAxis1(map, action_name)) |id| return .{ .axis1 = id };
        if (self.findAxis2(map, action_name)) |id| return .{ .axis2 = id };
        return null;
    }

    /// Returns the number of registered digital actions.
    pub fn digitalCount(self: *const ActionRegistry) usize {
        return self.digital_count;
    }

    /// Returns the number of registered 1D axis actions.
    pub fn axis1Count(self: *const ActionRegistry) usize {
        return self.axis1_count;
    }

    /// Returns the number of registered 2D axis actions.
    pub fn axis2Count(self: *const ActionRegistry) usize {
        return self.axis2_count;
    }

    /// Validates that a map handle points to a registered map.
    fn ensureMapExists(self: *const ActionRegistry, map: ActionMapId) !void {
        if (!self.hasMap(map)) return Error.UnknownActionMap;
    }
};
