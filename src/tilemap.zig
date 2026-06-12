const std = @import("std");
const render2d = @import("render2d/renderer.zig");

pub const Tile = struct {
    id: u16,

    pub fn empty() Tile {
        return .{ .id = 0 };
    }

    pub fn fromAtlasIndex(index: u16) Tile {
        return .{ .id = index + 1 };
    }

    pub fn isEmpty(self: Tile) bool {
        return self.id == 0;
    }

    pub fn atlasIndex(self: Tile) u32 {
        std.debug.assert(!self.isEmpty());
        return @as(u32, self.id) - 1;
    }
};

pub const Tileset = struct {
    atlas: render2d.TextureAtlas,
    tile_width: u32,
    tile_height: u32,
    columns: u32,
    rows: u32,

    pub fn init(
        atlas: render2d.TextureAtlas,
        tile_width: u32,
        tile_height: u32,
    ) Tileset {
        std.debug.assert(tile_width > 0);
        std.debug.assert(tile_height > 0);
        std.debug.assert(atlas.width >= tile_width);
        std.debug.assert(atlas.height >= tile_height);
        std.debug.assert(atlas.width % tile_width == 0);
        std.debug.assert(atlas.height % tile_height == 0);

        return .{
            .atlas = atlas,
            .tile_width = tile_width,
            .tile_height = tile_height,
            .columns = atlas.width / tile_width,
            .rows = atlas.height / tile_height,
        };
    }

    pub fn tileCount(self: Tileset) u32 {
        return self.columns * self.rows;
    }

    pub fn sprite(self: Tileset, tile: Tile) render2d.Sprite {
        const atlas_index = tile.atlasIndex();
        std.debug.assert(atlas_index < self.tileCount());

        const column = atlas_index % self.columns;
        const row = atlas_index / self.columns;

        return self.atlas.spriteGrid(
            column,
            row,
            self.tile_width,
            self.tile_height,
        );
    }
};

pub const Tilemap = struct {
    width: u32,
    height: u32,
    tile_size: render2d.Vector2,
    tiles: []const Tile,

    pub fn init(
        width: u32,
        height: u32,
        tile_size: render2d.Vector2,
        tiles: []const Tile,
    ) Tilemap {
        std.debug.assert(width > 0);
        std.debug.assert(height > 0);
        std.debug.assert(tile_size.x > 0.0);
        std.debug.assert(tile_size.y > 0.0);
        std.debug.assert(tiles.len == @as(usize, @intCast(width * height)));

        return .{
            .width = width,
            .height = height,
            .tile_size = tile_size,
            .tiles = tiles,
        };
    }

    pub fn tileAt(self: Tilemap, x: u32, y: u32) Tile {
        std.debug.assert(x < self.width);
        std.debug.assert(y < self.height);

        return self.tiles[self.index(x, y)];
    }

    pub fn draw(
        self: Tilemap,
        draw_list: *render2d.DrawList,
        tileset: Tileset,
        origin: render2d.Vector2,
        layer: i32,
    ) !void {
        try self.drawTinted(
            draw_list,
            tileset,
            origin,
            render2d.ColorRgba.rgb(1.0, 1.0, 1.0),
            layer,
        );
    }

    pub fn drawTinted(
        self: Tilemap,
        draw_list: *render2d.DrawList,
        tileset: Tileset,
        origin: render2d.Vector2,
        tint: render2d.ColorRgba,
        layer: i32,
    ) !void {
        var y: u32 = 0;
        while (y < self.height) : (y += 1) {
            var x: u32 = 0;
            while (x < self.width) : (x += 1) {
                const tile = self.tileAt(x, y);
                if (tile.isEmpty()) continue;

                var sprite = tileset.sprite(tile);
                sprite.tint = tint;

                try draw_list.drawSpriteLayer(
                    self.tileCenter(origin, x, y),
                    self.tile_size,
                    sprite,
                    layer,
                );
            }
        }
    }

    fn tileCenter(
        self: Tilemap,
        origin: render2d.Vector2,
        x: u32,
        y: u32,
    ) render2d.Vector2 {
        return render2d.Vector2.xy(
            origin.x + @as(f32, @floatFromInt(x)) * self.tile_size.x +
                self.tile_size.x * 0.5,
            origin.y + @as(f32, @floatFromInt(y)) * self.tile_size.y +
                self.tile_size.y * 0.5,
        );
    }

    fn index(self: Tilemap, x: u32, y: u32) usize {
        return @intCast(y * self.width + x);
    }
};

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
