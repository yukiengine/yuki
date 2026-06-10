const std = @import("std");
const wgpu = @import("wgpu.zig");

const c = @cImport({
    @cDefine("SDL_MAIN_HANDLED", "1");
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_main.h");
});

pub const Error = error{ InitFailed, CreateWindowFailed, CreateRendererFailed, RenderFailed, GetWindowSizeFailed };

/// Delta time
const FrameClock = struct {
    last_counter: u64,
    frequency: u64,

    pub fn init() FrameClock {
        return .{
            .last_counter = c.SDL_GetPerformanceCounter(),
            .frequency = c.SDL_GetPerformanceFrequency(),
        };
    }

    pub fn tick(self: *FrameClock) f64 {
        const now = c.SDL_GetPerformanceCounter();
        const delta = now - self.last_counter;
        self.last_counter = now;

        return @as(f64, @floatFromInt(delta)) / @as(f64, @floatFromInt(self.frequency));
    }
};

pub fn runHelloWindow() !void {
    c.SDL_SetMainReady();

    if (!c.SDL_Init(c.SDL_INIT_VIDEO)) {
        std.log.err("SDL_Init failed: {s}", .{c.SDL_GetError()});
        return Error.InitFailed;
    }
    defer c.SDL_Quit();

    const window = c.SDL_CreateWindow("Yuki", 960, 540, c.SDL_WINDOW_RESIZABLE) orelse {
        std.log.err("SDL_CreateWindow failed: {s}", .{c.SDL_GetError()});
        return Error.CreateWindowFailed;
    };
    defer c.SDL_DestroyWindow(window);

    var width: c_int = 0;
    var height: c_int = 0;
    if (!c.SDL_GetWindowSizeInPixels(window, &width, &height)) {
        std.log.err("SDL_GetWindowSizeInPixels failed: {s}", .{c.SDL_GetError()});
        return Error.GetWindowSizeFailed;
    }

    var gpu = try wgpu.Gpu.init(@ptrCast(window), @intCast(width), @intCast(height));
    defer gpu.deinit();

    var clock = FrameClock.init();
    var frame_index: u64 = 0;

    var running = true;
    while (running) {
        // Event poling
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event)) {
            switch (event.type) {
                c.SDL_EVENT_QUIT => running = false,
                c.SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED => {
                    gpu.resize(@intCast(event.window.data1), @intCast(event.window.data2));
                },
                c.SDL_EVENT_WINDOW_RESIZED => {
                    var width_new: c_int = 0;
                    var height_new: c_int = 0;
                    if (c.SDL_GetWindowSizeInPixels(window, &width_new, &height_new)) {
                        gpu.resize(@intCast(width_new), @intCast(height_new));
                    }
                },
                else => {},
            }
        }

        // Delta time calculations
        const dt = clock.tick();
        frame_index += 1;

        // Logging every 120 FPS
        if (frame_index % 120 == 0) {
            std.log.info("frame dt: {d:.4}s", .{dt});
        }

        // Render frame
        try gpu.render();

        // Delay to run ~60FPS
        // TODO: Handle frame pacing with a proper frame limiter
        c.SDL_Delay(16);
    }
}
