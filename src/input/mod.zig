const std = @import("std");
const types = @import("types.zig");
const events_mod = @import("events.zig");
const state_mod = @import("state.zig");
const registry_mod = @import("registry.zig");

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

/// Options used when enabling an action map in an input context.
pub const ActiveMapOptions = struct {
    priority: i16 = 0,
    blocking: bool = false,

    /// Creates default non-blocking map options.
    pub fn normal() ActiveMapOptions {
        return .{};
    }

    /// Creates blocking map options for modal UI-like input.
    pub fn modal(priority: i16) ActiveMapOptions {
        return .{
            .priority = priority,
            .blocking = true,
        };
    }
};

/// One active action map entry inside an input context.
pub const ActiveActionMap = struct {
    map: ActionMapId,
    priority: i16,
    blocking: bool,
    order: usize,

    /// Creates an active map entry.
    pub fn init(map: ActionMapId, options: ActiveMapOptions, order: usize) ActiveActionMap {
        return .{
            .map = map,
            .priority = options.priority,
            .blocking = options.blocking,
            .order = order,
        };
    }

    /// Returns true when this entry refers to the map.
    pub fn hasMap(self: ActiveActionMap, map: ActionMapId) bool {
        return self.map.eql(map);
    }
};

/// Runtime input context that controls which action maps are active.
pub const InputContext = struct {
    active_maps: [max_active_action_maps]ActiveActionMap,
    active_map_count: usize,
    next_order: usize,

    /// Creates an empty input context.
    pub fn init() InputContext {
        return .{
            .active_maps = undefined,
            .active_map_count = 0,
            .next_order = 0,
        };
    }

    /// Removes all active maps.
    pub fn clear(self: *InputContext) void {
        self.active_map_count = 0;
        self.next_order = 0;
    }

    /// Returns the number of active maps.
    pub fn count(self: *const InputContext) usize {
        return self.active_map_count;
    }

    /// Returns true when no maps are active.
    pub fn isEmpty(self: *const InputContext) bool {
        return self.active_map_count == 0;
    }

    /// Enables a map with default non-blocking options.
    pub fn pushMap(self: *InputContext, map: ActionMapId) !void {
        try self.pushMapOptions(map, .{});
    }

    /// Enables a map with explicit priority and blocking options.
    pub fn pushMapOptions(
        self: *InputContext,
        map: ActionMapId,
        options: ActiveMapOptions,
    ) !void {
        if (self.indexOfMap(map)) |existing_index| {
            self.active_maps[existing_index] = ActiveActionMap.init(
                map,
                options,
                self.claimOrder(),
            );
            self.sortActiveMaps();
            return;
        }

        if (self.active_map_count == max_active_action_maps) {
            return Error.InputContextFull;
        }

        self.active_maps[self.active_map_count] = ActiveActionMap.init(
            map,
            options,
            self.claimOrder(),
        );
        self.active_map_count += 1;
        self.sortActiveMaps();
    }

    /// Disables a map and returns true when it was active.
    pub fn popMap(self: *InputContext, map: ActionMapId) bool {
        const index = self.indexOfMap(map) orelse return false;

        var cursor = index;
        while (cursor + 1 < self.active_map_count) : (cursor += 1) {
            self.active_maps[cursor] = self.active_maps[cursor + 1];
        }

        self.active_map_count -= 1;
        return true;
    }

    /// Returns true when a map is active.
    pub fn containsMap(self: *const InputContext, map: ActionMapId) bool {
        return self.indexOfMap(map) != null;
    }

    /// Returns the active entry for a map.
    pub fn findMap(self: *const InputContext, map: ActionMapId) ?ActiveActionMap {
        const index = self.indexOfMap(map) orelse return null;
        return self.active_maps[index];
    }

    /// Returns active maps ordered by priority and activation order.
    pub fn items(self: *const InputContext) []const ActiveActionMap {
        return self.active_maps[0..self.active_map_count];
    }

    /// Returns the highest-priority active map.
    pub fn top(self: *const InputContext) ?ActiveActionMap {
        if (self.active_map_count == 0) return null;
        return self.active_maps[0];
    }

    /// Returns the active maps that should be processed before blocking stops traversal.
    pub fn processedItems(self: *const InputContext) []const ActiveActionMap {
        return self.active_maps[0..self.processedCount()];
    }

    /// Returns true when this map is active and not hidden behind a higher map.
    pub fn canProcessMap(self: *const InputContext, map: ActionMapId) bool {
        for (self.processedItems()) |entry| {
            if (entry.hasMap(map)) return true;
        }

        return false;
    }

    /// Returns the number of maps visible to input processing.
    fn processedCount(self: *const InputContext) usize {
        var total: usize = 0;

        for (self.items()) |entry| {
            total += 1;
            if (entry.blocking) break;
        }

        return total;
    }

    /// Returns the index of an active map.
    fn indexOfMap(self: *const InputContext, map: ActionMapId) ?usize {
        var index: usize = 0;
        while (index < self.active_map_count) : (index += 1) {
            if (self.active_maps[index].hasMap(map)) return index;
        }

        return null;
    }

    /// Returns the next activation order number.
    fn claimOrder(self: *InputContext) usize {
        const order = self.next_order;
        self.next_order += 1;
        return order;
    }

    /// Sorts maps so higher priority and newer equal-priority maps come first.
    fn sortActiveMaps(self: *InputContext) void {
        var index: usize = 1;
        while (index < self.active_map_count) : (index += 1) {
            const entry = self.active_maps[index];
            var cursor = index;

            while (cursor > 0 and activeMapComesBefore(entry, self.active_maps[cursor - 1])) {
                self.active_maps[cursor] = self.active_maps[cursor - 1];
                cursor -= 1;
            }

            self.active_maps[cursor] = entry;
        }
    }
};

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

/// Binds one key to one digital action.
pub const DigitalKeyBinding = struct {
    key: Key,
    action: DigitalActionId,

    /// Creates a digital key binding.
    pub fn init(key: Key, action: DigitalActionId) DigitalKeyBinding {
        std.debug.assert(key != .count);

        return .{
            .key = key,
            .action = action,
        };
    }

    /// Returns true when this binding depends on the key.
    pub fn matchesKey(self: DigitalKeyBinding, key: Key) bool {
        return self.key == key;
    }
};

/// Binds two keys to one 1D axis action.
pub const Axis1KeyBinding = struct {
    negative: Key,
    positive: Key,
    action: Axis1ActionId,

    /// Creates a keyboard binding for a 1D axis.
    pub fn init(negative: Key, positive: Key, action: Axis1ActionId) Axis1KeyBinding {
        std.debug.assert(negative != .count);
        std.debug.assert(positive != .count);
        std.debug.assert(negative != positive);

        return .{
            .negative = negative,
            .positive = positive,
            .action = action,
        };
    }

    /// Returns true when this binding depends on the key.
    pub fn matchesKey(self: Axis1KeyBinding, key: Key) bool {
        return self.negative == key or self.positive == key;
    }

    /// Resolves the current axis value from key state.
    pub fn valueFromState(self: Axis1KeyBinding, state: *const State) f32 {
        return @floatFromInt(
            boolToI32(state.isKeyDown(self.positive)) -
                boolToI32(state.isKeyDown(self.negative)),
        );
    }
};

/// Binds four keys to one 2D axis action.
pub const Axis2KeyBinding = struct {
    left: Key,
    right: Key,
    up: Key,
    down: Key,
    action: Axis2ActionId,

    /// Creates a keyboard binding for a 2D axis.
    pub fn init(
        left: Key,
        right: Key,
        up: Key,
        down: Key,
        action: Axis2ActionId,
    ) Axis2KeyBinding {
        std.debug.assert(left != .count);
        std.debug.assert(right != .count);
        std.debug.assert(up != .count);
        std.debug.assert(down != .count);
        std.debug.assert(left != right);
        std.debug.assert(up != down);

        return .{
            .left = left,
            .right = right,
            .up = up,
            .down = down,
            .action = action,
        };
    }

    /// Returns true when this binding depends on the key.
    pub fn matchesKey(self: Axis2KeyBinding, key: Key) bool {
        return self.left == key or
            self.right == key or
            self.up == key or
            self.down == key;
    }

    /// Resolves the current axis value from key state.
    pub fn valueFromState(self: Axis2KeyBinding, state: *const State) Vector2 {
        return Vector2.xy(
            @floatFromInt(boolToI32(state.isKeyDown(self.right)) -
                boolToI32(state.isKeyDown(self.left))),
            @floatFromInt(boolToI32(state.isKeyDown(self.down)) -
                boolToI32(state.isKeyDown(self.up))),
        );
    }
};

/// One typed input binding inside an action map.
pub const Binding = union(enum) {
    digital_key: DigitalKeyBinding,
    axis1_keys: Axis1KeyBinding,
    axis2_keys: Axis2KeyBinding,

    /// Returns true when this binding depends on the key.
    pub fn matchesKey(self: Binding, key: Key) bool {
        return switch (self) {
            .digital_key => |binding| binding.matchesKey(key),
            .axis1_keys => |binding| binding.matchesKey(key),
            .axis2_keys => |binding| binding.matchesKey(key),
        };
    }
};

/// Named-map-ready collection of typed input bindings.
pub const ActionMap = struct {
    bindings: [max_bindings]Binding,
    binding_count: usize,

    /// Creates an empty action map.
    pub fn init() ActionMap {
        return .{
            .bindings = undefined,
            .binding_count = 0,
        };
    }

    /// Adds one typed binding.
    pub fn pushBinding(self: *ActionMap, binding: Binding) !void {
        if (self.binding_count == max_bindings) {
            return Error.InputMapFull;
        }

        self.bindings[self.binding_count] = binding;
        self.binding_count += 1;
    }

    /// Binds one key to one digital action.
    pub fn bindDigitalKey(self: *ActionMap, key: Key, action: DigitalActionId) !void {
        try self.pushBinding(.{
            .digital_key = DigitalKeyBinding.init(key, action),
        });
    }

    /// Binds two keys to one 1D axis action.
    pub fn bindAxis1Keys(
        self: *ActionMap,
        negative: Key,
        positive: Key,
        action: Axis1ActionId,
    ) !void {
        try self.pushBinding(.{
            .axis1_keys = Axis1KeyBinding.init(negative, positive, action),
        });
    }

    /// Binds four keys to one 2D axis action.
    pub fn bindAxis2Keys(
        self: *ActionMap,
        left: Key,
        right: Key,
        up: Key,
        down: Key,
        action: Axis2ActionId,
    ) !void {
        try self.pushBinding(.{
            .axis2_keys = Axis2KeyBinding.init(left, right, up, down, action),
        });
    }

    /// Compatibility wrapper for the old digital-only input map API.
    pub fn bind(self: *ActionMap, key: Key, action: ActionId) !void {
        try self.bindDigitalKey(key, action);
    }

    /// Applies one key event and refreshes affected typed action values.
    pub fn applyKey(
        self: *const ActionMap,
        state: *State,
        key: Key,
        down: bool,
        repeated: bool,
    ) void {
        if (repeated) return;

        state.setKey(key, down);
        self.syncKey(state, key);
    }

    /// Refreshes action values affected by a key that is already stored in State.
    pub fn syncKey(self: *const ActionMap, state: *State, key: Key) void {
        for (self.items()) |binding| {
            if (!binding.matchesKey(key)) continue;
            self.syncBinding(state, binding);
        }
    }

    /// Refreshes action values affected by a key and emits frame-local events.
    pub fn syncKeyWithEvents(
        self: *const ActionMap,
        state: *State,
        input_event_queue: *InputEventQueue,
        map: ActionMapId,
        source: InputSource,
        key: Key,
    ) void {
        for (self.items()) |binding| {
            if (!binding.matchesKey(key)) continue;
            self.syncBindingWithEvents(state, input_event_queue, map, source, binding);
        }
    }

    /// Refreshes one binding and records any action value edge/change.
    fn syncBindingWithEvents(
        self: *const ActionMap,
        state: *State,
        input_event_queue: *InputEventQueue,
        map: ActionMapId,
        source: InputSource,
        binding: Binding,
    ) void {
        switch (binding) {
            .digital_key => |digital| self.syncDigitalActionWithEvents(
                state,
                input_event_queue,
                map,
                source,
                digital.action,
            ),
            .axis1_keys => |axis| self.syncAxis1ActionWithEvents(
                state,
                input_event_queue,
                map,
                source,
                axis.action,
            ),
            .axis2_keys => |axis| self.syncAxis2ActionWithEvents(
                state,
                input_event_queue,
                map,
                source,
                axis.action,
            ),
        }
    }

    /// Refreshes one digital action and emits press/release events.
    fn syncDigitalActionWithEvents(
        self: *const ActionMap,
        state: *State,
        input_event_queue: *InputEventQueue,
        map: ActionMapId,
        source: InputSource,
        action: DigitalActionId,
    ) void {
        const was_down = state.digitalDown(action);

        self.syncDigitalAction(state, action);

        const is_down = state.digitalDown(action);
        if (!was_down and is_down) {
            input_event_queue.pushActionPressed(map, action, source);
        } else if (was_down and !is_down) {
            input_event_queue.pushActionReleased(map, action, source);
        }
    }

    /// Refreshes one 1D axis action and emits a change event.
    fn syncAxis1ActionWithEvents(
        self: *const ActionMap,
        state: *State,
        input_event_queue: *InputEventQueue,
        map: ActionMapId,
        source: InputSource,
        action: Axis1ActionId,
    ) void {
        const previous = state.axis1(action);

        self.syncAxis1Action(state, action);

        const value = state.axis1(action);
        if (previous != value) {
            input_event_queue.pushAxis1Changed(map, action, previous, value, source);
        }
    }

    /// Refreshes one 2D axis action and emits a change event.
    fn syncAxis2ActionWithEvents(
        self: *const ActionMap,
        state: *State,
        input_event_queue: *InputEventQueue,
        map: ActionMapId,
        source: InputSource,
        action: Axis2ActionId,
    ) void {
        const previous = state.axis2(action);

        self.syncAxis2Action(state, action);

        const value = state.axis2(action);
        if (!vector2Eql(previous, value)) {
            input_event_queue.pushAxis2Changed(map, action, previous, value, source);
        }
    }

    /// Returns all bindings in this map.
    pub fn items(self: *const ActionMap) []const Binding {
        return self.bindings[0..self.binding_count];
    }

    /// Refreshes the action value affected by one binding.
    fn syncBinding(self: *const ActionMap, state: *State, binding: Binding) void {
        switch (binding) {
            .digital_key => |digital| self.syncDigitalAction(state, digital.action),
            .axis1_keys => |axis| self.syncAxis1Action(state, axis.action),
            .axis2_keys => |axis| self.syncAxis2Action(state, axis.action),
        }
    }

    /// Refreshes one digital action from every matching digital binding.
    fn syncDigitalAction(self: *const ActionMap, state: *State, action: DigitalActionId) void {
        var down = false;

        for (self.items()) |binding| {
            switch (binding) {
                .digital_key => |digital| {
                    if (digital.action.index != action.index) continue;
                    if (state.isKeyDown(digital.key)) {
                        down = true;
                        break;
                    }
                },
                else => {},
            }
        }

        state.setDigitalDown(action, down);
    }

    /// Refreshes one 1D axis action from every matching axis binding.
    fn syncAxis1Action(self: *const ActionMap, state: *State, action: Axis1ActionId) void {
        var value: f32 = 0.0;

        for (self.items()) |binding| {
            switch (binding) {
                .axis1_keys => |axis| {
                    if (axis.action.index != action.index) continue;
                    value += axis.valueFromState(state);
                },
                else => {},
            }
        }

        state.setAxis1(action, clampAxis1(value));
    }

    /// Refreshes one 2D axis action from every matching axis binding.
    fn syncAxis2Action(self: *const ActionMap, state: *State, action: Axis2ActionId) void {
        var value = Vector2.xy(0.0, 0.0);

        for (self.items()) |binding| {
            switch (binding) {
                .axis2_keys => |axis| {
                    if (axis.action.index != action.index) continue;

                    const axis_value = axis.valueFromState(state);
                    value = Vector2.xy(
                        value.x + axis_value.x,
                        value.y + axis_value.y,
                    );
                },
                else => {},
            }
        }

        state.setAxis2(action, clampAxis2(value));
    }
};

/// Compatibility alias while callers migrate from InputMap to ActionMap.
pub const InputMap = ActionMap;

fn activeMapComesBefore(lhs: ActiveActionMap, rhs: ActiveActionMap) bool {
    if (lhs.priority != rhs.priority) {
        return lhs.priority > rhs.priority;
    }

    return lhs.order > rhs.order;
}

fn boolToI32(value: bool) i32 {
    return if (value) 1 else 0;
}

fn clampAxis1(value: f32) f32 {
    if (value < -1.0) return -1.0;
    if (value > 1.0) return 1.0;
    return value;
}

fn clampAxis2(value: Vector2) Vector2 {
    return Vector2.xy(
        clampAxis1(value.x),
        clampAxis1(value.y),
    );
}

fn vector2Eql(lhs: Vector2, rhs: Vector2) bool {
    return lhs.x == rhs.x and lhs.y == rhs.y;
}
