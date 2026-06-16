//! Luau world API binding.
//!
//! This module turns the Zig-side ScriptWorld registry into `ctx.world`.
//! Scripts receive cacheable Actor userdata handles, not raw Zig pointers.
//! Each Actor operation calls back through CallbackRuntime, so actor handles
//! remain generation-checked and only work during script lifecycle callbacks.

const std = @import("std");
const luau = @import("../backend/luau.zig");
const context_mod = @import("context.zig");
const input_api = @import("input_api.zig");
const world_mod = @import("world.zig");

const CallbackRuntime = input_api.CallbackRuntime;
const ScriptActor = world_mod.ScriptActor;
const Vector2 = world_mod.Vector2;

/// Userdata payload copied into Luau Actor handles.
const ActorHandleData = extern struct {
    key_len: u8,
    key_bytes: [world_mod.max_actor_key_bytes]u8,
    id_index: u16,
    id_generation: u16,

    /// Copies a script actor into userdata-safe storage.
    fn init(actor: ScriptActor) ActorHandleData {
        var data = ActorHandleData{
            .key_len = 0,
            .key_bytes = undefined,
            .id_index = actor.actorId().index,
            .id_generation = actor.actorId().generation,
        };

        const key_name = actor.keyName();
        @memcpy(data.key_bytes[0..key_name.len], key_name);
        data.key_len = @intCast(key_name.len);

        return data;
    }

    /// Returns the stored actor key.
    fn key(self: *const ActorHandleData) []const u8 {
        return self.key_bytes[0..self.key_len];
    }

    /// Rebuilds the Zig script actor value from copied userdata.
    fn scriptActor(self: *const ActorHandleData) context_mod.Error!ScriptActor {
        return .{
            .key = try world_mod.ActorKey.init(self.key()),
            .id = .{
                .index = self.id_index,
                .generation = self.id_generation,
            },
        };
    }
};

/// Pushes the readonly `ctx.world` API table.
pub fn pushWorldApi(state: *luau.State, runtime: *CallbackRuntime) void {
    luau.createTable(state, 0, 2);

    const world_index = luau.stackTop(state);

    setRuntimeCallbackField(state, world_index, runtime, "actor", worldActorCallbackC, "ctx.world.actor");
    setRuntimeCallbackField(state, world_index, runtime, "requireActor", worldRequireActorCallbackC, "ctx.world.requireActor");

    luau.setReadonly(state, world_index, true);
}

/// Stores a runtime-backed C closure into a table field.
fn setRuntimeCallbackField(
    state: *luau.State,
    table_index: i32,
    runtime: *CallbackRuntime,
    field_name: [:0]const u8,
    callback: luau.CFunction,
    debug_name: [:0]const u8,
) void {
    luau.pushLightUserdata(state, @ptrCast(runtime));
    luau.pushCClosure(state, callback, debug_name, 1);
    luau.setField(state, table_index, field_name);
}

/// Pushes a runtime-backed C closure as a return value.
fn pushRuntimeCallback(
    state: *luau.State,
    runtime: *CallbackRuntime,
    callback: luau.CFunction,
    debug_name: [:0]const u8,
) void {
    luau.pushLightUserdata(state, @ptrCast(runtime));
    luau.pushCClosure(state, callback, debug_name, 1);
}

/// Reads the callback runtime from closure upvalue 1.
fn runtimeFromUpvalue(state: *luau.State) ?*CallbackRuntime {
    const raw = luau.toLightUserdataUpvalue(state, 1) orelse return null;
    return @ptrCast(@alignCast(raw));
}

/// Reads the active script context for a lifecycle callback.
fn activeContextFromState(state: *luau.State) ?context_mod.ScriptContext {
    const runtime = runtimeFromUpvalue(state) orelse return null;
    return runtime.activeContext();
}

/// Converts a Luau Vector2 payload into the world Vector2 type.
fn vectorFromLuau(value: luau.Vector2Value) Vector2 {
    return Vector2.xy(@floatCast(value.x), @floatCast(value.y));
}

/// Pushes a cacheable Actor userdata handle.
fn pushActorHandle(state: *luau.State, runtime: *CallbackRuntime, actor: ScriptActor) void {
    const handle = luau.newUserdata(state, ActorHandleData);
    handle.* = ActorHandleData.init(actor);

    pushActorMetatable(state, runtime);
    luau.setMetatable(state, -2);
}

/// Pushes the Actor userdata metatable.
fn pushActorMetatable(state: *luau.State, runtime: *CallbackRuntime) void {
    luau.createTable(state, 0, 4);

    const metatable_index = luau.stackTop(state);

    setRuntimeCallbackField(state, metatable_index, runtime, "__index", actorIndexCallbackC, "Actor.__index");
    setRuntimeCallbackField(state, metatable_index, runtime, "__newindex", actorNewIndexCallbackC, "Actor.__newindex");

    luau.pushString(state, "YukiActor");
    luau.setField(state, metatable_index, "__metatable");

    luau.setReadonly(state, metatable_index, true);
}

/// Reads an Actor userdata receiver.
fn actorFromReceiver(state: *luau.State, receiver_index: i32) ?ScriptActor {
    const handle = luau.toUserdata(state, ActorHandleData, receiver_index) orelse return null;
    return handle.scriptActor() catch null;
}

/// Raises a Luau runtime error.
fn raise(state: *luau.State, message: [:0]const u8) c_int {
    return luau.raiseError(state, message);
}

/// Converts world/context errors into script-facing messages.
fn raiseContextError(state: *luau.State, err: context_mod.Error) c_int {
    return switch (err) {
        error.MissingWorld => raise(state, "world is unavailable during this script callback"),
        error.MissingScriptActor => raise(state, "script actor was not found"),
        error.StaleScriptActor => raise(state, "script actor is stale"),
        error.ScriptActorKeyTooLong => raise(state, "script actor key is empty or too long"),
        error.DuplicateScriptActorKey => raise(state, "script actor key is already registered"),
        error.ScriptActorRegistryFull => raise(state, "script actor registry is full"),
        else => raise(state, "world query failed"),
    };
}

/// Unwraps the nullable C callback state.
fn unwrapState(state: ?*luau.State) *luau.State {
    return state orelse unreachable;
}

fn worldActorCallbackC(state: ?*luau.State) callconv(.c) c_int {
    return worldActorCallback(unwrapState(state));
}

fn worldRequireActorCallbackC(state: ?*luau.State) callconv(.c) c_int {
    return worldRequireActorCallback(unwrapState(state));
}

fn actorIndexCallbackC(state: ?*luau.State) callconv(.c) c_int {
    return actorIndexCallback(unwrapState(state));
}

fn actorNewIndexCallbackC(state: ?*luau.State) callconv(.c) c_int {
    return actorNewIndexCallback(unwrapState(state));
}

fn actorIsAliveCallbackC(state: ?*luau.State) callconv(.c) c_int {
    return actorIsAliveCallback(unwrapState(state));
}

fn actorMoveByCallbackC(state: ?*luau.State) callconv(.c) c_int {
    return actorMoveByCallback(unwrapState(state));
}

fn actorSetPositionCallbackC(state: ?*luau.State) callconv(.c) c_int {
    return actorSetPositionCallback(unwrapState(state));
}

/// Implements `ctx.world:actor(key)`.
fn worldActorCallback(state: *luau.State) callconv(.c) c_int {
    const runtime = runtimeFromUpvalue(state) orelse {
        return raise(state, "ctx.world callback missing runtime");
    };

    const context = runtime.activeContext() orelse {
        return raise(state, "ctx.world is only available during script callbacks");
    };

    const key = luau.readString(state, 2) orelse {
        return raise(state, "ctx.world:actor expected an actor key string");
    };

    const actor = context.worldActor(key) catch |err| {
        return raiseContextError(state, err);
    };

    if (actor) |value| {
        pushActorHandle(state, runtime, value);
    } else {
        luau.pushNil(state);
    }

    return 1;
}

/// Implements `ctx.world:requireActor(key)`.
fn worldRequireActorCallback(state: *luau.State) callconv(.c) c_int {
    const runtime = runtimeFromUpvalue(state) orelse {
        return raise(state, "ctx.world callback missing runtime");
    };

    const context = runtime.activeContext() orelse {
        return raise(state, "ctx.world is only available during script callbacks");
    };

    const key = luau.readString(state, 2) orelse {
        return raise(state, "ctx.world:requireActor expected an actor key string");
    };

    const actor = context.worldRequireActor(key) catch |err| {
        return raiseContextError(state, err);
    };

    pushActorHandle(state, runtime, actor);
    return 1;
}

/// Implements Actor property reads and method lookup.
fn actorIndexCallback(state: *luau.State) callconv(.c) c_int {
    const runtime = runtimeFromUpvalue(state) orelse {
        return raise(state, "Actor callback missing runtime");
    };

    const context = runtime.activeContext() orelse {
        return raise(state, "Actor is only available during script callbacks");
    };

    const actor = actorFromReceiver(state, 1) orelse {
        return raise(state, "Actor property read expected an Actor receiver");
    };

    const field = luau.readString(state, 2) orelse {
        return raise(state, "Actor property read expected a field name");
    };

    if (std.mem.eql(u8, field, "position")) {
        const position = context.worldActorPosition(actor) catch |err| {
            return raiseContextError(state, err);
        };

        luau.pushVector2(state, @floatCast(position.x), @floatCast(position.y));
        return 1;
    }

    if (std.mem.eql(u8, field, "isAlive")) {
        pushRuntimeCallback(state, runtime, actorIsAliveCallbackC, "Actor.isAlive");
        return 1;
    }

    if (std.mem.eql(u8, field, "moveBy")) {
        pushRuntimeCallback(state, runtime, actorMoveByCallbackC, "Actor.moveBy");
        return 1;
    }

    if (std.mem.eql(u8, field, "setPosition")) {
        pushRuntimeCallback(state, runtime, actorSetPositionCallbackC, "Actor.setPosition");
        return 1;
    }

    luau.pushNil(state);
    return 1;
}

/// Implements Actor property writes.
fn actorNewIndexCallback(state: *luau.State) callconv(.c) c_int {
    const context = activeContextFromState(state) orelse {
        return raise(state, "Actor is only available during script callbacks");
    };

    const actor = actorFromReceiver(state, 1) orelse {
        return raise(state, "Actor property write expected an Actor receiver");
    };

    const field = luau.readString(state, 2) orelse {
        return raise(state, "Actor property write expected a field name");
    };

    if (!std.mem.eql(u8, field, "position")) {
        return raise(state, "Actor only supports assigning position in v0");
    }

    const value = luau.readVector2Value(state, 3) orelse {
        return raise(state, "Actor.position expected a Vector2 value");
    };

    context.setWorldActorPosition(actor, vectorFromLuau(value)) catch |err| {
        return raiseContextError(state, err);
    };

    return 0;
}

/// Implements `actor:isAlive()`.
fn actorIsAliveCallback(state: *luau.State) callconv(.c) c_int {
    const context = activeContextFromState(state) orelse {
        return raise(state, "Actor is only available during script callbacks");
    };

    const actor = actorFromReceiver(state, 1) orelse {
        return raise(state, "Actor:isAlive expected an Actor receiver");
    };

    const alive = context.worldActorAlive(actor) catch |err| {
        return raiseContextError(state, err);
    };

    luau.pushBoolean(state, alive);
    return 1;
}

/// Implements `actor:moveBy(delta)`.
fn actorMoveByCallback(state: *luau.State) callconv(.c) c_int {
    const context = activeContextFromState(state) orelse {
        return raise(state, "Actor is only available during script callbacks");
    };

    const actor = actorFromReceiver(state, 1) orelse {
        return raise(state, "Actor:moveBy expected an Actor receiver");
    };

    const delta = luau.readVector2Value(state, 2) orelse {
        return raise(state, "Actor:moveBy expected a Vector2 delta");
    };

    context.moveWorldActorBy(actor, vectorFromLuau(delta)) catch |err| {
        return raiseContextError(state, err);
    };

    return 0;
}

/// Implements `actor:setPosition(position)`.
fn actorSetPositionCallback(state: *luau.State) callconv(.c) c_int {
    const context = activeContextFromState(state) orelse {
        return raise(state, "Actor is only available during script callbacks");
    };

    const actor = actorFromReceiver(state, 1) orelse {
        return raise(state, "Actor:setPosition expected an Actor receiver");
    };

    const position = luau.readVector2Value(state, 2) orelse {
        return raise(state, "Actor:setPosition expected a Vector2 position");
    };

    context.setWorldActorPosition(actor, vectorFromLuau(position)) catch |err| {
        return raiseContextError(state, err);
    };

    return 0;
}
