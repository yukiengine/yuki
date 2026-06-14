//! Action-map bindings.
//!
//! This module owns the developer-authored bindings that translate physical
//! inputs into typed digital, 1D axis, and 2D axis actions.

const std = @import("std");
const types = @import("types.zig");
const events = @import("events.zig");
const state_mod = @import("state.zig");

pub const Vector2 = types.Vector2;
pub const Error = types.Error;
pub const max_bindings = types.max_bindings;

pub const ActionId = types.ActionId;
pub const DigitalActionId = types.DigitalActionId;
pub const Axis1ActionId = types.Axis1ActionId;
pub const Axis2ActionId = types.Axis2ActionId;
pub const ActionMapId = types.ActionMapId;
pub const Key = types.Key;

pub const InputSource = events.InputSource;
pub const InputEventQueue = events.InputEventQueue;
pub const State = state_mod.State;

/// Binds one keyboard key to one digital action.
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

/// Binds two keyboard keys to one one-dimensional axis action.
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

/// Binds four keyboard keys to one two-dimensional axis action.
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

/// Collection of typed input bindings for one gameplay/UI mode.
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

    /// Returns all bindings in this map.
    pub fn items(self: *const ActionMap) []const Binding {
        return self.bindings[0..self.binding_count];
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
                    value = Vector2.xy(value.x + axis_value.x, value.y + axis_value.y);
                },
                else => {},
            }
        }

        state.setAxis2(action, clampAxis2(value));
    }
};

/// Compatibility alias while callers migrate from InputMap to ActionMap.
pub const InputMap = ActionMap;

/// Converts a bool to a signed integer for axis math.
fn boolToI32(value: bool) i32 {
    return if (value) 1 else 0;
}

/// Clamps a one-dimensional input axis into the normalized range.
fn clampAxis1(value: f32) f32 {
    if (value < -1.0) return -1.0;
    if (value > 1.0) return 1.0;
    return value;
}

/// Clamps a two-dimensional input axis component-wise.
fn clampAxis2(value: Vector2) Vector2 {
    return Vector2.xy(
        clampAxis1(value.x),
        clampAxis1(value.y),
    );
}

/// Returns true when two Vector2 values are exactly equal.
fn vector2Eql(lhs: Vector2, rhs: Vector2) bool {
    return lhs.x == rhs.x and lhs.y == rhs.y;
}
