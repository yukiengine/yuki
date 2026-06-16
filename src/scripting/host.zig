//! Minimal Luau script host.
//!
//! This layer proves Yuki can compile a Luau source module, run its top-level
//! chunk, require the module to return a table, resolve optional lifecycle
//! functions, and call them with a real callback context while keeping the Luau
//! stack balanced. The context is intentionally empty and readonly until the
//! input/world APIs are bound; this avoids exposing placeholder runtime fields
//! that scripts might accidentally depend on.

const luau = @import("../backend/luau.zig");
const context_mod = @import("context.zig");

const ScriptContext = context_mod.ScriptContext;

const invalid_ref: i32 = -1;

/// Errors that can happen while creating, loading, or running scripts.
pub const Error = error{
    CreateStateFailed,
    CompileFailed,
    LoadFailed,
    RuntimeFailed,
    ScriptDidNotReturnTable,
    ScriptLifecycleNotFunction,
};

/// A loaded Luau script module table pinned in the VM registry.
pub const ScriptModule = struct {
    table_ref: i32,
    init_ref: i32,
    update_ref: i32,

    /// Returns true when this module owns a registry reference.
    pub fn isLoaded(self: ScriptModule) bool {
        return self.table_ref >= 0;
    }

    /// Returns true when the module exposes an init lifecycle function.
    pub fn hasInit(self: ScriptModule) bool {
        return self.init_ref >= 0;
    }

    /// Returns true when the module exposes an update lifecycle function.
    pub fn hasUpdate(self: ScriptModule) bool {
        return self.update_ref >= 0;
    }

    /// Returns the internal table registry reference for tests and future host code.
    pub fn registryRef(self: ScriptModule) i32 {
        return self.table_ref;
    }

    /// Calls init(ctx) with an empty runtime context when the module defines it.
    pub fn callInit(self: *const ScriptModule, host: *ScriptHost) Error!void {
        try self.callInitWithContext(host, ScriptContext.empty());
    }

    /// Calls init(ctx) with an explicit runtime context.
    pub fn callInitWithContext(
        self: *const ScriptModule,
        host: *ScriptHost,
        context: ScriptContext,
    ) Error!void {
        try host.callLifecycleWithContextOnly(self.init_ref, context);
    }

    /// Calls update(ctx, dt) with an empty runtime context when the module defines it.
    pub fn callUpdate(self: *const ScriptModule, host: *ScriptHost, dt: f64) Error!void {
        try self.callUpdateWithContext(host, ScriptContext.empty(), dt);
    }

    /// Calls update(ctx, dt) with an explicit runtime context.
    pub fn callUpdateWithContext(
        self: *const ScriptModule,
        host: *ScriptHost,
        context: ScriptContext,
        dt: f64,
    ) Error!void {
        try host.callLifecycleWithDelta(self.update_ref, context, dt);
    }

    /// Releases module table and lifecycle registry references.
    pub fn deinit(self: *ScriptModule, host: *ScriptHost) void {
        host.releaseRegistryRef(self.init_ref);
        host.releaseRegistryRef(self.update_ref);
        host.releaseRegistryRef(self.table_ref);

        self.table_ref = invalid_ref;
        self.init_ref = invalid_ref;
        self.update_ref = invalid_ref;
    }
};

/// Owns one Luau VM state for the runtime.
pub const ScriptHost = struct {
    state: *luau.State,

    /// Creates a Luau VM state owned by this host.
    pub fn init() Error!ScriptHost {
        const state = luau.createState() orelse return Error.CreateStateFailed;

        luau.installVector2(state);

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

        const init_ref = try self.resolveLifecycleField(-1, "init");
        errdefer self.releaseRegistryRef(init_ref);

        const update_ref = try self.resolveLifecycleField(-1, "update");
        errdefer self.releaseRegistryRef(update_ref);

        const table_ref = luau.ref(self.state, -1);
        luau.pop(self.state, 1);

        return .{
            .table_ref = table_ref,
            .init_ref = init_ref,
            .update_ref = update_ref,
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

    fn resolveLifecycleField(
        self: *ScriptHost,
        table_index: i32,
        field_name: [:0]const u8,
    ) Error!i32 {
        luau.getField(self.state, table_index, field_name);

        if (luau.isNil(self.state, -1)) {
            luau.pop(self.state, 1);
            return invalid_ref;
        }

        if (!luau.isFunction(self.state, -1)) {
            luau.pop(self.state, 1);
            return Error.ScriptLifecycleNotFunction;
        }

        const function_ref = luau.ref(self.state, -1);
        luau.pop(self.state, 1);

        return function_ref;
    }

    fn callLifecycleWithContextOnly(
        self: *ScriptHost,
        function_ref: i32,
        context: ScriptContext,
    ) Error!void {
        if (function_ref < 0) {
            return;
        }

        const initial_top = self.stackTop();
        errdefer self.restoreStack(initial_top);

        luau.getRef(self.state, function_ref);

        if (!luau.isFunction(self.state, -1)) {
            return Error.ScriptLifecycleNotFunction;
        }

        self.pushCallbackContext(context);
        try luau.call(self.state, 1, 0);

        self.restoreStack(initial_top);
    }

    fn callLifecycleWithDelta(
        self: *ScriptHost,
        function_ref: i32,
        context: ScriptContext,
        dt: f64,
    ) Error!void {
        if (function_ref < 0) {
            return;
        }

        const initial_top = self.stackTop();
        errdefer self.restoreStack(initial_top);

        luau.getRef(self.state, function_ref);

        if (!luau.isFunction(self.state, -1)) {
            return Error.ScriptLifecycleNotFunction;
        }

        self.pushCallbackContext(context);
        luau.pushNumber(self.state, dt);
        try luau.call(self.state, 2, 0);

        self.restoreStack(initial_top);
    }

    fn pushCallbackContext(self: *ScriptHost, context: ScriptContext) void {
        // The Zig context is accepted now so the runtime call shape is stable.
        // The Luau table remains empty until the next slice binds `ctx.input`.
        _ = context;

        luau.createTable(self.state, 0, 0);
        luau.setReadonly(self.state, -1, true);
    }

    fn releaseRegistryRef(self: *ScriptHost, registry_ref: i32) void {
        if (registry_ref >= 0) {
            luau.unref(self.state, registry_ref);
        }
    }

    fn restoreStack(self: *ScriptHost, top: i32) void {
        const current_top = self.stackTop();

        if (current_top > top) {
            luau.pop(self.state, current_top - top);
        }
    }
};
