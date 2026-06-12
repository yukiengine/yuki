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

pub const ButtonState = struct {
    down: bool = false,
    pressed: bool = false,
    released: bool = false,

    pub fn beginFrame(self: *ButtonState) void {
        self.pressed = false;
        self.released = false;
    }

    pub fn setDown(self: *ButtonState, down: bool) void {
        if (self.down == down) return;

        self.down = down;

        if (down) {
            self.pressed = true;
        } else {
            self.released = true;
        }
    }
};

pub const State = struct {
    buttons: [button_count]ButtonState,

    pub fn init() State {
        return .{
            .buttons = [_]ButtonState{.{}} ** button_count,
        };
    }

    pub fn beginFrame(self: *State) void {
        for (&self.buttons) |*button| {
            button.beginFrame();
        }
    }

    pub fn releaseAll(self: *State) void {
        for (&self.buttons) |*button| {
            button.setDown(false);
        }
    }

    pub fn set(self: *State, button: Button, down: bool) void {
        self.buttonState(button).setDown(down);
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

        for (self.items()) |binding| {
            if (!binding.matches(key)) continue;

            state.set(binding.button, down);
        }
    }

    pub fn items(self: *const InputMap) []const Binding {
        return self.bindings[0..self.binding_count];
    }
};

fn buttonIndex(button: Button) usize {
    std.debug.assert(button != .count);
    return @intFromEnum(button);
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

test "input map can bind multiple keys to one button" {
    var map = InputMap.init();
    try map.bind(.a, .move_left);
    try map.bind(.left, .move_left);

    var state = State.init();

    map.applyKey(&state, .a, true, false);
    try std.testing.expect(state.isDown(.move_left));
    try std.testing.expect(state.wasPressed(.move_left));

    state.beginFrame();
    state.set(.move_left, false);

    map.applyKey(&state, .left, true, false);
    try std.testing.expect(state.isDown(.move_left));
    try std.testing.expect(state.wasPressed(.move_left));
}

test "input map ignores repeated key down events" {
    const map = InputMap.defaultKeyboard();
    var state = State.init();

    map.applyKey(&state, .space, true, false);
    try std.testing.expect(state.wasPressed(.pause_animation));

    state.beginFrame();

    map.applyKey(&state, .space, true, true);
    try std.testing.expect(state.isDown(.pause_animation));
    try std.testing.expect(!state.wasPressed(.pause_animation));
}
