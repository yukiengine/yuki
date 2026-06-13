//! Scene2D event queue, command queue, and frame lifecycle tests.
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

test "scene emits first actor overlap event" {
    const player_tag = ActorTag.fromIndex(30);
    const pickup_tag = ActorTag.fromIndex(31);

    var scene = Scene.init();

    const player_prefab = try scene.registerPrefab(.{
        .name = "player",
        .size = render2d.Vector2.xy(16.0, 16.0),
        .tag = player_tag,
    });

    const pickup_prefab = try scene.registerPrefab(.{
        .name = "pickup",
        .size = render2d.Vector2.xy(16.0, 16.0),
        .tag = pickup_tag,
    });

    const player = try scene.spawn(player_prefab, .{
        .position = render2d.Vector2.xy(0.0, 0.0),
    });

    const pickup = try scene.spawn(pickup_prefab, .{
        .position = render2d.Vector2.xy(4.0, 0.0),
    });

    scene.beginFrame();

    try std.testing.expect(try scene.emitFirstActorOverlap(player, pickup_tag));
    try std.testing.expectEqual(@as(usize, 1), scene.eventItems().len);

    const event = scene.eventItems()[0];

    const overlap = event.actorOverlapOrNull().?;
    try std.testing.expect(overlap.actor.eql(player));
    try std.testing.expect(overlap.other.eql(pickup));
    try std.testing.expect(overlap.actor_tag.eql(player_tag));
    try std.testing.expect(overlap.other_tag.eql(pickup_tag));
}

test "scene emits all actor overlap events" {
    const player_tag = ActorTag.fromIndex(32);
    const marker_tag = ActorTag.fromIndex(33);

    var scene = Scene.init();

    const player_prefab = try scene.registerPrefab(.{
        .name = "player",
        .size = render2d.Vector2.xy(16.0, 16.0),
        .tag = player_tag,
    });

    const marker_prefab = try scene.registerPrefab(.{
        .name = "marker",
        .size = render2d.Vector2.xy(16.0, 16.0),
        .tag = marker_tag,
    });

    const player = try scene.spawn(player_prefab, .{});

    _ = try scene.spawn(marker_prefab, .{
        .position = render2d.Vector2.xy(4.0, 0.0),
    });

    _ = try scene.spawn(marker_prefab, .{
        .position = render2d.Vector2.xy(-4.0, 0.0),
    });

    scene.beginFrame();

    const emitted = try scene.emitActorOverlaps(player, marker_tag);

    try std.testing.expectEqual(@as(usize, 2), emitted);
    try std.testing.expectEqual(@as(usize, 2), scene.eventItems().len);
}

test "scene clears frame events" {
    const player_tag = ActorTag.fromIndex(34);
    const marker_tag = ActorTag.fromIndex(35);

    var scene = Scene.init();

    const player_prefab = try scene.registerPrefab(.{
        .name = "player",
        .size = render2d.Vector2.xy(16.0, 16.0),
        .tag = player_tag,
    });

    const marker_prefab = try scene.registerPrefab(.{
        .name = "marker",
        .size = render2d.Vector2.xy(16.0, 16.0),
        .tag = marker_tag,
    });

    const player = try scene.spawn(player_prefab, .{});
    _ = try scene.spawn(marker_prefab, .{});

    _ = try scene.emitActorOverlaps(player, marker_tag);
    scene.clearEvents();

    try std.testing.expectEqual(@as(usize, 0), scene.eventItems().len);
}

test "scene applies queued movement command" {
    var scene = Scene.init();

    const prefab_id = try scene.registerPrefab(.{
        .name = "command.actor",
        .size = render2d.Vector2.xy(8.0, 8.0),
    });

    const actor_id = try scene.spawn(prefab_id, .{
        .position = render2d.Vector2.xy(10.0, 20.0),
    });

    try scene.queueMoveActor(actor_id, render2d.Vector2.xy(5.0, -3.0));
    scene.applyCommands();

    const actor_data = scene.actorConst(actor_id).?;

    try std.testing.expectEqual(@as(f32, 15.0), actor_data.position.x);
    try std.testing.expectEqual(@as(f32, 17.0), actor_data.position.y);
    try std.testing.expectEqual(@as(usize, 0), scene.commandItems().len);
}

test "scene applies queued velocity command" {
    var scene = Scene.init();

    const prefab_id = try scene.registerPrefab(.{
        .name = "velocity.actor",
        .size = render2d.Vector2.xy(8.0, 8.0),
    });

    const actor_id = try scene.spawn(prefab_id, .{});

    try scene.queueSetActorVelocity(actor_id, render2d.Vector2.xy(12.0, -6.0));
    scene.applyCommands();

    const actor_data = scene.actorConst(actor_id).?;

    try std.testing.expectEqual(@as(f32, 12.0), actor_data.velocity.x);
    try std.testing.expectEqual(@as(f32, -6.0), actor_data.velocity.y);
}

test "scene applies queued despawn command" {
    var scene = Scene.init();

    const prefab_id = try scene.registerPrefab(.{
        .name = "despawn.actor",
        .size = render2d.Vector2.xy(8.0, 8.0),
    });

    const actor_id = try scene.spawn(prefab_id, .{});

    try scene.queueDespawnActor(actor_id);
    scene.applyCommands();

    try std.testing.expect(scene.actorConst(actor_id) == null);
    try std.testing.expectEqual(@as(usize, 0), scene.commandItems().len);
}

test "scene frame queues start empty" {
    var scene = Scene.init();

    const queues = scene.frameQueues();

    try std.testing.expect(queues.isEmpty());
    try std.testing.expect(!queues.hasEvents());
    try std.testing.expect(!queues.hasCommands());
    try std.testing.expect(!queues.hasWork());
    try std.testing.expectEqual(@as(usize, 0), queues.event_count);
    try std.testing.expectEqual(@as(usize, 0), queues.command_count);
}

test "scene begin frame clears events and commands" {
    const player_tag = ActorTag.fromIndex(40);
    const marker_tag = ActorTag.fromIndex(41);

    var scene = Scene.init();

    const player_prefab = try scene.registerPrefab(.{
        .name = "frame.player",
        .size = render2d.Vector2.xy(16.0, 16.0),
        .tag = player_tag,
    });

    const marker_prefab = try scene.registerPrefab(.{
        .name = "frame.marker",
        .size = render2d.Vector2.xy(16.0, 16.0),
        .tag = marker_tag,
    });

    const player = try scene.spawn(player_prefab, .{
        .position = render2d.Vector2.xy(0.0, 0.0),
    });

    const marker = try scene.spawn(marker_prefab, .{
        .position = render2d.Vector2.xy(4.0, 0.0),
    });

    scene.beginFrame();

    _ = try scene.emitActorOverlaps(player, marker_tag);
    try scene.queueMoveActor(marker, render2d.Vector2.xy(8.0, 0.0));

    const before = scene.frameQueues();

    try std.testing.expect(before.hasEvents());
    try std.testing.expect(before.hasCommands());
    try std.testing.expect(before.hasWork());
    try std.testing.expectEqual(@as(usize, 1), before.event_count);
    try std.testing.expectEqual(@as(usize, 1), before.command_count);

    scene.beginFrame();

    const after = scene.frameQueues();

    try std.testing.expect(after.isEmpty());
    try std.testing.expectEqual(@as(usize, 0), scene.eventItems().len);
    try std.testing.expectEqual(@as(usize, 0), scene.commandItems().len);
}

test "scene finish frame applies queued movement" {
    var scene = Scene.init();

    const prefab_id = try scene.registerPrefab(.{
        .name = "finish.actor",
        .size = render2d.Vector2.xy(8.0, 8.0),
    });

    const actor_id = try scene.spawn(prefab_id, .{
        .position = render2d.Vector2.xy(10.0, 20.0),
    });

    try scene.queueMoveActor(actor_id, render2d.Vector2.xy(5.0, -3.0));

    try std.testing.expect(scene.hasQueuedCommands());
    try std.testing.expectEqual(@as(usize, 1), scene.frameQueues().command_count);

    scene.finishFrame();

    const actor_data = scene.actorConst(actor_id).?;

    try std.testing.expectEqual(@as(f32, 15.0), actor_data.position.x);
    try std.testing.expectEqual(@as(f32, 17.0), actor_data.position.y);

    try std.testing.expect(!scene.hasQueuedCommands());
    try std.testing.expectEqual(@as(usize, 0), scene.commandItems().len);
}

test "scene finish frame applies queued position replacement" {
    var scene = Scene.init();

    const prefab_id = try scene.registerPrefab(.{
        .name = "position.actor",
        .size = render2d.Vector2.xy(8.0, 8.0),
    });

    const actor_id = try scene.spawn(prefab_id, .{
        .position = render2d.Vector2.xy(1.0, 2.0),
    });

    try scene.queueSetActorPosition(
        actor_id,
        render2d.Vector2.xy(100.0, 200.0),
    );

    scene.finishFrame();

    const actor_data = scene.actorConst(actor_id).?;

    try std.testing.expectEqual(@as(f32, 100.0), actor_data.position.x);
    try std.testing.expectEqual(@as(f32, 200.0), actor_data.position.y);
}

test "scene finish frame applies queued velocity replacement" {
    var scene = Scene.init();

    const prefab_id = try scene.registerPrefab(.{
        .name = "velocity.actor",
        .size = render2d.Vector2.xy(8.0, 8.0),
    });

    const actor_id = try scene.spawn(prefab_id, .{});

    try scene.queueSetActorVelocity(
        actor_id,
        render2d.Vector2.xy(30.0, -12.0),
    );

    scene.finishFrame();

    const actor_data = scene.actorConst(actor_id).?;

    try std.testing.expectEqual(@as(f32, 30.0), actor_data.velocity.x);
    try std.testing.expectEqual(@as(f32, -12.0), actor_data.velocity.y);
}

test "scene finish frame applies queued despawn" {
    var scene = Scene.init();

    const prefab_id = try scene.registerPrefab(.{
        .name = "despawn.frame.actor",
        .size = render2d.Vector2.xy(8.0, 8.0),
    });

    const actor_id = try scene.spawn(prefab_id, .{});

    try scene.queueDespawnActor(actor_id);
    scene.finishFrame();

    try std.testing.expect(scene.actorConst(actor_id) == null);
    try std.testing.expect(!scene.hasQueuedCommands());
    try std.testing.expectEqual(@as(usize, 1), scene.eventReader().countActorLifecycle(
        ActorLifecycleFilter.despawned().withActor(actor_id),
    ));
}
