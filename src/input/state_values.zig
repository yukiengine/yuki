//! Frame-aware input value states.
//!
//! This module owns the small reusable state machines used by keys, actions,
//! mouse buttons, and typed axes.

const types = @import("types.zig");

pub const Vector2 = types.Vector2;

/// Frame-aware digital state for one key, action, or mouse button.
pub const DigitalState = struct {
    down: bool = false,
    pressed: bool = false,
    released: bool = false,

    /// Clears one-frame press and release edges.
    pub fn beginFrame(self: *DigitalState) void {
        self.pressed = false;
        self.released = false;
    }

    /// Updates held state and records press/release edges.
    pub fn setDown(self: *DigitalState, down: bool) void {
        if (self.down == down) return;

        self.down = down;
        if (down) {
            self.pressed = true;
        } else {
            self.released = true;
        }
    }

    /// Forces the value released and records a release edge if needed.
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

    /// Clears the one-frame changed edge and stores current as previous.
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

    /// Clears the one-frame changed edge and stores current as previous.
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

/// Digital state for one keyboard key.
pub const KeyState = DigitalState;

/// Digital state for one action.
pub const ActionState = DigitalState;

/// Returns true when two vectors are exactly equal.
fn vector2Eql(lhs: Vector2, rhs: Vector2) bool {
    return lhs.x == rhs.x and lhs.y == rhs.y;
}
