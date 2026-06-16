//! Scripting host tests.
//!
//! These tests only prove that Yuki can link Luau and manage VM lifetime.
//! Script loading stays out until the host boundary itself is reliable.

const std = @import("std");
const scripting = @import("mod.zig");
const input = @import("../input/mod.zig");

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

test "script host installs Vector2 global API" {
    const source =
        \\local script = {}
        \\
        \\function script.init(ctx)
        \\    local value = Vector2.new(3, 4)
        \\
        \\    if value.x ~= 3 then
        \\        local bad = nil
        \\        bad()
        \\    end
        \\
        \\    if value.y ~= 4 then
        \\        local bad = nil
        \\        bad()
        \\    end
        \\end
        \\
        \\return script
    ;

    var host = try scripting.ScriptHost.init();
    defer host.deinit();

    var module = try host.loadModuleFromSource(source, "vector2_global_api");
    defer module.deinit(&host);

    try module.callInit(&host);

    try std.testing.expectEqual(@as(i32, 0), host.stackTop());
}

test "script host Vector2 supports basic arithmetic" {
    const source =
        \\local script = {}
        \\
        \\function script.update(ctx, dt)
        \\    local a = Vector2.new(2, 3)
        \\    local b = Vector2.new(5, 7)
        \\    local sum = a + b
        \\    local diff = b - a
        \\    local scaled = sum * 2 * dt
        \\    local left_scaled = 2 * a
        \\    local divided = b / 2
        \\    local negated = -a
        \\
        \\    if sum.x ~= 7 or sum.y ~= 10 then
        \\        local bad = nil
        \\        bad()
        \\    end
        \\
        \\    if diff.x ~= 3 or diff.y ~= 4 then
        \\        local bad = nil
        \\        bad()
        \\    end
        \\
        \\    if scaled.x ~= 7 or scaled.y ~= 10 then
        \\        local bad = nil
        \\        bad()
        \\    end
        \\
        \\    if left_scaled.x ~= 4 or left_scaled.y ~= 6 then
        \\        local bad = nil
        \\        bad()
        \\    end
        \\
        \\    if divided.x ~= 2.5 or divided.y ~= 3.5 then
        \\        local bad = nil
        \\        bad()
        \\    end
        \\
        \\    if negated.x ~= -2 or negated.y ~= -3 then
        \\        local bad = nil
        \\        bad()
        \\    end
        \\end
        \\
        \\return script
    ;

    var host = try scripting.ScriptHost.init();
    defer host.deinit();

    var module = try host.loadModuleFromSource(source, "vector2_arithmetic");
    defer module.deinit(&host);

    try module.callUpdate(&host, 0.5);

    try std.testing.expectEqual(@as(i32, 0), host.stackTop());
}

test "script host Vector2 constants are available" {
    const source =
        \\local script = {}
        \\
        \\function script.init(ctx)
        \\    if Vector2.zero.x ~= 0 or Vector2.zero.y ~= 0 then
        \\        local bad = nil
        \\        bad()
        \\    end
        \\
        \\    if Vector2.one.x ~= 1 or Vector2.one.y ~= 1 then
        \\        local bad = nil
        \\        bad()
        \\    end
        \\
        \\    if Vector2.right.x ~= 1 or Vector2.right.y ~= 0 then
        \\        local bad = nil
        \\        bad()
        \\    end
        \\
        \\    if Vector2.up.x ~= 0 or Vector2.up.y ~= 1 then
        \\        local bad = nil
        \\        bad()
        \\    end
        \\end
        \\
        \\return script
    ;

    var host = try scripting.ScriptHost.init();
    defer host.deinit();

    var module = try host.loadModuleFromSource(source, "vector2_constants");
    defer module.deinit(&host);

    try module.callInit(&host);

    try std.testing.expectEqual(@as(i32, 0), host.stackTop());
}

test "script host Vector2 values are readonly" {
    const source =
        \\local script = {}
        \\
        \\function script.init(ctx)
        \\    local value = Vector2.new(1, 2)
        \\    value.x = 10
        \\end
        \\
        \\return script
    ;

    var host = try scripting.ScriptHost.init();
    defer host.deinit();

    var module = try host.loadModuleFromSource(source, "vector2_readonly_value");
    defer module.deinit(&host);

    try std.testing.expectError(
        scripting.ScriptHostError.RuntimeFailed,
        module.callInit(&host),
    );

    try std.testing.expectEqual(@as(i32, 0), host.stackTop());
}

test "script host Vector2 API table is readonly" {
    const source =
        \\Vector2.extra = true
        \\
        \\return {}
    ;

    var host = try scripting.ScriptHost.init();
    defer host.deinit();

    try std.testing.expectError(
        scripting.ScriptHostError.RuntimeFailed,
        host.loadModuleFromSource(source, "vector2_readonly_api"),
    );

    try std.testing.expectEqual(@as(i32, 0), host.stackTop());
}

test "script host Vector2 rejects invalid arithmetic" {
    const source =
        \\local script = {}
        \\
        \\function script.update(ctx, dt)
        \\    local value = Vector2.new(1, 2) + 4
        \\end
        \\
        \\return script
    ;

    var host = try scripting.ScriptHost.init();
    defer host.deinit();

    var module = try host.loadModuleFromSource(source, "vector2_bad_add");
    defer module.deinit(&host);

    try std.testing.expectError(
        scripting.ScriptHostError.RuntimeFailed,
        module.callUpdate(&host, 0.016),
    );

    try std.testing.expectEqual(@as(i32, 0), host.stackTop());
}

test "script context without input rejects input queries" {
    const context = scripting.ScriptContext.empty();

    try std.testing.expect(!context.hasInput());

    try std.testing.expectError(
        scripting.ScriptContextError.MissingInput,
        context.requireInput(),
    );

    try std.testing.expectError(
        scripting.ScriptContextError.MissingInput,
        context.inputMap("gameplay"),
    );

    try std.testing.expectError(
        scripting.ScriptContextError.MissingInput,
        context.inputMapPressed("gameplay", "player.jump"),
    );
}

test "script context reads named input actions" {
    var builder = input.InputSessionBuilder.init();

    _ = try builder.addMap("gameplay");
    _ = try builder.addDigital("gameplay", "player.jump");
    _ = try builder.addAxis1("gameplay", "player.look_x");
    _ = try builder.addAxis2("gameplay", "player.move");

    try builder.bindDigitalKeyName("gameplay", "player.jump", "space");
    try builder.bindAxis1KeyNames("gameplay", "player.look_x", "q", "e");
    try builder.bindAxis2KeyNames("gameplay", "player.move", "a", "d", "w", "s");
    try builder.activateMap("gameplay");

    var session = try builder.build();

    try session.applyKey(.space, true, false);
    try session.applyKey(.e, true, false);
    try session.applyKey(.d, true, false);

    const context = scripting.ScriptContext.fromInput(&session);

    try std.testing.expect(context.hasInput());
    try std.testing.expect(try context.inputMapActive("gameplay"));
    try std.testing.expect(try context.inputMapCanProcess("gameplay"));
    try std.testing.expect(try context.inputMapDown("gameplay", "player.jump"));
    try std.testing.expect(try context.inputMapPressed("gameplay", "player.jump"));

    const look_x = try context.inputMapAxis1("gameplay", "player.look_x");
    try std.testing.expectEqual(@as(f32, 1.0), look_x);

    const move = try context.inputMapAxis2("gameplay", "player.move");
    try std.testing.expectEqual(@as(f32, 1.0), move.x);
    try std.testing.expectEqual(@as(f32, 0.0), move.y);
}

test "script context reads pointer state through named input maps" {
    var builder = input.InputSessionBuilder.init();

    _ = try builder.addMap("gameplay");
    _ = try builder.addDigital("gameplay", "pointer.select");

    try builder.bindMouseButtonName("gameplay", "pointer.select", "left");
    try builder.activateMap("gameplay");

    var session = try builder.build();

    session.applyMouseMotion(input.Vector2.xy(32.0, 64.0));
    try session.applyMouseButton(.left, true, input.Vector2.xy(32.0, 64.0));
    session.applyMouseWheel(
        input.Vector2.xy(0.0, -1.0),
        input.Vector2.xy(32.0, 64.0),
    );

    const context = scripting.ScriptContext.fromInput(&session);

    const position = try context.inputMapMousePosition("gameplay");
    try std.testing.expectEqual(@as(f32, 32.0), position.x);
    try std.testing.expectEqual(@as(f32, 64.0), position.y);

    const delta = try context.inputMapMouseDelta("gameplay");
    try std.testing.expectEqual(@as(f32, 32.0), delta.x);
    try std.testing.expectEqual(@as(f32, 64.0), delta.y);

    const wheel = try context.inputMapMouseWheel("gameplay");
    try std.testing.expectEqual(@as(f32, 0.0), wheel.x);
    try std.testing.expectEqual(@as(f32, -1.0), wheel.y);

    try std.testing.expect(try context.inputMapMouseInsideSurface("gameplay"));
    try std.testing.expect(try context.inputMapMouseButtonDown("gameplay", .left));
    try std.testing.expect(try context.inputMapMouseButtonPressed("gameplay", .left));
    try std.testing.expect(!try context.inputMapMouseButtonReleased("gameplay", .left));
}

test "script context forwards unknown input names" {
    var builder = input.InputSessionBuilder.init();

    _ = try builder.addMap("gameplay");
    _ = try builder.addDigital("gameplay", "player.jump");

    try builder.bindDigitalKeyName("gameplay", "player.jump", "space");
    try builder.activateMap("gameplay");

    var session = try builder.build();
    const context = scripting.ScriptContext.fromInput(&session);

    try std.testing.expectError(
        input.Error.UnknownActionMap,
        context.inputMap("missing"),
    );

    try std.testing.expectError(
        input.Error.UnknownActionName,
        context.inputMapPressed("gameplay", "player.missing"),
    );
}

test "script module accepts explicit context for lifecycle calls" {
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

    var module = try host.loadModuleFromSource(source, "explicit_context_lifecycle");
    defer module.deinit(&host);

    const context = scripting.ScriptContext.empty();

    try module.callInitWithContext(&host, context);
    try module.callUpdateWithContext(&host, context, 0.016);

    try std.testing.expectEqual(@as(i32, 0), host.stackTop());
}
