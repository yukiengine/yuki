//! World2D actor tag and overlap query tests.
//!
//! These tests target the internal world table directly while still using the
//! public Yuki2D facade for shared render types.

const std = @import("std");
const yuki2d = @import("yuki2d.zig");
const world2d = @import("world2d.zig");

const render2d = yuki2d.render;

const ActorQuery = world2d.ActorQuery;
const ActorQueryResult = world2d.ActorQueryResult;
const ActorTag = world2d.ActorTag;
const World = world2d.World;

test "world finds and counts actors by tag" {
    const player_tag = ActorTag.fromIndex(1);
    const marker_tag = ActorTag.fromIndex(2);

    var world = World.init();

    const player = try world.spawn(.{
        .position = render2d.Vector2.xy(1.0, 2.0),
        .size = render2d.Vector2.xy(8.0, 8.0),
        .tag = player_tag,
    });

    _ = try world.spawn(.{
        .position = render2d.Vector2.xy(3.0, 4.0),
        .size = render2d.Vector2.xy(8.0, 8.0),
        .tag = marker_tag,
    });

    _ = try world.spawn(.{
        .position = render2d.Vector2.xy(5.0, 6.0),
        .size = render2d.Vector2.xy(8.0, 8.0),
        .tag = marker_tag,
    });

    try std.testing.expectEqual(player.index, world.findFirstByTag(player_tag).?.index);
    try std.testing.expectEqual(@as(usize, 1), world.countByTag(player_tag));
    try std.testing.expectEqual(@as(usize, 2), world.countByTag(marker_tag));
}

test "world despawns actors by tag" {
    const pickup_tag = ActorTag.fromIndex(3);

    var world = World.init();

    const first = try world.spawn(.{
        .size = render2d.Vector2.xy(8.0, 8.0),
        .tag = pickup_tag,
    });

    const second = try world.spawn(.{
        .size = render2d.Vector2.xy(8.0, 8.0),
        .tag = pickup_tag,
    });

    const other = try world.spawn(.{
        .size = render2d.Vector2.xy(8.0, 8.0),
    });

    try std.testing.expectEqual(@as(usize, 2), world.despawnByTag(pickup_tag));
    try std.testing.expect(world.get(first) == null);
    try std.testing.expect(world.get(second) == null);
    try std.testing.expect(world.get(other) != null);
}

test "world finds actors overlapping a rectangle" {
    const pickup_tag = ActorTag.fromIndex(1);

    var world = World.init();

    const first = try world.spawn(.{
        .position = render2d.Vector2.xy(10.0, 10.0),
        .size = render2d.Vector2.xy(10.0, 10.0),
        .tag = pickup_tag,
    });

    _ = try world.spawn(.{
        .position = render2d.Vector2.xy(100.0, 100.0),
        .size = render2d.Vector2.xy(10.0, 10.0),
        .tag = pickup_tag,
    });

    const query = ActorQuery
        .all(render2d.Rect2D.fromCenterSize(
            render2d.Vector2.xy(10.0, 10.0),
            render2d.Vector2.xy(20.0, 20.0),
        ))
        .withTag(pickup_tag);

    const hit = world.firstActorInRect(query).?;

    try std.testing.expectEqual(first.index, hit.id.index);
    try std.testing.expect(hit.tag.eql(pickup_tag));
}

test "world overlap query can exclude an actor" {
    const player_tag = ActorTag.fromIndex(1);

    var world = World.init();

    const first = try world.spawn(.{
        .position = render2d.Vector2.xy(0.0, 0.0),
        .size = render2d.Vector2.xy(16.0, 16.0),
        .tag = player_tag,
    });

    const second = try world.spawn(.{
        .position = render2d.Vector2.xy(0.0, 0.0),
        .size = render2d.Vector2.xy(16.0, 16.0),
        .tag = player_tag,
    });

    const query = ActorQuery
        .all(render2d.Rect2D.fromCenterSize(
            render2d.Vector2.xy(0.0, 0.0),
            render2d.Vector2.xy(32.0, 32.0),
        ))
        .withTag(player_tag)
        .withoutActor(first);

    const hit = world.firstActorInRect(query).?;

    try std.testing.expectEqual(second.index, hit.id.index);
}

test "world collects actors overlapping a rectangle" {
    const pickup_tag = ActorTag.fromIndex(2);

    var world = World.init();

    _ = try world.spawn(.{
        .position = render2d.Vector2.xy(0.0, 0.0),
        .size = render2d.Vector2.xy(8.0, 8.0),
        .tag = pickup_tag,
    });

    _ = try world.spawn(.{
        .position = render2d.Vector2.xy(10.0, 0.0),
        .size = render2d.Vector2.xy(8.0, 8.0),
        .tag = pickup_tag,
    });

    _ = try world.spawn(.{
        .position = render2d.Vector2.xy(100.0, 0.0),
        .size = render2d.Vector2.xy(8.0, 8.0),
        .tag = pickup_tag,
    });

    var result = ActorQueryResult.init();

    try world.collectActorsInRect(
        ActorQuery
            .all(render2d.Rect2D.fromCenterSize(
                render2d.Vector2.xy(5.0, 0.0),
                render2d.Vector2.xy(32.0, 16.0),
            ))
            .withTag(pickup_tag),
        &result,
    );

    try std.testing.expectEqual(@as(usize, 2), result.items().len);
}

test "world detects actor overlap by tag" {
    const player_tag = ActorTag.fromIndex(1);
    const enemy_tag = ActorTag.fromIndex(2);

    var world = World.init();

    const player = try world.spawn(.{
        .position = render2d.Vector2.xy(0.0, 0.0),
        .size = render2d.Vector2.xy(16.0, 16.0),
        .tag = player_tag,
    });

    const enemy = try world.spawn(.{
        .position = render2d.Vector2.xy(4.0, 0.0),
        .size = render2d.Vector2.xy(16.0, 16.0),
        .tag = enemy_tag,
    });

    const hit = world.firstActorOverlappingActor(player, enemy_tag).?;

    try std.testing.expectEqual(enemy.index, hit.id.index);
}
