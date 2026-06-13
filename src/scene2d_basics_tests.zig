//! Scene2D basic prefab, spawn, movement, and clearing tests.
//!
//! These tests use the public Yuki2D facade so they exercise the same surface
//! that future Luau bindings should mirror.

const std = @import("std");
const yuki2d = @import("yuki2d.zig");

const render2d = yuki2d.render;
const tilemap = yuki2d.tilemap;
const scene2d = yuki2d.scene;

const Scene = scene2d.Scene;
const ActorTag = scene2d.ActorTag;
const ActorQuery = scene2d.ActorQuery;
const ActorQueryResult = scene2d.ActorQueryResult;
const ActorSnapshotFilter = scene2d.ActorSnapshotFilter;
const ActorSnapshotList = scene2d.ActorSnapshotList;
const ActorLifecycleFilter = scene2d.ActorLifecycleFilter;
const ActorPickFilter = scene2d.ActorPickFilter;
const ActorPickResult = scene2d.ActorPickResult;

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
