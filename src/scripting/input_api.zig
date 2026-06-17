//! Luau input API binding.
//!
//! This module turns the frame-local Zig ScriptContext into the first real Luau
//! callback context API: `ctx.input`. The binding is intentionally narrow. It
//! exposes named input maps and read-only frame values, but it does not let Luau
//! mutate routing, bindings, or action registration.
//!
//! Input map tables may be cached by scripts. They do not hold raw input
//! pointers; they hold a map name and call back through CallbackRuntime. The
//! runtime is only active during lifecycle callbacks, so using a cached handle
//! outside `init`/`update` returns a Luau runtime error instead of reading stale
//! frame data.

const luau = @import("../backend/luau.zig");
const context_mod = @import("context.zig");
const callbacks = @import("callbacks.zig");

const ScriptContext = context_mod.ScriptContext;

/// Pushes the readonly `ctx.input` API table.
pub fn pushInputApi(state: *luau.State, runtime: *callbacks.Runtime) void {
    luau.createTable(state, 0, 1);

    const input_index = luau.stackTop(state);

    setRuntimeCallbackField(
        state,
        input_index,
        runtime,
        "map",
        inputMapCallbackC,
        "ctx.input.map",
    );

    luau.setReadonly(state, input_index, true);
}

fn pushInputMap(state: *luau.State, runtime: *callbacks.Runtime, map_name: []const u8) void {
    luau.createTable(state, 0, 9);

    const map_index = luau.stackTop(state);

    luau.pushString(state, map_name);
    luau.setField(state, map_index, "__map_name");

    setRuntimeCallbackField(state, map_index, runtime, "down", inputMapDownCallbackC, "InputMap.down");
    setRuntimeCallbackField(state, map_index, runtime, "pressed", inputMapPressedCallbackC, "InputMap.pressed");
    setRuntimeCallbackField(state, map_index, runtime, "released", inputMapReleasedCallbackC, "InputMap.released");
    setRuntimeCallbackField(state, map_index, runtime, "axis1", inputMapAxis1CallbackC, "InputMap.axis1");
    setRuntimeCallbackField(state, map_index, runtime, "axis2", inputMapAxis2CallbackC, "InputMap.axis2");
    setRuntimeCallbackField(state, map_index, runtime, "mousePosition", inputMapMousePositionCallbackC, "InputMap.mousePosition");
    setRuntimeCallbackField(state, map_index, runtime, "mouseDelta", inputMapMouseDeltaCallbackC, "InputMap.mouseDelta");
    setRuntimeCallbackField(state, map_index, runtime, "mouseWheel", inputMapMouseWheelCallbackC, "InputMap.mouseWheel");

    luau.setReadonly(state, map_index, true);
}

fn setRuntimeCallbackField(
    state: *luau.State,
    table_index: i32,
    runtime: *callbacks.Runtime,
    field_name: [:0]const u8,
    callback: luau.CFunction,
    debug_name: [:0]const u8,
) void {
    callbacks.setRuntimeCallbackField(
        state,
        table_index,
        runtime,
        field_name,
        callback,
        debug_name,
    );
}

fn runtimeFromUpvalue(state: *luau.State) ?*callbacks.Runtime {
    return callbacks.runtimeFromUpvalue(state);
}

fn activeContextFromState(state: *luau.State) ?context_mod.ScriptContext {
    return callbacks.activeContextFromState(state);
}

fn raise(state: *luau.State, message: [:0]const u8) c_int {
    return callbacks.raise(state, message);
}

fn raiseContextError(state: *luau.State, err: context_mod.Error) c_int {
    return callbacks.raiseContextError(state, .input, err);
}

fn unwrapState(state: ?*luau.State) *luau.State {
    return callbacks.unwrapState(state);
}

fn readMapNameFromSelf(state: *luau.State) ?[]const u8 {
    if (!luau.isTable(state, 1)) return null;

    luau.getField(state, 1, "__map_name");
    defer luau.pop(state, 1);

    return luau.readString(state, -1);
}

fn readActionName(state: *luau.State) ?[]const u8 {
    return luau.readString(state, 2);
}

fn inputMapCallbackC(state: ?*luau.State) callconv(.c) c_int {
    return inputMapCallback(unwrapState(state));
}

fn inputMapDownCallbackC(state: ?*luau.State) callconv(.c) c_int {
    return inputMapDownCallback(unwrapState(state));
}

fn inputMapPressedCallbackC(state: ?*luau.State) callconv(.c) c_int {
    return inputMapPressedCallback(unwrapState(state));
}

fn inputMapReleasedCallbackC(state: ?*luau.State) callconv(.c) c_int {
    return inputMapReleasedCallback(unwrapState(state));
}

fn inputMapAxis1CallbackC(state: ?*luau.State) callconv(.c) c_int {
    return inputMapAxis1Callback(unwrapState(state));
}

fn inputMapAxis2CallbackC(state: ?*luau.State) callconv(.c) c_int {
    return inputMapAxis2Callback(unwrapState(state));
}

fn inputMapMousePositionCallbackC(state: ?*luau.State) callconv(.c) c_int {
    return inputMapMousePositionCallback(unwrapState(state));
}

fn inputMapMouseDeltaCallbackC(state: ?*luau.State) callconv(.c) c_int {
    return inputMapMouseDeltaCallback(unwrapState(state));
}

fn inputMapMouseWheelCallbackC(state: ?*luau.State) callconv(.c) c_int {
    return inputMapMouseWheelCallback(unwrapState(state));
}

fn inputMapCallback(state: *luau.State) callconv(.c) c_int {
    const runtime = runtimeFromUpvalue(state) orelse {
        return raise(state, "ctx.input callback missing runtime");
    };

    const context = runtime.activeContext() orelse {
        return raise(state, "ctx.input is only available during script callbacks");
    };

    const map_name = luau.readString(state, 2) orelse {
        return raise(state, "ctx.input:map expected a map name string");
    };

    _ = context.inputMap(map_name) catch |err| {
        return raiseContextError(state, err);
    };

    pushInputMap(state, runtime, map_name);
    return 1;
}

fn inputMapDownCallback(state: *luau.State) callconv(.c) c_int {
    const context = activeContextFromState(state) orelse {
        return raise(state, "InputMap is only available during script callbacks");
    };

    const map_name = readMapNameFromSelf(state) orelse {
        return raise(state, "InputMap:down expected an input map receiver");
    };

    const action_name = readActionName(state) orelse {
        return raise(state, "InputMap:down expected an action name string");
    };

    const value = context.inputMapDown(map_name, action_name) catch |err| {
        return raiseContextError(state, err);
    };

    luau.pushBoolean(state, value);
    return 1;
}

fn inputMapPressedCallback(state: *luau.State) callconv(.c) c_int {
    const context = activeContextFromState(state) orelse {
        return raise(state, "InputMap is only available during script callbacks");
    };

    const map_name = readMapNameFromSelf(state) orelse {
        return raise(state, "InputMap:pressed expected an input map receiver");
    };

    const action_name = readActionName(state) orelse {
        return raise(state, "InputMap:pressed expected an action name string");
    };

    const value = context.inputMapPressed(map_name, action_name) catch |err| {
        return raiseContextError(state, err);
    };

    luau.pushBoolean(state, value);
    return 1;
}

fn inputMapReleasedCallback(state: *luau.State) callconv(.c) c_int {
    const context = activeContextFromState(state) orelse {
        return raise(state, "InputMap is only available during script callbacks");
    };

    const map_name = readMapNameFromSelf(state) orelse {
        return raise(state, "InputMap:released expected an input map receiver");
    };

    const action_name = readActionName(state) orelse {
        return raise(state, "InputMap:released expected an action name string");
    };

    const value = context.inputMapReleased(map_name, action_name) catch |err| {
        return raiseContextError(state, err);
    };

    luau.pushBoolean(state, value);
    return 1;
}

fn inputMapAxis1Callback(state: *luau.State) callconv(.c) c_int {
    const context = activeContextFromState(state) orelse {
        return raise(state, "InputMap is only available during script callbacks");
    };

    const map_name = readMapNameFromSelf(state) orelse {
        return raise(state, "InputMap:axis1 expected an input map receiver");
    };

    const action_name = readActionName(state) orelse {
        return raise(state, "InputMap:axis1 expected an action name string");
    };

    const value = context.inputMapAxis1(map_name, action_name) catch |err| {
        return raiseContextError(state, err);
    };

    luau.pushNumber(state, @floatCast(value));
    return 1;
}

fn inputMapAxis2Callback(state: *luau.State) callconv(.c) c_int {
    const context = activeContextFromState(state) orelse {
        return raise(state, "InputMap is only available during script callbacks");
    };

    const map_name = readMapNameFromSelf(state) orelse {
        return raise(state, "InputMap:axis2 expected an input map receiver");
    };

    const action_name = readActionName(state) orelse {
        return raise(state, "InputMap:axis2 expected an action name string");
    };

    const value = context.inputMapAxis2(map_name, action_name) catch |err| {
        return raiseContextError(state, err);
    };

    luau.pushVector2(state, @floatCast(value.x), @floatCast(value.y));
    return 1;
}

fn inputMapMousePositionCallback(state: *luau.State) callconv(.c) c_int {
    const context = activeContextFromState(state) orelse {
        return raise(state, "InputMap is only available during script callbacks");
    };

    const map_name = readMapNameFromSelf(state) orelse {
        return raise(state, "InputMap:mousePosition expected an input map receiver");
    };

    const value = context.inputMapMousePosition(map_name) catch |err| {
        return raiseContextError(state, err);
    };

    luau.pushVector2(state, @floatCast(value.x), @floatCast(value.y));
    return 1;
}

fn inputMapMouseDeltaCallback(state: *luau.State) callconv(.c) c_int {
    const context = activeContextFromState(state) orelse {
        return raise(state, "InputMap is only available during script callbacks");
    };

    const map_name = readMapNameFromSelf(state) orelse {
        return raise(state, "InputMap:mouseDelta expected an input map receiver");
    };

    const value = context.inputMapMouseDelta(map_name) catch |err| {
        return raiseContextError(state, err);
    };

    luau.pushVector2(state, @floatCast(value.x), @floatCast(value.y));
    return 1;
}

fn inputMapMouseWheelCallback(state: *luau.State) callconv(.c) c_int {
    const context = activeContextFromState(state) orelse {
        return raise(state, "InputMap is only available during script callbacks");
    };

    const map_name = readMapNameFromSelf(state) orelse {
        return raise(state, "InputMap:mouseWheel expected an input map receiver");
    };

    const value = context.inputMapMouseWheel(map_name) catch |err| {
        return raiseContextError(state, err);
    };

    luau.pushVector2(state, @floatCast(value.x), @floatCast(value.y));
    return 1;
}
