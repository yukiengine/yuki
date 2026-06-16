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
