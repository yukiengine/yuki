//! Luau C bridge boundary.
//!
//! Luau itself is built as C++, so Zig talks to Yuki-owned C bridge symbols
//! instead of importing Luau VM symbols directly.

pub const c = @cImport({
    @cInclude("backend/luau_bridge.h");
});

/// Opaque Luau VM state owned by the scripting host.
pub const State = c.lua_State;

/// Errors returned by the low-level Luau bridge wrapper.
pub const Error = error{
    CompileFailed,
    LoadFailed,
    RuntimeFailed,
};

/// Owned compiled Luau bytecode.
pub const Bytecode = struct {
    raw: c.YukiLuauBytecode,

    /// Returns the compiled bytecode bytes.
    pub fn bytes(self: Bytecode) []const u8 {
        return self.raw.data[0..self.raw.size];
    }

    /// Releases compiler-allocated bytecode memory.
    pub fn deinit(self: *Bytecode) void {
        if (self.raw.data != null) {
            c.yuki_luau_free_bytecode(self.raw);
            self.raw = .{ .data = null, .size = 0 };
        }
    }
};

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

/// Compiles source text into owned Luau bytecode.
pub fn compile(source: []const u8) Error!Bytecode {
    var raw: c.YukiLuauBytecode = .{
        .data = null,
        .size = 0,
    };

    try statusToError(c.yuki_luau_compile(source.ptr, source.len, &raw));

    return .{ .raw = raw };
}

/// Loads bytecode and leaves the loaded function on top of the stack.
pub fn loadBytecode(
    state: *State,
    chunk_name: [:0]const u8,
    bytecode: []const u8,
) Error!void {
    try statusToError(c.yuki_luau_load_bytecode(
        state,
        chunk_name.ptr,
        bytecode.ptr,
        bytecode.len,
    ));
}

/// Calls a function already present on the stack.
pub fn call(state: *State, arg_count: i32, result_count: i32) Error!void {
    try statusToError(c.yuki_luau_call(state, arg_count, result_count));
}

/// Returns true when the stack value at index is a table.
pub fn isTable(state: *State, index: i32) bool {
    return c.yuki_luau_is_table(state, index) != 0;
}

/// Stores a registry reference to the stack value at index.
pub fn ref(state: *State, index: i32) i32 {
    return @intCast(c.yuki_luau_ref(state, index));
}

/// Releases a registry reference created by `ref`.
pub fn unref(state: *State, registry_ref: i32) void {
    c.yuki_luau_unref(state, registry_ref);
}

/// Pops count values from the stack.
pub fn pop(state: *State, count: i32) void {
    if (count > 0) {
        c.yuki_luau_pop(state, count);
    }
}

/// Converts a stack value to a string when Luau can represent it as one.
pub fn toString(state: *State, index: i32) ?[*:0]const u8 {
    return c.yuki_luau_to_string(state, index);
}

fn statusToError(status: c_int) Error!void {
    return switch (status) {
        c.YUKI_LUAU_OK => {},
        c.YUKI_LUAU_COMPILE_FAILED => Error.CompileFailed,
        c.YUKI_LUAU_LOAD_FAILED => Error.LoadFailed,
        c.YUKI_LUAU_RUNTIME_FAILED => Error.RuntimeFailed,
        else => Error.RuntimeFailed,
    };
}

/// Pushes a registry-referenced value onto the stack.
pub fn getRef(state: *State, registry_ref: i32) void {
    c.yuki_luau_get_ref(state, registry_ref);
}

/// Pushes table[field_name] onto the stack.
pub fn getField(state: *State, index: i32, field_name: [:0]const u8) void {
    _ = c.yuki_luau_get_field(state, index, field_name.ptr);
}

/// Returns true when the stack value at index is nil.
pub fn isNil(state: *State, index: i32) bool {
    return c.yuki_luau_is_nil(state, index) != 0;
}

/// Returns true when the stack value at index is a function.
pub fn isFunction(state: *State, index: i32) bool {
    return c.yuki_luau_is_function(state, index) != 0;
}

/// Pushes nil onto the stack.
pub fn pushNil(state: *State) void {
    c.yuki_luau_push_nil(state);
}

/// Pushes a number onto the stack.
pub fn pushNumber(state: *State, value: f64) void {
    c.yuki_luau_push_number(state, value);
}

/// Pushes a new table onto the stack.
pub fn createTable(state: *State, array_count: i32, record_count: i32) void {
    c.yuki_luau_create_table(state, array_count, record_count);
}

/// Marks a table as readonly or writable.
pub fn setReadonly(state: *State, index: i32, enabled: bool) void {
    c.yuki_luau_set_readonly(state, index, if (enabled) 1 else 0);
}
