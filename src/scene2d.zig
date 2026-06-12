const std = @import("std");
const render2d = @import("render2d/renderer.zig");
const tilemap = @import("tilemap.zig");
const world2d = @import("world2d.zig");
const prefab2d = @import("prefab2d.zig");

/// Public actor handle used by 2D scenes.
pub const ActorId = world2d.ActorId;

/// Public prefab handle used by 2D scenes.
pub const PrefabId = prefab2d.PrefabId;

/// Public actor type stored by a scene.
pub const Actor = world2d.Actor;

/// Public actor prefab type registered into a scene.
pub const ActorPrefab = prefab2d.ActorPrefab;

/// Optional values used to override prefab defaults when spawning.
pub const SpawnOverride = prefab2d.SpawnOverride;

/// Scene-level errors.
pub const Error = prefab2d.Error;

/// High-level 2D scene made of prefabs and actors.
pub const Scene = struct {
    world: world2d.World,
    prefabs: prefab2d.PrefabCatalog,

    /// Creates an empty 2D scene.
    pub fn init() Scene {
        return .{
            .world = world2d.World.init(),
            .prefabs = prefab2d.PrefabCatalog.init(),
        };
    }

    /// Registers a prefab and returns its handle.
    pub fn registerPrefab(self: *Scene, actor_prefab: ActorPrefab) !PrefabId {
        return try self.prefabs.add(actor_prefab);
    }

    /// Returns true when a prefab name exists in the scene catalog.
    pub fn hasPrefab(self: *const Scene, name: []const u8) bool {
        return self.prefabs.containsName(name);
    }

    /// Finds a prefab by name.
    pub fn prefabId(self: *const Scene, name: []const u8) ?PrefabId {
        return self.prefabs.findByName(name);
    }

    /// Returns a prefab by handle.
    pub fn prefab(self: *const Scene, id: PrefabId) ActorPrefab {
        return self.prefabs.get(id);
    }

    /// Spawns an actor from a prefab handle.
    pub fn spawn(
        self: *Scene,
        prefab_id: PrefabId,
        spawn_override: SpawnOverride,
    ) !ActorId {
        return try self.prefabs.spawn(
            prefab_id,
            &self.world,
            spawn_override,
        );
    }

    /// Spawns an actor from a prefab name.
    pub fn spawnByName(
        self: *Scene,
        name: []const u8,
        spawn_override: SpawnOverride,
    ) !ActorId {
        return try self.prefabs.spawnByName(
            name,
            &self.world,
            spawn_override,
        );
    }

    /// Despawns an actor and invalidates its handle.
    pub fn despawn(self: *Scene, id: ActorId) void {
        self.world.despawn(id);
    }

    /// Returns a mutable actor pointer for a valid handle.
    pub fn actor(self: *Scene, id: ActorId) ?*Actor {
        return self.world.get(id);
    }

    /// Returns a const actor pointer for a valid handle.
    pub fn actorConst(self: *const Scene, id: ActorId) ?*const Actor {
        return self.world.getConst(id);
    }

    /// Sets an actor velocity.
    pub fn setVelocity(self: *Scene, id: ActorId, velocity: render2d.Vector2) void {
        self.world.setVelocity(id, velocity);
    }

    /// Moves an actor directly without collision.
    pub fn moveActor(self: *Scene, id: ActorId, delta: render2d.Vector2) void {
        self.world.moveActor(id, delta);
    }

    /// Moves an actor using tilemap AABB collision.
    pub fn moveActorWithTilemap(
        self: *Scene,
        id: ActorId,
        map: tilemap.Tilemap,
        rules: tilemap.TileRules,
        origin: render2d.Vector2,
        delta: render2d.Vector2,
    ) tilemap.MoveResult {
        return self.world.moveActorWithTilemap(
            id,
            map,
            rules,
            origin,
            delta,
        );
    }

    /// Moves one actor by its velocity for a time step.
    pub fn integrateActorVelocity(self: *Scene, id: ActorId, dt_seconds: f32) void {
        std.debug.assert(dt_seconds >= 0.0);

        const target = self.actor(id) orelse unreachable;
        target.moveBy(scaledVelocity(target.velocity, dt_seconds));
    }

    /// Advances all actors with velocity and animations.
    pub fn update(self: *Scene, dt_seconds: f32) void {
        std.debug.assert(dt_seconds >= 0.0);

        for (&self.world.actors) |*target| {
            if (!target.active) continue;

            target.moveBy(scaledVelocity(target.velocity, dt_seconds));
            target.updateAnimation(dt_seconds);
        }
    }

    /// Advances animations for all live actors without applying velocity.
    pub fn updateAnimations(self: *Scene, dt_seconds: f32) void {
        self.world.updateAnimations(dt_seconds);
    }

    /// Draws every live actor.
    pub fn draw(self: *const Scene, draw_list: *render2d.DrawList) !void {
        try self.world.draw(draw_list);
    }

    /// Draws live actors that intersect the visible world rectangle.
    pub fn drawVisible(
        self: *const Scene,
        draw_list: *render2d.DrawList,
        visible_world: render2d.Rect2D,
    ) !void {
        try self.world.drawVisible(draw_list, visible_world);
    }

    /// Removes all actors while keeping registered prefabs.
    pub fn clearActors(self: *Scene) void {
        var index: usize = 0;
        while (index < world2d.max_actors) : (index += 1) {
            if (!self.world.actors[index].active) continue;

            const id = ActorId{
                .index = @intCast(index),
                .generation = self.world.actors[index].generation,
            };

            self.world.despawn(id);
        }
    }
};

/// Returns velocity scaled by a frame delta.
fn scaledVelocity(velocity: render2d.Vector2, dt_seconds: f32) render2d.Vector2 {
    return render2d.Vector2.xy(
        velocity.x * dt_seconds,
        velocity.y * dt_seconds,
    );
}

test "scene registers and finds prefabs" {
    var scene = Scene.init();

    const id = try scene.registerPrefab(.{
        .name = "demo.player",
        .size = render2d.Vector2.xy(32.0, 48.0),
        .layer = 10,
    });

    try std.testing.expect(scene.hasPrefab("demo.player"));
    try std.testing.expect(scene.prefabId("missing") == null);
    try std.testing.expectEqual(id.index, scene.prefabId("demo.player").?.index);

    const prefab_value = scene.prefab(id);
    try std.testing.expectEqualStrings("demo.player", prefab_value.name);
    try std.testing.expectEqual(@as(i32, 10), prefab_value.layer);
}

test "scene spawns actors by prefab handle" {
    var scene = Scene.init();

    const prefab_id = try scene.registerPrefab(.{
        .name = "test.actor",
        .size = render2d.Vector2.xy(10.0, 20.0),
        .layer = 3,
    });

    const actor_id = try scene.spawn(prefab_id, .{
        .position = render2d.Vector2.xy(100.0, 200.0),
    });

    const target = scene.actor(actor_id).?;

    try std.testing.expectEqual(@as(f32, 100.0), target.position.x);
    try std.testing.expectEqual(@as(f32, 200.0), target.position.y);
    try std.testing.expectEqual(@as(f32, 10.0), target.size.x);
    try std.testing.expectEqual(@as(f32, 20.0), target.size.y);
    try std.testing.expectEqual(@as(i32, 3), target.layer);
}

test "scene spawns actors by prefab name" {
    var scene = Scene.init();

    _ = try scene.registerPrefab(.{
        .name = "demo.marker",
        .size = render2d.Vector2.xy(16.0, 16.0),
    });

    const actor_id = try scene.spawnByName("demo.marker", .{
        .position = render2d.Vector2.xy(-12.0, 8.0),
    });

    const target = scene.actorConst(actor_id).?;

    try std.testing.expectEqual(@as(f32, -12.0), target.position.x);
    try std.testing.expectEqual(@as(f32, 8.0), target.position.y);
}

test "scene integrates actor velocity" {
    var scene = Scene.init();

    const prefab_id = try scene.registerPrefab(.{
        .name = "moving.actor",
        .size = render2d.Vector2.xy(8.0, 8.0),
    });

    const actor_id = try scene.spawn(prefab_id, .{
        .position = render2d.Vector2.xy(1.0, 2.0),
    });

    scene.setVelocity(actor_id, render2d.Vector2.xy(10.0, -4.0));
    scene.integrateActorVelocity(actor_id, 0.5);

    const target = scene.actorConst(actor_id).?;

    try std.testing.expectEqual(@as(f32, 6.0), target.position.x);
    try std.testing.expectEqual(@as(f32, 0.0), target.position.y);
}

test "scene update applies velocity to all live actors" {
    var scene = Scene.init();

    const prefab_id = try scene.registerPrefab(.{
        .name = "moving.actor",
        .size = render2d.Vector2.xy(8.0, 8.0),
    });

    const first = try scene.spawn(prefab_id, .{
        .position = render2d.Vector2.xy(0.0, 0.0),
    });

    const second = try scene.spawn(prefab_id, .{
        .position = render2d.Vector2.xy(10.0, 10.0),
    });

    scene.setVelocity(first, render2d.Vector2.xy(2.0, 0.0));
    scene.setVelocity(second, render2d.Vector2.xy(0.0, 4.0));

    scene.update(2.0);

    try std.testing.expectEqual(@as(f32, 4.0), scene.actorConst(first).?.position.x);
    try std.testing.expectEqual(@as(f32, 18.0), scene.actorConst(second).?.position.y);
}

test "scene movement can use tilemap collision" {
    const solid = tilemap.Tile.fromAtlasIndex(0);

    const Storage = tilemap.StaticTilemap(2, 1);
    var storage = Storage.empty();
    storage.set(1, 0, solid);

    var rules = tilemap.TileRules.init();
    rules.setSolid(solid, true);

    const map = storage.view(render2d.Vector2.xy(16.0, 16.0));

    var scene = Scene.init();
    const prefab_id = try scene.registerPrefab(.{
        .name = "collider",
        .size = render2d.Vector2.xy(8.0, 8.0),
    });

    const actor_id = try scene.spawn(prefab_id, .{
        .position = render2d.Vector2.xy(4.0, 8.0),
    });

    const result = scene.moveActorWithTilemap(
        actor_id,
        map,
        rules,
        render2d.Vector2.xy(0.0, 0.0),
        render2d.Vector2.xy(20.0, 0.0),
    );

    const target = scene.actorConst(actor_id).?;

    try std.testing.expect(result.blocked_x);
    try std.testing.expectEqual(@as(f32, 12.0), target.position.x);
}

test "scene can clear actors without clearing prefabs" {
    var scene = Scene.init();

    const prefab_id = try scene.registerPrefab(.{
        .name = "clear.test",
        .size = render2d.Vector2.xy(8.0, 8.0),
    });

    const actor_id = try scene.spawn(prefab_id, .{});
    scene.clearActors();

    try std.testing.expect(scene.actor(actor_id) == null);
    try std.testing.expect(scene.hasPrefab("clear.test"));
}

test "scene clear invalidates handles before slot reuse" {
    var scene = Scene.init();

    const prefab_id = try scene.registerPrefab(.{
        .name = "reuse.test",
        .size = render2d.Vector2.xy(8.0, 8.0),
    });

    const first = try scene.spawn(prefab_id, .{});
    scene.clearActors();

    const second = try scene.spawn(prefab_id, .{});

    try std.testing.expectEqual(first.index, second.index);
    try std.testing.expect(first.generation != second.generation);
    try std.testing.expect(scene.actor(first) == null);
    try std.testing.expect(scene.actor(second) != null);
}
