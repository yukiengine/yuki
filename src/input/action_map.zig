//! Action-map bindings.
//!
//! This module owns the developer-authored bindings that translate physical
//! inputs into typed digital, 1D axis, and 2D axis actions.

const types = @import("types.zig");
const events = @import("events.zig");
const state_mod = @import("state.zig");
const bindings_mod = @import("bindings.zig");

pub const Vector2 = types.Vector2;
pub const Error = types.Error;
pub const max_bindings = types.max_bindings;

pub const ActionId = types.ActionId;
pub const DigitalActionId = types.DigitalActionId;
pub const Axis1ActionId = types.Axis1ActionId;
pub const Axis2ActionId = types.Axis2ActionId;
pub const ActionMapId = types.ActionMapId;
pub const Key = types.Key;
pub const MouseButton = types.MouseButton;
pub const MouseButtonBinding = bindings_mod.MouseButtonBinding;

pub const InputSource = events.InputSource;
pub const InputEventQueue = events.InputEventQueue;
pub const State = state_mod.State;

pub const DigitalKeyBinding = bindings_mod.DigitalKeyBinding;
pub const Axis1KeyBinding = bindings_mod.Axis1KeyBinding;
pub const Axis2KeyBinding = bindings_mod.Axis2KeyBinding;
pub const Binding = bindings_mod.Binding;

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

    /// Binds one mouse button to one digital action.
    pub fn bindMouseButton(
        self: *ActionMap,
        button: MouseButton,
        action: DigitalActionId,
    ) !void {
        try self.pushBinding(.{
            .mouse_button = MouseButtonBinding.init(button, action),
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

    /// Applies one mouse button event and refreshes affected digital actions.
    pub fn applyMouseButton(
        self: *const ActionMap,
        state: *State,
        button: MouseButton,
        down: bool,
        position: Vector2,
    ) void {
        state.setMouseButton(button, down, position);
        self.syncMouseButton(state, button);
    }

    /// Refreshes action values affected by a mouse button already stored in State.
    pub fn syncMouseButton(self: *const ActionMap, state: *State, button: MouseButton) void {
        for (self.items()) |binding| {
            if (!binding.matchesMouseButton(button)) continue;
            self.syncBinding(state, binding);
        }
    }

    /// Refreshes mouse-button action values and emits frame-local events.
    pub fn syncMouseButtonWithEvents(
        self: *const ActionMap,
        state: *State,
        input_event_queue: *InputEventQueue,
        map: ActionMapId,
        source: InputSource,
        button: MouseButton,
    ) void {
        for (self.items()) |binding| {
            if (!binding.matchesMouseButton(button)) continue;
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
            .mouse_button => |mouse| self.syncDigitalActionWithEvents(
                state,
                input_event_queue,
                map,
                source,
                mouse.action,
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
            .mouse_button => |mouse| self.syncDigitalAction(state, mouse.action),
        }
    }

    /// Refreshes one digital action from every matching digital binding.
    fn syncDigitalAction(self: *const ActionMap, state: *State, action: DigitalActionId) void {
        var down = false;

        for (self.items()) |binding| {
            switch (binding) {
                .digital_key => |digital| {
                    if (!digital.matchesAction(action)) continue;
                    if (state.isKeyDown(digital.key)) {
                        down = true;
                        break;
                    }
                },
                .mouse_button => |mouse| {
                    if (!mouse.matchesAction(action)) continue;
                    if (state.isMouseButtonDown(mouse.button)) {
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
                    if (!axis.matchesAction(action)) continue;
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
                    if (!axis.matchesAction(action)) continue;

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
