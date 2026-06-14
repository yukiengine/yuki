//! Resolved input state.
//!
//! This module owns frame-aware keyboard, action, axis, and mouse state. It is
//! still backend-neutral: platform code feeds it keys, mouse buttons, movement,
//! and wheel deltas, while higher layers read resolved values.

const types = @import("types.zig");
const events = @import("events.zig");
const state_values = @import("state_values.zig");
const state_mouse = @import("state_mouse.zig");

pub const Vector2 = types.Vector2;
pub const ActionId = types.ActionId;
pub const DigitalActionId = types.DigitalActionId;
pub const Axis1ActionId = types.Axis1ActionId;
pub const Axis2ActionId = types.Axis2ActionId;
pub const Key = types.Key;
pub const MouseButton = types.MouseButton;

pub const max_actions = types.max_actions;
pub const max_digital_actions = types.max_digital_actions;
pub const max_axis1_actions = types.max_axis1_actions;
pub const max_axis2_actions = types.max_axis2_actions;

pub const InputEventQueue = events.InputEventQueue;

const key_count: usize = @intFromEnum(Key.count);

pub const DigitalState = state_values.DigitalState;
pub const Axis1State = state_values.Axis1State;
pub const Axis2State = state_values.Axis2State;
pub const KeyState = state_values.KeyState;
pub const ActionState = state_values.ActionState;

pub const MouseButtonState = state_mouse.MouseButtonState;
pub const MouseState = state_mouse.MouseState;

/// Complete resolved input state for one runtime frame.
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
        input_event_queue: *InputEventQueue,
        position: Vector2,
    ) void {
        const previous = self.mousePosition();

        self.setMousePosition(position);

        const delta = Vector2.xy(
            position.x - previous.x,
            position.y - previous.y,
        );

        if (!vector2Eql(delta, Vector2.xy(0.0, 0.0))) {
            input_event_queue.pushMouseMoved(position, delta);
        }
    }

    /// Adds mouse wheel movement and records mouse motion/scroll events.
    pub fn addMouseWheelWithEvents(
        self: *State,
        input_event_queue: *InputEventQueue,
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
            input_event_queue.pushMouseMoved(position, delta);
        }

        if (!vector2Eql(wheel, Vector2.xy(0.0, 0.0))) {
            input_event_queue.pushMouseScrolled(wheel, position);
        }
    }

    /// Updates one mouse button and records press/release events.
    pub fn setMouseButtonWithEvents(
        self: *State,
        input_event_queue: *InputEventQueue,
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
            input_event_queue.pushMouseMoved(position, delta);
        }

        const is_down = self.isMouseButtonDown(button);
        if (!was_down and is_down) {
            input_event_queue.pushMouseButtonPressed(button, position);
        } else if (was_down and !is_down) {
            input_event_queue.pushMouseButtonReleased(button, position);
        }
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

    /// Returns mutable state for a key.
    fn keyState(self: *State, key: Key) *KeyState {
        return &self.keys[keyIndex(key)];
    }

    /// Returns readonly state for a key.
    fn keyStateConst(self: *const State, key: Key) KeyState {
        return self.keys[keyIndex(key)];
    }
};

/// Converts a key enum into an array index.
fn keyIndex(key: Key) usize {
    @import("std").debug.assert(key != .count);
    return @intFromEnum(key);
}

/// Converts a digital action handle into an array index.
fn digitalActionIndex(action: DigitalActionId) usize {
    const index: usize = @intCast(action.index);
    @import("std").debug.assert(index < max_digital_actions);
    return index;
}

/// Converts a 1D axis action handle into an array index.
fn axis1ActionIndex(action: Axis1ActionId) usize {
    const index: usize = @intCast(action.index);
    @import("std").debug.assert(index < max_axis1_actions);
    return index;
}

/// Converts a 2D axis action handle into an array index.
fn axis2ActionIndex(action: Axis2ActionId) usize {
    const index: usize = @intCast(action.index);
    @import("std").debug.assert(index < max_axis2_actions);
    return index;
}

/// Converts bool to signed digital-axis contribution.
fn boolToI32(value: bool) i32 {
    return if (value) 1 else 0;
}

/// Returns true when two vectors are exactly equal.
fn vector2Eql(lhs: Vector2, rhs: Vector2) bool {
    return lhs.x == rhs.x and lhs.y == rhs.y;
}
