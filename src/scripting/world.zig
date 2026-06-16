//! Script-facing 2D world registry.
//!
//! Luau scripts should not receive raw engine pointers or search actors by
//! display names. The runtime API described in `docs/15_LUAU_RUNTIME_API.md`
//! says scripts should use stable actor keys such as `"player"` and receive
//! handles that remain generation-checked.
//!
//! This module adds that missing Zig-side layer. It maps script actor keys to
//! `scene2d.ActorId` values, verifies that handles still point at live actors,
//! and exposes the small position API needed by the first scripted movement
//! demo. A later slice can bind this to Luau as `ctx.world:requireActor("player")`.

const std = @import("std");
const render2d = @import("../render2d.zig");
const scene2d = @import("../scene2d.zig");

/// Maximum number of keyed actor entries exposed to scripts.
pub const max_script_actors = 64;

/// Maximum bytes in one script actor key.
pub const max_actor_key_bytes = 64;

/// Errors returned by script-facing world lookups and mutations.
pub const Error = error{
    ScriptActorRegistryFull,
    ScriptActorKeyTooLong,
    DuplicateScriptActorKey,
    MissingScriptActor,
    StaleScriptActor,
};

/// Public 2D scene type borrowed by ScriptWorld.
pub const Scene = scene2d.Scene;

/// Public actor handle stored behind script keys.
pub const ActorId = scene2d.ActorId;

/// Shared 2D vector type used by script actor properties.
pub const Vector2 = render2d.Vector2;

/// Fixed-size owned actor key.
///
/// The key is copied into the registry so callers do not need to keep source
/// strings alive. This is intentionally byte-based and case-sensitive; higher
/// level naming policy can come later.
pub const ActorKey = struct {
    bytes: [max_actor_key_bytes]u8 = undefined,
    len: u8 = 0,

    /// Copies a caller-provided key into bounded key storage.
    pub fn init(value: []const u8) Error!ActorKey {
        if (value.len == 0 or value.len > max_actor_key_bytes) {
            return Error.ScriptActorKeyTooLong;
        }

        var key = ActorKey{};
        @memcpy(key.bytes[0..value.len], value);
        key.len = @intCast(value.len);
        return key;
    }

    /// Returns the key bytes as a slice.
    pub fn slice(self: *const ActorKey) []const u8 {
        return self.bytes[0..self.len];
    }

    /// Returns true when this key has the provided bytes.
    pub fn eql(self: *const ActorKey, value: []const u8) bool {
        return std.mem.eql(u8, self.slice(), value);
    }
};

/// One key-to-actor mapping.
pub const ActorBinding = struct {
    key: ActorKey,
    id: ActorId,

    /// Creates a binding from key bytes and an actor handle.
    pub fn init(key: []const u8, id: ActorId) Error!ActorBinding {
        return .{
            .key = try ActorKey.init(key),
            .id = id,
        };
    }
};

/// Script-facing handle to a keyed actor.
///
/// This is a value handle, not a pointer. Every operation goes back through
/// ScriptWorld and the scene's generation checks.
pub const ScriptActor = struct {
    key: ActorKey,
    id: ActorId,

    /// Returns the stable script key for this actor handle.
    pub fn keyName(self: *const ScriptActor) []const u8 {
        return self.key.slice();
    }

    /// Returns the generation-checked engine actor id.
    pub fn actorId(self: ScriptActor) ActorId {
        return self.id;
    }

    /// Returns true when this handle still points at a live scene actor.
    pub fn isAlive(self: ScriptActor, world: *const ScriptWorld) bool {
        return world.isActorAlive(self);
    }

    /// Reads the actor position through ScriptWorld.
    pub fn position(self: ScriptActor, world: *const ScriptWorld) Error!Vector2 {
        return world.actorPosition(self);
    }

    /// Replaces the actor position through ScriptWorld.
    pub fn setPosition(
        self: ScriptActor,
        world: *ScriptWorld,
        value: Vector2,
    ) Error!void {
        try world.setActorPosition(self, value);
    }

    /// Moves the actor by a delta through ScriptWorld.
    pub fn moveBy(
        self: ScriptActor,
        world: *ScriptWorld,
        delta: Vector2,
    ) Error!void {
        const current = try self.position(world);
        try self.setPosition(world, Vector2.xy(
            current.x + delta.x,
            current.y + delta.y,
        ));
    }
};

/// Registry that maps script keys to live scene actors.
pub const ScriptWorld = struct {
    scene: *Scene,
    bindings: [max_script_actors]ActorBinding = undefined,
    binding_count: usize = 0,

    /// Creates a script world view over a mutable scene.
    pub fn init(scene: *Scene) ScriptWorld {
        return .{
            .scene = scene,
        };
    }

    /// Returns the number of registered script actor keys.
    pub fn count(self: *const ScriptWorld) usize {
        return self.binding_count;
    }

    /// Returns true when no actor keys are registered.
    pub fn isEmpty(self: *const ScriptWorld) bool {
        return self.binding_count == 0;
    }

    /// Removes every script actor key while leaving scene actors untouched.
    pub fn clear(self: *ScriptWorld) void {
        self.binding_count = 0;
    }

    /// Registers a stable script key for a live scene actor.
    pub fn bindActor(
        self: *ScriptWorld,
        key: []const u8,
        id: ActorId,
    ) Error!void {
        _ = try ActorKey.init(key);

        if (self.scene.actorConst(id) == null) {
            return Error.StaleScriptActor;
        }

        if (self.findBindingIndex(key)) |_| {
            return Error.DuplicateScriptActorKey;
        }

        if (self.binding_count == max_script_actors) {
            return Error.ScriptActorRegistryFull;
        }

        self.bindings[self.binding_count] = try ActorBinding.init(key, id);
        self.binding_count += 1;
    }

    /// Replaces or inserts a stable script key for a live scene actor.
    pub fn putActor(
        self: *ScriptWorld,
        key: []const u8,
        id: ActorId,
    ) Error!void {
        _ = try ActorKey.init(key);

        if (self.scene.actorConst(id) == null) {
            return Error.StaleScriptActor;
        }

        if (self.findBindingIndex(key)) |index| {
            self.bindings[index] = try ActorBinding.init(key, id);
            return;
        }

        try self.bindActor(key, id);
    }

    /// Removes a script actor key and returns true when one existed.
    pub fn unbindActor(self: *ScriptWorld, key: []const u8) bool {
        const index = self.findBindingIndex(key) orelse return false;

        var cursor = index;
        while (cursor + 1 < self.binding_count) : (cursor += 1) {
            self.bindings[cursor] = self.bindings[cursor + 1];
        }

        self.binding_count -= 1;
        return true;
    }

    /// Returns true when a script key is registered.
    pub fn containsActor(self: *const ScriptWorld, key: []const u8) bool {
        return self.findBindingIndex(key) != null;
    }

    /// Returns an actor handle for a key or null when the key is absent/stale.
    pub fn actor(self: *const ScriptWorld, key: []const u8) ?ScriptActor {
        const binding = self.findBinding(key) orelse return null;

        if (self.scene.actorConst(binding.id) == null) {
            return null;
        }

        return .{
            .key = binding.key,
            .id = binding.id,
        };
    }

    /// Returns an actor handle for a key or an explicit error.
    pub fn requireActor(self: *const ScriptWorld, key: []const u8) Error!ScriptActor {
        const binding = self.findBinding(key) orelse return Error.MissingScriptActor;

        if (self.scene.actorConst(binding.id) == null) {
            return Error.StaleScriptActor;
        }

        return .{
            .key = binding.key,
            .id = binding.id,
        };
    }

    /// Returns true when a script actor handle still points at a live actor.
    pub fn isActorAlive(self: *const ScriptWorld, script_actor: ScriptActor) bool {
        return self.scene.actorConst(script_actor.id) != null;
    }

    /// Reads the current actor position.
    pub fn actorPosition(self: *const ScriptWorld, script_actor: ScriptActor) Error!Vector2 {
        const target = self.scene.actorConst(script_actor.id) orelse {
            return Error.StaleScriptActor;
        };

        return target.position;
    }

    /// Replaces the current actor position.
    pub fn setActorPosition(
        self: *ScriptWorld,
        script_actor: ScriptActor,
        position: Vector2,
    ) Error!void {
        if (self.scene.actorConst(script_actor.id) == null) {
            return Error.StaleScriptActor;
        }

        self.scene.setPosition(script_actor.id, position);
    }

    /// Moves the current actor position by a delta.
    pub fn moveActorBy(
        self: *ScriptWorld,
        script_actor: ScriptActor,
        delta: Vector2,
    ) Error!void {
        if (self.scene.actorConst(script_actor.id) == null) {
            return Error.StaleScriptActor;
        }

        self.scene.moveActor(script_actor.id, delta);
    }

    /// Finds a binding by key.
    fn findBinding(self: *const ScriptWorld, key: []const u8) ?ActorBinding {
        const index = self.findBindingIndex(key) orelse return null;
        return self.bindings[index];
    }

    /// Finds the index for a binding key.
    fn findBindingIndex(self: *const ScriptWorld, key: []const u8) ?usize {
        var index: usize = 0;

        while (index < self.binding_count) : (index += 1) {
            if (self.bindings[index].key.eql(key)) return index;
        }

        return null;
    }
};
