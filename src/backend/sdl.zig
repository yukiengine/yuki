const std = @import("std");
const wgpu = @import("wgpu.zig");
const c = @import("sdl_c.zig").c;
const input = @import("../input.zig");
const runtime = @import("../runtime.zig");
const time = @import("../time.zig");

pub const Error = error{
    InitFailed,
    CreateWindowFailed,
    CreateRendererFailed,
    RenderFailed,
    GetWindowSizeFailed,
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

    var app = try runtime.App.init(&gpu, .{});

    var clock = time.FrameClock.init();
    const limiter = time.FrameLimiter.fps(60);
    var fps_counter = time.FpsCounter.init(time.Duration.fromSeconds(1.0));

    var running = true;
    while (running) {
        app.beginFrame();

        // Event polling
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event)) {
            switch (event.type) {
                c.SDL_EVENT_QUIT => app.requestQuit(),

                c.SDL_EVENT_WINDOW_FOCUS_LOST => {
                    app.releaseInput();
                },

                c.SDL_EVENT_KEY_DOWN, c.SDL_EVENT_KEY_UP => {
                    const pressed = event.type == c.SDL_EVENT_KEY_DOWN;
                    const repeated = event.key.repeat;

                    if (keyFromSdlKey(event.key.key)) |key| {
                        app.applyKey(key, pressed, repeated);
                    }
                },
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

        if (app.shouldQuit()) {
            running = false;
            continue;
        }

        const frame = clock.tick();
        const dt_seconds = frame.delta.seconds32();

        if (fps_counter.update(frame.delta)) {
            std.log.info(
                "fps: {d:.1}, frame: {d:.3}ms",
                .{ fps_counter.fps(), fps_counter.averageFrameTime().milliseconds() },
            );
        }

        app.update(dt_seconds);

        if (app.shouldQuit()) {
            running = false;
            continue;
        }

        try app.render(&gpu);

        limiter.wait(frame.started_at_ns);
    }
}

fn keyFromSdlKey(key: c.SDL_Keycode) ?input.Key {
    return switch (key) {
        c.SDLK_ESCAPE => .escape,
        c.SDLK_SPACE => .space,
        c.SDLK_R => .r,

        c.SDLK_A => .a,
        c.SDLK_D => .d,
        c.SDLK_W => .w,
        c.SDLK_S => .s,

        c.SDLK_Q => .q,
        c.SDLK_E => .e,

        c.SDLK_LEFT => .left,
        c.SDLK_RIGHT => .right,
        c.SDLK_UP => .up,
        c.SDLK_DOWN => .down,

        else => null,
    };
}
