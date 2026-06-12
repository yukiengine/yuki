const std = @import("std");

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
        return boolToI32(self.isDown(.move_down)) - boolToI32(self.isDown(.move_up));
    }

    fn buttonState(self: *State, button: Button) *ButtonState {
        return &self.buttons[buttonIndex(button)];
    }

    fn buttonStateConst(self: *const State, button: Button) ButtonState {
        return self.buttons[buttonIndex(button)];
    }
};

fn buttonIndex(button: Button) usize {
    std.debug.assert(button != .count);
    return @intFromEnum(button);
}

fn boolToI32(value: bool) i32 {
    return if (value) 1 else 0;
}
