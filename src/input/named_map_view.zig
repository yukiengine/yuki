//! Map-scoped named input API view.
//!
//! This module packages the read-only input data that a script/debug API usually
//! wants for one action map: current action values, frame-local named events,
//! active-context state, and binding descriptors.
//!
//! The view does not own input data and does not mutate routing. It borrows
//! InputSession internals through const pointers so the public API stays close to
//! the real runtime state.

const types = @import("types.zig");
const events_mod = @import("events.zig");
const state_mod = @import("state.zig");
const registry_mod = @import("registry.zig");
const context_mod = @import("context.zig");
const action_map_mod = @import("action_map.zig");
const named_frame_mod = @import("named_frame.zig");
const named_events_mod = @import("named_events.zig");
const binding_descriptors_mod = @import("binding_descriptors.zig");
const named_context_mod = @import("named_context.zig");

/// Shared input error set.
pub const Error = types.Error;

/// Shared 2D vector type.
pub const Vector2 = types.Vector2;

/// Handle to a named action map.
pub const ActionMapId = types.ActionMapId;

/// Handle to a digital action.
pub const DigitalActionId = types.DigitalActionId;

/// Handle to a one-dimensional axis action.
pub const Axis1ActionId = types.Axis1ActionId;

/// Handle to a two-dimensional axis action.
pub const Axis2ActionId = types.Axis2ActionId;

/// Type-safe reference to any registered action.
pub const ActionRef = types.ActionRef;

/// Frame-local input event.
pub const InputEvent = events_mod.InputEvent;

/// Resolved runtime input state.
pub const State = state_mod.State;

/// Named action registry.
pub const ActionRegistry = registry_mod.ActionRegistry;

/// Active action-map context.
pub const InputContext = context_mod.InputContext;

/// Runtime action map.
pub const ActionMap = action_map_mod.ActionMap;

/// Named frame state facade.
pub const NamedFrame = named_frame_mod.NamedFrame;

/// Named input event reader.
pub const NamedEventReader = named_events_mod.NamedEventReader;

/// Named digital action event payload.
pub const NamedDigitalActionEvent = named_events_mod.NamedDigitalActionEvent;

/// Named 1D axis action event payload.
pub const NamedAxis1ActionEvent = named_events_mod.NamedAxis1ActionEvent;

/// Named 2D axis action event payload.
pub const NamedAxis2ActionEvent = named_events_mod.NamedAxis2ActionEvent;

/// Mouse button enum used by pointer queries.
pub const MouseButton = types.MouseButton;

/// Named mouse motion event payload.
pub const NamedMouseMotionEvent = named_events_mod.NamedMouseMotionEvent;

/// Named mouse button event payload.
pub const NamedMouseButtonEvent = named_events_mod.NamedMouseButtonEvent;

/// Named mouse wheel event payload.
pub const NamedMouseWheelEvent = named_events_mod.NamedMouseWheelEvent;

/// Named binding descriptor.
pub const NamedBinding = binding_descriptors_mod.NamedBinding;

/// Named binding reader.
pub const NamedBindingReader = binding_descriptors_mod.NamedBindingReader;

/// Named active context reader.
pub const NamedInputContext = named_context_mod.NamedInputContext;

/// Named active map descriptor.
pub const NamedActiveMap = named_context_mod.NamedActiveMap;

/// Read-only API view for one named input map.
pub const NamedInputMapView = struct {
    registry: *const ActionRegistry,
    map: ActionMapId,
    action_map: *const ActionMap,
    state: *const State,
    event_items: []const InputEvent,
    context: *const InputContext,

    /// Creates a read-only view over one installed action map.
    pub fn init(
        registry: *const ActionRegistry,
        map: ActionMapId,
        action_map: *const ActionMap,
        state: *const State,
        input_events: []const InputEvent,
        context: *const InputContext,
    ) NamedInputMapView {
        return .{
            .registry = registry,
            .map = map,
            .action_map = action_map,
            .state = state,
            .event_items = input_events,
            .context = context,
        };
    }

    /// Returns the map handle this view describes.
    pub fn mapId(self: NamedInputMapView) ActionMapId {
        return self.map;
    }

    /// Returns the stable map name for this view.
    pub fn mapName(self: NamedInputMapView) ![]const u8 {
        return self.registry.mapName(self.map) orelse Error.UnknownActionMap;
    }

    /// Returns true when this map is currently active.
    pub fn isActive(self: NamedInputMapView) bool {
        return self.context.containsMap(self.map);
    }

    /// Returns true when this map receives input after modal/blocking rules.
    pub fn canProcess(self: NamedInputMapView) bool {
        return self.context.canProcessMap(self.map);
    }

    /// Returns this map's active-context descriptor, if the map is active.
    pub fn activeEntry(self: NamedInputMapView) ?NamedActiveMap {
        const active = self.context.findMap(self.map) orelse return null;
        return self.namedContext().describe(active);
    }

    /// Returns a named frame facade for current action values.
    pub fn frame(self: NamedInputMapView) NamedFrame {
        return NamedFrame.init(
            self.registry,
            self.map,
            self.state,
            self.event_items,
        );
    }

    /// Returns a named event reader scoped to this map.
    pub fn namedEvents(self: NamedInputMapView) NamedEventReader {
        return NamedEventReader.init(
            self.registry,
            self.map,
            self.event_items,
        );
    }

    /// Returns a named binding reader scoped to this map.
    pub fn bindings(self: NamedInputMapView) NamedBindingReader {
        return NamedBindingReader.init(
            self.registry,
            self.map,
            self.action_map,
        );
    }

    /// Returns a named view of the active input context.
    pub fn namedContext(self: NamedInputMapView) NamedInputContext {
        return NamedInputContext.init(
            self.registry,
            self.context,
        );
    }

    /// Returns the number of raw bindings installed on this map.
    pub fn bindingCount(self: NamedInputMapView) usize {
        return self.bindings().count();
    }

    /// Counts bindings that target a named action.
    pub fn bindingCountForAction(self: NamedInputMapView, action_name: []const u8) !usize {
        _ = try self.requireAction(action_name);
        return self.bindings().countForAction(action_name);
    }

    /// Returns the first binding descriptor for a named action.
    pub fn firstBindingForAction(self: NamedInputMapView, action_name: []const u8) !?NamedBinding {
        _ = try self.requireAction(action_name);
        return self.bindings().firstForAction(action_name);
    }

    /// Returns true when a named action has at least one binding.
    pub fn hasBindingForAction(self: NamedInputMapView, action_name: []const u8) !bool {
        return (try self.firstBindingForAction(action_name)) != null;
    }

    /// Returns true while a named digital action is held.
    pub fn digitalDown(self: NamedInputMapView, action_name: []const u8) !bool {
        return self.frame().digitalDown(action_name);
    }

    /// Returns true only on the frame a named digital action was pressed.
    pub fn digitalPressed(self: NamedInputMapView, action_name: []const u8) !bool {
        return self.frame().digitalPressed(action_name);
    }

    /// Returns true only on the frame a named digital action was released.
    pub fn digitalReleased(self: NamedInputMapView, action_name: []const u8) !bool {
        return self.frame().digitalReleased(action_name);
    }

    /// Returns the current value for a named 1D axis action.
    pub fn axis1(self: NamedInputMapView, action_name: []const u8) !f32 {
        return self.frame().axis1(action_name);
    }

    /// Returns true when a named 1D axis changed during this frame.
    pub fn axis1Changed(self: NamedInputMapView, action_name: []const u8) !bool {
        return self.frame().axis1Changed(action_name);
    }

    /// Returns the current value for a named 2D axis action.
    pub fn axis2(self: NamedInputMapView, action_name: []const u8) !Vector2 {
        return self.frame().axis2(action_name);
    }

    /// Returns true when a named 2D axis changed during this frame.
    pub fn axis2Changed(self: NamedInputMapView, action_name: []const u8) !bool {
        return self.frame().axis2Changed(action_name);
    }

    /// Returns the current mouse position in screen pixels.
    pub fn mousePosition(self: NamedInputMapView) Vector2 {
        return self.state.mousePosition();
    }

    /// Returns mouse movement accumulated during this frame.
    pub fn mouseDelta(self: NamedInputMapView) Vector2 {
        return self.state.mouseDelta();
    }

    /// Returns mouse wheel movement accumulated during this frame.
    pub fn mouseWheel(self: NamedInputMapView) Vector2 {
        return self.state.mouseWheel();
    }

    /// Returns true once the mouse has entered the app surface.
    pub fn mouseInsideSurface(self: NamedInputMapView) bool {
        return self.state.isMouseInsideWindow();
    }

    /// Returns true while a mouse button is held.
    pub fn mouseButtonDown(self: NamedInputMapView, button: MouseButton) bool {
        return self.state.isMouseButtonDown(button);
    }

    /// Returns true only on the frame a mouse button was pressed.
    pub fn mouseButtonPressed(self: NamedInputMapView, button: MouseButton) bool {
        return self.state.wasMouseButtonPressed(button);
    }

    /// Returns true only on the frame a mouse button was released.
    pub fn mouseButtonReleased(self: NamedInputMapView, button: MouseButton) bool {
        return self.state.wasMouseButtonReleased(button);
    }

    /// Returns the first mouse motion event in this frame.
    pub fn firstMouseMoved(self: NamedInputMapView) ?NamedMouseMotionEvent {
        var iterator = self.namedEvents().iter();

        while (iterator.next()) |event| {
            switch (event) {
                .mouse_moved => |item| return item,
                else => {},
            }
        }

        return null;
    }

    /// Returns the first mouse button press event for a button.
    pub fn firstMouseButtonPressed(
        self: NamedInputMapView,
        button: MouseButton,
    ) ?NamedMouseButtonEvent {
        var iterator = self.namedEvents().iter();

        while (iterator.next()) |event| {
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
    pub fn firstMouseButtonReleased(
        self: NamedInputMapView,
        button: MouseButton,
    ) ?NamedMouseButtonEvent {
        var iterator = self.namedEvents().iter();

        while (iterator.next()) |event| {
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
    pub fn firstMouseScrolled(self: NamedInputMapView) ?NamedMouseWheelEvent {
        var iterator = self.namedEvents().iter();

        while (iterator.next()) |event| {
            switch (event) {
                .mouse_scrolled => |item| return item,
                else => {},
            }
        }

        return null;
    }

    /// Returns the first named press event for a digital action.
    pub fn firstActionPressed(
        self: NamedInputMapView,
        action_name: []const u8,
    ) !?NamedDigitalActionEvent {
        _ = try self.requireDigital(action_name);
        return self.namedEvents().firstActionPressed(action_name);
    }

    /// Returns the first named release event for a digital action.
    pub fn firstActionReleased(
        self: NamedInputMapView,
        action_name: []const u8,
    ) !?NamedDigitalActionEvent {
        _ = try self.requireDigital(action_name);
        return self.namedEvents().firstActionReleased(action_name);
    }

    /// Returns the first named 1D axis change event.
    pub fn firstAxis1Changed(
        self: NamedInputMapView,
        action_name: []const u8,
    ) !?NamedAxis1ActionEvent {
        _ = try self.requireAxis1(action_name);
        return self.namedEvents().firstAxis1Changed(action_name);
    }

    /// Returns the first named 2D axis change event.
    pub fn firstAxis2Changed(
        self: NamedInputMapView,
        action_name: []const u8,
    ) !?NamedAxis2ActionEvent {
        _ = try self.requireAxis2(action_name);
        return self.namedEvents().firstAxis2Changed(action_name);
    }

    /// Resolves any named action inside this map.
    fn requireAction(self: NamedInputMapView, action_name: []const u8) !ActionRef {
        return self.registry.findAction(self.map, action_name) orelse Error.UnknownActionName;
    }

    /// Resolves a named digital action inside this map.
    fn requireDigital(self: NamedInputMapView, action_name: []const u8) !DigitalActionId {
        return self.registry.findDigital(self.map, action_name) orelse Error.UnknownActionName;
    }

    /// Resolves a named 1D axis action inside this map.
    fn requireAxis1(self: NamedInputMapView, action_name: []const u8) !Axis1ActionId {
        return self.registry.findAxis1(self.map, action_name) orelse Error.UnknownActionName;
    }

    /// Resolves a named 2D axis action inside this map.
    fn requireAxis2(self: NamedInputMapView, action_name: []const u8) !Axis2ActionId {
        return self.registry.findAxis2(self.map, action_name) orelse Error.UnknownActionName;
    }
};
