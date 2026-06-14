//! Input action bindings.
//!
//! This module owns the small binding records that translate physical keyboard
//! state into typed input action values.

const std = @import("std");
const types = @import("types.zig");
const state_mod = @import("state.zig");

pub const Vector2 = types.Vector2;
pub const DigitalActionId = types.DigitalActionId;
pub const Axis1ActionId = types.Axis1ActionId;
pub const Axis2ActionId = types.Axis2ActionId;
pub const Key = types.Key;
pub const MouseButton = types.MouseButton;
pub const State = state_mod.State;

/// Binds one keyboard key to one digital action.
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

    /// Returns true when this binding writes to the action.
    pub fn matchesAction(self: DigitalKeyBinding, action: DigitalActionId) bool {
        return self.action.index == action.index;
    }
};

/// Binds one mouse button to one digital action.
pub const MouseButtonBinding = struct {
    button: MouseButton,
    action: DigitalActionId,

    /// Creates a mouse button binding.
    pub fn init(button: MouseButton, action: DigitalActionId) MouseButtonBinding {
        std.debug.assert(button != .count);

        return .{
            .button = button,
            .action = action,
        };
    }

    /// Returns true when this binding depends on the mouse button.
    pub fn matchesButton(self: MouseButtonBinding, button: MouseButton) bool {
        return self.button == button;
    }

    /// Returns true when this binding writes to the action.
    pub fn matchesAction(self: MouseButtonBinding, action: DigitalActionId) bool {
        return self.action.index == action.index;
    }
};

/// Binds two keyboard keys to one one-dimensional axis action.
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

    /// Returns true when this binding writes to the action.
    pub fn matchesAction(self: Axis1KeyBinding, action: Axis1ActionId) bool {
        return self.action.index == action.index;
    }

    /// Resolves the current axis value from key state.
    pub fn valueFromState(self: Axis1KeyBinding, state: *const State) f32 {
        return @floatFromInt(
            boolToI32(state.isKeyDown(self.positive)) -
                boolToI32(state.isKeyDown(self.negative)),
        );
    }
};

/// Binds four keyboard keys to one two-dimensional axis action.
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

    /// Returns true when this binding writes to the action.
    pub fn matchesAction(self: Axis2KeyBinding, action: Axis2ActionId) bool {
        return self.action.index == action.index;
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
    mouse_button: MouseButtonBinding,
    axis1_keys: Axis1KeyBinding,
    axis2_keys: Axis2KeyBinding,

    /// Returns true when this binding depends on the key.
    pub fn matchesKey(self: Binding, key: Key) bool {
        return switch (self) {
            .digital_key => |binding| binding.matchesKey(key),
            .mouse_button => false,
            .axis1_keys => |binding| binding.matchesKey(key),
            .axis2_keys => |binding| binding.matchesKey(key),
        };
    }

    /// Returns true when this binding depends on the mouse button.
    pub fn matchesMouseButton(self: Binding, button: MouseButton) bool {
        return switch (self) {
            .digital_key => false,
            .mouse_button => |binding| binding.matchesButton(button),
            .axis1_keys => false,
            .axis2_keys => false,
        };
    }

    /// Returns the digital action written by this binding, if it has one.
    pub fn digitalAction(self: Binding) ?DigitalActionId {
        return switch (self) {
            .digital_key => |binding| binding.action,
            .mouse_button => |binding| binding.action,
            else => null,
        };
    }

    /// Returns the 1D axis action written by this binding, if it has one.
    pub fn axis1Action(self: Binding) ?Axis1ActionId {
        return switch (self) {
            .axis1_keys => |binding| binding.action,
            else => null,
        };
    }

    /// Returns the 2D axis action written by this binding, if it has one.
    pub fn axis2Action(self: Binding) ?Axis2ActionId {
        return switch (self) {
            .axis2_keys => |binding| binding.action,
            else => null,
        };
    }
};

/// Converts a bool to a signed integer for axis math.
fn boolToI32(value: bool) i32 {
    return if (value) 1 else 0;
}
