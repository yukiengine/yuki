//! Input routing.
//!
//! This module owns installed action maps and routes physical input through the
//! currently active input context into resolved input state and frame events.

const types = @import("types.zig");
const events = @import("events.zig");
const state_mod = @import("state.zig");
const context_mod = @import("context.zig");
const action_map_mod = @import("action_map.zig");

pub const Error = types.Error;
pub const max_action_maps = types.max_action_maps;
pub const Vector2 = types.Vector2;
pub const MouseButton = types.MouseButton;
pub const ActionMapId = types.ActionMapId;
pub const Key = types.Key;

pub const InputSource = events.InputSource;
pub const InputEventQueue = events.InputEventQueue;

pub const State = state_mod.State;

pub const ActiveMapOptions = context_mod.ActiveMapOptions;
pub const InputContext = context_mod.InputContext;

pub const ActionMap = action_map_mod.ActionMap;

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
            return Error.ActionMapSetFull;
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

    /// Returns the number of installed action maps.
    pub fn mapCount(self: *const InputRouter) usize {
        return self.maps.count();
    }

    /// Returns all installed action-map entries.
    pub fn installedMaps(self: *const InputRouter) []const StoredActionMap {
        return self.maps.items();
    }

    /// Returns a read-only installed action map by id.
    pub fn actionMap(self: *const InputRouter, id: ActionMapId) ?*const ActionMap {
        return self.maps.getConst(id);
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

    /// Applies a mouse button event through every processable active map.
    pub fn applyMouseButton(
        self: *const InputRouter,
        state: *State,
        button: MouseButton,
        down: bool,
        position: Vector2,
    ) !void {
        state.setMouseButton(button, down, position);

        for (self.context.processedItems()) |active| {
            const map = self.maps.getConst(active.map) orelse return Error.UnknownActionMap;
            map.syncMouseButton(state, button);
        }
    }

    /// Applies a mouse button event through active maps and records input events.
    pub fn applyMouseButtonWithEvents(
        self: *const InputRouter,
        state: *State,
        input_event_queue: *InputEventQueue,
        button: MouseButton,
        down: bool,
        position: Vector2,
    ) !void {
        state.setMouseButtonWithEvents(input_event_queue, button, down, position);

        const source = InputSource.mouseButton(button);
        for (self.context.processedItems()) |active| {
            const map = self.maps.getConst(active.map) orelse return Error.UnknownActionMap;
            map.syncMouseButtonWithEvents(
                state,
                input_event_queue,
                active.map,
                source,
                button,
            );
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

    /// Applies a mouse button event to raw state and all installed maps, ignoring context.
    pub fn applyMouseButtonToAllMaps(
        self: *const InputRouter,
        state: *State,
        button: MouseButton,
        down: bool,
        position: Vector2,
    ) void {
        state.setMouseButton(button, down, position);

        for (self.maps.items()) |entry| {
            entry.map.syncMouseButton(state, button);
        }
    }

    /// Ensures a map exists before it is activated.
    fn requireMap(self: *const InputRouter, id: ActionMapId) !void {
        if (!self.maps.contains(id)) return Error.UnknownActionMap;
    }
};
