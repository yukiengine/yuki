//! Frame-local script runtime context.
//!
//! ScriptContext is the Zig-side carrier for runtime systems that scripts reach
//! through Luau's `ctx` table. The first host implementation pushed an empty
//! readonly table because no runtime systems were wired yet. This type gives the
//! host a real, explicit value to pass through lifecycle calls before we bind
//! concrete Luau methods such as `ctx.input:map("gameplay")`.
//!
//! The context borrows runtime systems; it does not own input, world, or frame
//! state. That keeps ownership in the app/runtime layer and prevents scripts
//! from extending the lifetime of per-frame data.

const input = @import("../input/mod.zig");

/// Errors returned by script context runtime lookups.
pub const Error = error{
    MissingInput,
} || input.Error;

/// Runtime input owner borrowed by ScriptContext.
pub const InputSession = input.InputSession;

/// Read-only named input map view returned by context input helpers.
pub const NamedInputMapView = input.NamedInputMapView;

/// Shared vector type used by input axis and pointer helpers.
pub const Vector2 = input.Vector2;

/// Mouse button enum accepted by pointer button helpers.
pub const MouseButton = input.MouseButton;

/// Frame-local runtime systems available to a script callback.
pub const ScriptContext = struct {
    /// Borrowed input session for the current frame, when input is available.
    input_session: ?*const InputSession = null,

    /// Creates a context with no runtime systems attached.
    pub fn empty() ScriptContext {
        return .{};
    }

    /// Creates a context that exposes the current input session.
    pub fn fromInput(input_session: *const InputSession) ScriptContext {
        return .{
            .input_session = input_session,
        };
    }

    /// Returns a copy of this context with an input session attached.
    pub fn withInput(self: ScriptContext, input_session: *const InputSession) ScriptContext {
        var next = self;
        next.input_session = input_session;
        return next;
    }

    /// Returns true when input can be queried through this context.
    pub fn hasInput(self: ScriptContext) bool {
        return self.input_session != null;
    }

    /// Returns the borrowed input session or an explicit missing-input error.
    pub fn requireInput(self: ScriptContext) Error!*const InputSession {
        return self.input_session orelse Error.MissingInput;
    }

    /// Returns a read-only named input map view for a map name.
    pub fn inputMap(self: ScriptContext, map_name: []const u8) Error!NamedInputMapView {
        const session = try self.requireInput();
        return try session.namedMapViewByName(map_name);
    }

    /// Returns true when a named map exists and is active this frame.
    pub fn inputMapActive(self: ScriptContext, map_name: []const u8) Error!bool {
        const view = try self.inputMap(map_name);
        return view.isActive();
    }

    /// Returns true when a named map can process input this frame.
    pub fn inputMapCanProcess(self: ScriptContext, map_name: []const u8) Error!bool {
        const view = try self.inputMap(map_name);
        return view.canProcess();
    }

    /// Returns true while a named digital action is held.
    pub fn inputMapDown(
        self: ScriptContext,
        map_name: []const u8,
        action_name: []const u8,
    ) Error!bool {
        const view = try self.inputMap(map_name);
        return try view.digitalDown(action_name);
    }

    /// Returns true only on the frame a named digital action was pressed.
    pub fn inputMapPressed(
        self: ScriptContext,
        map_name: []const u8,
        action_name: []const u8,
    ) Error!bool {
        const view = try self.inputMap(map_name);
        return try view.digitalPressed(action_name);
    }

    /// Returns true only on the frame a named digital action was released.
    pub fn inputMapReleased(
        self: ScriptContext,
        map_name: []const u8,
        action_name: []const u8,
    ) Error!bool {
        const view = try self.inputMap(map_name);
        return try view.digitalReleased(action_name);
    }

    /// Returns the current numeric value for a named 1D axis action.
    pub fn inputMapAxis1(
        self: ScriptContext,
        map_name: []const u8,
        action_name: []const u8,
    ) Error!f32 {
        const view = try self.inputMap(map_name);
        return try view.axis1(action_name);
    }

    /// Returns the current vector value for a named 2D axis action.
    pub fn inputMapAxis2(
        self: ScriptContext,
        map_name: []const u8,
        action_name: []const u8,
    ) Error!Vector2 {
        const view = try self.inputMap(map_name);
        return try view.axis2(action_name);
    }

    /// Returns the current mouse position for a map-scoped input view.
    pub fn inputMapMousePosition(self: ScriptContext, map_name: []const u8) Error!Vector2 {
        const view = try self.inputMap(map_name);
        return view.mousePosition();
    }

    /// Returns mouse movement accumulated during the current frame.
    pub fn inputMapMouseDelta(self: ScriptContext, map_name: []const u8) Error!Vector2 {
        const view = try self.inputMap(map_name);
        return view.mouseDelta();
    }

    /// Returns mouse wheel movement accumulated during the current frame.
    pub fn inputMapMouseWheel(self: ScriptContext, map_name: []const u8) Error!Vector2 {
        const view = try self.inputMap(map_name);
        return view.mouseWheel();
    }

    /// Returns true once the pointer has entered the app surface.
    pub fn inputMapMouseInsideSurface(self: ScriptContext, map_name: []const u8) Error!bool {
        const view = try self.inputMap(map_name);
        return view.mouseInsideSurface();
    }

    /// Returns true while a mouse button is held.
    pub fn inputMapMouseButtonDown(
        self: ScriptContext,
        map_name: []const u8,
        button: MouseButton,
    ) Error!bool {
        const view = try self.inputMap(map_name);
        return view.mouseButtonDown(button);
    }

    /// Returns true only on the frame a mouse button was pressed.
    pub fn inputMapMouseButtonPressed(
        self: ScriptContext,
        map_name: []const u8,
        button: MouseButton,
    ) Error!bool {
        const view = try self.inputMap(map_name);
        return view.mouseButtonPressed(button);
    }

    /// Returns true only on the frame a mouse button was released.
    pub fn inputMapMouseButtonReleased(
        self: ScriptContext,
        map_name: []const u8,
        button: MouseButton,
    ) Error!bool {
        const view = try self.inputMap(map_name);
        return view.mouseButtonReleased(button);
    }
};
