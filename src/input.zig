const std = @import("std");

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

    count,
};

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

pub const KeyState = DigitalState;
pub const ActionState = DigitalState;

pub const State = struct {
    keys: [key_count]KeyState,
    actions: [max_actions]ActionState,

    pub fn init() State {
        return .{
            .keys = [_]KeyState{.{}} ** key_count,
            .actions = [_]ActionState{.{}} ** max_actions,
        };
    }

    pub fn beginFrame(self: *State) void {
        for (&self.keys) |*key| {
            key.beginFrame();
        }

        for (&self.actions) |*action| {
            action.beginFrame();
        }
    }

    pub fn releaseAll(self: *State) void {
        for (&self.keys) |*key| {
            key.forceRelease();
        }

        for (&self.actions) |*action| {
            action.forceRelease();
        }
    }

    pub fn setKey(self: *State, key: Key, down: bool) void {
        self.keyState(key).setDown(down);
    }

    pub fn setActionDown(self: *State, action: ActionId, down: bool) void {
        self.actionState(action).setDown(down);
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

    pub fn isActionDown(self: *const State, action: ActionId) bool {
        return self.actionStateConst(action).down;
    }

    pub fn actionWasPressed(self: *const State, action: ActionId) bool {
        return self.actionStateConst(action).pressed;
    }

    pub fn actionWasReleased(self: *const State, action: ActionId) bool {
        return self.actionStateConst(action).released;
    }

    pub fn axis(self: *const State, negative: ActionId, positive: ActionId) i32 {
        return boolToI32(self.isActionDown(positive)) -
            boolToI32(self.isActionDown(negative));
    }

    fn keyState(self: *State, key: Key) *KeyState {
        return &self.keys[keyIndex(key)];
    }

    fn keyStateConst(self: *const State, key: Key) KeyState {
        return self.keys[keyIndex(key)];
    }

    fn actionState(self: *State, action: ActionId) *ActionState {
        return &self.actions[actionIndex(action)];
    }

    fn actionStateConst(self: *const State, action: ActionId) ActionState {
        return self.actions[actionIndex(action)];
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

test "action pressed and released are one-frame edges" {
    const jump = ActionId.fromIndex(0);
    var state = State.init();

    state.setActionDown(jump, true);
    try std.testing.expect(state.isActionDown(jump));
    try std.testing.expect(state.actionWasPressed(jump));
    try std.testing.expect(!state.actionWasReleased(jump));

    state.beginFrame();
    try std.testing.expect(state.isActionDown(jump));
    try std.testing.expect(!state.actionWasPressed(jump));
    try std.testing.expect(!state.actionWasReleased(jump));

    state.setActionDown(jump, false);
    try std.testing.expect(!state.isActionDown(jump));
    try std.testing.expect(!state.actionWasPressed(jump));
    try std.testing.expect(state.actionWasReleased(jump));
}

test "key pressed and released are one-frame edges" {
    var state = State.init();

    state.setKey(.space, true);
    try std.testing.expect(state.isKeyDown(.space));
    try std.testing.expect(state.wasKeyPressed(.space));
    try std.testing.expect(!state.wasKeyReleased(.space));

    state.beginFrame();

    state.setKey(.space, false);
    try std.testing.expect(!state.isKeyDown(.space));
    try std.testing.expect(state.wasKeyReleased(.space));
}

test "axis combines opposite actions" {
    const move_left = ActionId.fromIndex(0);
    const move_right = ActionId.fromIndex(1);
    var state = State.init();

    try std.testing.expectEqual(@as(i32, 0), state.axis(move_left, move_right));

    state.setActionDown(move_left, true);
    try std.testing.expectEqual(@as(i32, -1), state.axis(move_left, move_right));

    state.setActionDown(move_right, true);
    try std.testing.expectEqual(@as(i32, 0), state.axis(move_left, move_right));

    state.setActionDown(move_left, false);
    try std.testing.expectEqual(@as(i32, 1), state.axis(move_left, move_right));
}

test "input map derives actions from keys" {
    const jump = ActionId.fromIndex(0);

    var map = InputMap.init();
    try map.bind(.space, jump);

    var state = State.init();

    map.applyKey(&state, .space, true, false);
    try std.testing.expect(state.isKeyDown(.space));
    try std.testing.expect(state.wasKeyPressed(.space));
    try std.testing.expect(state.isActionDown(jump));
    try std.testing.expect(state.actionWasPressed(jump));

    state.beginFrame();

    map.applyKey(&state, .space, false, false);
    try std.testing.expect(!state.isKeyDown(.space));
    try std.testing.expect(state.wasKeyReleased(.space));
    try std.testing.expect(!state.isActionDown(jump));
    try std.testing.expect(state.actionWasReleased(jump));
}

test "input map aliases stay down until every bound key is released" {
    const move_left = ActionId.fromIndex(0);

    var map = InputMap.init();
    try map.bind(.a, move_left);
    try map.bind(.left, move_left);

    var state = State.init();

    map.applyKey(&state, .a, true, false);
    try std.testing.expect(state.isActionDown(move_left));
    try std.testing.expect(state.actionWasPressed(move_left));

    state.beginFrame();

    map.applyKey(&state, .left, true, false);
    try std.testing.expect(state.isActionDown(move_left));
    try std.testing.expect(!state.actionWasPressed(move_left));

    state.beginFrame();

    map.applyKey(&state, .a, false, false);
    try std.testing.expect(!state.isKeyDown(.a));
    try std.testing.expect(state.isKeyDown(.left));
    try std.testing.expect(state.isActionDown(move_left));
    try std.testing.expect(!state.actionWasReleased(move_left));

    state.beginFrame();

    map.applyKey(&state, .left, false, false);
    try std.testing.expect(!state.isActionDown(move_left));
    try std.testing.expect(state.actionWasReleased(move_left));
}

test "input map ignores repeated key down events" {
    const pause = ActionId.fromIndex(0);

    var map = InputMap.init();
    try map.bind(.space, pause);

    var state = State.init();

    map.applyKey(&state, .space, true, false);
    try std.testing.expect(state.actionWasPressed(pause));

    state.beginFrame();

    map.applyKey(&state, .space, true, true);
    try std.testing.expect(state.isKeyDown(.space));
    try std.testing.expect(state.isActionDown(pause));
    try std.testing.expect(!state.wasKeyPressed(.space));
    try std.testing.expect(!state.actionWasPressed(pause));
}

test "release all clears keys and actions" {
    const move_left = ActionId.fromIndex(0);
    const pause = ActionId.fromIndex(1);

    var map = InputMap.init();
    try map.bind(.a, move_left);
    try map.bind(.space, pause);

    var state = State.init();

    map.applyKey(&state, .a, true, false);
    map.applyKey(&state, .space, true, false);

    try std.testing.expect(state.isActionDown(move_left));
    try std.testing.expect(state.isActionDown(pause));

    state.releaseAll();

    try std.testing.expect(!state.isKeyDown(.a));
    try std.testing.expect(!state.isKeyDown(.space));
    try std.testing.expect(!state.isActionDown(move_left));
    try std.testing.expect(!state.isActionDown(pause));
    try std.testing.expect(state.wasKeyReleased(.a));
    try std.testing.expect(state.actionWasReleased(move_left));
}
