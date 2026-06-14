//! Input session builder.
//!
//! InputSessionBuilder owns setup-time input registration and binding. It keeps
//! author-facing names in setup code, then builds a handle-based InputSession.

const std = @import("std");
const types = @import("types.zig");
const registry_mod = @import("registry.zig");
const context_mod = @import("context.zig");
const action_map_mod = @import("action_map.zig");
const session_mod = @import("session.zig");
const router_mod = @import("router.zig");

/// Runtime input router.
pub const InputRouter = router_mod.InputRouter;

/// Shared input error set.
pub const Error = types.Error;

/// Keyboard key enum used by bindings.
pub const Key = types.Key;

/// Mouse button enum used by bindings.
pub const MouseButton = types.MouseButton;

/// Maximum number of action maps in one input setup.
pub const max_action_maps = types.max_action_maps;

/// Maximum number of active action maps in one input setup.
pub const max_active_action_maps = types.max_active_action_maps;

/// Handle to an action map.
pub const ActionMapId = types.ActionMapId;

/// Handle to a digital action.
pub const DigitalActionId = types.DigitalActionId;

/// Handle to a one-dimensional axis action.
pub const Axis1ActionId = types.Axis1ActionId;

/// Handle to a two-dimensional axis action.
pub const Axis2ActionId = types.Axis2ActionId;

/// Named action registry.
pub const ActionRegistry = registry_mod.ActionRegistry;

/// Active action-map options.
pub const ActiveMapOptions = context_mod.ActiveMapOptions;

/// Runtime action map.
pub const ActionMap = action_map_mod.ActionMap;

/// Owned runtime input session.
pub const InputSession = session_mod.InputSession;

/// One action map being assembled by the session builder.
pub const SessionMapEntry = struct {
    id: ActionMapId,
    map: ActionMap,

    /// Creates a builder-owned map entry.
    pub fn init(id: ActionMapId) SessionMapEntry {
        return .{
            .id = id,
            .map = ActionMap.init(),
        };
    }
};

/// One action map activation requested for the built session.
pub const SessionActiveMap = struct {
    id: ActionMapId,
    options: ActiveMapOptions,

    /// Creates an active map request.
    pub fn init(id: ActionMapId, options: ActiveMapOptions) SessionActiveMap {
        return .{
            .id = id,
            .options = options,
        };
    }
};

/// Setup-time builder for named maps, actions, bindings, and active maps.
pub const InputSessionBuilder = struct {
    registry_data: ActionRegistry,
    maps: [max_action_maps]SessionMapEntry,
    map_count: usize,
    active_maps: [max_active_action_maps]SessionActiveMap,
    active_count: usize,

    /// Creates an empty input session builder.
    pub fn init() InputSessionBuilder {
        return .{
            .registry_data = ActionRegistry.init(),
            .maps = undefined,
            .map_count = 0,
            .active_maps = undefined,
            .active_count = 0,
        };
    }

    /// Returns the registry built so far.
    pub fn registry(self: *const InputSessionBuilder) *const ActionRegistry {
        return &self.registry_data;
    }

    /// Returns the number of action maps registered in this builder.
    pub fn mapCount(self: *const InputSessionBuilder) usize {
        return self.map_count;
    }

    /// Returns the number of maps that will be active in the built session.
    pub fn activeMapCount(self: *const InputSessionBuilder) usize {
        return self.active_count;
    }

    /// Adds a named action map.
    pub fn addMap(self: *InputSessionBuilder, map_name: []const u8) !ActionMapId {
        const id = try self.registry_data.addMap(map_name);

        std.debug.assert(self.map_count < max_action_maps);
        self.maps[self.map_count] = SessionMapEntry.init(id);
        self.map_count += 1;

        return id;
    }

    /// Adds a named digital action to a map.
    pub fn addDigital(
        self: *InputSessionBuilder,
        map_name: []const u8,
        action_name: []const u8,
    ) !DigitalActionId {
        const map = try self.requireMap(map_name);
        return self.registry_data.addDigital(map, action_name);
    }

    /// Adds a named 1D axis action to a map.
    pub fn addAxis1(
        self: *InputSessionBuilder,
        map_name: []const u8,
        action_name: []const u8,
    ) !Axis1ActionId {
        const map = try self.requireMap(map_name);
        return self.registry_data.addAxis1(map, action_name);
    }

    /// Adds a named 2D axis action to a map.
    pub fn addAxis2(
        self: *InputSessionBuilder,
        map_name: []const u8,
        action_name: []const u8,
    ) !Axis2ActionId {
        const map = try self.requireMap(map_name);
        return self.registry_data.addAxis2(map, action_name);
    }

    /// Binds one key to a named digital action.
    pub fn bindDigitalKey(
        self: *InputSessionBuilder,
        map_name: []const u8,
        action_name: []const u8,
        key: Key,
    ) !void {
        const map_index = try self.requireMapIndex(map_name);
        const map = self.maps[map_index].id;
        const action = self.registry_data.findDigital(map, action_name) orelse {
            return Error.UnknownActionName;
        };

        try self.maps[map_index].map.bindDigitalKey(key, action);
    }

    /// Binds one mouse button to a named digital action.
    pub fn bindMouseButton(
        self: *InputSessionBuilder,
        map_name: []const u8,
        action_name: []const u8,
        button: MouseButton,
    ) !void {
        const map_index = try self.requireMapIndex(map_name);
        const map = self.maps[map_index].id;
        const action = self.registry_data.findDigital(map, action_name) orelse {
            return Error.UnknownActionName;
        };

        try self.maps[map_index].map.bindMouseButton(button, action);
    }

    /// Binds two keys to a named 1D axis action.
    pub fn bindAxis1Keys(
        self: *InputSessionBuilder,
        map_name: []const u8,
        action_name: []const u8,
        negative: Key,
        positive: Key,
    ) !void {
        const map_index = try self.requireMapIndex(map_name);
        const map = self.maps[map_index].id;
        const action = self.registry_data.findAxis1(map, action_name) orelse {
            return Error.UnknownActionName;
        };

        try self.maps[map_index].map.bindAxis1Keys(negative, positive, action);
    }

    /// Binds four keys to a named 2D axis action.
    pub fn bindAxis2Keys(
        self: *InputSessionBuilder,
        map_name: []const u8,
        action_name: []const u8,
        left: Key,
        right: Key,
        up: Key,
        down: Key,
    ) !void {
        const map_index = try self.requireMapIndex(map_name);
        const map = self.maps[map_index].id;
        const action = self.registry_data.findAxis2(map, action_name) orelse {
            return Error.UnknownActionName;
        };

        try self.maps[map_index].map.bindAxis2Keys(left, right, up, down, action);
    }

    /// Marks a map as active with default non-blocking options.
    pub fn activateMap(self: *InputSessionBuilder, map_name: []const u8) !void {
        try self.activateMapOptions(map_name, .{});
    }

    /// Marks a map as active with explicit options.
    pub fn activateMapOptions(
        self: *InputSessionBuilder,
        map_name: []const u8,
        options: ActiveMapOptions,
    ) !void {
        const map = try self.requireMap(map_name);

        if (self.active_count == max_active_action_maps) {
            return Error.InputContextFull;
        }

        self.active_maps[self.active_count] = SessionActiveMap.init(map, options);
        self.active_count += 1;
    }

    /// Returns a copy of the registry built so far.
    pub fn buildRegistry(self: *const InputSessionBuilder) ActionRegistry {
        return self.registry_data;
    }

    /// Returns a copy of one action map by id.
    pub fn actionMap(self: *const InputSessionBuilder, map: ActionMapId) ?ActionMap {
        const map_index = self.indexOfMap(map) orelse return null;
        return self.maps[map_index].map;
    }

    /// Returns a copy of one action map by name.
    pub fn actionMapByName(self: *const InputSessionBuilder, map_name: []const u8) !ActionMap {
        const map = try self.requireMap(map_name);
        return self.actionMap(map) orelse Error.UnknownActionMap;
    }

    /// Builds an input router from registered maps and active map requests.
    pub fn buildRouter(self: *const InputSessionBuilder) !InputRouter {
        var router = InputRouter.init();

        var map_index: usize = 0;
        while (map_index < self.map_count) : (map_index += 1) {
            const entry = self.maps[map_index];
            try router.putMap(entry.id, entry.map);
        }

        var active_index: usize = 0;
        while (active_index < self.active_count) : (active_index += 1) {
            const active = self.active_maps[active_index];
            try router.pushMapOptions(active.id, active.options);
        }

        return router;
    }

    /// Builds an owned input session from registered maps and active map requests.
    pub fn build(self: *const InputSessionBuilder) !InputSession {
        return InputSession.init(
            self.registry_data,
            try self.buildRouter(),
        );
    }

    /// Finds the local builder map index for a map handle.
    fn indexOfMap(self: *const InputSessionBuilder, map: ActionMapId) ?usize {
        var index: usize = 0;
        while (index < self.map_count) : (index += 1) {
            if (self.maps[index].id.eql(map)) return index;
        }

        return null;
    }
    /// Resolves a map name into a handle.
    fn requireMap(self: *const InputSessionBuilder, map_name: []const u8) !ActionMapId {
        return self.registry_data.findMap(map_name) orelse Error.UnknownActionMap;
    }

    /// Resolves a map name into the local builder map index.
    fn requireMapIndex(self: *const InputSessionBuilder, map_name: []const u8) !usize {
        const map = try self.requireMap(map_name);
        return self.indexOfMap(map) orelse Error.UnknownActionMap;
    }
};
