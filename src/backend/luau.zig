//! Luau C bridge boundary.
//!
//! Luau itself is built as C++, so Zig talks to Yuki-owned C bridge symbols
//! instead of importing Luau VM symbols directly.

pub const c = @cImport({
    @cInclude("backend/luau_bridge.h");
});

/// Opaque Luau VM state owned by the scripting host.
pub const State = c.lua_State;

/// Creates a fresh Luau VM state.
pub fn createState() ?*State {
    return c.yuki_luau_new_state();
}

/// Destroys a Luau VM state created by `createState`.
pub fn destroyState(state: *State) void {
    c.yuki_luau_close(state);
}

/// Returns the current Luau stack height for smoke tests and debug checks.
pub fn stackTop(state: *State) i32 {
    return @intCast(c.yuki_luau_stack_top(state));
}
