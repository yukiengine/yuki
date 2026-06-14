//! Read-only input frame facade.
//!
//! This module is the shape game-facing code should move toward: one frame
//! object that exposes polling state and frame-local events without exposing
//! backend/platform details.

const input = @import("input.zig");

/// Read-only view of resolved input state and frame-local input events.
pub const Frame = struct {
    state: *const input.State,
    event_items: []const input.InputEvent,

    /// Creates a frame view from input state and the current frame event slice.
    pub fn init(state: *const input.State, input_events: []const input.InputEvent) Frame {
        return .{
            .state = state,
            .event_items = input_events,
        };
    }

    /// Returns all frame-local input events.
    pub fn events(self: Frame) []const input.InputEvent {
        return self.event_items;
    }

    /// Returns an iterator over frame-local input events.
    pub fn iter(self: Frame) EventIterator {
        return EventIterator.init(self.event_items);
    }

    /// Returns the number of frame-local input events.
    pub fn eventCount(self: Frame) usize {
        return self.event_items.len;
    }

    /// Returns true when the frame has no input events.
    pub fn hasNoEvents(self: Frame) bool {
        return self.event_items.len == 0;
    }

    /// Returns true while a digital action is held.
    pub fn digitalDown(self: Frame, action: input.DigitalActionId) bool {
        return self.state.digitalDown(action);
    }

    /// Returns true only on the frame a digital action was pressed.
    pub fn digitalPressed(self: Frame, action: input.DigitalActionId) bool {
        return self.state.digitalPressed(action);
    }

    /// Returns true only on the frame a digital action was released.
    pub fn digitalReleased(self: Frame, action: input.DigitalActionId) bool {
        return self.state.digitalReleased(action);
    }

    /// Returns the current value for a 1D axis action.
    pub fn axis1(self: Frame, action: input.Axis1ActionId) f32 {
        return self.state.axis1(action);
    }

    /// Returns true when a 1D axis changed during this frame.
    pub fn axis1Changed(self: Frame, action: input.Axis1ActionId) bool {
        return self.state.axis1Changed(action);
    }

    /// Returns the current value for a 2D axis action.
    pub fn axis2(self: Frame, action: input.Axis2ActionId) input.Vector2 {
        return self.state.axis2(action);
    }

    /// Returns true when a 2D axis changed during this frame.
    pub fn axis2Changed(self: Frame, action: input.Axis2ActionId) bool {
        return self.state.axis2Changed(action);
    }

    /// Returns -1.0, 0.0, or 1.0 from two digital actions.
    pub fn digitalAxis1(
        self: Frame,
        negative: input.DigitalActionId,
        positive: input.DigitalActionId,
    ) f32 {
        return self.state.digitalAxis1(negative, positive);
    }

    /// Returns a Vector2 from left/right/up/down digital action pairs.
    pub fn digitalAxis2(
        self: Frame,
        left: input.DigitalActionId,
        right: input.DigitalActionId,
        up: input.DigitalActionId,
        down: input.DigitalActionId,
    ) input.Vector2 {
        return self.state.digitalAxis2(left, right, up, down);
    }

    /// Returns true while a keyboard key is held.
    pub fn keyDown(self: Frame, key: input.Key) bool {
        return self.state.isKeyDown(key);
    }

    /// Returns true only on the frame a keyboard key was pressed.
    pub fn keyPressed(self: Frame, key: input.Key) bool {
        return self.state.wasKeyPressed(key);
    }

    /// Returns true only on the frame a keyboard key was released.
    pub fn keyReleased(self: Frame, key: input.Key) bool {
        return self.state.wasKeyReleased(key);
    }

    /// Returns the current mouse position in screen pixels.
    pub fn mousePosition(self: Frame) input.Vector2 {
        return self.state.mousePosition();
    }

    /// Returns mouse movement accumulated during this frame.
    pub fn mouseDelta(self: Frame) input.Vector2 {
        return self.state.mouseDelta();
    }

    /// Returns mouse wheel movement accumulated during this frame.
    pub fn mouseWheel(self: Frame) input.Vector2 {
        return self.state.mouseWheel();
    }

    /// Returns true once the mouse has entered the app surface.
    pub fn mouseInsideSurface(self: Frame) bool {
        return self.state.isMouseInsideWindow();
    }

    /// Returns true while a mouse button is held.
    pub fn mouseButtonDown(self: Frame, button: input.MouseButton) bool {
        return self.state.isMouseButtonDown(button);
    }

    /// Returns true only on the frame a mouse button was pressed.
    pub fn mouseButtonPressed(self: Frame, button: input.MouseButton) bool {
        return self.state.wasMouseButtonPressed(button);
    }

    /// Returns true only on the frame a mouse button was released.
    pub fn mouseButtonReleased(self: Frame, button: input.MouseButton) bool {
        return self.state.wasMouseButtonReleased(button);
    }

    /// Returns the first press event for a digital action.
    pub fn firstActionPressed(self: Frame, action: input.DigitalActionId) ?input.DigitalActionEvent {
        for (self.event_items) |event| {
            switch (event) {
                .action_pressed => |item| {
                    if (item.action.index == action.index) return item;
                },
                else => {},
            }
        }

        return null;
    }

    /// Returns the first release event for a digital action.
    pub fn firstActionReleased(self: Frame, action: input.DigitalActionId) ?input.DigitalActionEvent {
        for (self.event_items) |event| {
            switch (event) {
                .action_released => |item| {
                    if (item.action.index == action.index) return item;
                },
                else => {},
            }
        }

        return null;
    }

    /// Returns the first press event for a digital action in a specific map.
    pub fn firstMapActionPressed(
        self: Frame,
        map: input.ActionMapId,
        action: input.DigitalActionId,
    ) ?input.DigitalActionEvent {
        for (self.event_items) |event| {
            switch (event) {
                .action_pressed => |item| {
                    if (item.map.eql(map) and item.action.index == action.index) return item;
                },
                else => {},
            }
        }

        return null;
    }

    /// Returns the first release event for a digital action in a specific map.
    pub fn firstMapActionReleased(
        self: Frame,
        map: input.ActionMapId,
        action: input.DigitalActionId,
    ) ?input.DigitalActionEvent {
        for (self.event_items) |event| {
            switch (event) {
                .action_released => |item| {
                    if (item.map.eql(map) and item.action.index == action.index) return item;
                },
                else => {},
            }
        }

        return null;
    }

    /// Returns the first changed event for a 1D axis action.
    pub fn firstAxis1Changed(self: Frame, action: input.Axis1ActionId) ?input.Axis1ActionEvent {
        for (self.event_items) |event| {
            switch (event) {
                .axis1_changed => |item| {
                    if (item.action.index == action.index) return item;
                },
                else => {},
            }
        }

        return null;
    }

    /// Returns the first changed event for a 2D axis action.
    pub fn firstAxis2Changed(self: Frame, action: input.Axis2ActionId) ?input.Axis2ActionEvent {
        for (self.event_items) |event| {
            switch (event) {
                .axis2_changed => |item| {
                    if (item.action.index == action.index) return item;
                },
                else => {},
            }
        }

        return null;
    }

    /// Returns the first mouse motion event in this frame.
    pub fn firstMouseMoved(self: Frame) ?input.MouseMotionEvent {
        for (self.event_items) |event| {
            switch (event) {
                .mouse_moved => |item| return item,
                else => {},
            }
        }

        return null;
    }

    /// Returns the first mouse button press event for a button.
    pub fn firstMouseButtonPressed(self: Frame, button: input.MouseButton) ?input.MouseButtonEvent {
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
    pub fn firstMouseButtonReleased(self: Frame, button: input.MouseButton) ?input.MouseButtonEvent {
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
    pub fn firstMouseScrolled(self: Frame) ?input.MouseWheelEvent {
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
    event_items: []const input.InputEvent,
    index: usize,

    /// Creates an iterator over an event slice.
    pub fn init(events: []const input.InputEvent) EventIterator {
        return .{
            .event_items = events,
            .index = 0,
        };
    }

    /// Returns the next event, or null when iteration is complete.
    pub fn next(self: *EventIterator) ?input.InputEvent {
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
