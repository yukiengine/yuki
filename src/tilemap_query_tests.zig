//! Tilemap visible range and solid query tests.
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

test "tilemap visible range clips to viewport" {
    const tiles = [_]Tile{Tile.fromAtlasIndex(0)} ** 16;

    const map = Tilemap.init(
        4,
        4,
        render2d.Vector2.xy(16.0, 16.0),
        tiles[0..],
    );

    const range = map.visibleRange(
        render2d.Vector2.xy(0.0, 0.0),
        render2d.Rect2D.fromMinMax(
            render2d.Vector2.xy(8.0, 8.0),
            render2d.Vector2.xy(40.0, 40.0),
        ),
    );

    try std.testing.expectEqual(@as(u32, 0), range.min_x);
    try std.testing.expectEqual(@as(u32, 0), range.min_y);
    try std.testing.expectEqual(@as(u32, 3), range.max_x);
    try std.testing.expectEqual(@as(u32, 3), range.max_y);
}

test "tilemap visible range is empty outside map" {
    const tiles = [_]Tile{Tile.fromAtlasIndex(0)} ** 4;

    const map = Tilemap.init(
        2,
        2,
        render2d.Vector2.xy(16.0, 16.0),
        tiles[0..],
    );

    const range = map.visibleRange(
        render2d.Vector2.xy(0.0, 0.0),
        render2d.Rect2D.fromMinMax(
            render2d.Vector2.xy(100.0, 100.0),
            render2d.Vector2.xy(120.0, 120.0),
        ),
    );

    try std.testing.expect(range.isEmpty());
}

test "tilemap detects solid tiles in world rect" {
    const floor = Tile.fromAtlasIndex(0);
    const wall = Tile.fromAtlasIndex(1);

    const tiles = [_]Tile{
        floor, floor,
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

    try std.testing.expect(map.intersectsSolid(
        rules,
        render2d.Vector2.xy(0.0, 0.0),
        render2d.Rect2D.fromMinSize(
            render2d.Vector2.xy(18.0, 18.0),
            render2d.Vector2.xy(4.0, 4.0),
        ),
    ));

    try std.testing.expect(!map.intersectsSolid(
        rules,
        render2d.Vector2.xy(0.0, 0.0),
        render2d.Rect2D.fromMinSize(
            render2d.Vector2.xy(2.0, 2.0),
            render2d.Vector2.xy(4.0, 4.0),
        ),
    ));
}
