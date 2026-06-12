const std = @import("std");
const render2d = @import("render2d/renderer.zig");
const input = @import("input.zig");
const tilemap = @import("tilemap.zig");

const layer_background: i32 = -20;
const layer_tilemap: i32 = -10;
const layer_world: i32 = 0;
const layer_player: i32 = 10;
const layer_overlay: i32 = 100;

const demo_map_width: u32 = 10;
const demo_map_height: u32 = 8;
const demo_tile_size = render2d.Vector2.xy(48.0, 48.0);
const demo_map_origin = render2d.Vector2.xy(-240.0, -192.0);
const player_size = render2d.Vector2.xy(80.0, 80.0);

const DemoTilemap = tilemap.StaticTilemap(demo_map_width, demo_map_height);

const tile_empty = tilemap.Tile.empty();
const tile_a = tilemap.Tile.fromAtlasIndex(0);
const tile_b = tilemap.Tile.fromAtlasIndex(1);
const tile_c = tilemap.Tile.fromAtlasIndex(2);
const tile_d = tilemap.Tile.fromAtlasIndex(3);

fn buildDemoMap() DemoTilemap {
    var map = DemoTilemap.filled(tile_empty);

    map.setBorder(tile_a);

    map.fillRect(1, 1, 3, 3, tile_b);
    map.fillRect(6, 1, 3, 3, tile_c);
    map.fillRect(3, 3, 4, 2, tile_b);
    map.fillRect(1, 5, 3, 2, tile_c);
    map.fillRect(6, 5, 3, 2, tile_b);

    map.clearRect(4, 1, 2, 2);
    map.clearRect(1, 4, 2, 1);
    map.clearRect(7, 4, 2, 1);
    map.clearRect(4, 5, 2, 2);

    map.set(2, 2, tile_d);
    map.set(7, 2, tile_d);
    map.set(2, 6, tile_d);
    map.set(7, 6, tile_d);

    return map;
}

pub const Controls = struct {
    pub const move_left = input.ActionId.fromIndex(0);
    pub const move_right = input.ActionId.fromIndex(1);
    pub const move_up = input.ActionId.fromIndex(2);
    pub const move_down = input.ActionId.fromIndex(3);
    pub const zoom_in = input.ActionId.fromIndex(4);
    pub const zoom_out = input.ActionId.fromIndex(5);
    pub const pause_animation = input.ActionId.fromIndex(6);
    pub const reset_animation = input.ActionId.fromIndex(7);
    pub const quit = input.ActionId.fromIndex(8);

    pub fn defaultInputMap() input.InputMap {
        var map = input.InputMap.init();

        map.bind(.escape, quit) catch unreachable;
        map.bind(.space, pause_animation) catch unreachable;
        map.bind(.r, reset_animation) catch unreachable;

        map.bind(.a, move_left) catch unreachable;
        map.bind(.left, move_left) catch unreachable;

        map.bind(.d, move_right) catch unreachable;
        map.bind(.right, move_right) catch unreachable;

        map.bind(.w, move_up) catch unreachable;
        map.bind(.up, move_up) catch unreachable;

        map.bind(.s, move_down) catch unreachable;
        map.bind(.down, move_down) catch unreachable;

        map.bind(.q, zoom_out) catch unreachable;
        map.bind(.e, zoom_in) catch unreachable;

        return map;
    }
};

pub const Input = struct {
    move_x: i32 = 0,
    move_y: i32 = 0,
    zoom_in: bool = false,
    zoom_out: bool = false,
    pause_animation_pressed: bool = false,
    reset_animation_pressed: bool = false,

    pub fn fromState(state: *const input.State) Input {
        return .{
            .move_x = state.axis(Controls.move_left, Controls.move_right),
            .move_y = state.axis(Controls.move_up, Controls.move_down),
            .zoom_in = state.isActionDown(Controls.zoom_in),
            .zoom_out = state.isActionDown(Controls.zoom_out),
            .pause_animation_pressed = state.actionWasPressed(Controls.pause_animation),
            .reset_animation_pressed = state.actionWasPressed(Controls.reset_animation),
        };
    }
};

pub const Demo = struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
    rotation: f32 = 0.0,
    camera_zoom: f32 = 1.0,
    animation_player: render2d.AnimationPlayer,
    debug_atlas: render2d.TextureAtlas,
    tile_storage: DemoTilemap,
    tile_rules: tilemap.TileRules,
    tileset: tilemap.Tileset,

    pub fn init(player_animation: render2d.SpriteAnimation, debug_atlas: render2d.TextureAtlas) Demo {
        return .{
            .animation_player = render2d.AnimationPlayer.init(player_animation),
            .debug_atlas = debug_atlas,
            .tile_storage = buildDemoMap(),
            .tile_rules = buildTileRules(),
            .tileset = tilemap.Tileset.init(debug_atlas, 1, 1),
        };
    }

    pub fn update(self: *Demo, input_state: Input, dt_seconds: f32) void {
        const speed: f32 = 240.0;
        const movement = render2d.Vector2.xy(
            @as(f32, @floatFromInt(input_state.move_x)) * speed * dt_seconds,
            @as(f32, @floatFromInt(input_state.move_y)) * speed * dt_seconds,
        );

        const map = self.tile_storage.view(demo_tile_size);
        const moved = map.moveAabb(
            self.tile_rules,
            demo_map_origin,
            render2d.Vector2.xy(self.x, self.y),
            player_size,
            movement,
        );

        self.x = moved.position.x;
        self.y = moved.position.y;

        if (input_state.pause_animation_pressed) self.animation_player.toggle();
        if (input_state.reset_animation_pressed) self.animation_player.reset();
        self.animation_player.update(dt_seconds);

        self.rotation += 2.0 * dt_seconds;
        if (self.rotation >= std.math.tau) self.rotation -= std.math.tau;

        const zoom_speed: f32 = 1.5;
        if (input_state.zoom_in) self.camera_zoom += zoom_speed * dt_seconds;
        if (input_state.zoom_out) self.camera_zoom -= zoom_speed * dt_seconds;
        self.camera_zoom = @max(0.25, @min(4.0, self.camera_zoom));
    }

    pub fn camera(self: Demo) render2d.Camera2D {
        return render2d.Camera2D.init(render2d.Vector2.xy(self.x, self.y), self.camera_zoom);
    }

    pub fn draw(
        self: *const Demo,
        world: *render2d.DrawList,
        screen: *render2d.DrawList,
        visible_world: render2d.Rect2D,
    ) !void {
        const map = self.tile_storage.view(demo_tile_size);

        try map.drawVisible(
            world,
            self.tileset,
            demo_map_origin,
            visible_world,
            layer_tilemap,
        );

        try world.drawRectLayer(
            render2d.Vector2.xy(0.0, 0.0),
            render2d.Vector2.xy(360.0, 220.0),
            render2d.ColorRgba.rgb(0.15, 0.18, 0.24),
            layer_background,
        );
        try screen.drawRectLayer(
            render2d.Vector2.xy(80.0, 0.0),
            render2d.Vector2.xy(360.0, 140.0),
            render2d.ColorRgba.rgba(1.0, 0.1, 0.1, 0.35),
            layer_overlay,
        );
        try world.drawSpriteTransformLayer(
            render2d.Transform2D.rotated(render2d.Vector2.xy(self.x, self.y), render2d.Vector2.xy(80.0, 80.0), self.rotation),
            self.animation_player.sprite(),
            layer_player,
        );
        try world.drawSpriteLayer(
            render2d.Vector2.xy(-180.0, -120.0),
            player_size,
            self.debug_atlas.spritePixels(0, 0, 1, 1),
            layer_world,
        );
    }
};

fn buildTileRules() tilemap.TileRules {
    var rules = tilemap.TileRules.init();

    rules.setSolid(tile_a, true);
    rules.setSolid(tile_d, true);

    return rules;
}
