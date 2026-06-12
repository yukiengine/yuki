const std = @import("std");
const wgpu = @import("backend/wgpu.zig");
const c = @import("backend/sdl_c.zig").c;
const render2d = @import("render2d/renderer.zig");

pub const max_texture_assets = 32;

pub const Error = error{
    LoadBmpFailed,
    ConvertSurfaceFailed,
    InvalidSurfacePixels,
    UnsupportedSurfacePitch,
    TextureCatalogFull,
};

pub const TextureAssetId = extern struct {
    index: u32,

    pub fn fromIndex(index: u32) TextureAssetId {
        return .{ .index = index };
    }
};

pub const LoadedTexture = struct {
    texture: render2d.TextureId,
    width: u32,
    height: u32,

    pub fn atlas(self: LoadedTexture) render2d.TextureAtlas {
        return render2d.TextureAtlas.init(self.texture, self.width, self.height);
    }
};

pub const TextureAsset = struct {
    name: [:0]const u8,
    texture: render2d.TextureId,
    width: u32,
    height: u32,

    pub fn atlas(self: TextureAsset) render2d.TextureAtlas {
        return render2d.TextureAtlas.init(self.texture, self.width, self.height);
    }

    pub fn fullSprite(self: TextureAsset) render2d.Sprite {
        return render2d.Sprite.init(self.texture);
    }

    pub fn spritePixels(
        self: TextureAsset,
        x: u32,
        y: u32,
        width: u32,
        height: u32,
    ) render2d.Sprite {
        return self.atlas().spritePixels(x, y, width, height);
    }

    pub fn spriteGrid(
        self: TextureAsset,
        column: u32,
        row: u32,
        cell_width: u32,
        cell_height: u32,
    ) render2d.Sprite {
        return self.atlas().spriteGrid(column, row, cell_width, cell_height);
    }

    pub fn animationGrid(
        self: TextureAsset,
        start_column: u32,
        row: u32,
        frame_count: u32,
        frame_width: u32,
        frame_height: u32,
        seconds_per_frame: f32,
    ) render2d.SpriteAnimation {
        return render2d.SpriteAnimation.init(
            self.atlas(),
            start_column,
            row,
            frame_count,
            frame_width,
            frame_height,
            seconds_per_frame,
        );
    }
};

pub const TextureCatalog = struct {
    textures: [max_texture_assets]TextureAsset,
    texture_count: usize,

    pub fn init() TextureCatalog {
        return .{
            .textures = undefined,
            .texture_count = 0,
        };
    }

    pub fn loadBmp(
        self: *TextureCatalog,
        gpu: *wgpu.Gpu,
        name: [:0]const u8,
        path: [:0]const u8,
    ) !TextureAssetId {
        const loaded = try loadBmpTexture(gpu, path);
        return self.addLoadedTexture(name, loaded);
    }

    pub fn createRgbaTexture(
        self: *TextureCatalog,
        gpu: *wgpu.Gpu,
        name: [:0]const u8,
        width: u32,
        height: u32,
        pixels: []const u8,
    ) !TextureAssetId {
        const texture = try gpu.createTextureFromRgbaPixels(
            name,
            width,
            height,
            pixels,
        );

        return self.addTexture(.{
            .name = name,
            .texture = texture,
            .width = width,
            .height = height,
        });
    }

    pub fn get(self: *const TextureCatalog, id: TextureAssetId) TextureAsset {
        const index: usize = @intCast(id.index);
        std.debug.assert(index < self.texture_count);

        return self.textures[index];
    }

    pub fn atlas(self: *const TextureCatalog, id: TextureAssetId) render2d.TextureAtlas {
        return self.get(id).atlas();
    }

    pub fn fullSprite(self: *const TextureCatalog, id: TextureAssetId) render2d.Sprite {
        return self.get(id).fullSprite();
    }

    pub fn spritePixels(
        self: *const TextureCatalog,
        id: TextureAssetId,
        x: u32,
        y: u32,
        width: u32,
        height: u32,
    ) render2d.Sprite {
        return self.get(id).spritePixels(x, y, width, height);
    }

    pub fn animationGrid(
        self: *const TextureCatalog,
        id: TextureAssetId,
        start_column: u32,
        row: u32,
        frame_count: u32,
        frame_width: u32,
        frame_height: u32,
        seconds_per_frame: f32,
    ) render2d.SpriteAnimation {
        return self.get(id).animationGrid(
            start_column,
            row,
            frame_count,
            frame_width,
            frame_height,
            seconds_per_frame,
        );
    }

    fn addLoadedTexture(
        self: *TextureCatalog,
        name: [:0]const u8,
        loaded: LoadedTexture,
    ) !TextureAssetId {
        return self.addTexture(.{
            .name = name,
            .texture = loaded.texture,
            .width = loaded.width,
            .height = loaded.height,
        });
    }

    fn addTexture(self: *TextureCatalog, texture: TextureAsset) !TextureAssetId {
        if (self.texture_count == max_texture_assets) {
            return Error.TextureCatalogFull;
        }

        const id = TextureAssetId.fromIndex(@intCast(self.texture_count));
        self.textures[self.texture_count] = texture;
        self.texture_count += 1;

        return id;
    }
};

pub fn loadBmpTexture(gpu: *wgpu.Gpu, path: [:0]const u8) !LoadedTexture {
    const source = c.SDL_LoadBMP(path.ptr) orelse {
        std.log.err("SDL_LoadBMP failed: {s}", .{c.SDL_GetError()});
        return Error.LoadBmpFailed;
    };
    defer c.SDL_DestroySurface(source);

    const rgba = c.SDL_ConvertSurface(source, c.SDL_PIXELFORMAT_RGBA32) orelse {
        std.log.err("SDL_ConvertSurface failed: {s}", .{c.SDL_GetError()});
        return Error.ConvertSurfaceFailed;
    };
    defer c.SDL_DestroySurface(rgba);

    const width: u32 = @intCast(rgba.*.w);
    const height: u32 = @intCast(rgba.*.h);
    const pitch: usize = @intCast(rgba.*.pitch);
    const expected_pitch = @as(usize, @intCast(width)) * 4;

    if (pitch != expected_pitch) return Error.UnsupportedSurfacePitch;

    const pixels_raw = rgba.*.pixels orelse return Error.InvalidSurfacePixels;
    const pixels_ptr: [*]const u8 = @ptrCast(pixels_raw);
    const pixels = pixels_ptr[0 .. pitch * @as(usize, @intCast(height))];

    return .{
        .texture = try gpu.createTextureFromRgbaPixels(path, width, height, pixels),
        .width = width,
        .height = height,
    };
}
