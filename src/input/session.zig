//! Input session.
//!
//! InputSession owns the runtime input state, event queue, router, and action
//! registry as one API-facing object.

const types = @import("types.zig");
const events_mod = @import("events.zig");
const state_mod = @import("state.zig");
const registry_mod = @import("registry.zig");
const context_mod = @import("context.zig");
const action_map_mod = @import("action_map.zig");
const router_mod = @import("router.zig");
const event_reader_mod = @import("event_reader.zig");
const named_frame_mod = @import("named_frame.zig");
const named_context_mod = @import("named_context.zig");
const binding_descriptors_mod = @import("binding_descriptors.zig");
const named_map_view_mod = @import("named_map_view.zig");

/// Shared input error set.
pub const Error = types.Error;

/// Shared 2D vector type.
pub const Vector2 = types.Vector2;

/// Keyboard key enum used by the input router.
pub const Key = types.Key;

/// Mouse button enum used by the input router.
pub const MouseButton = types.MouseButton;

/// Handle to an action map.
pub const ActionMapId = types.ActionMapId;

/// Frame-local input events.
pub const InputEvent = events_mod.InputEvent;

/// Frame-local input event queue.
pub const InputEventQueue = events_mod.InputEventQueue;

/// Resolved input state.
pub const State = state_mod.State;

/// Named action registry.
pub const ActionRegistry = registry_mod.ActionRegistry;

/// Active action-map options.
pub const ActiveMapOptions = context_mod.ActiveMapOptions;

/// Active action-map context.
pub const InputContext = context_mod.InputContext;

/// Runtime action map.
pub const ActionMap = action_map_mod.ActionMap;

/// Runtime input router.
pub const InputRouter = router_mod.InputRouter;

/// Read-only event query helper.
pub const EventReader = event_reader_mod.EventReader;

/// Named read-only frame helper.
pub const NamedFrame = named_frame_mod.NamedFrame;

/// Named active input context helper.
pub const NamedInputContext = named_context_mod.NamedInputContext;

/// Read-only named binding descriptor helper.
pub const NamedBindingReader = binding_descriptors_mod.NamedBindingReader;

/// Read-only map-scoped named input API view.
pub const NamedInputMapView = named_map_view_mod.NamedInputMapView;

/// Runtime owner for input registry, routing, resolved state, and events.
pub const InputSession = struct {
    registry: ActionRegistry,
    router: InputRouter,
    state: State,
    events: InputEventQueue,

    /// Creates an input session from a registry and router.
    pub fn init(registry: ActionRegistry, router: InputRouter) InputSession {
        return .{
            .registry = registry,
            .router = router,
            .state = State.init(),
            .events = InputEventQueue.init(),
        };
    }

    /// Creates an empty input session with no registered maps.
    pub fn empty() InputSession {
        return InputSession.init(
            ActionRegistry.init(),
            InputRouter.init(),
        );
    }

    /// Replaces all session data with an empty input setup.
    pub fn clear(self: *InputSession) void {
        self.registry = ActionRegistry.init();
        self.router = InputRouter.init();
        self.state = State.init();
        self.events = InputEventQueue.init();
    }

    /// Clears frame-local input edges and event items.
    pub fn beginFrame(self: *InputSession) void {
        self.state.beginFrame();
        self.events.beginFrame();
    }

    /// Releases all held input state without emitting release events.
    pub fn releaseAll(self: *InputSession) void {
        self.state.releaseAll();
    }

    /// Returns the named action registry.
    pub fn actionRegistry(self: *const InputSession) *const ActionRegistry {
        return &self.registry;
    }

    /// Returns mutable access to the named action registry.
    pub fn actionRegistryMut(self: *InputSession) *ActionRegistry {
        return &self.registry;
    }

    /// Returns the input router.
    pub fn inputRouter(self: *const InputSession) *const InputRouter {
        return &self.router;
    }

    /// Returns mutable access to the input router.
    pub fn inputRouterMut(self: *InputSession) *InputRouter {
        return &self.router;
    }

    /// Returns the number of installed action maps.
    pub fn installedMapCount(self: *const InputSession) usize {
        return self.router.mapCount();
    }

    /// Returns a read-only installed action map by id.
    pub fn actionMap(self: *const InputSession, map: ActionMapId) ?*const ActionMap {
        return self.router.actionMap(map);
    }

    /// Returns the resolved input state.
    pub fn inputState(self: *const InputSession) *const State {
        return &self.state;
    }

    /// Returns mutable access to the resolved input state.
    pub fn inputStateMut(self: *InputSession) *State {
        return &self.state;
    }

    /// Returns the current frame-local event items.
    pub fn inputEvents(self: *const InputSession) []const InputEvent {
        return self.events.items();
    }

    /// Returns a read-only event query object.
    pub fn reader(self: *const InputSession) EventReader {
        return EventReader.init(self.events.items());
    }

    /// Returns the number of frame-local input events.
    pub fn eventCount(self: *const InputSession) usize {
        return self.events.count();
    }

    /// Returns the number of frame-local input events that were dropped.
    pub fn droppedEvents(self: *const InputSession) usize {
        return self.events.droppedCount();
    }

    /// Installs or replaces one action map in the router.
    pub fn putMap(self: *InputSession, map: ActionMapId, action_map: ActionMap) !void {
        try self.router.putMap(map, action_map);
    }

    /// Enables an installed map with default options.
    pub fn pushMap(self: *InputSession, map: ActionMapId) !void {
        try self.router.pushMap(map);
    }

    /// Enables an installed map with explicit options.
    pub fn pushMapOptions(
        self: *InputSession,
        map: ActionMapId,
        options: ActiveMapOptions,
    ) !void {
        try self.router.pushMapOptions(map, options);
    }

    /// Disables an active map and returns true when it was active.
    pub fn popMap(self: *InputSession, map: ActionMapId) bool {
        return self.router.popMap(map);
    }

    /// Enables an installed map by registry name.
    pub fn pushMapByName(self: *InputSession, map_name: []const u8) !void {
        try self.pushMap(try self.requireMap(map_name));
    }

    /// Enables an installed map by registry name with explicit options.
    pub fn pushMapOptionsByName(
        self: *InputSession,
        map_name: []const u8,
        options: ActiveMapOptions,
    ) !void {
        try self.pushMapOptions(try self.requireMap(map_name), options);
    }

    /// Disables an active map by registry name.
    pub fn popMapByName(self: *InputSession, map_name: []const u8) !bool {
        return self.popMap(try self.requireMap(map_name));
    }

    /// Returns the active input context.
    pub fn activeContext(self: *const InputSession) *const InputContext {
        return self.router.activeContext();
    }

    /// Returns a name-based view of the active input context.
    pub fn namedActiveContext(self: *const InputSession) NamedInputContext {
        return NamedInputContext.init(
            &self.registry,
            self.router.activeContext(),
        );
    }

    /// Returns a read-only named binding view for one installed map.
    pub fn namedBindingReader(self: *const InputSession, map: ActionMapId) !NamedBindingReader {
        const action_map = self.actionMap(map) orelse return Error.UnknownActionMap;

        return NamedBindingReader.init(
            &self.registry,
            map,
            action_map,
        );
    }

    /// Returns a read-only named binding view by resolving a map name.
    pub fn namedBindingReaderByName(self: *const InputSession, map_name: []const u8) !NamedBindingReader {
        const map = try self.requireMap(map_name);
        return self.namedBindingReader(map);
    }

    /// Returns a read-only named API view for one installed map.
    pub fn namedMapView(self: *const InputSession, map: ActionMapId) !NamedInputMapView {
        const action_map = self.actionMap(map) orelse return Error.UnknownActionMap;

        return NamedInputMapView.init(
            &self.registry,
            map,
            action_map,
            &self.state,
            self.events.items(),
            self.router.activeContext(),
        );
    }

    /// Returns a read-only named API view by resolving a map name.
    pub fn namedMapViewByName(self: *const InputSession, map_name: []const u8) !NamedInputMapView {
        const map = try self.requireMap(map_name);
        return self.namedMapView(map);
    }

    /// Applies one keyboard event through the active action maps.
    pub fn applyKey(
        self: *InputSession,
        key: Key,
        down: bool,
        repeated: bool,
    ) !void {
        try self.router.applyKeyWithEvents(
            &self.state,
            &self.events,
            key,
            down,
            repeated,
        );
    }

    /// Applies mouse motion directly to pointer state and events.
    pub fn applyMouseMotion(self: *InputSession, position: Vector2) void {
        self.state.setMousePositionWithEvents(
            &self.events,
            position,
        );
    }

    /// Applies one mouse button event through the active action maps.
    pub fn applyMouseButton(
        self: *InputSession,
        button: MouseButton,
        down: bool,
        position: Vector2,
    ) !void {
        try self.router.applyMouseButtonWithEvents(
            &self.state,
            &self.events,
            button,
            down,
            position,
        );
    }

    /// Applies mouse wheel movement to pointer state and events.
    pub fn applyMouseWheel(
        self: *InputSession,
        wheel: Vector2,
        position: Vector2,
    ) void {
        self.state.addMouseWheelWithEvents(
            &self.events,
            wheel,
            position,
        );
    }

    /// Returns a named frame view for one resolved map.
    pub fn namedFrame(self: *const InputSession, map: ActionMapId) NamedFrame {
        return NamedFrame.init(
            &self.registry,
            map,
            &self.state,
            self.events.items(),
        );
    }

    /// Returns a named frame view by resolving a map name.
    pub fn namedFrameByName(self: *const InputSession, map_name: []const u8) !NamedFrame {
        return NamedFrame.fromMapName(
            &self.registry,
            map_name,
            &self.state,
            self.events.items(),
        );
    }

    /// Resolves a registered map name.
    fn requireMap(self: *const InputSession, map_name: []const u8) !ActionMapId {
        return self.registry.findMap(map_name) orelse Error.UnknownActionMap;
    }
};
