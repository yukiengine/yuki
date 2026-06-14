//! Frame-local input events.
//!
//! This module owns backend-neutral input event payloads and the fixed-capacity
//! queue used by the runtime to expose one-frame input transitions.

const types = @import("types.zig");

/// Shared 2D vector type used by pointer and axis event payloads.
pub const Vector2 = types.Vector2;

/// Maximum number of frame-local input events.
pub const max_input_events = types.max_input_events;

/// Handle to a digital action.
pub const DigitalActionId = types.DigitalActionId;

/// Handle to a one-dimensional action.
pub const Axis1ActionId = types.Axis1ActionId;

/// Handle to a two-dimensional action.
pub const Axis2ActionId = types.Axis2ActionId;

/// Handle to an action map.
pub const ActionMapId = types.ActionMapId;

/// Keyboard key enum used by keyboard input sources.
pub const Key = types.Key;

/// Mouse button enum used by mouse input sources.
pub const MouseButton = types.MouseButton;

/// Kind of physical source that produced an input event.
pub const InputSourceKind = enum(u8) {
    keyboard,
    mouse,
    gamepad,
};

/// Backend-neutral source metadata for an input event.
pub const InputSource = struct {
    kind: InputSourceKind,
    key: ?Key = null,
    mouse_button: ?MouseButton = null,
    gamepad_index: u8 = 0,

    /// Creates a keyboard input source.
    pub fn keyboard(key: Key) InputSource {
        return .{
            .kind = .keyboard,
            .key = key,
        };
    }

    /// Creates a mouse button input source.
    pub fn mouseButton(button: MouseButton) InputSource {
        return .{
            .kind = .mouse,
            .mouse_button = button,
        };
    }

    /// Creates a gamepad input source placeholder.
    pub fn gamepad(index: u8) InputSource {
        return .{
            .kind = .gamepad,
            .gamepad_index = index,
        };
    }
};

/// Event tags emitted by the input system during one frame.
pub const InputEventKind = enum(u8) {
    action_pressed,
    action_released,
    axis1_changed,
    axis2_changed,
    mouse_moved,
    mouse_button_pressed,
    mouse_button_released,
    mouse_scrolled,
};

/// Payload for digital action input events.
pub const DigitalActionEvent = struct {
    map: ActionMapId,
    action: DigitalActionId,
    source: InputSource,
};

/// Payload for one-dimensional axis input events.
pub const Axis1ActionEvent = struct {
    map: ActionMapId,
    action: Axis1ActionId,
    value: f32,
    previous: f32,
    source: InputSource,
};

/// Payload for two-dimensional axis input events.
pub const Axis2ActionEvent = struct {
    map: ActionMapId,
    action: Axis2ActionId,
    value: Vector2,
    previous: Vector2,
    source: InputSource,
};

/// Payload for mouse motion input events.
pub const MouseMotionEvent = struct {
    position: Vector2,
    delta: Vector2,
};

/// Payload for mouse button input events.
pub const MouseButtonEvent = struct {
    button: MouseButton,
    position: Vector2,
    source: InputSource,
};

/// Payload for mouse wheel input events.
pub const MouseWheelEvent = struct {
    wheel: Vector2,
    position: Vector2,
};

/// One frame-local input event.
pub const InputEvent = union(InputEventKind) {
    action_pressed: DigitalActionEvent,
    action_released: DigitalActionEvent,
    axis1_changed: Axis1ActionEvent,
    axis2_changed: Axis2ActionEvent,
    mouse_moved: MouseMotionEvent,
    mouse_button_pressed: MouseButtonEvent,
    mouse_button_released: MouseButtonEvent,
    mouse_scrolled: MouseWheelEvent,

    /// Returns the tag for this event.
    pub fn kind(self: InputEvent) InputEventKind {
        return switch (self) {
            .action_pressed => .action_pressed,
            .action_released => .action_released,
            .axis1_changed => .axis1_changed,
            .axis2_changed => .axis2_changed,
            .mouse_moved => .mouse_moved,
            .mouse_button_pressed => .mouse_button_pressed,
            .mouse_button_released => .mouse_button_released,
            .mouse_scrolled => .mouse_scrolled,
        };
    }
};

/// Fixed-capacity frame-local queue of input events.
pub const InputEventQueue = struct {
    events: [max_input_events]InputEvent,
    event_count: usize,
    dropped_count: usize,

    /// Creates an empty input event queue.
    pub fn init() InputEventQueue {
        return .{
            .events = undefined,
            .event_count = 0,
            .dropped_count = 0,
        };
    }

    /// Clears events from the previous frame.
    pub fn beginFrame(self: *InputEventQueue) void {
        self.event_count = 0;
        self.dropped_count = 0;
    }

    /// Returns true when the queue has no events.
    pub fn isEmpty(self: *const InputEventQueue) bool {
        return self.event_count == 0;
    }

    /// Returns the number of stored events.
    pub fn count(self: *const InputEventQueue) usize {
        return self.event_count;
    }

    /// Returns the number of events dropped because the queue was full.
    pub fn droppedCount(self: *const InputEventQueue) usize {
        return self.dropped_count;
    }

    /// Returns all events stored for the current frame.
    pub fn items(self: *const InputEventQueue) []const InputEvent {
        return self.events[0..self.event_count];
    }

    /// Appends one event, dropping it if the queue is full.
    pub fn push(self: *InputEventQueue, event: InputEvent) void {
        if (self.event_count == max_input_events) {
            self.dropped_count += 1;
            return;
        }

        self.events[self.event_count] = event;
        self.event_count += 1;
    }

    /// Records a digital action press.
    pub fn pushActionPressed(
        self: *InputEventQueue,
        map: ActionMapId,
        action: DigitalActionId,
        source: InputSource,
    ) void {
        self.push(.{
            .action_pressed = .{
                .map = map,
                .action = action,
                .source = source,
            },
        });
    }

    /// Records a digital action release.
    pub fn pushActionReleased(
        self: *InputEventQueue,
        map: ActionMapId,
        action: DigitalActionId,
        source: InputSource,
    ) void {
        self.push(.{
            .action_released = .{
                .map = map,
                .action = action,
                .source = source,
            },
        });
    }

    /// Records a 1D axis value change.
    pub fn pushAxis1Changed(
        self: *InputEventQueue,
        map: ActionMapId,
        action: Axis1ActionId,
        previous: f32,
        value: f32,
        source: InputSource,
    ) void {
        self.push(.{
            .axis1_changed = .{
                .map = map,
                .action = action,
                .previous = previous,
                .value = value,
                .source = source,
            },
        });
    }

    /// Records a 2D axis value change.
    pub fn pushAxis2Changed(
        self: *InputEventQueue,
        map: ActionMapId,
        action: Axis2ActionId,
        previous: Vector2,
        value: Vector2,
        source: InputSource,
    ) void {
        self.push(.{
            .axis2_changed = .{
                .map = map,
                .action = action,
                .previous = previous,
                .value = value,
                .source = source,
            },
        });
    }

    /// Records mouse movement.
    pub fn pushMouseMoved(self: *InputEventQueue, position: Vector2, delta: Vector2) void {
        self.push(.{
            .mouse_moved = .{
                .position = position,
                .delta = delta,
            },
        });
    }

    /// Records a mouse button press.
    pub fn pushMouseButtonPressed(
        self: *InputEventQueue,
        button: MouseButton,
        position: Vector2,
    ) void {
        self.push(.{
            .mouse_button_pressed = .{
                .button = button,
                .position = position,
                .source = InputSource.mouseButton(button),
            },
        });
    }

    /// Records a mouse button release.
    pub fn pushMouseButtonReleased(
        self: *InputEventQueue,
        button: MouseButton,
        position: Vector2,
    ) void {
        self.push(.{
            .mouse_button_released = .{
                .button = button,
                .position = position,
                .source = InputSource.mouseButton(button),
            },
        });
    }

    /// Records mouse wheel movement.
    pub fn pushMouseScrolled(self: *InputEventQueue, wheel: Vector2, position: Vector2) void {
        self.push(.{
            .mouse_scrolled = .{
                .wheel = wheel,
                .position = position,
            },
        });
    }
};
