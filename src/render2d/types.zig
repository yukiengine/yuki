//! Public 2D rendering types.
//!
//! This file contains the data-oriented API used by game code to describe
//! what should be drawn. It does not own GPU resources.

const std = @import("std");

/// Maximum number of quads that can be submitted in one frame.
pub const max_quads = 128;

pub const DrawError = error{
    TooManyQuads,
};

/// Two-dimensional vector used for positions, sizes, and UV coordinates.
pub const Vector2 = extern struct {
    x: f32,
    y: f32,

    pub fn xy(x: f32, y: f32) Vector2 {
        return .{ .x = x, .y = y };
    }
};

/// Position, size, and rotation for a 2D object.
pub const Transform2D = struct {
    position: Vector2,
    size: Vector2,
    rotation_radians: f32 = 0.0,

    pub fn init(position: Vector2, size: Vector2) Transform2D {
        return .{
            .position = position,
            .size = size,
        };
    }

    pub fn rotated(position: Vector2, size: Vector2, rotation_radians: f32) Transform2D {
        return .{
            .position = position,
            .size = size,
            .rotation_radians = rotation_radians,
        };
    }
};

/// Linear RGBA color with float channels in the 0.0 to 1.0 range.
pub const ColorRgba = extern struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32,

    pub fn rgba(r: f32, g: f32, b: f32, a: f32) ColorRgba {
        return .{ .r = r, .g = g, .b = b, .a = a };
    }

    pub fn rgb(r: f32, g: f32, b: f32) ColorRgba {
        return rgba(r, g, b, 1.0);
    }
};

/// Rectangle inside a texture, expressed in normalized UV coordinates.
pub const UvRect = extern struct {
    min: Vector2,
    max: Vector2,

    pub fn full() UvRect {
        return .{
            .min = Vector2.xy(0.0, 0.0),
            .max = Vector2.xy(1.0, 1.0),
        };
    }

    pub fn init(min: Vector2, max: Vector2) UvRect {
        return .{ .min = min, .max = max };
    }
};

/// Handle to a texture owned by the renderer.
pub const TextureId = extern struct {
    index: u32,

    pub fn default() TextureId {
        return .{ .index = 0 };
    }
};

/// Renderable 2D quad submitted to the renderer.
pub const Quad = struct {
    transform: Transform2D,
    color: ColorRgba,
    texture: TextureId = TextureId.default(),
    uv: UvRect = UvRect.full(),
    layer: i32 = 0,

    pub fn init(position: Vector2, size: Vector2, color: ColorRgba) Quad {
        return .{
            .transform = Transform2D.init(position, size),
            .color = color,
        };
    }

    pub fn sprite(position: Vector2, size: Vector2, sprite_value: Sprite) Quad {
        return .{
            .transform = Transform2D.init(position, size),
            .color = sprite_value.tint,
            .texture = sprite_value.texture,
            .uv = sprite_value.uv,
        };
    }

    pub fn spriteTransform(transform: Transform2D, sprite_value: Sprite) Quad {
        return .{
            .transform = transform,
            .color = sprite_value.tint,
            .texture = sprite_value.texture,
            .uv = sprite_value.uv,
        };
    }

    pub fn withLayer(self: Quad, layer: i32) Quad {
        var quad = self;
        quad.layer = layer;
        return quad;
    }
};

/// Texture region plus tint used to draw a sprite.
pub const Sprite = struct {
    texture: TextureId = TextureId.default(),
    uv: UvRect = UvRect.full(),
    tint: ColorRgba = ColorRgba.rgb(1.0, 1.0, 1.0),

    pub fn init(texture: TextureId) Sprite {
        return .{
            .texture = texture,
        };
    }

    pub fn region(texture: TextureId, uv: UvRect) Sprite {
        return .{
            .texture = texture,
            .uv = uv,
        };
    }

    pub fn tinted(texture: TextureId, uv: UvRect, tint: ColorRgba) Sprite {
        return .{
            .texture = texture,
            .uv = uv,
            .tint = tint,
        };
    }
};

/// Simple 2D camera that converts world coordinates into screen space.
pub const Camera2D = struct {
    position: Vector2 = .{ .x = 0.0, .y = 0.0 },
    zoom: f32 = 1.0,

    pub fn init(position: Vector2, zoom: f32) Camera2D {
        std.debug.assert(zoom > 0.0);

        return .{
            .position = position,
            .zoom = zoom,
        };
    }
};

const empty_quads = [_]Quad{};

/// Complete set of draw data for one rendered frame.
pub const Frame = struct {
    clear_color: ColorRgba,
    quads: []const Quad,
    screen_quads: []const Quad,
    camera: Camera2D,

    pub fn init(clear_color: ColorRgba, quads: []const Quad) Frame {
        return .{
            .clear_color = clear_color,
            .quads = quads,
            .screen_quads = empty_quads[0..],
            .camera = .{},
        };
    }

    pub fn withCamera(clear_color: ColorRgba, camera: Camera2D, quads: []const Quad) Frame {
        return .{
            .clear_color = clear_color,
            .camera = camera,
            .quads = quads,
            .screen_quads = empty_quads[0..],
        };
    }

    pub fn withCameraAndScreen(
        clear_color: ColorRgba,
        camera: Camera2D,
        quads: []const Quad,
        screen_quads: []const Quad,
    ) Frame {
        return .{
            .clear_color = clear_color,
            .camera = camera,
            .quads = quads,
            .screen_quads = screen_quads,
        };
    }
};

/// Temporary per-frame list of draw commands.
pub const DrawList = struct {
    quads: [max_quads]Quad,
    quad_count: usize,

    pub fn init() DrawList {
        return .{
            .quads = undefined,
            .quad_count = 0,
        };
    }

    pub fn drawQuad(self: *DrawList, quad: Quad) !void {
        if (self.quad_count == max_quads) return DrawError.TooManyQuads;

        self.quads[self.quad_count] = quad;
        self.quad_count += 1;
    }

    pub fn drawSprite(self: *DrawList, position: Vector2, size: Vector2, sprite: Sprite) !void {
        try self.drawQuad(Quad.sprite(position, size, sprite));
    }

    pub fn items(self: *const DrawList) []const Quad {
        return self.quads[0..self.quad_count];
    }

    pub fn frame(self: *const DrawList, clear_color: ColorRgba, camera: Camera2D) Frame {
        return Frame.withCamera(clear_color, camera, self.items());
    }

    /// Clears the draw list so it can collect commands for a new frame.
    pub fn beginFrame(self: *DrawList) void {
        self.quad_count = 0;
    }

    pub fn drawSpriteTransform(self: *DrawList, transform: Transform2D, sprite: Sprite) !void {
        try self.drawQuad(Quad.spriteTransform(transform, sprite));
    }

    fn lessThanLayer(_: void, lhs: Quad, rhs: Quad) bool {
        return lhs.layer < rhs.layer;
    }

    pub fn sortByLayer(self: *DrawList) void {
        std.mem.sort(Quad, self.quads[0..self.quad_count], {}, lessThanLayer);
    }

    pub fn drawSpriteLayer(self: *DrawList, position: Vector2, size: Vector2, sprite: Sprite, layer: i32) !void {
        try self.drawQuad(Quad.sprite(position, size, sprite).withLayer(layer));
    }

    pub fn drawSpriteTransformLayer(self: *DrawList, transform: Transform2D, sprite: Sprite, layer: i32) !void {
        try self.drawQuad(Quad.spriteTransform(transform, sprite).withLayer(layer));
    }

    /// Sorts submitted quads by layer and returns a frame view over them.
    pub fn sortedFrame(self: *DrawList, clear_color: ColorRgba, camera: Camera2D) Frame {
        self.sortByLayer();
        return self.frame(clear_color, camera);
    }

    pub fn drawRect(self: *DrawList, position: Vector2, size: Vector2, color: ColorRgba) !void {
        try self.drawQuad(Quad.init(position, size, color));
    }

    pub fn drawRectLayer(self: *DrawList, position: Vector2, size: Vector2, color: ColorRgba, layer: i32) !void {
        try self.drawQuad(Quad.init(position, size, color).withLayer(layer));
    }

    pub fn sortedFrameWithScreen(self: *DrawList, clear_color: ColorRgba, camera: Camera2D, screen_draw_list: *DrawList) Frame {
        self.sortByLayer();
        screen_draw_list.sortByLayer();

        return Frame.withCameraAndScreen(
            clear_color,
            camera,
            self.items(),
            screen_draw_list.items(),
        );
    }
};

/// Helper for selecting sprites from a larger texture using pixel coordinates.
pub const TextureAtlas = struct {
    texture: TextureId,
    width: u32,
    height: u32,

    pub fn init(texture: TextureId, width: u32, height: u32) TextureAtlas {
        std.debug.assert(width > 0);
        std.debug.assert(height > 0);

        return .{
            .texture = texture,
            .width = width,
            .height = height,
        };
    }

    pub fn uvPixels(self: TextureAtlas, x: u32, y: u32, width: u32, height: u32) UvRect {
        std.debug.assert(width > 0);
        std.debug.assert(height > 0);
        std.debug.assert(x < self.width);
        std.debug.assert(y < self.height);
        std.debug.assert(width <= self.width - x);
        std.debug.assert(height <= self.height - y);

        const atlas_width = @as(f32, @floatFromInt(self.width));
        const atlas_height = @as(f32, @floatFromInt(self.height));

        const left = @as(f32, @floatFromInt(x)) / atlas_width;
        const top = @as(f32, @floatFromInt(y)) / atlas_height;
        const right = @as(f32, @floatFromInt(x + width)) / atlas_width;
        const bottom = @as(f32, @floatFromInt(y + height)) / atlas_height;

        return UvRect.init(
            Vector2.xy(left, top),
            Vector2.xy(right, bottom),
        );
    }

    pub fn spritePixels(self: TextureAtlas, x: u32, y: u32, width: u32, height: u32) Sprite {
        return Sprite.region(self.texture, self.uvPixels(x, y, width, height));
    }

    pub fn spriteGrid(self: TextureAtlas, column: u32, row: u32, cell_width: u32, cell_height: u32) Sprite {
        return self.spritePixels(
            column * cell_width,
            row * cell_height,
            cell_width,
            cell_height,
        );
    }
};

pub const SpriteAnimation = struct {
    atlas: TextureAtlas,
    start_column: u32,
    row: u32,
    frame_count: u32,
    frame_width: u32,
    frame_height: u32,
    seconds_per_frame: f32,

    pub fn init(
        atlas: TextureAtlas,
        start_column: u32,
        row: u32,
        frame_count: u32,
        frame_width: u32,
        frame_height: u32,
        seconds_per_frame: f32,
    ) SpriteAnimation {
        std.debug.assert(frame_count > 0);
        std.debug.assert(seconds_per_frame > 0.0);

        return .{
            .atlas = atlas,
            .start_column = start_column,
            .row = row,
            .frame_count = frame_count,
            .frame_width = frame_width,
            .frame_height = frame_height,
            .seconds_per_frame = seconds_per_frame,
        };
    }

    pub fn spriteAtTime(self: SpriteAnimation, elapsed_seconds: f32) Sprite {
        const frame_float = elapsed_seconds / self.seconds_per_frame;
        const frame_index: u32 = @intFromFloat(@floor(frame_float));
        const column = self.start_column + frame_index % self.frame_count;

        return self.atlas.spriteGrid(column, self.row, self.frame_width, self.frame_height);
    }
};

pub const AnimationPlayer = struct {
    animation: SpriteAnimation,
    elapsed_seconds: f32 = 0.0,
    speed: f32 = 1.0,
    playing: bool = true,

    pub fn init(animation: SpriteAnimation) AnimationPlayer {
        return .{
            .animation = animation,
        };
    }

    pub fn update(self: *AnimationPlayer, dt_seconds: f32) void {
        if (!self.playing) return;

        self.elapsed_seconds += dt_seconds * self.speed;
    }

    pub fn sprite(self: AnimationPlayer) Sprite {
        return self.animation.spriteAtTime(self.elapsed_seconds);
    }

    pub fn reset(self: *AnimationPlayer) void {
        self.elapsed_seconds = 0.0;
    }
};
