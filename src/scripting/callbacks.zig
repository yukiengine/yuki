//! Shared Luau callback runtime helpers.
//!
//! Luau API bindings such as `ctx.input` and `ctx.world` are implemented as C
//! callbacks. Those callbacks need the same host-owned runtime state: the
//! current frame ScriptContext, an active/inactive lifecycle guard, and small
//! helpers for pushing runtime-backed closures.
//!
//! Keeping this here avoids making one API binding depend on another. Input,
//! world, logging, time, and future script APIs can all share this boundary
//! without exposing SDL, wgpu, scene internals, or raw Zig pointers to Luau.

const luau = @import("../backend/luau.zig");
const context_mod = @import("context.zig");

/// Frame-local context type borrowed while Luau callbacks are running.
pub const ScriptContext = context_mod.ScriptContext;

/// Shared context error type returned by script-facing runtime APIs.
pub const ContextError = context_mod.Error;

/// Names the API family that is converting a Zig error into a Luau error.
pub const ErrorDomain = enum {
    input,
    world,
    actor,
    generic,

    /// Returns a generic fallback message for an unclassified error.
    pub fn fallbackMessage(self: ErrorDomain) [:0]const u8 {
        return switch (self) {
            .input => "input query failed",
            .world => "world query failed",
            .actor => "actor query failed",
            .generic => "script callback failed",
        };
    }

    /// Returns the message used when a callback is invoked outside lifecycle.
    pub fn inactiveMessage(self: ErrorDomain) [:0]const u8 {
        return switch (self) {
            .input => "InputMap is only available during script callbacks",
            .world => "ctx.world is only available during script callbacks",
            .actor => "Actor is only available during script callbacks",
            .generic => "script API is only available during script callbacks",
        };
    }

    /// Returns the message used when a closure was built without runtime state.
    pub fn missingRuntimeMessage(self: ErrorDomain) [:0]const u8 {
        return switch (self) {
            .input => "ctx.input callback missing runtime",
            .world => "ctx.world callback missing runtime",
            .actor => "Actor callback missing runtime",
            .generic => "script callback missing runtime",
        };
    }
};

/// Host-owned callback state borrowed by Luau C closures.
pub const Runtime = struct {
    active: bool = false,
    context: ScriptContext = ScriptContext.empty(),

    /// Marks a script lifecycle callback as active.
    pub fn begin(self: *Runtime, context: ScriptContext) void {
        self.context = context;
        self.active = true;
    }

    /// Clears the active lifecycle callback context.
    pub fn end(self: *Runtime) void {
        self.active = false;
        self.context = ScriptContext.empty();
    }

    /// Returns true while host code is inside init/update.
    pub fn isActive(self: *const Runtime) bool {
        return self.active;
    }

    /// Returns the active context when a Luau callback is running.
    pub fn activeContext(self: *const Runtime) ?ScriptContext {
        if (!self.active) return null;
        return self.context;
    }

    /// Returns the active context or raises a Luau runtime error.
    pub fn activeContextOrRaise(
        self: *const Runtime,
        state: *luau.State,
        domain: ErrorDomain,
    ) ?ScriptContext {
        return self.activeContext() orelse {
            _ = raise(state, domain.inactiveMessage());
            return null;
        };
    }
};

/// Stores a runtime-backed C closure into a table field.
pub fn setRuntimeCallbackField(
    state: *luau.State,
    table_index: i32,
    runtime: *Runtime,
    field_name: [:0]const u8,
    callback: luau.CFunction,
    debug_name: [:0]const u8,
) void {
    pushRuntimeCallback(state, runtime, callback, debug_name);
    luau.setField(state, table_index, field_name);
}

/// Pushes a runtime-backed C closure as a stack value.
pub fn pushRuntimeCallback(
    state: *luau.State,
    runtime: *Runtime,
    callback: luau.CFunction,
    debug_name: [:0]const u8,
) void {
    luau.pushLightUserdata(state, @ptrCast(runtime));
    luau.pushCClosure(state, callback, debug_name, 1);
}

/// Reads callback runtime from closure upvalue 1.
pub fn runtimeFromUpvalue(state: *luau.State) ?*Runtime {
    const raw = luau.toLightUserdataUpvalue(state, 1) orelse return null;
    return @ptrCast(@alignCast(raw));
}

/// Reads the active context from the runtime upvalue.
pub fn activeContextFromState(state: *luau.State) ?ScriptContext {
    const runtime = runtimeFromUpvalue(state) orelse return null;
    return runtime.activeContext();
}

/// Reads the active context or raises an API-specific runtime error.
pub fn activeContextFromStateOrRaise(
    state: *luau.State,
    domain: ErrorDomain,
) ?ScriptContext {
    const runtime = runtimeFromUpvalue(state) orelse {
        _ = raise(state, domain.missingRuntimeMessage());
        return null;
    };

    return runtime.activeContextOrRaise(state, domain);
}

/// Unwraps the nullable state received by C callback adapters.
pub fn unwrapState(state: ?*luau.State) *luau.State {
    return state orelse unreachable;
}

/// Raises a Luau runtime error with a static message.
pub fn raise(state: *luau.State, message: [:0]const u8) c_int {
    return luau.raiseError(state, message);
}

/// Raises a missing-runtime error for a callback family.
pub fn raiseMissingRuntime(state: *luau.State, domain: ErrorDomain) c_int {
    return raise(state, domain.missingRuntimeMessage());
}

/// Raises an inactive-callback error for a callback family.
pub fn raiseInactive(state: *luau.State, domain: ErrorDomain) c_int {
    return raise(state, domain.inactiveMessage());
}

/// Converts ScriptContext errors into Luau runtime errors.
pub fn raiseContextError(
    state: *luau.State,
    domain: ErrorDomain,
    err: ContextError,
) c_int {
    return switch (err) {
        error.MissingInput => raise(state, "input is unavailable during this script callback"),
        error.UnknownActionMap => raise(state, "unknown input map"),
        error.UnknownActionName => raise(state, "unknown input action"),

        error.MissingWorld => raise(state, "world is unavailable during this script callback"),
        error.MissingScriptActor => raise(state, "script actor was not found"),
        error.StaleScriptActor => raise(state, "script actor is stale"),
        error.ScriptActorKeyTooLong => raise(state, "script actor key is empty or too long"),
        error.DuplicateScriptActorKey => raise(state, "script actor key is already registered"),
        error.ScriptActorRegistryFull => raise(state, "script actor registry is full"),

        else => raise(state, domain.fallbackMessage()),
    };
}
