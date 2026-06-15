//! Named input event reader.
//!
//! This module turns frame-local input events from handle-based runtime data
//! into name-based API data. Runtime systems should keep using handles, but
//! Luau/debug-facing code should receive stable map/action names instead of raw
//! integer slots.

const std = @import("std");
const types = @import("types.zig");
const events_mod = @import("events.zig");
const registry_mod = @import("registry.zig");

/// Shared 2D vector type used by pointer and axis event payloads.
pub const Vector2 = types.Vector2;

/// Handle to a named action map.
pub const ActionMapId = types.ActionMapId;

/// Handle to a digital action.
pub const DigitalActionId = types.DigitalActionId;

/// Handle to a one-dimensional axis action.
pub const Axis1ActionId = types.Axis1ActionId;

/// Handle to a two-dimensional axis action.
pub const Axis2ActionId = types.Axis2ActionId;

/// Backend-neutral source metadata for an input event.
pub const InputSource = events_mod.InputSource;

/// Mouse button enum used by pointer events.
pub const MouseButton = types.MouseButton;

/// Raw frame-local input event.
pub const InputEvent = events_mod.InputEvent;

/// Named action registry used to resolve handles into stable names.
pub const ActionRegistry = registry_mod.ActionRegistry;

/// Named digital action event payload for script/debug-facing APIs.
pub const NamedDigitalActionEvent = struct {
    map: ActionMapId,
    map_name: []const u8,
    action: DigitalActionId,
    action_name: []const u8,
    source: InputSource,
};

/// Named 1D axis event payload for script/debug-facing APIs.
pub const NamedAxis1ActionEvent = struct {
    map: ActionMapId,
    map_name: []const u8,
    action: Axis1ActionId,
    action_name: []const u8,
    previous: f32,
    value: f32,
    source: InputSource,
};

/// Named 2D axis event payload for script/debug-facing APIs.
pub const NamedAxis2ActionEvent = struct {
    map: ActionMapId,
    map_name: []const u8,
    action: Axis2ActionId,
    action_name: []const u8,
    previous: Vector2,
    value: Vector2,
    source: InputSource,
};

/// Named mouse motion event payload.
pub const NamedMouseMotionEvent = struct {
    position: Vector2,
    delta: Vector2,
};

/// Named mouse button event payload.
pub const NamedMouseButtonEvent = struct {
    button: MouseButton,
    position: Vector2,
    source: InputSource,
};

/// Named mouse wheel event payload.
pub const NamedMouseWheelEvent = struct {
    wheel: Vector2,
    position: Vector2,
};

/// Script/debug-facing input event with action names attached.
pub const NamedInputEvent = union(enum) {
    action_pressed: NamedDigitalActionEvent,
    action_released: NamedDigitalActionEvent,
    axis1_changed: NamedAxis1ActionEvent,
    axis2_changed: NamedAxis2ActionEvent,
    mouse_moved: NamedMouseMotionEvent,
    mouse_button_pressed: NamedMouseButtonEvent,
    mouse_button_released: NamedMouseButtonEvent,
    mouse_scrolled: NamedMouseWheelEvent,

    /// Returns true when this event is an action event bound to a named map.
    pub fn isActionEvent(self: NamedInputEvent) bool {
        return switch (self) {
            .action_pressed,
            .action_released,
            .axis1_changed,
            .axis2_changed,
            => true,

            .mouse_moved,
            .mouse_button_pressed,
            .mouse_button_released,
            .mouse_scrolled,
            => false,
        };
    }

    /// Returns the action name for action events, or null for pointer events.
    pub fn actionName(self: NamedInputEvent) ?[]const u8 {
        return switch (self) {
            .action_pressed => |event| event.action_name,
            .action_released => |event| event.action_name,
            .axis1_changed => |event| event.action_name,
            .axis2_changed => |event| event.action_name,
            else => null,
        };
    }

    /// Returns the map name for action events, or null for pointer events.
    pub fn mapName(self: NamedInputEvent) ?[]const u8 {
        return switch (self) {
            .action_pressed => |event| event.map_name,
            .action_released => |event| event.map_name,
            .axis1_changed => |event| event.map_name,
            .axis2_changed => |event| event.map_name,
            else => null,
        };
    }
};

/// Read-only map-scoped reader that resolves raw input events into names.
pub const NamedEventReader = struct {
    registry: *const ActionRegistry,
    map: ActionMapId,
    event_items: []const InputEvent,

    /// Creates a named event reader for one action map.
    pub fn init(
        registry: *const ActionRegistry,
        map: ActionMapId,
        input_events: []const InputEvent,
    ) NamedEventReader {
        return .{
            .registry = registry,
            .map = map,
            .event_items = input_events,
        };
    }

    /// Returns all raw events visible to this reader.
    pub fn rawEvents(self: NamedEventReader) []const InputEvent {
        return self.event_items;
    }

    /// Returns the number of raw events visible to this reader.
    pub fn count(self: NamedEventReader) usize {
        return self.event_items.len;
    }

    /// Returns true when no raw events are visible.
    pub fn isEmpty(self: NamedEventReader) bool {
        return self.event_items.len == 0;
    }

    /// Returns a forward-only iterator over named events.
    pub fn iter(self: NamedEventReader) NamedEventIterator {
        return NamedEventIterator.init(self);
    }

    /// Converts one raw event into a named event when it belongs to this map.
    pub fn describe(self: NamedEventReader, event: InputEvent) ?NamedInputEvent {
        return switch (event) {
            .action_pressed => |item| self.describeActionPressed(item),
            .action_released => |item| self.describeActionReleased(item),
            .axis1_changed => |item| self.describeAxis1Changed(item),
            .axis2_changed => |item| self.describeAxis2Changed(item),
            .mouse_moved => |item| .{
                .mouse_moved = .{
                    .position = item.position,
                    .delta = item.delta,
                },
            },
            .mouse_button_pressed => |item| .{
                .mouse_button_pressed = .{
                    .button = item.button,
                    .position = item.position,
                    .source = item.source,
                },
            },
            .mouse_button_released => |item| .{
                .mouse_button_released = .{
                    .button = item.button,
                    .position = item.position,
                    .source = item.source,
                },
            },
            .mouse_scrolled => |item| .{
                .mouse_scrolled = .{
                    .wheel = item.wheel,
                    .position = item.position,
                },
            },
        };
    }

    /// Returns the first named event in this reader.
    pub fn first(self: NamedEventReader) ?NamedInputEvent {
        var iterator = self.iter();
        return iterator.next();
    }

    /// Returns the first named press event for an action name.
    pub fn firstActionPressed(self: NamedEventReader, action_name: []const u8) ?NamedDigitalActionEvent {
        var iterator = self.iter();

        while (iterator.next()) |event| {
            switch (event) {
                .action_pressed => |item| {
                    if (std.mem.eql(u8, item.action_name, action_name)) return item;
                },
                else => {},
            }
        }

        return null;
    }

    /// Returns the first named release event for an action name.
    pub fn firstActionReleased(self: NamedEventReader, action_name: []const u8) ?NamedDigitalActionEvent {
        var iterator = self.iter();

        while (iterator.next()) |event| {
            switch (event) {
                .action_released => |item| {
                    if (std.mem.eql(u8, item.action_name, action_name)) return item;
                },
                else => {},
            }
        }

        return null;
    }

    /// Returns the first named 1D axis change event for an action name.
    pub fn firstAxis1Changed(self: NamedEventReader, action_name: []const u8) ?NamedAxis1ActionEvent {
        var iterator = self.iter();

        while (iterator.next()) |event| {
            switch (event) {
                .axis1_changed => |item| {
                    if (std.mem.eql(u8, item.action_name, action_name)) return item;
                },
                else => {},
            }
        }

        return null;
    }

    /// Returns the first named 2D axis change event for an action name.
    pub fn firstAxis2Changed(self: NamedEventReader, action_name: []const u8) ?NamedAxis2ActionEvent {
        var iterator = self.iter();

        while (iterator.next()) |event| {
            switch (event) {
                .axis2_changed => |item| {
                    if (std.mem.eql(u8, item.action_name, action_name)) return item;
                },
                else => {},
            }
        }

        return null;
    }

    /// Describes a digital press event when it belongs to this reader's map.
    fn describeActionPressed(
        self: NamedEventReader,
        event: events_mod.DigitalActionEvent,
    ) ?NamedInputEvent {
        if (!event.map.eql(self.map)) return null;

        const map_name = self.registry.mapName(event.map) orelse return null;
        const action = self.registry.digitalInfo(event.action) orelse return null;
        if (!action.map.eql(event.map)) return null;

        return .{
            .action_pressed = .{
                .map = event.map,
                .map_name = map_name,
                .action = event.action,
                .action_name = action.name,
                .source = event.source,
            },
        };
    }

    /// Describes a digital release event when it belongs to this reader's map.
    fn describeActionReleased(
        self: NamedEventReader,
        event: events_mod.DigitalActionEvent,
    ) ?NamedInputEvent {
        if (!event.map.eql(self.map)) return null;

        const map_name = self.registry.mapName(event.map) orelse return null;
        const action = self.registry.digitalInfo(event.action) orelse return null;
        if (!action.map.eql(event.map)) return null;

        return .{
            .action_released = .{
                .map = event.map,
                .map_name = map_name,
                .action = event.action,
                .action_name = action.name,
                .source = event.source,
            },
        };
    }

    /// Describes a 1D axis change event when it belongs to this reader's map.
    fn describeAxis1Changed(
        self: NamedEventReader,
        event: events_mod.Axis1ActionEvent,
    ) ?NamedInputEvent {
        if (!event.map.eql(self.map)) return null;

        const map_name = self.registry.mapName(event.map) orelse return null;
        const action = self.registry.axis1Info(event.action) orelse return null;
        if (!action.map.eql(event.map)) return null;

        return .{
            .axis1_changed = .{
                .map = event.map,
                .map_name = map_name,
                .action = event.action,
                .action_name = action.name,
                .previous = event.previous,
                .value = event.value,
                .source = event.source,
            },
        };
    }

    /// Describes a 2D axis change event when it belongs to this reader's map.
    fn describeAxis2Changed(
        self: NamedEventReader,
        event: events_mod.Axis2ActionEvent,
    ) ?NamedInputEvent {
        if (!event.map.eql(self.map)) return null;

        const map_name = self.registry.mapName(event.map) orelse return null;
        const action = self.registry.axis2Info(event.action) orelse return null;
        if (!action.map.eql(event.map)) return null;

        return .{
            .axis2_changed = .{
                .map = event.map,
                .map_name = map_name,
                .action = event.action,
                .action_name = action.name,
                .previous = event.previous,
                .value = event.value,
                .source = event.source,
            },
        };
    }
};

/// Iterator that yields named events and skips action events from other maps.
pub const NamedEventIterator = struct {
    reader: NamedEventReader,
    index: usize,

    /// Creates an iterator over a named event reader.
    pub fn init(reader: NamedEventReader) NamedEventIterator {
        return .{
            .reader = reader,
            .index = 0,
        };
    }

    /// Returns the next named event, skipping events that cannot be described.
    pub fn next(self: *NamedEventIterator) ?NamedInputEvent {
        while (self.index < self.reader.event_items.len) {
            const raw = self.reader.event_items[self.index];
            self.index += 1;

            if (self.reader.describe(raw)) |event| return event;
        }

        return null;
    }

    /// Restarts iteration from the first event.
    pub fn reset(self: *NamedEventIterator) void {
        self.index = 0;
    }
};
