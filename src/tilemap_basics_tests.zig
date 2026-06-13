//! Tilemap basic tile, tileset, storage, and rule tests.
//!
//! These tests use the public Yuki2D facade so they exercise the same surface
//! that future Luau bindings should mirror.

const std = @import("std");
const yuki2d = @import("yuki2d.zig");

const render2d = yuki2d.render;
const tilemap = yuki2d.tilemap;

const Tile = tilemap.Tile;
const Tilemap = tilemap.Tilemap;
const Tileset = tilemap.Tileset;
const TileRules = tilemap.TileRules;
const StaticTilemap = tilemap.StaticTilemap;

test "tile atlas index uses zero as empty" {
    const empty = Tile.empty();
    const first = Tile.fromAtlasIndex(0);
    const second = Tile.fromAtlasIndex(1);

    try std.testing.expect(empty.isEmpty());
    try std.testing.expect(!first.isEmpty());
    try std.testing.expectEqual(@as(u32, 0), first.atlasIndex());
    try std.testing.expectEqual(@as(u32, 1), second.atlasIndex());
}

test "tileset counts atlas cells" {
    const atlas = render2d.TextureAtlas.init(
        render2d.TextureId.default(),
        4,
        2,
    );

    const tileset = Tileset.init(atlas, 1, 1);

    try std.testing.expectEqual(@as(u32, 4), tileset.columns);
    try std.testing.expectEqual(@as(u32, 2), tileset.rows);
    try std.testing.expectEqual(@as(u32, 8), tileset.tileCount());
}

test "tilemap indexes rows" {
    const tiles = [_]Tile{
        Tile.fromAtlasIndex(0),
        Tile.fromAtlasIndex(1),
        Tile.empty(),
        Tile.fromAtlasIndex(2),
    };

    const map = Tilemap.init(
        2,
        2,
        render2d.Vector2.xy(16.0, 16.0),
        tiles[0..],
    );

    try std.testing.expectEqual(@as(u16, 1), map.tileAt(0, 0).id);
    try std.testing.expectEqual(@as(u16, 2), map.tileAt(1, 0).id);
    try std.testing.expectEqual(@as(u16, 0), map.tileAt(0, 1).id);
    try std.testing.expectEqual(@as(u16, 3), map.tileAt(1, 1).id);
}

test "static tilemap stores fixed tile data" {
    var map = StaticTilemap(3, 2).empty();

    map.set(1, 0, Tile.fromAtlasIndex(2));
    map.set(2, 1, Tile.fromAtlasIndex(4));

    try std.testing.expect(map.get(0, 0).isEmpty());
    try std.testing.expectEqual(@as(u32, 2), map.get(1, 0).atlasIndex());
    try std.testing.expectEqual(@as(u32, 4), map.get(2, 1).atlasIndex());
}

test "static tilemap can fill rectangles" {
    var map = StaticTilemap(4, 3).empty();

    map.fillRect(1, 1, 2, 1, Tile.fromAtlasIndex(0));

    try std.testing.expect(map.get(0, 0).isEmpty());
    try std.testing.expect(!map.get(1, 1).isEmpty());
    try std.testing.expect(!map.get(2, 1).isEmpty());
    try std.testing.expect(map.get(3, 1).isEmpty());
}

test "static tilemap border fills edges" {
    var map = StaticTilemap(4, 3).empty();

    map.setBorder(Tile.fromAtlasIndex(0));

    try std.testing.expect(!map.get(0, 0).isEmpty());
    try std.testing.expect(!map.get(3, 0).isEmpty());
    try std.testing.expect(!map.get(0, 2).isEmpty());
    try std.testing.expect(!map.get(3, 2).isEmpty());
    try std.testing.expect(map.get(1, 1).isEmpty());
}

test "static tilemap creates a tilemap view" {
    var storage = StaticTilemap(2, 2).empty();
    storage.set(1, 1, Tile.fromAtlasIndex(3));

    const view = storage.view(render2d.Vector2.xy(16.0, 16.0));

    try std.testing.expectEqual(@as(u32, 2), view.width);
    try std.testing.expectEqual(@as(u32, 2), view.height);
    try std.testing.expectEqual(@as(u32, 3), view.tileAt(1, 1).atlasIndex());
}

test "tile rules mark selected tiles solid" {
    const floor = Tile.fromAtlasIndex(0);
    const wall = Tile.fromAtlasIndex(1);

    var rules = TileRules.init();
    rules.setSolid(wall, true);

    try std.testing.expect(!rules.isSolid(Tile.empty()));
    try std.testing.expect(!rules.isSolid(floor));
    try std.testing.expect(rules.isSolid(wall));
}
