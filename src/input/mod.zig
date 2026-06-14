const std = @import("std");
const types = @import("types.zig");
const events_mod = @import("events.zig");
const state_mod = @import("state.zig");
const registry_mod = @import("registry.zig");
const context_mod = @import("context.zig");
const action_map_mod = @import("action_map.zig");

pub const Vector2 = types.Vector2;

pub const max_action_maps = types.max_action_maps;
pub const max_active_action_maps = types.max_active_action_maps;
pub const max_digital_actions = types.max_digital_actions;
pub const max_axis1_actions = types.max_axis1_actions;
pub const max_axis2_actions = types.max_axis2_actions;
pub const max_bindings = types.max_bindings;
pub const max_input_events = types.max_input_events;
pub const max_actions = types.max_actions;

pub const Error = types.Error;

pub const DigitalActionId = types.DigitalActionId;
pub const ActionId = types.ActionId;
pub const Axis1ActionId = types.Axis1ActionId;
pub const Axis2ActionId = types.Axis2ActionId;
pub const ActionMapId = types.ActionMapId;
pub const ActionKind = types.ActionKind;
pub const ActionRef = types.ActionRef;
pub const Key = types.Key;
pub const MouseButton = types.MouseButton;
pub const InputSourceKind = events_mod.InputSourceKind;
pub const InputSource = events_mod.InputSource;
pub const InputEventKind = events_mod.InputEventKind;
pub const DigitalActionEvent = events_mod.DigitalActionEvent;
pub const Axis1ActionEvent = events_mod.Axis1ActionEvent;
pub const Axis2ActionEvent = events_mod.Axis2ActionEvent;
pub const MouseMotionEvent = events_mod.MouseMotionEvent;
pub const MouseButtonEvent = events_mod.MouseButtonEvent;
pub const MouseWheelEvent = events_mod.MouseWheelEvent;
pub const InputEvent = events_mod.InputEvent;
pub const InputEventQueue = events_mod.InputEventQueue;
pub const DigitalState = state_mod.DigitalState;
pub const Axis1State = state_mod.Axis1State;
pub const Axis2State = state_mod.Axis2State;
pub const MouseButtonState = state_mod.MouseButtonState;
pub const MouseState = state_mod.MouseState;
pub const KeyState = state_mod.KeyState;
pub const ActionState = state_mod.ActionState;
pub const State = state_mod.State;
pub const NamedActionMap = registry_mod.NamedActionMap;
pub const NamedDigitalAction = registry_mod.NamedDigitalAction;
pub const NamedAxis1Action = registry_mod.NamedAxis1Action;
pub const NamedAxis2Action = registry_mod.NamedAxis2Action;
pub const ActionRegistry = registry_mod.ActionRegistry;
pub const ActiveMapOptions = context_mod.ActiveMapOptions;
pub const ActiveActionMap = context_mod.ActiveActionMap;
pub const InputContext = context_mod.InputContext;
pub const DigitalKeyBinding = action_map_mod.DigitalKeyBinding;
pub const Axis1KeyBinding = action_map_mod.Axis1KeyBinding;
pub const Axis2KeyBinding = action_map_mod.Axis2KeyBinding;
pub const Binding = action_map_mod.Binding;
pub const ActionMap = action_map_mod.ActionMap;
pub const InputMap = action_map_mod.InputMap;

/// Stores one action map with the registry handle that owns it.
pub const StoredActionMap = struct {
    id: ActionMapId,
    map: ActionMap,

    /// Creates a stored action map entry.
    pub fn init(id: ActionMapId, map: ActionMap) StoredActionMap {
        return .{
            .id = id,
            .map = map,
        };
    }

    /// Returns true when this entry belongs to the map.
    pub fn hasId(self: StoredActionMap, id: ActionMapId) bool {
        return self.id.eql(id);
    }
};

/// Bounded storage for action maps keyed by ActionMapId.
pub const ActionMapSet = struct {
    maps: [max_action_maps]StoredActionMap,
    map_count: usize,

    /// Creates an empty action map set.
    pub fn init() ActionMapSet {
        return .{
            .maps = undefined,
            .map_count = 0,
        };
    }

    /// Removes all stored maps.
    pub fn clear(self: *ActionMapSet) void {
        self.map_count = 0;
    }

    /// Returns the number of stored maps.
    pub fn count(self: *const ActionMapSet) usize {
        return self.map_count;
    }

    /// Returns true when no action maps are stored.
    pub fn isEmpty(self: *const ActionMapSet) bool {
        return self.map_count == 0;
    }

    /// Adds or replaces the action map for an id.
    pub fn put(self: *ActionMapSet, id: ActionMapId, map: ActionMap) !void {
        if (self.indexOf(id)) |index| {
            self.maps[index] = StoredActionMap.init(id, map);
            return;
        }

        if (self.map_count == max_action_maps) {
            return Error.InputMapSetFull;
        }

        self.maps[self.map_count] = StoredActionMap.init(id, map);
        self.map_count += 1;
    }

    /// Returns true when the set contains a map id.
    pub fn contains(self: *const ActionMapSet, id: ActionMapId) bool {
        return self.indexOf(id) != null;
    }

    /// Returns a mutable action map by id.
    pub fn get(self: *ActionMapSet, id: ActionMapId) ?*ActionMap {
        const index = self.indexOf(id) orelse return null;
        return &self.maps[index].map;
    }

    /// Returns a read-only action map by id.
    pub fn getConst(self: *const ActionMapSet, id: ActionMapId) ?*const ActionMap {
        const index = self.indexOf(id) orelse return null;
        return &self.maps[index].map;
    }

    /// Removes a map and returns true when it existed.
    pub fn remove(self: *ActionMapSet, id: ActionMapId) bool {
        const index = self.indexOf(id) orelse return false;

        var cursor = index;
        while (cursor + 1 < self.map_count) : (cursor += 1) {
            self.maps[cursor] = self.maps[cursor + 1];
        }

        self.map_count -= 1;
        return true;
    }

    /// Returns stored map entries.
    pub fn items(self: *const ActionMapSet) []const StoredActionMap {
        return self.maps[0..self.map_count];
    }

    /// Finds the array index for a map id.
    fn indexOf(self: *const ActionMapSet, id: ActionMapId) ?usize {
        var index: usize = 0;
        while (index < self.map_count) : (index += 1) {
            if (self.maps[index].hasId(id)) return index;
        }

        return null;
    }
};

/// Routes physical input through active action maps into an input state.
pub const InputRouter = struct {
    maps: ActionMapSet,
    context: InputContext,

    /// Creates an empty input router.
    pub fn init() InputRouter {
        return .{
            .maps = ActionMapSet.init(),
            .context = InputContext.init(),
        };
    }

    /// Removes all maps and active context entries.
    pub fn clear(self: *InputRouter) void {
        self.maps.clear();
        self.context.clear();
    }

    /// Adds or replaces a routable action map.
    pub fn putMap(self: *InputRouter, id: ActionMapId, map: ActionMap) !void {
        try self.maps.put(id, map);
    }

    /// Returns true when a map is installed.
    pub fn hasMap(self: *const InputRouter, id: ActionMapId) bool {
        return self.maps.contains(id);
    }

    /// Enables an installed map with default non-blocking options.
    pub fn pushMap(self: *InputRouter, id: ActionMapId) !void {
        try self.requireMap(id);
        try self.context.pushMap(id);
    }

    /// Enables an installed map with explicit options.
    pub fn pushMapOptions(
        self: *InputRouter,
        id: ActionMapId,
        options: ActiveMapOptions,
    ) !void {
        try self.requireMap(id);
        try self.context.pushMapOptions(id, options);
    }

    /// Disables an active map and returns true when it was active.
    pub fn popMap(self: *InputRouter, id: ActionMapId) bool {
        return self.context.popMap(id);
    }

    /// Returns the active input context.
    pub fn activeContext(self: *const InputRouter) *const InputContext {
        return &self.context;
    }

    /// Returns mutable access to the active input context.
    pub fn activeContextMut(self: *InputRouter) *InputContext {
        return &self.context;
    }

    /// Applies a key event through every processable active map.
    pub fn applyKey(
        self: *const InputRouter,
        state: *State,
        key: Key,
        down: bool,
        repeated: bool,
    ) !void {
        if (repeated) return;

        state.setKey(key, down);

        for (self.context.processedItems()) |active| {
            const map = self.maps.getConst(active.map) orelse return Error.UnknownActionMap;
            map.syncKey(state, key);
        }
    }

    /// Applies a key event through active maps and records input events.
    pub fn applyKeyWithEvents(
        self: *const InputRouter,
        state: *State,
        input_event_queue: *InputEventQueue,
        key: Key,
        down: bool,
        repeated: bool,
    ) !void {
        if (repeated) return;

        state.setKey(key, down);

        const source = InputSource.keyboard(key);
        for (self.context.processedItems()) |active| {
            const map = self.maps.getConst(active.map) orelse return Error.UnknownActionMap;
            map.syncKeyWithEvents(state, input_event_queue, active.map, source, key);
        }
    }

    /// Applies a key event to raw state and all installed maps, ignoring context.
    pub fn applyKeyToAllMaps(
        self: *const InputRouter,
        state: *State,
        key: Key,
        down: bool,
        repeated: bool,
    ) void {
        if (repeated) return;

        state.setKey(key, down);

        for (self.maps.items()) |entry| {
            entry.map.syncKey(state, key);
        }
    }

    /// Ensures a map exists before it is activated.
    fn requireMap(self: *const InputRouter, id: ActionMapId) !void {
        if (!self.maps.contains(id)) return Error.UnknownActionMap;
    }
};
