const std = @import("std");
const render_types = @import("render2d/types.zig");

/// Shared 2D vector type used for pointer positions and deltas.
pub const Vector2 = render_types.Vector2;

pub const max_actions = 64;
pub const max_bindings = 64;

pub const Error = error{
    InputMapFull,
};

pub const ActionId = extern struct {
    index: u16,

    pub fn fromIndex(index: u16) ActionId {
        std.debug.assert(index < max_actions);
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
    actions: [max_actions]ActionState,
    mouse: MouseState,

    /// Creates empty keyboard, action, and mouse state.
    pub fn init() State {
        return .{
            .keys = [_]KeyState{.{}} ** key_count,
            .actions = [_]ActionState{.{}} ** max_actions,
            .mouse = MouseState.init(),
        };
    }

    /// Clears one-frame input edges and pointer deltas.
    pub fn beginFrame(self: *State) void {
        for (&self.keys) |*key| {
            key.beginFrame();
        }

        for (&self.actions) |*action| {
            action.beginFrame();
        }

        self.mouse.beginFrame();
    }

    /// Releases all held keys, actions, and mouse buttons.
    pub fn releaseAll(self: *State) void {
        for (&self.keys) |*key| {
            key.forceRelease();
        }

        for (&self.actions) |*action| {
            action.forceRelease();
        }

        self.mouse.releaseAll();
    }

    /// Updates one keyboard key.
    pub fn setKey(self: *State, key: Key, down: bool) void {
        self.keyState(key).setDown(down);
    }

    /// Updates one action directly.
    pub fn setActionDown(self: *State, action: ActionId, down: bool) void {
        self.actionState(action).setDown(down);
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

    /// Returns true while an action is held.
    pub fn isActionDown(self: *const State, action: ActionId) bool {
        return self.actionStateConst(action).down;
    }

    /// Returns true only on the frame an action was pressed.
    pub fn actionWasPressed(self: *const State, action: ActionId) bool {
        return self.actionStateConst(action).pressed;
    }

    /// Returns true only on the frame an action was released.
    pub fn actionWasReleased(self: *const State, action: ActionId) bool {
        return self.actionStateConst(action).released;
    }

    /// Returns -1, 0, or 1 from a negative and positive action pair.
    pub fn axis(self: *const State, negative: ActionId, positive: ActionId) i32 {
        return boolToI32(self.isActionDown(positive)) -
            boolToI32(self.isActionDown(negative));
    }

    /// Returns mutable state for a key.
    fn keyState(self: *State, key: Key) *KeyState {
        return &self.keys[keyIndex(key)];
    }

    /// Returns readonly state for a key.
    fn keyStateConst(self: *const State, key: Key) KeyState {
        return self.keys[keyIndex(key)];
    }

    /// Returns mutable state for an action.
    fn actionState(self: *State, action: ActionId) *ActionState {
        return &self.actions[actionIndex(action)];
    }

    /// Returns readonly state for an action.
    fn actionStateConst(self: *const State, action: ActionId) ActionState {
        return self.actions[actionIndex(action)];
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

pub const Binding = struct {
    key: Key,
    action: ActionId,

    pub fn init(key: Key, action: ActionId) Binding {
        std.debug.assert(key != .count);

        return .{
            .key = key,
            .action = action,
        };
    }

    pub fn matches(self: Binding, key: Key) bool {
        return self.key == key;
    }
};

pub const InputMap = struct {
    bindings: [max_bindings]Binding,
    binding_count: usize,

    pub fn init() InputMap {
        return .{
            .bindings = undefined,
            .binding_count = 0,
        };
    }

    pub fn bind(self: *InputMap, key: Key, action: ActionId) !void {
        if (self.binding_count == max_bindings) {
            return Error.InputMapFull;
        }

        self.bindings[self.binding_count] = Binding.init(key, action);
        self.binding_count += 1;
    }

    pub fn applyKey(
        self: *const InputMap,
        state: *State,
        key: Key,
        down: bool,
        repeated: bool,
    ) void {
        if (repeated) return;

        state.setKey(key, down);

        for (self.items()) |binding| {
            if (!binding.matches(key)) continue;

            self.syncAction(state, binding.action);
        }
    }

    pub fn items(self: *const InputMap) []const Binding {
        return self.bindings[0..self.binding_count];
    }

    fn syncAction(self: *const InputMap, state: *State, action: ActionId) void {
        state.setActionDown(action, self.actionDownFromKeys(state, action));
    }

    fn actionDownFromKeys(self: *const InputMap, state: *const State, action: ActionId) bool {
        for (self.items()) |binding| {
            if (binding.action.index != action.index) continue;
            if (state.isKeyDown(binding.key)) return true;
        }

        return false;
    }
};

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

/// Converts a mouse button enum into an array index.
fn mouseButtonIndex(button: MouseButton) usize {
    std.debug.assert(button != .count);
    return @intFromEnum(button);
}
