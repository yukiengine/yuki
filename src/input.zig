const std = @import("std");
const render_types = @import("render2d/types.zig");

/// Shared 2D vector type used for pointer positions and deltas.
pub const Vector2 = render_types.Vector2;

pub const max_digital_actions = 64;
pub const max_axis1_actions = 32;
pub const max_axis2_actions = 32;
pub const max_bindings = 64;

/// Backwards-compatible alias while the input API migrates from generic actions.
pub const max_actions = max_digital_actions;

pub const Error = error{
    InputMapFull,
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

        for (self.items()) |binding| {
            if (!binding.matchesKey(key)) continue;
            self.syncBinding(state, binding);
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
