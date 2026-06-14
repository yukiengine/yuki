const std = @import("std");
const render_types = @import("render2d/types.zig");

/// Shared 2D vector type used for pointer positions and deltas.
pub const Vector2 = render_types.Vector2;

pub const max_action_maps = 16;
pub const max_active_action_maps = max_action_maps;
pub const max_digital_actions = 64;
pub const max_axis1_actions = 32;
pub const max_axis2_actions = 32;
pub const max_bindings = 64;
pub const max_input_events = 128;

/// Backwards-compatible alias while the input API migrates from generic actions.
pub const max_actions = max_digital_actions;

pub const Error = error{
    InputMapFull,
    InputMapSetFull,
    InputContextFull,
    ActionMapRegistryFull,
    DigitalActionRegistryFull,
    Axis1ActionRegistryFull,
    Axis2ActionRegistryFull,
    DuplicateActionMapName,
    DuplicateActionName,
    UnknownActionMap,
};

/// Handle to a digital action with bool/down/pressed/released state.
pub const DigitalActionId = extern struct {
    index: u16,

    /// Creates a digital action handle from a compact runtime index.
    pub fn fromIndex(index: u16) DigitalActionId {
        std.debug.assert(index < max_digital_actions);
        return .{ .index = index };
    }
};

/// Temporary compatibility alias for the old API.
pub const ActionId = DigitalActionId;

/// Handle to a one-dimensional action value.
pub const Axis1ActionId = extern struct {
    index: u16,

    /// Creates a 1D axis action handle from a compact runtime index.
    pub fn fromIndex(index: u16) Axis1ActionId {
        std.debug.assert(index < max_axis1_actions);
        return .{ .index = index };
    }
};

/// Handle to a two-dimensional action value.
pub const Axis2ActionId = extern struct {
    index: u16,

    /// Creates a 2D axis action handle from a compact runtime index.
    pub fn fromIndex(index: u16) Axis2ActionId {
        std.debug.assert(index < max_axis2_actions);
        return .{ .index = index };
    }
};

/// Handle to a named action map registered by game content.
pub const ActionMapId = extern struct {
    index: u16,

    /// Creates an action map handle from a compact runtime index.
    pub fn fromIndex(index: u16) ActionMapId {
        std.debug.assert(index < max_action_maps);
        return .{ .index = index };
    }

    /// Returns true when two map handles refer to the same map slot.
    pub fn eql(self: ActionMapId, other: ActionMapId) bool {
        return self.index == other.index;
    }
};

/// Kind tag for a registered action value.
pub const ActionKind = enum(u8) {
    digital,
    axis1,
    axis2,
};

/// Type-safe reference to any registered action handle.
pub const ActionRef = union(ActionKind) {
    digital: DigitalActionId,
    axis1: Axis1ActionId,
    axis2: Axis2ActionId,

    /// Returns the value kind carried by this action reference.
    pub fn kind(self: ActionRef) ActionKind {
        return switch (self) {
            .digital => .digital,
            .axis1 => .axis1,
            .axis2 => .axis2,
        };
    }
};

/// Kind of physical source that produced an input event.
pub const InputSourceKind = enum(u8) {
    keyboard,
    mouse,
    gamepad,
};

/// Backend-neutral source metadata for an input event.
pub const InputSource = struct {
    kind: InputSourceKind,
    key: ?Key = null,
    mouse_button: ?MouseButton = null,
    gamepad_index: u8 = 0,

    /// Creates a keyboard input source.
    pub fn keyboard(key: Key) InputSource {
        return .{
            .kind = .keyboard,
            .key = key,
        };
    }

    /// Creates a mouse button input source.
    pub fn mouseButton(button: MouseButton) InputSource {
        return .{
            .kind = .mouse,
            .mouse_button = button,
        };
    }

    /// Creates a gamepad input source placeholder.
    pub fn gamepad(index: u8) InputSource {
        return .{
            .kind = .gamepad,
            .gamepad_index = index,
        };
    }
};

/// Event tags emitted by the input system during one frame.
pub const InputEventKind = enum(u8) {
    action_pressed,
    action_released,
    axis1_changed,
    axis2_changed,
    mouse_moved,
    mouse_button_pressed,
    mouse_button_released,
    mouse_scrolled,
};

/// Payload for digital action input events.
pub const DigitalActionEvent = struct {
    map: ActionMapId,
    action: DigitalActionId,
    source: InputSource,
};

/// Payload for one-dimensional axis input events.
pub const Axis1ActionEvent = struct {
    map: ActionMapId,
    action: Axis1ActionId,
    value: f32,
    previous: f32,
    source: InputSource,
};

/// Payload for two-dimensional axis input events.
pub const Axis2ActionEvent = struct {
    map: ActionMapId,
    action: Axis2ActionId,
    value: Vector2,
    previous: Vector2,
    source: InputSource,
};

/// Payload for mouse motion input events.
pub const MouseMotionEvent = struct {
    position: Vector2,
    delta: Vector2,
};

/// Payload for mouse button input events.
pub const MouseButtonEvent = struct {
    button: MouseButton,
    position: Vector2,
    source: InputSource,
};

/// Payload for mouse wheel input events.
pub const MouseWheelEvent = struct {
    wheel: Vector2,
    position: Vector2,
};

/// One frame-local input event.
pub const InputEvent = union(InputEventKind) {
    action_pressed: DigitalActionEvent,
    action_released: DigitalActionEvent,
    axis1_changed: Axis1ActionEvent,
    axis2_changed: Axis2ActionEvent,
    mouse_moved: MouseMotionEvent,
    mouse_button_pressed: MouseButtonEvent,
    mouse_button_released: MouseButtonEvent,
    mouse_scrolled: MouseWheelEvent,

    /// Returns the tag for this event.
    pub fn kind(self: InputEvent) InputEventKind {
        return switch (self) {
            .action_pressed => .action_pressed,
            .action_released => .action_released,
            .axis1_changed => .axis1_changed,
            .axis2_changed => .axis2_changed,
            .mouse_moved => .mouse_moved,
            .mouse_button_pressed => .mouse_button_pressed,
            .mouse_button_released => .mouse_button_released,
            .mouse_scrolled => .mouse_scrolled,
        };
    }
};

/// Fixed-capacity frame-local queue of input events.
pub const InputEventQueue = struct {
    events: [max_input_events]InputEvent,
    event_count: usize,
    dropped_count: usize,

    /// Creates an empty input event queue.
    pub fn init() InputEventQueue {
        return .{
            .events = undefined,
            .event_count = 0,
            .dropped_count = 0,
        };
    }

    /// Clears events from the previous frame.
    pub fn beginFrame(self: *InputEventQueue) void {
        self.event_count = 0;
        self.dropped_count = 0;
    }

    /// Returns true when the queue has no events.
    pub fn isEmpty(self: *const InputEventQueue) bool {
        return self.event_count == 0;
    }

    /// Returns the number of stored events.
    pub fn count(self: *const InputEventQueue) usize {
        return self.event_count;
    }

    /// Returns the number of events dropped because the queue was full.
    pub fn droppedCount(self: *const InputEventQueue) usize {
        return self.dropped_count;
    }

    /// Returns all events stored for the current frame.
    pub fn items(self: *const InputEventQueue) []const InputEvent {
        return self.events[0..self.event_count];
    }

    /// Appends one event, dropping it if the queue is full.
    pub fn push(self: *InputEventQueue, event: InputEvent) void {
        if (self.event_count == max_input_events) {
            self.dropped_count += 1;
            return;
        }

        self.events[self.event_count] = event;
        self.event_count += 1;
    }

    /// Records a digital action press.
    pub fn pushActionPressed(
        self: *InputEventQueue,
        map: ActionMapId,
        action: DigitalActionId,
        source: InputSource,
    ) void {
        self.push(.{
            .action_pressed = .{
                .map = map,
                .action = action,
                .source = source,
            },
        });
    }

    /// Records a digital action release.
    pub fn pushActionReleased(
        self: *InputEventQueue,
        map: ActionMapId,
        action: DigitalActionId,
        source: InputSource,
    ) void {
        self.push(.{
            .action_released = .{
                .map = map,
                .action = action,
                .source = source,
            },
        });
    }

    /// Records a 1D axis value change.
    pub fn pushAxis1Changed(
        self: *InputEventQueue,
        map: ActionMapId,
        action: Axis1ActionId,
        previous: f32,
        value: f32,
        source: InputSource,
    ) void {
        self.push(.{
            .axis1_changed = .{
                .map = map,
                .action = action,
                .previous = previous,
                .value = value,
                .source = source,
            },
        });
    }

    /// Records a 2D axis value change.
    pub fn pushAxis2Changed(
        self: *InputEventQueue,
        map: ActionMapId,
        action: Axis2ActionId,
        previous: Vector2,
        value: Vector2,
        source: InputSource,
    ) void {
        self.push(.{
            .axis2_changed = .{
                .map = map,
                .action = action,
                .previous = previous,
                .value = value,
                .source = source,
            },
        });
    }

    /// Records mouse movement.
    pub fn pushMouseMoved(self: *InputEventQueue, position: Vector2, delta: Vector2) void {
        self.push(.{
            .mouse_moved = .{
                .position = position,
                .delta = delta,
            },
        });
    }

    /// Records a mouse button press.
    pub fn pushMouseButtonPressed(
        self: *InputEventQueue,
        button: MouseButton,
        position: Vector2,
    ) void {
        self.push(.{
            .mouse_button_pressed = .{
                .button = button,
                .position = position,
                .source = InputSource.mouseButton(button),
            },
        });
    }

    /// Records a mouse button release.
    pub fn pushMouseButtonReleased(
        self: *InputEventQueue,
        button: MouseButton,
        position: Vector2,
    ) void {
        self.push(.{
            .mouse_button_released = .{
                .button = button,
                .position = position,
                .source = InputSource.mouseButton(button),
            },
        });
    }

    /// Records mouse wheel movement.
    pub fn pushMouseScrolled(self: *InputEventQueue, wheel: Vector2, position: Vector2) void {
        self.push(.{
            .mouse_scrolled = .{
                .wheel = wheel,
                .position = position,
            },
        });
    }
};

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
    pub fn addDigital(self: *ActionRegistry, map: ActionMapId, action_name: []const u8) !DigitalActionId {
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
    pub fn addAxis1(self: *ActionRegistry, map: ActionMapId, action_name: []const u8) !Axis1ActionId {
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
    pub fn addAxis2(self: *ActionRegistry, map: ActionMapId, action_name: []const u8) !Axis2ActionId {
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
    pub fn findDigital(self: *const ActionRegistry, map: ActionMapId, action_name: []const u8) ?DigitalActionId {
        var index: usize = 0;
        while (index < self.digital_count) : (index += 1) {
            const item = self.digital_actions[index];
            if (!item.map.eql(map)) continue;
            if (std.mem.eql(u8, item.name, action_name)) return item.id;
        }

        return null;
    }

    /// Finds a 1D axis action by map and name.
    pub fn findAxis1(self: *const ActionRegistry, map: ActionMapId, action_name: []const u8) ?Axis1ActionId {
        var index: usize = 0;
        while (index < self.axis1_count) : (index += 1) {
            const item = self.axis1_actions[index];
            if (!item.map.eql(map)) continue;
            if (std.mem.eql(u8, item.name, action_name)) return item.id;
        }

        return null;
    }

    /// Finds a 2D axis action by map and name.
    pub fn findAxis2(self: *const ActionRegistry, map: ActionMapId, action_name: []const u8) ?Axis2ActionId {
        var index: usize = 0;
        while (index < self.axis2_count) : (index += 1) {
            const item = self.axis2_actions[index];
            if (!item.map.eql(map)) continue;
            if (std.mem.eql(u8, item.name, action_name)) return item.id;
        }

        return null;
    }

    /// Finds any typed action by map and name.
    pub fn findAction(self: *const ActionRegistry, map: ActionMapId, action_name: []const u8) ?ActionRef {
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
        events: *InputEventQueue,
        key: Key,
        down: bool,
        repeated: bool,
    ) !void {
        if (repeated) return;

        state.setKey(key, down);

        const source = InputSource.keyboard(key);
        for (self.context.processedItems()) |active| {
            const map = self.maps.getConst(active.map) orelse return Error.UnknownActionMap;
            map.syncKeyWithEvents(state, events, active.map, source, key);
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

pub const Key = enum(u8) {
    escape,
    space,
    r,

    a,
    d,
    w,
    s,

    q,
    e,

    left,
    right,
    up,
    down,

    f1,
    count,
};

/// Mouse buttons tracked by the input state.
pub const MouseButton = enum(u8) {
    left,
    middle,
    right,
    x1,
    x2,
    count,
};

const mouse_button_count: usize = @intFromEnum(MouseButton.count);

const key_count: usize = @intFromEnum(Key.count);

const DigitalState = struct {
    down: bool = false,
    pressed: bool = false,
    released: bool = false,

    pub fn beginFrame(self: *DigitalState) void {
        self.pressed = false;
        self.released = false;
    }

    pub fn setDown(self: *DigitalState, down: bool) void {
        if (self.down == down) return;

        self.down = down;

        if (down) {
            self.pressed = true;
        } else {
            self.released = true;
        }
    }

    pub fn forceRelease(self: *DigitalState) void {
        const was_down = self.down;

        self.down = false;
        self.pressed = false;
        self.released = was_down;
    }
};

/// Frame-aware state for one f32 input axis.
pub const Axis1State = struct {
    value: f32 = 0.0,
    previous: f32 = 0.0,
    changed: bool = false,

    /// Clears the one-frame changed edge and stores the current value as previous.
    pub fn beginFrame(self: *Axis1State) void {
        self.previous = self.value;
        self.changed = false;
    }

    /// Sets the axis value and records whether it changed this frame.
    pub fn setValue(self: *Axis1State, value: f32) void {
        if (self.value == value) return;

        self.value = value;
        self.changed = true;
    }

    /// Resets the axis to neutral.
    pub fn forceNeutral(self: *Axis1State) void {
        self.setValue(0.0);
    }
};

/// Frame-aware state for one Vector2 input axis.
pub const Axis2State = struct {
    value: Vector2 = Vector2.xy(0.0, 0.0),
    previous: Vector2 = Vector2.xy(0.0, 0.0),
    changed: bool = false,

    /// Clears the one-frame changed edge and stores the current value as previous.
    pub fn beginFrame(self: *Axis2State) void {
        self.previous = self.value;
        self.changed = false;
    }

    /// Sets the axis value and records whether it changed this frame.
    pub fn setValue(self: *Axis2State, value: Vector2) void {
        if (vector2Eql(self.value, value)) return;

        self.value = value;
        self.changed = true;
    }

    /// Resets the axis to neutral.
    pub fn forceNeutral(self: *Axis2State) void {
        self.setValue(Vector2.xy(0.0, 0.0));
    }
};

/// Digital state for one mouse button.
pub const MouseButtonState = DigitalState;

/// Mouse pointer state for the current frame.
pub const MouseState = struct {
    position: Vector2 = Vector2.xy(0.0, 0.0),
    delta: Vector2 = Vector2.xy(0.0, 0.0),
    wheel: Vector2 = Vector2.xy(0.0, 0.0),
    buttons: [mouse_button_count]MouseButtonState,
    inside_window: bool = false,

    /// Creates an empty mouse state.
    pub fn init() MouseState {
        return .{
            .buttons = [_]MouseButtonState{.{}} ** mouse_button_count,
        };
    }

    /// Clears frame-local mouse edges, movement, and wheel deltas.
    pub fn beginFrame(self: *MouseState) void {
        self.delta = Vector2.xy(0.0, 0.0);
        self.wheel = Vector2.xy(0.0, 0.0);

        for (&self.buttons) |*button| {
            button.beginFrame();
        }
    }

    /// Releases all mouse buttons and marks the pointer outside the window.
    pub fn releaseAll(self: *MouseState) void {
        for (&self.buttons) |*button| {
            button.forceRelease();
        }

        self.delta = Vector2.xy(0.0, 0.0);
        self.wheel = Vector2.xy(0.0, 0.0);
        self.inside_window = false;
    }

    /// Moves the mouse pointer to a new screen-space position.
    pub fn moveTo(self: *MouseState, position: Vector2) void {
        const previous = self.position;

        self.position = position;
        self.delta = Vector2.xy(
            self.delta.x + position.x - previous.x,
            self.delta.y + position.y - previous.y,
        );
        self.inside_window = true;
    }

    /// Adds a mouse wheel delta at the given pointer position.
    pub fn scrollBy(self: *MouseState, delta: Vector2, position: Vector2) void {
        self.moveTo(position);
        self.wheel = Vector2.xy(
            self.wheel.x + delta.x,
            self.wheel.y + delta.y,
        );
    }

    /// Sets one mouse button and updates pointer position.
    pub fn setButton(self: *MouseState, button: MouseButton, down: bool, position: Vector2) void {
        self.moveTo(position);
        self.buttonState(button).setDown(down);
    }

    /// Returns true while a mouse button is held.
    pub fn isButtonDown(self: *const MouseState, button: MouseButton) bool {
        return self.buttonStateConst(button).down;
    }

    /// Returns true only on the frame a mouse button was pressed.
    pub fn wasButtonPressed(self: *const MouseState, button: MouseButton) bool {
        return self.buttonStateConst(button).pressed;
    }

    /// Returns true only on the frame a mouse button was released.
    pub fn wasButtonReleased(self: *const MouseState, button: MouseButton) bool {
        return self.buttonStateConst(button).released;
    }

    /// Returns mutable state for a mouse button.
    fn buttonState(self: *MouseState, button: MouseButton) *MouseButtonState {
        return &self.buttons[mouseButtonIndex(button)];
    }

    /// Returns readonly state for a mouse button.
    fn buttonStateConst(self: *const MouseState, button: MouseButton) MouseButtonState {
        return self.buttons[mouseButtonIndex(button)];
    }
};

pub const KeyState = DigitalState;
pub const ActionState = DigitalState;

pub const State = struct {
    keys: [key_count]KeyState,
    actions: [max_digital_actions]ActionState,
    axis1_actions: [max_axis1_actions]Axis1State,
    axis2_actions: [max_axis2_actions]Axis2State,
    mouse: MouseState,

    /// Creates empty keyboard, action, axis, and mouse state.
    pub fn init() State {
        return .{
            .keys = [_]KeyState{.{}} ** key_count,
            .actions = [_]ActionState{.{}} ** max_digital_actions,
            .axis1_actions = [_]Axis1State{.{}} ** max_axis1_actions,
            .axis2_actions = [_]Axis2State{.{}} ** max_axis2_actions,
            .mouse = MouseState.init(),
        };
    }

    /// Clears one-frame input edges and pointer deltas.
    pub fn beginFrame(self: *State) void {
        for (&self.keys) |*key| key.beginFrame();
        for (&self.actions) |*action| action.beginFrame();
        for (&self.axis1_actions) |*axis_value| axis_value.beginFrame();
        for (&self.axis2_actions) |*axis_value| axis_value.beginFrame();

        self.mouse.beginFrame();
    }

    /// Releases all held keys, actions, axes, and mouse buttons.
    pub fn releaseAll(self: *State) void {
        for (&self.keys) |*key| key.forceRelease();
        for (&self.actions) |*action| action.forceRelease();
        for (&self.axis1_actions) |*axis_value| axis_value.forceNeutral();
        for (&self.axis2_actions) |*axis_value| axis_value.forceNeutral();

        self.mouse.releaseAll();
    }

    /// Updates one digital action directly.
    pub fn setDigitalDown(self: *State, action: DigitalActionId, down: bool) void {
        self.digitalState(action).setDown(down);
    }

    /// Returns true while a digital action is held.
    pub fn digitalDown(self: *const State, action: DigitalActionId) bool {
        return self.digitalStateConst(action).down;
    }

    /// Returns true only on the frame a digital action was pressed.
    pub fn digitalPressed(self: *const State, action: DigitalActionId) bool {
        return self.digitalStateConst(action).pressed;
    }

    /// Returns true only on the frame a digital action was released.
    pub fn digitalReleased(self: *const State, action: DigitalActionId) bool {
        return self.digitalStateConst(action).released;
    }

    /// Updates one 1D axis action directly.
    pub fn setAxis1(self: *State, action: Axis1ActionId, value: f32) void {
        self.axis1State(action).setValue(value);
    }

    /// Returns the current value for a 1D axis action.
    pub fn axis1(self: *const State, action: Axis1ActionId) f32 {
        return self.axis1StateConst(action).value;
    }

    /// Returns the previous-frame value for a 1D axis action.
    pub fn axis1Previous(self: *const State, action: Axis1ActionId) f32 {
        return self.axis1StateConst(action).previous;
    }

    /// Returns true when a 1D axis changed this frame.
    pub fn axis1Changed(self: *const State, action: Axis1ActionId) bool {
        return self.axis1StateConst(action).changed;
    }

    /// Updates one 2D axis action directly.
    pub fn setAxis2(self: *State, action: Axis2ActionId, value: Vector2) void {
        self.axis2State(action).setValue(value);
    }

    /// Returns the current value for a 2D axis action.
    pub fn axis2(self: *const State, action: Axis2ActionId) Vector2 {
        return self.axis2StateConst(action).value;
    }

    /// Returns the previous-frame value for a 2D axis action.
    pub fn axis2Previous(self: *const State, action: Axis2ActionId) Vector2 {
        return self.axis2StateConst(action).previous;
    }

    /// Returns true when a 2D axis changed this frame.
    pub fn axis2Changed(self: *const State, action: Axis2ActionId) bool {
        return self.axis2StateConst(action).changed;
    }

    /// Returns -1.0, 0.0, or 1.0 from a negative and positive digital action pair.
    pub fn digitalAxis1(self: *const State, negative: DigitalActionId, positive: DigitalActionId) f32 {
        return @floatFromInt(boolToI32(self.digitalDown(positive)) -
            boolToI32(self.digitalDown(negative)));
    }

    /// Returns a Vector2 from left/right/up/down digital action pairs.
    pub fn digitalAxis2(
        self: *const State,
        left: DigitalActionId,
        right: DigitalActionId,
        up: DigitalActionId,
        down: DigitalActionId,
    ) Vector2 {
        return Vector2.xy(
            self.digitalAxis1(left, right),
            self.digitalAxis1(up, down),
        );
    }

    /// Compatibility wrapper for the old generic action setter.
    pub fn setActionDown(self: *State, action: ActionId, down: bool) void {
        self.setDigitalDown(action, down);
    }

    /// Compatibility wrapper for the old generic action held query.
    pub fn isActionDown(self: *const State, action: ActionId) bool {
        return self.digitalDown(action);
    }

    /// Compatibility wrapper for the old generic action pressed query.
    pub fn actionWasPressed(self: *const State, action: ActionId) bool {
        return self.digitalPressed(action);
    }

    /// Compatibility wrapper for the old generic action released query.
    pub fn actionWasReleased(self: *const State, action: ActionId) bool {
        return self.digitalReleased(action);
    }

    /// Compatibility wrapper for the old integer digital axis helper.
    pub fn axis(self: *const State, negative: ActionId, positive: ActionId) i32 {
        return boolToI32(self.isActionDown(positive)) -
            boolToI32(self.isActionDown(negative));
    }

    /// Returns mutable state for a digital action.
    fn digitalState(self: *State, action: DigitalActionId) *ActionState {
        return &self.actions[digitalActionIndex(action)];
    }

    /// Returns readonly state for a digital action.
    fn digitalStateConst(self: *const State, action: DigitalActionId) ActionState {
        return self.actions[digitalActionIndex(action)];
    }

    /// Returns mutable state for a 1D axis action.
    fn axis1State(self: *State, action: Axis1ActionId) *Axis1State {
        return &self.axis1_actions[axis1ActionIndex(action)];
    }

    /// Returns readonly state for a 1D axis action.
    fn axis1StateConst(self: *const State, action: Axis1ActionId) Axis1State {
        return self.axis1_actions[axis1ActionIndex(action)];
    }

    /// Returns mutable state for a 2D axis action.
    fn axis2State(self: *State, action: Axis2ActionId) *Axis2State {
        return &self.axis2_actions[axis2ActionIndex(action)];
    }

    /// Returns readonly state for a 2D axis action.
    fn axis2StateConst(self: *const State, action: Axis2ActionId) Axis2State {
        return self.axis2_actions[axis2ActionIndex(action)];
    }

    /// Updates one keyboard key.
    pub fn setKey(self: *State, key: Key, down: bool) void {
        self.keyState(key).setDown(down);
    }

    /// Returns true while a key is held.
    pub fn isKeyDown(self: *const State, key: Key) bool {
        return self.keyStateConst(key).down;
    }

    /// Returns true only on the frame a key was pressed.
    pub fn wasKeyPressed(self: *const State, key: Key) bool {
        return self.keyStateConst(key).pressed;
    }

    /// Returns true only on the frame a key was released.
    pub fn wasKeyReleased(self: *const State, key: Key) bool {
        return self.keyStateConst(key).released;
    }

    /// Returns mutable state for a key.
    fn keyState(self: *State, key: Key) *KeyState {
        return &self.keys[keyIndex(key)];
    }

    /// Returns readonly state for a key.
    fn keyStateConst(self: *const State, key: Key) KeyState {
        return self.keys[keyIndex(key)];
    }

    /// Updates the mouse pointer position.
    pub fn setMousePosition(self: *State, position: Vector2) void {
        self.mouse.moveTo(position);
    }

    /// Adds mouse wheel movement for this frame.
    pub fn addMouseWheel(self: *State, wheel: Vector2, position: Vector2) void {
        self.mouse.scrollBy(wheel, position);
    }

    /// Updates one mouse button.
    pub fn setMouseButton(self: *State, button: MouseButton, down: bool, position: Vector2) void {
        self.mouse.setButton(button, down, position);
    }

    /// Returns the current mouse position in screen pixels.
    pub fn mousePosition(self: *const State) Vector2 {
        return self.mouse.position;
    }

    /// Returns mouse movement accumulated this frame.
    pub fn mouseDelta(self: *const State) Vector2 {
        return self.mouse.delta;
    }

    /// Returns mouse wheel movement accumulated this frame.
    pub fn mouseWheel(self: *const State) Vector2 {
        return self.mouse.wheel;
    }

    /// Returns true once SDL has reported the mouse inside the window.
    pub fn isMouseInsideWindow(self: *const State) bool {
        return self.mouse.inside_window;
    }

    /// Returns true while a mouse button is held.
    pub fn isMouseButtonDown(self: *const State, button: MouseButton) bool {
        return self.mouse.isButtonDown(button);
    }

    /// Returns true only on the frame a mouse button was pressed.
    pub fn wasMouseButtonPressed(self: *const State, button: MouseButton) bool {
        return self.mouse.wasButtonPressed(button);
    }

    /// Returns true only on the frame a mouse button was released.
    pub fn wasMouseButtonReleased(self: *const State, button: MouseButton) bool {
        return self.mouse.wasButtonReleased(button);
    }

    /// Updates the mouse pointer position and records a mouse motion event.
    pub fn setMousePositionWithEvents(
        self: *State,
        events: *InputEventQueue,
        position: Vector2,
    ) void {
        const previous = self.mousePosition();

        self.setMousePosition(position);

        const delta = Vector2.xy(
            position.x - previous.x,
            position.y - previous.y,
        );

        if (!vector2Eql(delta, Vector2.xy(0.0, 0.0))) {
            events.pushMouseMoved(position, delta);
        }
    }

    /// Adds mouse wheel movement and records mouse motion/scroll events.
    pub fn addMouseWheelWithEvents(
        self: *State,
        events: *InputEventQueue,
        wheel: Vector2,
        position: Vector2,
    ) void {
        const previous = self.mousePosition();

        self.addMouseWheel(wheel, position);

        const delta = Vector2.xy(
            position.x - previous.x,
            position.y - previous.y,
        );

        if (!vector2Eql(delta, Vector2.xy(0.0, 0.0))) {
            events.pushMouseMoved(position, delta);
        }

        if (!vector2Eql(wheel, Vector2.xy(0.0, 0.0))) {
            events.pushMouseScrolled(wheel, position);
        }
    }

    /// Updates one mouse button and records press/release events.
    pub fn setMouseButtonWithEvents(
        self: *State,
        events: *InputEventQueue,
        button: MouseButton,
        down: bool,
        position: Vector2,
    ) void {
        const previous_position = self.mousePosition();
        const was_down = self.isMouseButtonDown(button);

        self.setMouseButton(button, down, position);

        const delta = Vector2.xy(
            position.x - previous_position.x,
            position.y - previous_position.y,
        );

        if (!vector2Eql(delta, Vector2.xy(0.0, 0.0))) {
            events.pushMouseMoved(position, delta);
        }

        const is_down = self.isMouseButtonDown(button);
        if (!was_down and is_down) {
            events.pushMouseButtonPressed(button, position);
        } else if (was_down and !is_down) {
            events.pushMouseButtonReleased(button, position);
        }
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
        events: *InputEventQueue,
        map: ActionMapId,
        source: InputSource,
        key: Key,
    ) void {
        for (self.items()) |binding| {
            if (!binding.matchesKey(key)) continue;
            self.syncBindingWithEvents(state, events, map, source, binding);
        }
    }

    /// Refreshes one binding and records any action value edge/change.
    fn syncBindingWithEvents(
        self: *const ActionMap,
        state: *State,
        events: *InputEventQueue,
        map: ActionMapId,
        source: InputSource,
        binding: Binding,
    ) void {
        switch (binding) {
            .digital_key => |digital| self.syncDigitalActionWithEvents(
                state,
                events,
                map,
                source,
                digital.action,
            ),
            .axis1_keys => |axis| self.syncAxis1ActionWithEvents(
                state,
                events,
                map,
                source,
                axis.action,
            ),
            .axis2_keys => |axis| self.syncAxis2ActionWithEvents(
                state,
                events,
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
        events: *InputEventQueue,
        map: ActionMapId,
        source: InputSource,
        action: DigitalActionId,
    ) void {
        const was_down = state.digitalDown(action);

        self.syncDigitalAction(state, action);

        const is_down = state.digitalDown(action);
        if (!was_down and is_down) {
            events.pushActionPressed(map, action, source);
        } else if (was_down and !is_down) {
            events.pushActionReleased(map, action, source);
        }
    }

    /// Refreshes one 1D axis action and emits a change event.
    fn syncAxis1ActionWithEvents(
        self: *const ActionMap,
        state: *State,
        events: *InputEventQueue,
        map: ActionMapId,
        source: InputSource,
        action: Axis1ActionId,
    ) void {
        const previous = state.axis1(action);

        self.syncAxis1Action(state, action);

        const value = state.axis1(action);
        if (previous != value) {
            events.pushAxis1Changed(map, action, previous, value, source);
        }
    }

    /// Refreshes one 2D axis action and emits a change event.
    fn syncAxis2ActionWithEvents(
        self: *const ActionMap,
        state: *State,
        events: *InputEventQueue,
        map: ActionMapId,
        source: InputSource,
        action: Axis2ActionId,
    ) void {
        const previous = state.axis2(action);

        self.syncAxis2Action(state, action);

        const value = state.axis2(action);
        if (!vector2Eql(previous, value)) {
            events.pushAxis2Changed(map, action, previous, value, source);
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

fn keyIndex(key: Key) usize {
    std.debug.assert(key != .count);
    return @intFromEnum(key);
}

fn actionIndex(action: ActionId) usize {
    const index: usize = @intCast(action.index);
    std.debug.assert(index < max_actions);
    return index;
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

/// Converts a mouse button enum into an array index.
fn mouseButtonIndex(button: MouseButton) usize {
    std.debug.assert(button != .count);
    return @intFromEnum(button);
}

fn digitalActionIndex(action: DigitalActionId) usize {
    const index: usize = @intCast(action.index);
    std.debug.assert(index < max_digital_actions);
    return index;
}

fn axis1ActionIndex(action: Axis1ActionId) usize {
    const index: usize = @intCast(action.index);
    std.debug.assert(index < max_axis1_actions);
    return index;
}

fn axis2ActionIndex(action: Axis2ActionId) usize {
    const index: usize = @intCast(action.index);
    std.debug.assert(index < max_axis2_actions);
    return index;
}

fn vector2Eql(lhs: Vector2, rhs: Vector2) bool {
    return lhs.x == rhs.x and lhs.y == rhs.y;
}
