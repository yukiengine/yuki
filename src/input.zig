const std = @import("std");

pub const max_bindings = 32;

pub const Error = error{
    InputMapFull,
};

pub const Button = enum(u8) {
    move_left,
    move_right,
    move_up,
    move_down,
    zoom_in,
    zoom_out,
    pause_animation,
    reset_animation,
    quit,
    count,
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

    count,
};

const button_count: usize = @intFromEnum(Button.count);
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

pub const ButtonState = DigitalState;
pub const KeyState = DigitalState;

pub const State = struct {
    keys: [key_count]KeyState,
    buttons: [button_count]ButtonState,

    pub fn init() State {
        return .{
            .keys = [_]KeyState{.{}} ** key_count,
            .buttons = [_]ButtonState{.{}} ** button_count,
        };
    }

    pub fn beginFrame(self: *State) void {
        for (&self.keys) |*key| {
            key.beginFrame();
        }

        for (&self.buttons) |*button| {
            button.beginFrame();
        }
    }

    pub fn releaseAll(self: *State) void {
        for (&self.keys) |*key| {
            key.forceRelease();
        }

        for (&self.buttons) |*button| {
            button.forceRelease();
        }
    }

    pub fn set(self: *State, button: Button, down: bool) void {
        self.buttonState(button).setDown(down);
    }

    pub fn setKey(self: *State, key: Key, down: bool) void {
        self.keyState(key).setDown(down);
    }

    pub fn isDown(self: *const State, button: Button) bool {
        return self.buttonStateConst(button).down;
    }

    pub fn wasPressed(self: *const State, button: Button) bool {
        return self.buttonStateConst(button).pressed;
    }

    pub fn wasReleased(self: *const State, button: Button) bool {
        return self.buttonStateConst(button).released;
    }

    pub fn isKeyDown(self: *const State, key: Key) bool {
        return self.keyStateConst(key).down;
    }

    pub fn wasKeyPressed(self: *const State, key: Key) bool {
        return self.keyStateConst(key).pressed;
    }

    pub fn wasKeyReleased(self: *const State, key: Key) bool {
        return self.keyStateConst(key).released;
    }

    pub fn axisX(self: *const State) i32 {
        return boolToI32(self.isDown(.move_right)) -
            boolToI32(self.isDown(.move_left));
    }

    pub fn axisY(self: *const State) i32 {
        return boolToI32(self.isDown(.move_down)) -
            boolToI32(self.isDown(.move_up));
    }

    fn buttonState(self: *State, button: Button) *ButtonState {
        return &self.buttons[buttonIndex(button)];
    }

    fn buttonStateConst(self: *const State, button: Button) ButtonState {
        return self.buttons[buttonIndex(button)];
    }

    fn keyState(self: *State, key: Key) *KeyState {
        return &self.keys[keyIndex(key)];
    }

    fn keyStateConst(self: *const State, key: Key) KeyState {
        return self.keys[keyIndex(key)];
    }
};

pub const Binding = struct {
    key: Key,
    button: Button,

    pub fn init(key: Key, button: Button) Binding {
        std.debug.assert(key != .count);
        std.debug.assert(button != .count);

        return .{
            .key = key,
            .button = button,
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

    pub fn defaultKeyboard() InputMap {
        var map = InputMap.init();

        map.bind(.escape, .quit) catch unreachable;
        map.bind(.space, .pause_animation) catch unreachable;
        map.bind(.r, .reset_animation) catch unreachable;

        map.bind(.a, .move_left) catch unreachable;
        map.bind(.left, .move_left) catch unreachable;

        map.bind(.d, .move_right) catch unreachable;
        map.bind(.right, .move_right) catch unreachable;

        map.bind(.w, .move_up) catch unreachable;
        map.bind(.up, .move_up) catch unreachable;

        map.bind(.s, .move_down) catch unreachable;
        map.bind(.down, .move_down) catch unreachable;

        map.bind(.q, .zoom_out) catch unreachable;
        map.bind(.e, .zoom_in) catch unreachable;

        return map;
    }

    pub fn bind(self: *InputMap, key: Key, button: Button) !void {
        if (self.binding_count == max_bindings) {
            return Error.InputMapFull;
        }

        self.bindings[self.binding_count] = Binding.init(key, button);
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

            self.syncButton(state, binding.button);
        }
    }

    pub fn items(self: *const InputMap) []const Binding {
        return self.bindings[0..self.binding_count];
    }

    fn syncButton(self: *const InputMap, state: *State, button: Button) void {
        state.set(button, self.buttonDownFromKeys(state, button));
    }

    fn buttonDownFromKeys(self: *const InputMap, state: *const State, button: Button) bool {
        for (self.items()) |binding| {
            if (binding.button != button) continue;
            if (state.isKeyDown(binding.key)) return true;
        }

        return false;
    }
};

fn buttonIndex(button: Button) usize {
    std.debug.assert(button != .count);
    return @intFromEnum(button);
}

fn keyIndex(key: Key) usize {
    std.debug.assert(key != .count);
    return @intFromEnum(key);
}

fn boolToI32(value: bool) i32 {
    return if (value) 1 else 0;
}

test "button pressed and released are one-frame edges" {
    var state = State.init();

    state.set(.quit, true);
    try std.testing.expect(state.isDown(.quit));
    try std.testing.expect(state.wasPressed(.quit));
    try std.testing.expect(!state.wasReleased(.quit));

    state.beginFrame();
    try std.testing.expect(state.isDown(.quit));
    try std.testing.expect(!state.wasPressed(.quit));
    try std.testing.expect(!state.wasReleased(.quit));

    state.set(.quit, false);
    try std.testing.expect(!state.isDown(.quit));
    try std.testing.expect(!state.wasPressed(.quit));
    try std.testing.expect(state.wasReleased(.quit));
}

test "key pressed and released are one-frame edges" {
    var state = State.init();

    state.setKey(.space, true);
    try std.testing.expect(state.isKeyDown(.space));
    try std.testing.expect(state.wasKeyPressed(.space));
    try std.testing.expect(!state.wasKeyReleased(.space));

    state.beginFrame();
    try std.testing.expect(state.isKeyDown(.space));
    try std.testing.expect(!state.wasKeyPressed(.space));
    try std.testing.expect(!state.wasKeyReleased(.space));

    state.setKey(.space, false);
    try std.testing.expect(!state.isKeyDown(.space));
    try std.testing.expect(!state.wasKeyPressed(.space));
    try std.testing.expect(state.wasKeyReleased(.space));
}

test "axis values combine opposite movement buttons" {
    var state = State.init();

    try std.testing.expectEqual(@as(i32, 0), state.axisX());
    try std.testing.expectEqual(@as(i32, 0), state.axisY());

    state.set(.move_left, true);
    try std.testing.expectEqual(@as(i32, -1), state.axisX());

    state.set(.move_right, true);
    try std.testing.expectEqual(@as(i32, 0), state.axisX());

    state.set(.move_left, false);
    try std.testing.expectEqual(@as(i32, 1), state.axisX());

    state.set(.move_up, true);
    try std.testing.expectEqual(@as(i32, -1), state.axisY());

    state.set(.move_down, true);
    try std.testing.expectEqual(@as(i32, 0), state.axisY());
}

test "input map derives buttons from keys" {
    var map = InputMap.init();
    try map.bind(.space, .pause_animation);

    var state = State.init();

    map.applyKey(&state, .space, true, false);
    try std.testing.expect(state.isKeyDown(.space));
    try std.testing.expect(state.wasKeyPressed(.space));
    try std.testing.expect(state.isDown(.pause_animation));
    try std.testing.expect(state.wasPressed(.pause_animation));

    state.beginFrame();

    map.applyKey(&state, .space, false, false);
    try std.testing.expect(!state.isKeyDown(.space));
    try std.testing.expect(state.wasKeyReleased(.space));
    try std.testing.expect(!state.isDown(.pause_animation));
    try std.testing.expect(state.wasReleased(.pause_animation));
}

test "input map aliases stay down until every bound key is released" {
    var map = InputMap.init();
    try map.bind(.a, .move_left);
    try map.bind(.left, .move_left);

    var state = State.init();

    map.applyKey(&state, .a, true, false);
    try std.testing.expect(state.isDown(.move_left));
    try std.testing.expect(state.wasPressed(.move_left));

    state.beginFrame();

    map.applyKey(&state, .left, true, false);
    try std.testing.expect(state.isDown(.move_left));
    try std.testing.expect(!state.wasPressed(.move_left));

    state.beginFrame();

    map.applyKey(&state, .a, false, false);
    try std.testing.expect(!state.isKeyDown(.a));
    try std.testing.expect(state.isKeyDown(.left));
    try std.testing.expect(state.isDown(.move_left));
    try std.testing.expect(!state.wasReleased(.move_left));

    state.beginFrame();

    map.applyKey(&state, .left, false, false);
    try std.testing.expect(!state.isKeyDown(.left));
    try std.testing.expect(!state.isDown(.move_left));
    try std.testing.expect(state.wasReleased(.move_left));
}

test "input map ignores repeated key down events" {
    const map = InputMap.defaultKeyboard();
    var state = State.init();

    map.applyKey(&state, .space, true, false);
    try std.testing.expect(state.wasPressed(.pause_animation));

    state.beginFrame();

    map.applyKey(&state, .space, true, true);
    try std.testing.expect(state.isKeyDown(.space));
    try std.testing.expect(state.isDown(.pause_animation));
    try std.testing.expect(!state.wasKeyPressed(.space));
    try std.testing.expect(!state.wasPressed(.pause_animation));
}

test "release all clears keys and buttons" {
    const map = InputMap.defaultKeyboard();
    var state = State.init();

    map.applyKey(&state, .a, true, false);
    map.applyKey(&state, .space, true, false);

    try std.testing.expect(state.isKeyDown(.a));
    try std.testing.expect(state.isKeyDown(.space));
    try std.testing.expect(state.isDown(.move_left));
    try std.testing.expect(state.isDown(.pause_animation));

    state.releaseAll();

    try std.testing.expect(!state.isKeyDown(.a));
    try std.testing.expect(!state.isKeyDown(.space));
    try std.testing.expect(!state.isDown(.move_left));
    try std.testing.expect(!state.isDown(.pause_animation));

    try std.testing.expect(!state.wasKeyPressed(.a));
    try std.testing.expect(!state.wasPressed(.move_left));
    try std.testing.expect(state.wasKeyReleased(.a));
    try std.testing.expect(state.wasReleased(.move_left));
}
