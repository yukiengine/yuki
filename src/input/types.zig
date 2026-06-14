//! Core input types.
//!
//! This file owns the small shared declarations that every input subsystem uses:
//! handles, capacity constants, keyboard keys, mouse buttons, and shared errors.

const std = @import("std");
const render_types = @import("../render2d/types.zig");

/// Shared 2D vector type used for pointer positions and deltas.
pub const Vector2 = render_types.Vector2;

/// Maximum number of action maps registered at runtime.
pub const max_action_maps = 16;

/// Maximum number of active action maps in the current input context.
pub const max_active_action_maps = max_action_maps;

/// Maximum number of digital action states.
pub const max_digital_actions = 64;

/// Maximum number of one-dimensional axis action states.
pub const max_axis1_actions = 32;

/// Maximum number of two-dimensional axis action states.
pub const max_axis2_actions = 32;

/// Maximum number of bindings inside one action map.
pub const max_bindings = 64;

/// Maximum number of frame-local input events.
pub const max_input_events = 128;

/// Backwards-compatible alias while the input API migrates from generic actions.
pub const max_actions = max_digital_actions;

/// Shared input error set.
pub const Error = error{
    InputMapFull,
    InputMapSetFull,
    InputContextFull,
    ActionMapRegistryFull,
    DigitalActionRegistryFull,
    Axis1ActionRegistryFull,
    Axis2ActionRegistryFull,
    DuplicateActionMapName,
    DuplicateActionName,
    UnknownActionMap,
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

/// Handle to a named action map registered by game content.
pub const ActionMapId = extern struct {
    index: u16,

    /// Creates an action map handle from a compact runtime index.
    pub fn fromIndex(index: u16) ActionMapId {
        std.debug.assert(index < max_action_maps);
        return .{ .index = index };
    }

    /// Returns true when two map handles refer to the same map slot.
    pub fn eql(self: ActionMapId, other: ActionMapId) bool {
        return self.index == other.index;
    }
};

/// Kind tag for a registered action value.
pub const ActionKind = enum(u8) {
    digital,
    axis1,
    axis2,
};

/// Type-safe reference to any registered action handle.
pub const ActionRef = union(ActionKind) {
    digital: DigitalActionId,
    axis1: Axis1ActionId,
    axis2: Axis2ActionId,

    /// Returns the value kind carried by this action reference.
    pub fn kind(self: ActionRef) ActionKind {
        return switch (self) {
            .digital => .digital,
            .axis1 => .axis1,
            .axis2 => .axis2,
        };
    }
};

/// Keyboard keys understood by the engine-level input layer.
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
