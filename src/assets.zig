const std = @import("std");
const wgpu = @import("backend/wgpu.zig");
const c = @import("backend/sdl_c.zig").c;
const render2d = @import("render2d/renderer.zig");

pub const Error = error{
    LoadBmpFailed,
    ConvertSurfaceFailed,
    InvalidSurfacePixels,
    UnsupportedSurfacePitch,
};

pub const LoadedTexture = struct {
    texture: render2d.TextureId,
    width: u32,
    height: u32,

    pub fn atlas(self: LoadedTexture) render2d.TextureAtlas {
        return render2d.TextureAtlas.init(self.texture, self.width, self.height);
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
