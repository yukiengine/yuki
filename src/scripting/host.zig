//! Minimal Luau script host.
//!
//! This layer proves Yuki can compile a Luau source module, run its top-level
//! chunk, require the module to return a table, and keep that table alive in the
//! Luau registry. It does not expose `ctx`, input, actors, or lifecycle calls
//! yet; those come after the module loading boundary is reliable.

const luau = @import("../backend/luau.zig");

/// Errors that can happen while creating or loading scripts.
pub const Error = error{
    CreateStateFailed,
    CompileFailed,
    LoadFailed,
    RuntimeFailed,
    ScriptDidNotReturnTable,
};

/// A loaded Luau script module table pinned in the VM registry.
pub const ScriptModule = struct {
    table_ref: i32,

    /// Returns true when this module owns a registry reference.
    pub fn isLoaded(self: ScriptModule) bool {
        return self.table_ref >= 0;
    }

    /// Returns the internal registry reference for tests and future host code.
    pub fn registryRef(self: ScriptModule) i32 {
        return self.table_ref;
    }

    /// Releases the module table registry reference.
    pub fn deinit(self: *ScriptModule, host: *ScriptHost) void {
        if (self.isLoaded()) {
            luau.unref(host.state, self.table_ref);
            self.table_ref = -1;
        }
    }
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

    /// Loads a Luau source module and requires it to return a table.
    pub fn loadModuleFromSource(
        self: *ScriptHost,
        source: []const u8,
        chunk_name: [:0]const u8,
    ) Error!ScriptModule {
        const initial_top = self.stackTop();
        errdefer self.restoreStack(initial_top);

        var bytecode = try luau.compile(source);
        defer bytecode.deinit();

        try luau.loadBytecode(self.state, chunk_name, bytecode.bytes());
        try luau.call(self.state, 0, 1);

        if (!luau.isTable(self.state, -1)) {
            return Error.ScriptDidNotReturnTable;
        }

        const table_ref = luau.ref(self.state, -1);
        luau.pop(self.state, 1);

        return .{
            .table_ref = table_ref,
        };
    }

    /// Returns the current Luau stack height.
    pub fn stackTop(self: *const ScriptHost) i32 {
        return luau.stackTop(self.state);
    }

    /// Returns the raw VM state for the next internal scripting layer.
    pub fn rawState(self: *ScriptHost) *luau.State {
        return self.state;
    }

    fn restoreStack(self: *ScriptHost, top: i32) void {
        const current_top = self.stackTop();

        if (current_top > top) {
            luau.pop(self.state, current_top - top);
        }
    }
};
