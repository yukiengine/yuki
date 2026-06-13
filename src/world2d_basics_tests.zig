//! World2D actor storage and movement tests.
//!
//! These tests target the internal world table directly while still using the
//! public Yuki2D facade for shared render and tilemap types.

const std = @import("std");
const yuki2d = @import("yuki2d.zig");
const world2d = @import("world2d.zig");

const render2d = yuki2d.render;
const tilemap = yuki2d.tilemap;

const World = world2d.World;

test "world spawns and returns actor by handle" {
    var world = World.init();

    const id = try world.spawn(.{
        .position = render2d.Vector2.xy(12.0, 24.0),
        .size = render2d.Vector2.xy(8.0, 16.0),
    });

    const actor = world.get(id).?;

    try std.testing.expectEqual(@as(u16, 0), id.index);
    try std.testing.expectEqual(@as(f32, 12.0), actor.position.x);
    try std.testing.expectEqual(@as(f32, 24.0), actor.position.y);
    try std.testing.expectEqual(@as(f32, 8.0), actor.size.x);
    try std.testing.expectEqual(@as(f32, 16.0), actor.size.y);
}

test "despawn invalidates old actor handle" {
    var world = World.init();

    const first = try world.spawn(.{});
    world.despawn(first);

    try std.testing.expect(world.get(first) == null);

    const second = try world.spawn(.{});
    try std.testing.expect(first.generation != second.generation);
}

test "actor tile movement stops at solid tile" {
    const solid = tilemap.Tile.fromAtlasIndex(0);

    const Storage = tilemap.StaticTilemap(2, 1);
    var storage = Storage.empty();
    storage.set(1, 0, solid);

    var rules = tilemap.TileRules.init();
    rules.setSolid(solid, true);

    const map = storage.view(render2d.Vector2.xy(16.0, 16.0));

    var world = World.init();
    const actor_id = try world.spawn(.{
        .position = render2d.Vector2.xy(4.0, 8.0),
        .size = render2d.Vector2.xy(8.0, 8.0),
    });

    const result = world.moveActorWithTilemap(
        actor_id,
        map,
        rules,
        render2d.Vector2.xy(0.0, 0.0),
        render2d.Vector2.xy(20.0, 0.0),
    );

    const actor = world.get(actor_id).?;

    try std.testing.expect(result.blocked_x);
    try std.testing.expectEqual(@as(f32, 12.0), actor.position.x);
    try std.testing.expectEqual(@as(f32, 8.0), actor.position.y);
}
