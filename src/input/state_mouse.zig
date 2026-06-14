//! Mouse input state.
//!
//! This module owns pointer position, per-frame pointer deltas, wheel deltas,
//! and frame-aware mouse button state.

const std = @import("std");
const types = @import("types.zig");
const state_values = @import("state_values.zig");

pub const Vector2 = types.Vector2;
pub const MouseButton = types.MouseButton;

/// Digital state for one mouse button.
pub const MouseButtonState = state_values.DigitalState;

const mouse_button_count: usize = @intFromEnum(MouseButton.count);

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
        self.delta = zeroVector();
        self.wheel = zeroVector();

        for (&self.buttons) |*button| {
            button.beginFrame();
        }
    }

    /// Releases all mouse buttons and marks the pointer outside the window.
    pub fn releaseAll(self: *MouseState) void {
        for (&self.buttons) |*button| {
            button.forceRelease();
        }

        self.delta = zeroVector();
        self.wheel = zeroVector();
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
    pub fn setButton(
        self: *MouseState,
        button: MouseButton,
        down: bool,
        position: Vector2,
    ) void {
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

/// Converts a mouse button enum into an array index.
fn mouseButtonIndex(button: MouseButton) usize {
    std.debug.assert(button != .count);
    return @intFromEnum(button);
}

/// Returns the canonical zero vector for pointer deltas.
fn zeroVector() Vector2 {
    return Vector2.xy(0.0, 0.0);
}
