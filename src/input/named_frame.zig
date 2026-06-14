//! Named input frame facade.
//!
//! NamedFrame is an API-facing wrapper over resolved input state and frame-local
//! events. It resolves action names through ActionRegistry, then delegates to the
//! handle-based runtime state.

const types = @import("types.zig");
const events_mod = @import("events.zig");
const state_mod = @import("state.zig");
const registry_mod = @import("registry.zig");
const event_reader_mod = @import("event_reader.zig");

/// Shared input error set.
pub const Error = types.Error;

/// Shared 2D vector type.
pub const Vector2 = types.Vector2;

/// Handle to an action map.
pub const ActionMapId = types.ActionMapId;

/// Handle to a digital action.
pub const DigitalActionId = types.DigitalActionId;

/// Handle to a one-dimensional axis action.
pub const Axis1ActionId = types.Axis1ActionId;

/// Handle to a two-dimensional axis action.
pub const Axis2ActionId = types.Axis2ActionId;

/// Resolved input state for one frame.
pub const State = state_mod.State;

/// Named action registry used to resolve author-facing names.
pub const ActionRegistry = registry_mod.ActionRegistry;

/// One frame-local input event.
pub const InputEvent = events_mod.InputEvent;

/// Payload for digital action input events.
pub const DigitalActionEvent = events_mod.DigitalActionEvent;

/// Payload for 1D axis input events.
pub const Axis1ActionEvent = events_mod.Axis1ActionEvent;

/// Payload for 2D axis input events.
pub const Axis2ActionEvent = events_mod.Axis2ActionEvent;

/// Read-only input event query helper.
pub const EventReader = event_reader_mod.EventReader;

/// Read-only named view of one input frame.
pub const NamedFrame = struct {
    registry: *const ActionRegistry,
    map: ActionMapId,
    state: *const State,
    event_items: []const InputEvent,

    /// Creates a named frame from an already-resolved action map id.
    pub fn init(
        registry: *const ActionRegistry,
        map: ActionMapId,
        state: *const State,
        input_events: []const InputEvent,
    ) NamedFrame {
        return .{
            .registry = registry,
            .map = map,
            .state = state,
            .event_items = input_events,
        };
    }

    /// Creates a named frame by resolving an action map name.
    pub fn fromMapName(
        registry: *const ActionRegistry,
        map_name: []const u8,
        state: *const State,
        input_events: []const InputEvent,
    ) !NamedFrame {
        const map = registry.findMap(map_name) orelse return Error.UnknownActionMap;
        return NamedFrame.init(registry, map, state, input_events);
    }

    /// Returns the action map this view resolves names against.
    pub fn mapId(self: NamedFrame) ActionMapId {
        return self.map;
    }

    /// Returns a read-only event reader for this frame.
    pub fn reader(self: NamedFrame) EventReader {
        return EventReader.init(self.event_items);
    }

    /// Returns true while a named digital action is held.
    pub fn digitalDown(self: NamedFrame, action_name: []const u8) !bool {
        const action = try self.requireDigital(action_name);
        return self.state.digitalDown(action);
    }

    /// Returns true only on the frame a named digital action was pressed.
    pub fn digitalPressed(self: NamedFrame, action_name: []const u8) !bool {
        const action = try self.requireDigital(action_name);
        return self.state.digitalPressed(action);
    }

    /// Returns true only on the frame a named digital action was released.
    pub fn digitalReleased(self: NamedFrame, action_name: []const u8) !bool {
        const action = try self.requireDigital(action_name);
        return self.state.digitalReleased(action);
    }

    /// Returns the current value for a named 1D axis action.
    pub fn axis1(self: NamedFrame, action_name: []const u8) !f32 {
        const action = try self.requireAxis1(action_name);
        return self.state.axis1(action);
    }

    /// Returns true when a named 1D axis changed during this frame.
    pub fn axis1Changed(self: NamedFrame, action_name: []const u8) !bool {
        const action = try self.requireAxis1(action_name);
        return self.state.axis1Changed(action);
    }

    /// Returns the current value for a named 2D axis action.
    pub fn axis2(self: NamedFrame, action_name: []const u8) !Vector2 {
        const action = try self.requireAxis2(action_name);
        return self.state.axis2(action);
    }

    /// Returns true when a named 2D axis changed during this frame.
    pub fn axis2Changed(self: NamedFrame, action_name: []const u8) !bool {
        const action = try self.requireAxis2(action_name);
        return self.state.axis2Changed(action);
    }

    /// Returns the first press event for a named digital action in this map.
    pub fn firstActionPressed(self: NamedFrame, action_name: []const u8) !?DigitalActionEvent {
        const action = try self.requireDigital(action_name);
        return self.reader().firstMapActionPressed(self.map, action);
    }

    /// Returns the first release event for a named digital action in this map.
    pub fn firstActionReleased(self: NamedFrame, action_name: []const u8) !?DigitalActionEvent {
        const action = try self.requireDigital(action_name);
        return self.reader().firstMapActionReleased(self.map, action);
    }

    /// Returns true when a named digital action was pressed in this map.
    pub fn hasActionPressed(self: NamedFrame, action_name: []const u8) !bool {
        return (try self.firstActionPressed(action_name)) != null;
    }

    /// Returns true when a named digital action was released in this map.
    pub fn hasActionReleased(self: NamedFrame, action_name: []const u8) !bool {
        return (try self.firstActionReleased(action_name)) != null;
    }

    /// Returns the first changed event for a named 1D axis action in this map.
    pub fn firstAxis1Changed(self: NamedFrame, action_name: []const u8) !?Axis1ActionEvent {
        const action = try self.requireAxis1(action_name);
        return self.reader().firstMapAxis1Changed(self.map, action);
    }

    /// Returns the first changed event for a named 2D axis action in this map.
    pub fn firstAxis2Changed(self: NamedFrame, action_name: []const u8) !?Axis2ActionEvent {
        const action = try self.requireAxis2(action_name);
        return self.reader().firstMapAxis2Changed(self.map, action);
    }

    /// Resolves a named digital action in this frame's map.
    fn requireDigital(self: NamedFrame, action_name: []const u8) !DigitalActionId {
        return self.registry.findDigital(self.map, action_name) orelse Error.UnknownActionName;
    }

    /// Resolves a named 1D axis action in this frame's map.
    fn requireAxis1(self: NamedFrame, action_name: []const u8) !Axis1ActionId {
        return self.registry.findAxis1(self.map, action_name) orelse Error.UnknownActionName;
    }

    /// Resolves a named 2D axis action in this frame's map.
    fn requireAxis2(self: NamedFrame, action_name: []const u8) !Axis2ActionId {
        return self.registry.findAxis2(self.map, action_name) orelse Error.UnknownActionName;
    }
};
