//! Tilemap AABB movement and collision tests.
//!
//! These tests use the public Yuki2D facade so they exercise the same surface
//! that future Luau bindings should mirror.

const std = @import("std");
const yuki2d = @import("yuki2d.zig");

const render2d = yuki2d.render;
const tilemap = yuki2d.tilemap;

const Tile = tilemap.Tile;
const Tilemap = tilemap.Tilemap;
const TileRules = tilemap.TileRules;

test "tilemap horizontal movement stops at solid tile" {
    const floor = Tile.fromAtlasIndex(0);
    const wall = Tile.fromAtlasIndex(1);

    const tiles = [_]Tile{
        floor, wall,
        floor, wall,
    };

    const map = Tilemap.init(
        2,
        2,
        render2d.Vector2.xy(16.0, 16.0),
        tiles[0..],
    );

    var rules = TileRules.init();
    rules.setSolid(wall, true);

    const moved = map.moveAabb(
        rules,
        render2d.Vector2.xy(0.0, 0.0),
        render2d.Vector2.xy(6.0, 8.0),
        render2d.Vector2.xy(8.0, 8.0),
        render2d.Vector2.xy(20.0, 0.0),
    );

    try std.testing.expect(moved.blocked_x);
    try std.testing.expectEqual(@as(f32, 12.0), moved.position.x);
    try std.testing.expectEqual(@as(f32, 8.0), moved.position.y);
}

test "tilemap vertical movement stops at solid tile" {
    const floor = Tile.fromAtlasIndex(0);
    const wall = Tile.fromAtlasIndex(1);

    const tiles = [_]Tile{
        floor, floor,
        wall,  wall,
    };

    const map = Tilemap.init(
        2,
        2,
        render2d.Vector2.xy(16.0, 16.0),
        tiles[0..],
    );

    var rules = TileRules.init();
    rules.setSolid(wall, true);

    const moved = map.moveAabb(
        rules,
        render2d.Vector2.xy(0.0, 0.0),
        render2d.Vector2.xy(8.0, 6.0),
        render2d.Vector2.xy(8.0, 8.0),
        render2d.Vector2.xy(0.0, 20.0),
    );

    try std.testing.expect(moved.blocked_y);
    try std.testing.expectEqual(@as(f32, 8.0), moved.position.x);
    try std.testing.expectEqual(@as(f32, 12.0), moved.position.y);
}
