const std = @import("std");
const render2d = @import("render2d.zig");

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

pub const max_tile_rules = 256;

pub const TileFlags = struct {
    solid: bool = false,
};

pub const TileRules = struct {
    flags: [max_tile_rules]TileFlags,

    pub fn init() TileRules {
        return .{
            .flags = [_]TileFlags{.{}} ** max_tile_rules,
        };
    }

    pub fn setSolid(self: *TileRules, tile: Tile, solid: bool) void {
        std.debug.assert(!tile.isEmpty());

        self.flags[tileRuleIndex(tile)].solid = solid;
    }

    pub fn isSolid(self: TileRules, tile: Tile) bool {
        if (tile.isEmpty()) return false;

        return self.flags[tileRuleIndex(tile)].solid;
    }
};

pub const TileHit = struct {
    x: u32,
    y: u32,
    tile: Tile,
};

pub const MoveResult = struct {
    position: render2d.Vector2,
    blocked_x: bool = false,
    blocked_y: bool = false,
};

pub const TileRange = struct {
    min_x: u32,
    min_y: u32,
    max_x: u32,
    max_y: u32,

    pub fn empty() TileRange {
        return .{
            .min_x = 0,
            .min_y = 0,
            .max_x = 0,
            .max_y = 0,
        };
    }

    pub fn isEmpty(self: TileRange) bool {
        return self.min_x >= self.max_x or self.min_y >= self.max_y;
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

        const expected_tile_count =
            @as(usize, @intCast(width)) * @as(usize, @intCast(height));
        std.debug.assert(tiles.len == expected_tile_count);

        return .{
            .width = width,
            .height = height,
            .tile_size = tile_size,
            .tiles = tiles,
        };
    }

    fn index(self: Tilemap, x: u32, y: u32) usize {
        return @as(usize, @intCast(y)) * @as(usize, @intCast(self.width)) +
            @as(usize, @intCast(x));
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

    pub fn worldBounds(self: Tilemap, origin: render2d.Vector2) render2d.Rect2D {
        return render2d.Rect2D.fromMinSize(
            origin,
            render2d.Vector2.xy(
                @as(f32, @floatFromInt(self.width)) * self.tile_size.x,
                @as(f32, @floatFromInt(self.height)) * self.tile_size.y,
            ),
        );
    }

    pub fn tileBounds(
        self: Tilemap,
        origin: render2d.Vector2,
        x: u32,
        y: u32,
    ) render2d.Rect2D {
        std.debug.assert(x < self.width);
        std.debug.assert(y < self.height);

        return render2d.Rect2D.fromMinSize(
            render2d.Vector2.xy(
                origin.x + @as(f32, @floatFromInt(x)) * self.tile_size.x,
                origin.y + @as(f32, @floatFromInt(y)) * self.tile_size.y,
            ),
            self.tile_size,
        );
    }

    pub fn visibleRange(
        self: Tilemap,
        origin: render2d.Vector2,
        visible_world: render2d.Rect2D,
    ) TileRange {
        if (!self.worldBounds(origin).intersects(visible_world)) {
            return TileRange.empty();
        }

        const min_x = floorTileIndex(
            (visible_world.min.x - origin.x) / self.tile_size.x,
            self.width,
        );
        const min_y = floorTileIndex(
            (visible_world.min.y - origin.y) / self.tile_size.y,
            self.height,
        );
        const max_x = ceilTileIndex(
            (visible_world.max.x - origin.x) / self.tile_size.x,
            self.width,
        );
        const max_y = ceilTileIndex(
            (visible_world.max.y - origin.y) / self.tile_size.y,
            self.height,
        );

        return .{
            .min_x = min_x,
            .min_y = min_y,
            .max_x = max_x,
            .max_y = max_y,
        };
    }

    pub fn drawVisible(
        self: Tilemap,
        draw_list: *render2d.DrawList,
        tileset: Tileset,
        origin: render2d.Vector2,
        visible_world: render2d.Rect2D,
        layer: i32,
    ) !void {
        try self.drawVisibleTinted(
            draw_list,
            tileset,
            origin,
            visible_world,
            render2d.ColorRgba.rgb(1.0, 1.0, 1.0),
            layer,
        );
    }

    pub fn drawVisibleTinted(
        self: Tilemap,
        draw_list: *render2d.DrawList,
        tileset: Tileset,
        origin: render2d.Vector2,
        visible_world: render2d.Rect2D,
        tint: render2d.ColorRgba,
        layer: i32,
    ) !void {
        const range = self.visibleRange(origin, visible_world);
        if (range.isEmpty()) return;

        var y = range.min_y;
        while (y < range.max_y) : (y += 1) {
            var x = range.min_x;
            while (x < range.max_x) : (x += 1) {
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

    pub fn firstSolidInRect(
        self: Tilemap,
        rules: TileRules,
        origin: render2d.Vector2,
        rect: render2d.Rect2D,
        x_forward: bool,
        y_forward: bool,
    ) ?TileHit {
        const range = self.visibleRange(origin, rect);
        if (range.isEmpty()) return null;

        const x_count = range.max_x - range.min_x;
        const y_count = range.max_y - range.min_y;

        var y_offset: u32 = 0;
        while (y_offset < y_count) : (y_offset += 1) {
            const y = orderedRangeValue(
                range.min_y,
                range.max_y,
                y_offset,
                y_forward,
            );

            var x_offset: u32 = 0;
            while (x_offset < x_count) : (x_offset += 1) {
                const x = orderedRangeValue(
                    range.min_x,
                    range.max_x,
                    x_offset,
                    x_forward,
                );

                const tile = self.tileAt(x, y);
                if (!rules.isSolid(tile)) continue;

                return .{
                    .x = x,
                    .y = y,
                    .tile = tile,
                };
            }
        }

        return null;
    }

    pub fn intersectsSolid(
        self: Tilemap,
        rules: TileRules,
        origin: render2d.Vector2,
        rect: render2d.Rect2D,
    ) bool {
        return self.firstSolidInRect(
            rules,
            origin,
            rect,
            true,
            true,
        ) != null;
    }

    pub fn moveAabb(
        self: Tilemap,
        rules: TileRules,
        origin: render2d.Vector2,
        position: render2d.Vector2,
        size: render2d.Vector2,
        delta: render2d.Vector2,
    ) MoveResult {
        std.debug.assert(size.x > 0.0);
        std.debug.assert(size.y > 0.0);

        const half_size = render2d.Vector2.xy(size.x * 0.5, size.y * 0.5);

        var result = MoveResult{
            .position = position,
        };

        if (delta.x != 0.0) {
            var next_position = result.position;
            next_position.x += delta.x;

            const next_rect = render2d.Rect2D.fromCenterSize(
                next_position,
                size,
            );

            if (self.firstSolidInRect(
                rules,
                origin,
                next_rect,
                delta.x > 0.0,
                true,
            )) |hit| {
                const bounds = self.tileBounds(origin, hit.x, hit.y);

                if (delta.x > 0.0) {
                    next_position.x = bounds.min.x - half_size.x;
                } else {
                    next_position.x = bounds.max.x + half_size.x;
                }

                result.blocked_x = true;
            }

            result.position.x = next_position.x;
        }

        if (delta.y != 0.0) {
            var next_position = result.position;
            next_position.y += delta.y;

            const next_rect = render2d.Rect2D.fromCenterSize(
                next_position,
                size,
            );

            if (self.firstSolidInRect(
                rules,
                origin,
                next_rect,
                true,
                delta.y > 0.0,
            )) |hit| {
                const bounds = self.tileBounds(origin, hit.x, hit.y);

                if (delta.y > 0.0) {
                    next_position.y = bounds.min.y - half_size.y;
                } else {
                    next_position.y = bounds.max.y + half_size.y;
                }

                result.blocked_y = true;
            }

            result.position.y = next_position.y;
        }

        return result;
    }
};

pub fn StaticTilemap(comptime map_width: u32, comptime map_height: u32) type {
    comptime {
        if (map_width == 0) @compileError("StaticTilemap width must be greater than zero");
        if (map_height == 0) @compileError("StaticTilemap height must be greater than zero");
    }

    const tile_count = @as(usize, map_width) * @as(usize, map_height);

    return struct {
        const Self = @This();

        pub const width = map_width;
        pub const height = map_height;

        tiles: [tile_count]Tile,

        pub fn empty() Self {
            return .{
                .tiles = [_]Tile{Tile.empty()} ** tile_count,
            };
        }

        pub fn filled(tile: Tile) Self {
            return .{
                .tiles = [_]Tile{tile} ** tile_count,
            };
        }

        pub fn view(self: *const Self, tile_size: render2d.Vector2) Tilemap {
            return Tilemap.init(
                map_width,
                map_height,
                tile_size,
                self.tiles[0..],
            );
        }

        pub fn items(self: *const Self) []const Tile {
            return self.tiles[0..];
        }

        pub fn set(self: *Self, x: u32, y: u32, tile: Tile) void {
            std.debug.assert(x < map_width);
            std.debug.assert(y < map_height);

            self.tiles[index(x, y)] = tile;
        }

        pub fn get(self: *const Self, x: u32, y: u32) Tile {
            std.debug.assert(x < map_width);
            std.debug.assert(y < map_height);

            return self.tiles[index(x, y)];
        }

        pub fn fill(self: *Self, tile: Tile) void {
            for (&self.tiles) |*slot| {
                slot.* = tile;
            }
        }

        pub fn clear(self: *Self) void {
            self.fill(Tile.empty());
        }

        pub fn fillRect(
            self: *Self,
            x: u32,
            y: u32,
            rect_width: u32,
            rect_height: u32,
            tile: Tile,
        ) void {
            std.debug.assert(rect_width > 0);
            std.debug.assert(rect_height > 0);
            std.debug.assert(x < map_width);
            std.debug.assert(y < map_height);
            std.debug.assert(rect_width <= map_width - x);
            std.debug.assert(rect_height <= map_height - y);

            var tile_y = y;
            while (tile_y < y + rect_height) : (tile_y += 1) {
                var tile_x = x;
                while (tile_x < x + rect_width) : (tile_x += 1) {
                    self.set(tile_x, tile_y, tile);
                }
            }
        }

        pub fn clearRect(
            self: *Self,
            x: u32,
            y: u32,
            rect_width: u32,
            rect_height: u32,
        ) void {
            self.fillRect(
                x,
                y,
                rect_width,
                rect_height,
                Tile.empty(),
            );
        }

        pub fn setBorder(self: *Self, tile: Tile) void {
            var x: u32 = 0;
            while (x < map_width) : (x += 1) {
                self.set(x, 0, tile);
                self.set(x, map_height - 1, tile);
            }

            var y: u32 = 0;
            while (y < map_height) : (y += 1) {
                self.set(0, y, tile);
                self.set(map_width - 1, y, tile);
            }
        }

        pub fn checker(self: *Self, first: Tile, second: Tile) void {
            var y: u32 = 0;
            while (y < map_height) : (y += 1) {
                var x: u32 = 0;
                while (x < map_width) : (x += 1) {
                    const use_first = ((x + y) % 2) == 0;
                    self.set(x, y, if (use_first) first else second);
                }
            }
        }

        fn index(x: u32, y: u32) usize {
            return @as(usize, y) * @as(usize, map_width) + @as(usize, x);
        }
    };
}

fn tileRuleIndex(tile: Tile) usize {
    std.debug.assert(!tile.isEmpty());

    const index: usize = @intCast(tile.atlasIndex());
    std.debug.assert(index < max_tile_rules);

    return index;
}

fn orderedRangeValue(min: u32, max: u32, offset: u32, forward: bool) u32 {
    std.debug.assert(min < max);
    std.debug.assert(offset < max - min);

    return if (forward)
        min + offset
    else
        max - 1 - offset;
}

fn floorTileIndex(relative: f32, limit: u32) u32 {
    if (relative <= 0.0) return 0;

    const limit_float = @as(f32, @floatFromInt(limit));
    if (relative >= limit_float) return limit;

    return @intFromFloat(@floor(relative));
}

fn ceilTileIndex(relative: f32, limit: u32) u32 {
    if (relative <= 0.0) return 0;

    const limit_float = @as(f32, @floatFromInt(limit));
    if (relative >= limit_float) return limit;

    return @intFromFloat(@ceil(relative));
}

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

test "tile rules mark selected tiles solid" {
    const floor = Tile.fromAtlasIndex(0);
    const wall = Tile.fromAtlasIndex(1);

    var rules = TileRules.init();
    rules.setSolid(wall, true);

    try std.testing.expect(!rules.isSolid(Tile.empty()));
    try std.testing.expect(!rules.isSolid(floor));
    try std.testing.expect(rules.isSolid(wall));
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
