//! Scene2D actor snapshot, mutation, lifecycle, and picking tests.
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

test "scene returns actor snapshots" {
    const player_tag = ActorTag.fromIndex(90);

    var scene = Scene.init();

    const player_prefab = try scene.registerPrefab(.{
        .name = "snapshot.player",
        .size = render2d.Vector2.xy(16.0, 24.0),
        .tag = player_tag,
        .layer = 8,
    });

    const player = try scene.spawn(player_prefab, .{
        .position = render2d.Vector2.xy(10.0, 20.0),
    });

    scene.setVelocity(player, render2d.Vector2.xy(3.0, -4.0));

    const snapshot = scene.actorSnapshot(player) orelse return error.ExpectedSnapshot;

    try std.testing.expect(snapshot.id.eql(player));
    try std.testing.expect(snapshot.hasTag(player_tag));
    try std.testing.expectEqual(@as(f32, 10.0), snapshot.position.x);
    try std.testing.expectEqual(@as(f32, 20.0), snapshot.position.y);
    try std.testing.expectEqual(@as(f32, 16.0), snapshot.size.x);
    try std.testing.expectEqual(@as(f32, 24.0), snapshot.size.y);
    try std.testing.expectEqual(@as(f32, 3.0), snapshot.velocity.x);
    try std.testing.expectEqual(@as(f32, -4.0), snapshot.velocity.y);
    try std.testing.expectEqual(@as(i32, 8), snapshot.layer);
}

test "scene collects actor snapshots by tag and rect" {
    const marker_tag = ActorTag.fromIndex(91);
    const enemy_tag = ActorTag.fromIndex(92);

    var scene = Scene.init();

    const marker_prefab = try scene.registerPrefab(.{
        .name = "snapshot.marker",
        .size = render2d.Vector2.xy(8.0, 8.0),
        .tag = marker_tag,
    });

    const enemy_prefab = try scene.registerPrefab(.{
        .name = "snapshot.enemy",
        .size = render2d.Vector2.xy(8.0, 8.0),
        .tag = enemy_tag,
    });

    _ = try scene.spawn(marker_prefab, .{
        .position = render2d.Vector2.xy(0.0, 0.0),
    });

    _ = try scene.spawn(marker_prefab, .{
        .position = render2d.Vector2.xy(10.0, 0.0),
    });

    _ = try scene.spawn(marker_prefab, .{
        .position = render2d.Vector2.xy(100.0, 0.0),
    });

    _ = try scene.spawn(enemy_prefab, .{
        .position = render2d.Vector2.xy(0.0, 0.0),
    });

    var snapshots = ActorSnapshotList.init();

    try scene.collectActorSnapshots(
        ActorSnapshotFilter
            .all()
            .withTag(marker_tag)
            .inRect(render2d.Rect2D.fromCenterSize(
            render2d.Vector2.xy(5.0, 0.0),
            render2d.Vector2.xy(32.0, 16.0),
        )),
        &snapshots,
    );

    try std.testing.expectEqual(@as(usize, 2), snapshots.count());
    try std.testing.expectEqual(@as(usize, 2), snapshots.countByTag(marker_tag));
    try std.testing.expectEqual(@as(usize, 0), snapshots.countByTag(enemy_tag));
}

test "scene actor snapshot filter can exclude actor" {
    const actor_tag = ActorTag.fromIndex(93);

    var scene = Scene.init();

    const prefab_id = try scene.registerPrefab(.{
        .name = "snapshot.exclude",
        .size = render2d.Vector2.xy(8.0, 8.0),
        .tag = actor_tag,
    });

    const first = try scene.spawn(prefab_id, .{
        .position = render2d.Vector2.xy(0.0, 0.0),
    });

    const second = try scene.spawn(prefab_id, .{
        .position = render2d.Vector2.xy(10.0, 0.0),
    });

    var snapshots = ActorSnapshotList.init();

    try scene.collectActorSnapshots(
        ActorSnapshotFilter
            .all()
            .withTag(actor_tag)
            .withoutActor(first),
        &snapshots,
    );

    try std.testing.expectEqual(@as(usize, 1), snapshots.count());

    const only = snapshots.first() orelse return error.ExpectedSnapshot;
    try std.testing.expect(only.id.eql(second));
}

test "scene direct actor mutation helpers update snapshot state" {
    const first_tag = ActorTag.fromIndex(100);
    const second_tag = ActorTag.fromIndex(101);

    var scene = Scene.init();

    const prefab_id = try scene.registerPrefab(.{
        .name = "mutation.actor",
        .size = render2d.Vector2.xy(8.0, 8.0),
        .tag = first_tag,
        .layer = 2,
    });

    const actor_id = try scene.spawn(prefab_id, .{});

    scene.setPosition(actor_id, render2d.Vector2.xy(10.0, 20.0));
    scene.setVelocity(actor_id, render2d.Vector2.xy(3.0, -4.0));
    scene.setActorRotation(actor_id, 1.0);
    scene.rotateActor(actor_id, 0.5);
    scene.setActorLayer(actor_id, 9);
    scene.setActorTag(actor_id, second_tag);

    const snapshot = scene.actorSnapshot(actor_id) orelse return error.ExpectedSnapshot;

    try std.testing.expectEqual(@as(f32, 10.0), snapshot.position.x);
    try std.testing.expectEqual(@as(f32, 20.0), snapshot.position.y);
    try std.testing.expectEqual(@as(f32, 3.0), snapshot.velocity.x);
    try std.testing.expectEqual(@as(f32, -4.0), snapshot.velocity.y);
    try std.testing.expectEqual(@as(f32, 1.5), snapshot.rotation_radians);
    try std.testing.expectEqual(@as(i32, 9), snapshot.layer);
    try std.testing.expect(snapshot.hasTag(second_tag));
}

test "scene applies queued actor transform commands" {
    const first_tag = ActorTag.fromIndex(102);
    const second_tag = ActorTag.fromIndex(103);

    var scene = Scene.init();

    const prefab_id = try scene.registerPrefab(.{
        .name = "queued.mutation.actor",
        .size = render2d.Vector2.xy(8.0, 8.0),
        .tag = first_tag,
    });

    const actor_id = try scene.spawn(prefab_id, .{});

    try scene.queueSetActorPosition(actor_id, render2d.Vector2.xy(30.0, 40.0));
    try scene.queueSetActorVelocity(actor_id, render2d.Vector2.xy(5.0, 6.0));
    try scene.queueSetActorRotation(actor_id, 0.25);
    try scene.queueRotateActor(actor_id, 0.75);
    try scene.queueSetActorLayer(actor_id, 12);
    try scene.queueSetActorTag(actor_id, second_tag);

    scene.finishFrame();

    const snapshot = scene.actorSnapshot(actor_id) orelse return error.ExpectedSnapshot;

    try std.testing.expectEqual(@as(f32, 30.0), snapshot.position.x);
    try std.testing.expectEqual(@as(f32, 40.0), snapshot.position.y);
    try std.testing.expectEqual(@as(f32, 5.0), snapshot.velocity.x);
    try std.testing.expectEqual(@as(f32, 6.0), snapshot.velocity.y);
    try std.testing.expectEqual(@as(f32, 1.0), snapshot.rotation_radians);
    try std.testing.expectEqual(@as(i32, 12), snapshot.layer);
    try std.testing.expect(snapshot.hasTag(second_tag));
    try std.testing.expectEqual(@as(usize, 0), scene.commandItems().len);
}

test "scene applies queued animation commands" {
    var scene = Scene.init();

    const atlas = render2d.TextureAtlas.init(render2d.TextureId.default(), 2, 1);
    const animation = render2d.SpriteAnimation.init(
        atlas,
        0,
        0,
        2,
        1,
        1,
        0.1,
    );

    const prefab_id = try scene.registerPrefab(.{
        .name = "animated.actor",
        .size = render2d.Vector2.xy(8.0, 8.0),
        .animation = animation,
    });

    const actor_id = try scene.spawn(prefab_id, .{});

    scene.updateAnimations(0.2);

    {
        const actor_data = scene.actorConst(actor_id) orelse return error.ExpectedActor;
        try std.testing.expect(actor_data.animation_player.?.elapsed_seconds > 0.0);
        try std.testing.expect(actor_data.animation_player.?.playing);
    }

    try scene.queueResetActorAnimation(actor_id);
    try scene.queueToggleActorAnimation(actor_id);
    scene.finishFrame();

    {
        const actor_data = scene.actorConst(actor_id) orelse return error.ExpectedActor;
        try std.testing.expectEqual(@as(f32, 0.0), actor_data.animation_player.?.elapsed_seconds);
        try std.testing.expect(!actor_data.animation_player.?.playing);
    }

    try scene.queueToggleActorAnimation(actor_id);
    scene.finishFrame();

    {
        const actor_data = scene.actorConst(actor_id) orelse return error.ExpectedActor;
        try std.testing.expect(actor_data.animation_player.?.playing);
    }
}

test "scene emits actor spawned event" {
    const player_tag = ActorTag.fromIndex(120);

    var scene = Scene.init();

    const prefab_id = try scene.registerPrefab(.{
        .name = "lifecycle.spawn",
        .size = render2d.Vector2.xy(32.0, 32.0),
        .tag = player_tag,
    });

    const actor = try scene.spawn(prefab_id, .{
        .position = render2d.Vector2.xy(0.0, 0.0),
    });

    const reader = scene.eventReader();

    try std.testing.expect(reader.hasActorLifecycle(
        ActorLifecycleFilter.spawned().withActor(actor),
    ));

    const event = reader.firstActorLifecycle(
        ActorLifecycleFilter.spawned().withTag(player_tag),
    ) orelse return error.MissingSpawnEvent;

    const payload = event.actorLifecycleOrNull() orelse return error.MissingSpawnPayload;

    try std.testing.expect(payload.actor.eql(actor));
    try std.testing.expect(payload.tag.eql(player_tag));
}

test "scene emits actor despawned event" {
    const enemy_tag = ActorTag.fromIndex(121);

    var scene = Scene.init();

    const prefab_id = try scene.registerPrefab(.{
        .name = "lifecycle.despawn",
        .size = render2d.Vector2.xy(32.0, 32.0),
        .tag = enemy_tag,
    });

    const actor = try scene.spawn(prefab_id, .{});

    scene.beginFrame();
    scene.despawn(actor);

    const reader = scene.eventReader();

    try std.testing.expect(reader.hasActorLifecycle(
        ActorLifecycleFilter.despawned().withActor(actor),
    ));

    const event = reader.firstActorLifecycle(
        ActorLifecycleFilter.despawned().withTag(enemy_tag),
    ) orelse return error.MissingDespawnEvent;

    const payload = event.actorLifecycleOrNull() orelse return error.MissingDespawnPayload;

    try std.testing.expect(payload.actor.eql(actor));
    try std.testing.expect(payload.tag.eql(enemy_tag));
}

test "scene picks top actor at point" {
    const actor_tag = ActorTag.fromIndex(130);

    var scene = Scene.init();

    const low_prefab = try scene.registerPrefab(.{
        .name = "pick.low",
        .size = render2d.Vector2.xy(32.0, 32.0),
        .layer = 0,
        .tag = actor_tag,
    });

    const high_prefab = try scene.registerPrefab(.{
        .name = "pick.high",
        .size = render2d.Vector2.xy(32.0, 32.0),
        .layer = 20,
        .tag = actor_tag,
    });

    _ = try scene.spawn(low_prefab, .{
        .position = render2d.Vector2.xy(0.0, 0.0),
    });

    const high = try scene.spawn(high_prefab, .{
        .position = render2d.Vector2.xy(0.0, 0.0),
    });

    const hit = scene.topActorAtPoint(
        render2d.Vector2.xy(0.0, 0.0),
        ActorPickFilter.all().withTag(actor_tag),
    ) orelse return error.ExpectedPickHit;

    try std.testing.expect(hit.actor().eql(high));
    try std.testing.expectEqual(@as(i32, 20), hit.layer());
}

test "scene collects actors at point" {
    const actor_tag = ActorTag.fromIndex(131);

    var scene = Scene.init();

    const prefab_id = try scene.registerPrefab(.{
        .name = "pick.collect",
        .size = render2d.Vector2.xy(32.0, 32.0),
        .tag = actor_tag,
    });

    const first = try scene.spawn(prefab_id, .{
        .position = render2d.Vector2.xy(0.0, 0.0),
    });

    const second = try scene.spawn(prefab_id, .{
        .position = render2d.Vector2.xy(8.0, 0.0),
    });

    var result = ActorPickResult.init();

    try scene.collectActorsAtPoint(
        render2d.Vector2.xy(4.0, 0.0),
        ActorPickFilter.all().withTag(actor_tag),
        &result,
    );

    try std.testing.expectEqual(@as(usize, 2), result.count());
    try std.testing.expect(result.items()[0].actor().eql(first));
    try std.testing.expect(result.items()[1].actor().eql(second));
}
