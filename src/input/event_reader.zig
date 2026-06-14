//! Read-only helpers for frame-local input events.
//!
//! EventReader is the small query surface game-facing code can use when it
//! wants input transitions as events instead of polling resolved state.

const types = @import("types.zig");
const events_mod = @import("events.zig");

/// Handle to a digital action.
pub const DigitalActionId = types.DigitalActionId;

/// Handle to a one-dimensional axis action.
pub const Axis1ActionId = types.Axis1ActionId;

/// Handle to a two-dimensional axis action.
pub const Axis2ActionId = types.Axis2ActionId;

/// Handle to an action map.
pub const ActionMapId = types.ActionMapId;

/// Mouse button enum used by mouse event helpers.
pub const MouseButton = types.MouseButton;

/// One frame-local input event.
pub const InputEvent = events_mod.InputEvent;

/// Payload for digital action events.
pub const DigitalActionEvent = events_mod.DigitalActionEvent;

/// Payload for 1D axis events.
pub const Axis1ActionEvent = events_mod.Axis1ActionEvent;

/// Payload for 2D axis events.
pub const Axis2ActionEvent = events_mod.Axis2ActionEvent;

/// Payload for mouse motion events.
pub const MouseMotionEvent = events_mod.MouseMotionEvent;

/// Payload for mouse button events.
pub const MouseButtonEvent = events_mod.MouseButtonEvent;

/// Payload for mouse wheel events.
pub const MouseWheelEvent = events_mod.MouseWheelEvent;

/// Read-only query object for frame-local input events.
pub const EventReader = struct {
    event_items: []const InputEvent,

    /// Creates a reader over a frame-local event slice.
    pub fn init(input_events: []const InputEvent) EventReader {
        return .{ .event_items = input_events };
    }

    /// Returns all events visible to this reader.
    pub fn events(self: EventReader) []const InputEvent {
        return self.event_items;
    }

    /// Returns a forward-only iterator over this reader's events.
    pub fn iter(self: EventReader) EventIterator {
        return EventIterator.init(self.event_items);
    }

    /// Returns the number of events in this reader.
    pub fn count(self: EventReader) usize {
        return self.event_items.len;
    }

    /// Returns true when this reader has no events.
    pub fn isEmpty(self: EventReader) bool {
        return self.event_items.len == 0;
    }

    /// Returns true when this reader has at least one event.
    pub fn hasEvents(self: EventReader) bool {
        return self.event_items.len > 0;
    }

    /// Returns the first press event for a digital action.
    pub fn firstActionPressed(self: EventReader, action: DigitalActionId) ?DigitalActionEvent {
        for (self.event_items) |event| {
            switch (event) {
                .action_pressed => |item| {
                    if (sameDigital(item.action, action)) return item;
                },
                else => {},
            }
        }

        return null;
    }

    /// Returns the first release event for a digital action.
    pub fn firstActionReleased(self: EventReader, action: DigitalActionId) ?DigitalActionEvent {
        for (self.event_items) |event| {
            switch (event) {
                .action_released => |item| {
                    if (sameDigital(item.action, action)) return item;
                },
                else => {},
            }
        }

        return null;
    }

    /// Returns the first press event for a digital action in one map.
    pub fn firstMapActionPressed(
        self: EventReader,
        map: ActionMapId,
        action: DigitalActionId,
    ) ?DigitalActionEvent {
        for (self.event_items) |event| {
            switch (event) {
                .action_pressed => |item| {
                    if (item.map.eql(map) and sameDigital(item.action, action)) return item;
                },
                else => {},
            }
        }

        return null;
    }

    /// Returns the first release event for a digital action in one map.
    pub fn firstMapActionReleased(
        self: EventReader,
        map: ActionMapId,
        action: DigitalActionId,
    ) ?DigitalActionEvent {
        for (self.event_items) |event| {
            switch (event) {
                .action_released => |item| {
                    if (item.map.eql(map) and sameDigital(item.action, action)) return item;
                },
                else => {},
            }
        }

        return null;
    }

    /// Returns true when a digital action was pressed this frame.
    pub fn hasActionPressed(self: EventReader, action: DigitalActionId) bool {
        return self.firstActionPressed(action) != null;
    }

    /// Returns true when a digital action was released this frame.
    pub fn hasActionReleased(self: EventReader, action: DigitalActionId) bool {
        return self.firstActionReleased(action) != null;
    }

    /// Returns the first changed event for a 1D axis action.
    pub fn firstAxis1Changed(self: EventReader, action: Axis1ActionId) ?Axis1ActionEvent {
        for (self.event_items) |event| {
            switch (event) {
                .axis1_changed => |item| {
                    if (sameAxis1(item.action, action)) return item;
                },
                else => {},
            }
        }

        return null;
    }

    /// Returns the first changed event for a 1D axis action in one map.
    pub fn firstMapAxis1Changed(
        self: EventReader,
        map: ActionMapId,
        action: Axis1ActionId,
    ) ?Axis1ActionEvent {
        for (self.event_items) |event| {
            switch (event) {
                .axis1_changed => |item| {
                    if (item.map.eql(map) and sameAxis1(item.action, action)) return item;
                },
                else => {},
            }
        }

        return null;
    }

    /// Returns the first changed event for a 2D axis action.
    pub fn firstAxis2Changed(self: EventReader, action: Axis2ActionId) ?Axis2ActionEvent {
        for (self.event_items) |event| {
            switch (event) {
                .axis2_changed => |item| {
                    if (sameAxis2(item.action, action)) return item;
                },
                else => {},
            }
        }

        return null;
    }

    /// Returns the first changed event for a 2D axis action in one map.
    pub fn firstMapAxis2Changed(
        self: EventReader,
        map: ActionMapId,
        action: Axis2ActionId,
    ) ?Axis2ActionEvent {
        for (self.event_items) |event| {
            switch (event) {
                .axis2_changed => |item| {
                    if (item.map.eql(map) and sameAxis2(item.action, action)) return item;
                },
                else => {},
            }
        }

        return null;
    }

    /// Returns the first mouse motion event in this frame.
    pub fn firstMouseMoved(self: EventReader) ?MouseMotionEvent {
        for (self.event_items) |event| {
            switch (event) {
                .mouse_moved => |item| return item,
                else => {},
            }
        }

        return null;
    }

    /// Returns the first mouse button press event for a button.
    pub fn firstMouseButtonPressed(self: EventReader, button: MouseButton) ?MouseButtonEvent {
        for (self.event_items) |event| {
            switch (event) {
                .mouse_button_pressed => |item| {
                    if (item.button == button) return item;
                },
                else => {},
            }
        }

        return null;
    }

    /// Returns the first mouse button release event for a button.
    pub fn firstMouseButtonReleased(self: EventReader, button: MouseButton) ?MouseButtonEvent {
        for (self.event_items) |event| {
            switch (event) {
                .mouse_button_released => |item| {
                    if (item.button == button) return item;
                },
                else => {},
            }
        }

        return null;
    }

    /// Returns the first mouse wheel event in this frame.
    pub fn firstMouseScrolled(self: EventReader) ?MouseWheelEvent {
        for (self.event_items) |event| {
            switch (event) {
                .mouse_scrolled => |item| return item,
                else => {},
            }
        }

        return null;
    }
};

/// Forward-only iterator over frame-local input events.
pub const EventIterator = struct {
    event_items: []const InputEvent,
    index: usize,

    /// Creates an iterator over an event slice.
    pub fn init(events: []const InputEvent) EventIterator {
        return .{
            .event_items = events,
            .index = 0,
        };
    }

    /// Returns the next event, or null when iteration is complete.
    pub fn next(self: *EventIterator) ?InputEvent {
        if (self.index >= self.event_items.len) return null;

        const event = self.event_items[self.index];
        self.index += 1;
        return event;
    }

    /// Restarts iteration from the first event.
    pub fn reset(self: *EventIterator) void {
        self.index = 0;
    }

    /// Returns the number of events not yet yielded.
    pub fn remainingCount(self: *const EventIterator) usize {
        if (self.index >= self.event_items.len) return 0;
        return self.event_items.len - self.index;
    }
};

/// Returns true when two digital action handles refer to the same slot.
fn sameDigital(left: DigitalActionId, right: DigitalActionId) bool {
    return left.index == right.index;
}

/// Returns true when two 1D axis handles refer to the same slot.
fn sameAxis1(left: Axis1ActionId, right: Axis1ActionId) bool {
    return left.index == right.index;
}

/// Returns true when two 2D axis handles refer to the same slot.
fn sameAxis2(left: Axis2ActionId, right: Axis2ActionId) bool {
    return left.index == right.index;
}
