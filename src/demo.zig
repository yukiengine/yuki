const std = @import("std");
const render2d = @import("render2d/renderer.zig");
const input = @import("input.zig");

const layer_background: i32 = -10;
const layer_world: i32 = 0;
const layer_player: i32 = 10;
const layer_overlay: i32 = 100;

pub const Input = struct {
    move_x: i32 = 0,
    move_y: i32 = 0,
    zoom_in: bool = false,
    zoom_out: bool = false,
    pause_animation_pressed: bool = false,
    reset_animation_pressed: bool = false,

    pub fn fromState(state: *const input.State) Input {
        return .{
            .move_x = state.axisX(),
            .move_y = state.axisY(),
            .zoom_in = state.isDown(.zoom_in),
            .zoom_out = state.isDown(.zoom_out),
            .pause_animation_pressed = state.wasPressed(.pause_animation),
            .reset_animation_pressed = state.wasPressed(.reset_animation),
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

    pub fn init(player_animation: render2d.SpriteAnimation, debug_atlas: render2d.TextureAtlas) Demo {
        return .{
            .animation_player = render2d.AnimationPlayer.init(player_animation),
            .debug_atlas = debug_atlas,
        };
    }

    pub fn update(self: *Demo, input_state: Input, dt_seconds: f32) void {
        const speed: f32 = 240.0;
        self.x += @as(f32, @floatFromInt(input_state.move_x)) * speed * dt_seconds;
        self.y += @as(f32, @floatFromInt(input_state.move_y)) * speed * dt_seconds;

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

    pub fn draw(self: Demo, world: *render2d.DrawList, screen: *render2d.DrawList) !void {
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
            render2d.Vector2.xy(80.0, 80.0),
            self.debug_atlas.spritePixels(0, 0, 1, 1),
            layer_world,
        );
    }
};
