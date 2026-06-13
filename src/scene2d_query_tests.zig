//! Scene2D actor query and overlap lookup tests.
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

test "scene queries actors by tag" {
    const player_tag = ActorTag.fromIndex(1);
    const marker_tag = ActorTag.fromIndex(2);

    var scene = Scene.init();

    const player_prefab = try scene.registerPrefab(.{
        .name = "player",
        .size = render2d.Vector2.xy(8.0, 8.0),
        .tag = player_tag,
    });

    const marker_prefab = try scene.registerPrefab(.{
        .name = "marker",
        .size = render2d.Vector2.xy(8.0, 8.0),
        .tag = marker_tag,
    });

    const player = try scene.spawn(player_prefab, .{});
    _ = try scene.spawn(marker_prefab, .{});
    _ = try scene.spawn(marker_prefab, .{});

    try std.testing.expectEqual(player.index, scene.findFirstByTag(player_tag).?.index);
    try std.testing.expectEqual(@as(usize, 1), scene.countByTag(player_tag));
    try std.testing.expectEqual(@as(usize, 2), scene.countByTag(marker_tag));
}

test "scene despawns actors by tag" {
    const enemy_tag = ActorTag.fromIndex(10);

    var scene = Scene.init();

    const enemy_prefab = try scene.registerPrefab(.{
        .name = "enemy",
        .size = render2d.Vector2.xy(8.0, 8.0),
        .tag = enemy_tag,
    });

    const first = try scene.spawn(enemy_prefab, .{});
    const second = try scene.spawn(enemy_prefab, .{});

    try std.testing.expectEqual(@as(usize, 2), scene.despawnByTag(enemy_tag));
    try std.testing.expect(scene.actor(first) == null);
    try std.testing.expect(scene.actor(second) == null);
}

test "scene finds actor overlaps by rectangle" {
    const pickup_tag = ActorTag.fromIndex(20);

    var scene = Scene.init();

    const prefab_id = try scene.registerPrefab(.{
        .name = "pickup",
        .size = render2d.Vector2.xy(8.0, 8.0),
        .tag = pickup_tag,
    });

    const pickup = try scene.spawn(prefab_id, .{
        .position = render2d.Vector2.xy(12.0, 0.0),
    });

    const hit = scene.firstActorInRect(
        ActorQuery
            .all(render2d.Rect2D.fromCenterSize(
                render2d.Vector2.xy(12.0, 0.0),
                render2d.Vector2.xy(16.0, 16.0),
            ))
            .withTag(pickup_tag),
    ).?;

    try std.testing.expectEqual(pickup.index, hit.id.index);
}

test "scene collects actor overlaps" {
    const marker_tag = ActorTag.fromIndex(21);

    var scene = Scene.init();

    const prefab_id = try scene.registerPrefab(.{
        .name = "marker",
        .size = render2d.Vector2.xy(8.0, 8.0),
        .tag = marker_tag,
    });

    _ = try scene.spawn(prefab_id, .{
        .position = render2d.Vector2.xy(0.0, 0.0),
    });

    _ = try scene.spawn(prefab_id, .{
        .position = render2d.Vector2.xy(10.0, 0.0),
    });

    var result = ActorQueryResult.init();

    try scene.collectActorsInRect(
        ActorQuery
            .all(render2d.Rect2D.fromCenterSize(
                render2d.Vector2.xy(5.0, 0.0),
                render2d.Vector2.xy(32.0, 16.0),
            ))
            .withTag(marker_tag),
        &result,
    );

    try std.testing.expectEqual(@as(usize, 2), result.items().len);
}

test "scene detects actor overlap by tag" {
    const player_tag = ActorTag.fromIndex(22);
    const enemy_tag = ActorTag.fromIndex(23);

    var scene = Scene.init();

    const player_prefab = try scene.registerPrefab(.{
        .name = "player",
        .size = render2d.Vector2.xy(16.0, 16.0),
        .tag = player_tag,
    });

    const enemy_prefab = try scene.registerPrefab(.{
        .name = "enemy",
        .size = render2d.Vector2.xy(16.0, 16.0),
        .tag = enemy_tag,
    });

    const player = try scene.spawn(player_prefab, .{
        .position = render2d.Vector2.xy(0.0, 0.0),
    });

    const enemy = try scene.spawn(enemy_prefab, .{
        .position = render2d.Vector2.xy(4.0, 0.0),
    });

    const hit = scene.firstActorOverlappingActor(player, enemy_tag).?;

    try std.testing.expectEqual(enemy.index, hit.id.index);
}
