//! Named action-map builder.
//!
//! This module bridges author-facing action names and runtime action maps.
//! The hot path still uses compact handles, while content/Luau-facing setup can
//! bind inputs through names resolved by ActionRegistry.
//!
//! Source-name helpers are setup-only sugar. They parse stable strings such as
//! "space" or "left" into engine enums, then reuse the enum-based binding path.

const types = @import("types.zig");
const registry_mod = @import("registry.zig");
const action_map_mod = @import("action_map.zig");
const router_mod = @import("router.zig");
const source_names_mod = @import("source_names.zig");

pub const Error = types.Error;
pub const Key = types.Key;
pub const MouseButton = types.MouseButton;

pub const ActionMapId = types.ActionMapId;
pub const DigitalActionId = types.DigitalActionId;
pub const Axis1ActionId = types.Axis1ActionId;
pub const Axis2ActionId = types.Axis2ActionId;

pub const ActionRegistry = registry_mod.ActionRegistry;
pub const ActionMap = action_map_mod.ActionMap;
pub const InputRouter = router_mod.InputRouter;

/// Builder for one named action map.
pub const ActionMapBuilder = struct {
    map: ActionMapId,
    action_map: ActionMap,

    /// Creates a builder for an already-resolved action map id.
    pub fn init(map: ActionMapId) ActionMapBuilder {
        return .{
            .map = map,
            .action_map = ActionMap.init(),
        };
    }

    /// Creates a builder by resolving an action map name.
    pub fn fromMapName(
        registry: *const ActionRegistry,
        map_name: []const u8,
    ) !ActionMapBuilder {
        return ActionMapBuilder.init(try requireMap(registry, map_name));
    }

    /// Returns the map id this builder targets.
    pub fn id(self: ActionMapBuilder) ActionMapId {
        return self.map;
    }

    /// Returns the built action map by value.
    pub fn build(self: ActionMapBuilder) ActionMap {
        return self.action_map;
    }

    /// Installs the built map into a router.
    pub fn install(self: ActionMapBuilder, router: *InputRouter) !void {
        try router.putMap(self.map, self.action_map);
    }

    /// Binds a keyboard key to a named digital action.
    pub fn bindDigitalKey(
        self: *ActionMapBuilder,
        registry: *const ActionRegistry,
        action_name: []const u8,
        key: Key,
    ) !void {
        const action = try self.requireDigital(registry, action_name);
        try self.action_map.bindDigitalKey(key, action);
    }

    /// Binds a mouse button to a named digital action.
    pub fn bindMouseButton(
        self: *ActionMapBuilder,
        registry: *const ActionRegistry,
        action_name: []const u8,
        button: MouseButton,
    ) !void {
        const action = try self.requireDigital(registry, action_name);
        try self.action_map.bindMouseButton(button, action);
    }

    /// Binds a keyboard key name to a named digital action.
    pub fn bindDigitalKeyName(
        self: *ActionMapBuilder,
        registry: *const ActionRegistry,
        action_name: []const u8,
        key_name: []const u8,
    ) !void {
        const key = try source_names_mod.parseKey(key_name);
        try self.bindDigitalKey(registry, action_name, key);
    }

    /// Binds a mouse button name to a named digital action.
    pub fn bindMouseButtonName(
        self: *ActionMapBuilder,
        registry: *const ActionRegistry,
        action_name: []const u8,
        button_name: []const u8,
    ) !void {
        const button = try source_names_mod.parseMouseButton(button_name);
        try self.bindMouseButton(registry, action_name, button);
    }

    /// Binds two keyboard key names to a named 1D axis action.
    pub fn bindAxis1KeyNames(
        self: *ActionMapBuilder,
        registry: *const ActionRegistry,
        action_name: []const u8,
        negative_name: []const u8,
        positive_name: []const u8,
    ) !void {
        const negative = try source_names_mod.parseKey(negative_name);
        const positive = try source_names_mod.parseKey(positive_name);

        try self.bindAxis1Keys(
            registry,
            action_name,
            negative,
            positive,
        );
    }

    /// Binds four keyboard key names to a named 2D axis action.
    pub fn bindAxis2KeyNames(
        self: *ActionMapBuilder,
        registry: *const ActionRegistry,
        action_name: []const u8,
        left_name: []const u8,
        right_name: []const u8,
        up_name: []const u8,
        down_name: []const u8,
    ) !void {
        const left = try source_names_mod.parseKey(left_name);
        const right = try source_names_mod.parseKey(right_name);
        const up = try source_names_mod.parseKey(up_name);
        const down = try source_names_mod.parseKey(down_name);

        try self.bindAxis2Keys(
            registry,
            action_name,
            left,
            right,
            up,
            down,
        );
    }

    /// Binds two keyboard keys to a named 1D axis action.
    pub fn bindAxis1Keys(
        self: *ActionMapBuilder,
        registry: *const ActionRegistry,
        action_name: []const u8,
        negative: Key,
        positive: Key,
    ) !void {
        const action = try self.requireAxis1(registry, action_name);
        try self.action_map.bindAxis1Keys(negative, positive, action);
    }

    /// Binds four keyboard keys to a named 2D axis action.
    pub fn bindAxis2Keys(
        self: *ActionMapBuilder,
        registry: *const ActionRegistry,
        action_name: []const u8,
        left: Key,
        right: Key,
        up: Key,
        down: Key,
    ) !void {
        const action = try self.requireAxis2(registry, action_name);
        try self.action_map.bindAxis2Keys(left, right, up, down, action);
    }

    /// Resolves a digital action in this builder's map.
    fn requireDigital(
        self: *const ActionMapBuilder,
        registry: *const ActionRegistry,
        action_name: []const u8,
    ) !DigitalActionId {
        return registry.findDigital(self.map, action_name) orelse Error.UnknownActionName;
    }

    /// Resolves a 1D axis action in this builder's map.
    fn requireAxis1(
        self: *const ActionMapBuilder,
        registry: *const ActionRegistry,
        action_name: []const u8,
    ) !Axis1ActionId {
        return registry.findAxis1(self.map, action_name) orelse Error.UnknownActionName;
    }

    /// Resolves a 2D axis action in this builder's map.
    fn requireAxis2(
        self: *const ActionMapBuilder,
        registry: *const ActionRegistry,
        action_name: []const u8,
    ) !Axis2ActionId {
        return registry.findAxis2(self.map, action_name) orelse Error.UnknownActionName;
    }
};

/// Resolves an action map name or returns an input setup error.
fn requireMap(registry: *const ActionRegistry, map_name: []const u8) !ActionMapId {
    return registry.findMap(map_name) orelse Error.UnknownActionMap;
}
