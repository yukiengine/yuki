//! Scripting host tests.
//!
//! These tests only prove that Yuki can link Luau and manage VM lifetime.
//! Script loading stays out until the host boundary itself is reliable.

const std = @import("std");
const scripting = @import("mod.zig");

test "script host creates an empty Luau stack" {
    var host = try scripting.ScriptHost.init();
    defer host.deinit();

    try std.testing.expectEqual(@as(i32, 0), host.stackTop());
}

test "script host exposes a raw state for internal bridge code" {
    var host = try scripting.ScriptHost.init();
    defer host.deinit();

    _ = host.rawState();
}

test "script host loads a source module that returns a table" {
    const source =
        \\local script = {}
        \\
        \\function script.init(ctx)
        \\end
        \\
        \\function script.update(ctx, dt)
        \\end
        \\
        \\return script
    ;

    var host = try scripting.ScriptHost.init();
    defer host.deinit();

    var module = try host.loadModuleFromSource(source, "return_table");
    defer module.deinit(&host);

    try std.testing.expect(module.isLoaded());
    try std.testing.expect(module.registryRef() >= 0);
    try std.testing.expectEqual(@as(i32, 0), host.stackTop());
}

test "script host rejects a module that returns a non-table" {
    const source =
        \\return 42
    ;

    var host = try scripting.ScriptHost.init();
    defer host.deinit();

    try std.testing.expectError(
        scripting.ScriptHostError.ScriptDidNotReturnTable,
        host.loadModuleFromSource(source, "return_number"),
    );

    try std.testing.expectEqual(@as(i32, 0), host.stackTop());
}

test "script host keeps stack balanced after load failure" {
    const source =
        \\local =
    ;

    var host = try scripting.ScriptHost.init();
    defer host.deinit();

    try std.testing.expectError(
        scripting.ScriptHostError.LoadFailed,
        host.loadModuleFromSource(source, "bad_syntax"),
    );

    try std.testing.expectEqual(@as(i32, 0), host.stackTop());
}

test "script host resolves optional lifecycle functions" {
    const source =
        \\local script = {}
        \\
        \\function script.init(ctx)
        \\end
        \\
        \\function script.update(ctx, dt)
        \\end
        \\
        \\return script
    ;

    var host = try scripting.ScriptHost.init();
    defer host.deinit();

    var module = try host.loadModuleFromSource(source, "lifecycle_fields");
    defer module.deinit(&host);

    try std.testing.expect(module.hasInit());
    try std.testing.expect(module.hasUpdate());
    try std.testing.expectEqual(@as(i32, 0), host.stackTop());
}

test "script host allows missing lifecycle functions" {
    const source =
        \\return {}
    ;

    var host = try scripting.ScriptHost.init();
    defer host.deinit();

    var module = try host.loadModuleFromSource(source, "missing_lifecycle");
    defer module.deinit(&host);

    try std.testing.expect(!module.hasInit());
    try std.testing.expect(!module.hasUpdate());

    try module.callInit(&host);
    try module.callUpdate(&host, 1.0);

    try std.testing.expectEqual(@as(i32, 0), host.stackTop());
}

test "script host rejects non-function lifecycle fields" {
    const source =
        \\return {
        \\    init = 42,
        \\}
    ;

    var host = try scripting.ScriptHost.init();
    defer host.deinit();

    try std.testing.expectError(
        scripting.ScriptHostError.ScriptLifecycleNotFunction,
        host.loadModuleFromSource(source, "bad_lifecycle_field"),
    );

    try std.testing.expectEqual(@as(i32, 0), host.stackTop());
}

test "script host calls init and update lifecycle functions" {
    const source =
        \\local script = {
        \\    initialized = false,
        \\    updates = 0,
        \\}
        \\
        \\function script.init(ctx)
        \\    if ctx == nil then
        \\        local bad = nil
        \\        bad()
        \\    end
        \\
        \\    script.initialized = true
        \\end
        \\
        \\function script.update(ctx, dt)
        \\    if ctx == nil then
        \\        local bad = nil
        \\        bad()
        \\    end
        \\
        \\    if not script.initialized then
        \\        local bad = nil
        \\        bad()
        \\    end
        \\
        \\    if dt <= 0 then
        \\        local bad = nil
        \\        bad()
        \\    end
        \\
        \\    script.updates = script.updates + 1
        \\end
        \\
        \\return script
    ;

    var host = try scripting.ScriptHost.init();
    defer host.deinit();

    var module = try host.loadModuleFromSource(source, "call_lifecycle");
    defer module.deinit(&host);

    try module.callInit(&host);
    try module.callUpdate(&host, 0.016);
    try module.callUpdate(&host, 0.032);

    try std.testing.expectEqual(@as(i32, 0), host.stackTop());
}

test "script host reports lifecycle runtime errors" {
    const source =
        \\local script = {}
        \\
        \\function script.update(ctx, dt)
        \\    local missing = nil
        \\    missing()
        \\end
        \\
        \\return script
    ;

    var host = try scripting.ScriptHost.init();
    defer host.deinit();

    var module = try host.loadModuleFromSource(source, "runtime_error");
    defer module.deinit(&host);

    try std.testing.expectError(
        scripting.ScriptHostError.RuntimeFailed,
        module.callUpdate(&host, 0.016),
    );

    try std.testing.expectEqual(@as(i32, 0), host.stackTop());
}

test "script host passes a real context table to init" {
    const source =
        \\local script = {}
        \\
        \\function script.init(ctx)
        \\    if ctx == nil then
        \\        local bad = nil
        \\        bad()
        \\    end
        \\end
        \\
        \\return script
    ;

    var host = try scripting.ScriptHost.init();
    defer host.deinit();

    var module = try host.loadModuleFromSource(source, "init_context_table");
    defer module.deinit(&host);

    try module.callInit(&host);

    try std.testing.expectEqual(@as(i32, 0), host.stackTop());
}

test "script host passes a real context table to update" {
    const source =
        \\local script = {}
        \\
        \\function script.update(ctx, dt)
        \\    if ctx == nil then
        \\        local bad = nil
        \\        bad()
        \\    end
        \\
        \\    if dt <= 0 then
        \\        local bad = nil
        \\        bad()
        \\    end
        \\end
        \\
        \\return script
    ;

    var host = try scripting.ScriptHost.init();
    defer host.deinit();

    var module = try host.loadModuleFromSource(source, "update_context_table");
    defer module.deinit(&host);

    try module.callUpdate(&host, 0.016);

    try std.testing.expectEqual(@as(i32, 0), host.stackTop());
}

test "script host context is readonly during init" {
    const source =
        \\local script = {}
        \\
        \\function script.init(ctx)
        \\    ctx.anything = true
        \\end
        \\
        \\return script
    ;

    var host = try scripting.ScriptHost.init();
    defer host.deinit();

    var module = try host.loadModuleFromSource(source, "readonly_init_context");
    defer module.deinit(&host);

    try std.testing.expectError(
        scripting.ScriptHostError.RuntimeFailed,
        module.callInit(&host),
    );

    try std.testing.expectEqual(@as(i32, 0), host.stackTop());
}

test "script host context is readonly during update" {
    const source =
        \\local script = {}
        \\
        \\function script.update(ctx, dt)
        \\    ctx.anything = dt
        \\end
        \\
        \\return script
    ;

    var host = try scripting.ScriptHost.init();
    defer host.deinit();

    var module = try host.loadModuleFromSource(source, "readonly_update_context");
    defer module.deinit(&host);

    try std.testing.expectError(
        scripting.ScriptHostError.RuntimeFailed,
        module.callUpdate(&host, 0.016),
    );

    try std.testing.expectEqual(@as(i32, 0), host.stackTop());
}
