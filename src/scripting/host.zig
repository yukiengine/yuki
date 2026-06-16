//! Minimal Luau script host.
//!
//! This is intentionally only a VM lifetime wrapper for now. Loading files,
//! validating returned script tables, registering `ctx`, and calling lifecycle
//! functions should come after this compiles and has a stable smoke test.

const luau = @import("../backend/luau.zig");

/// Errors that can happen while creating the Luau host.
pub const Error = error{
    CreateStateFailed,
};

/// Owns one Luau VM state for the runtime.
pub const ScriptHost = struct {
    state: *luau.State,

    /// Creates a Luau VM state owned by this host.
    pub fn init() Error!ScriptHost {
        const state = luau.createState() orelse return Error.CreateStateFailed;

        return .{
            .state = state,
        };
    }

    /// Releases the owned Luau VM state.
    pub fn deinit(self: *ScriptHost) void {
        luau.destroyState(self.state);
        self.* = undefined;
    }

    /// Returns the current Luau stack height.
    pub fn stackTop(self: *const ScriptHost) i32 {
        return luau.stackTop(self.state);
    }

    /// Returns the raw VM state for the next internal scripting layer.
    pub fn rawState(self: *ScriptHost) *luau.State {
        return self.state;
    }
};
