const std = @import("std");
const wgpu = @import("wgpu.zig");
const c = @import("sdl_c.zig").c;
const render2d = @import("../render2d/renderer.zig");

pub const Error = error{ InitFailed, CreateWindowFailed, CreateRendererFailed, RenderFailed, GetWindowSizeFailed };

const GameState = struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
};

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

/// Input handler
const Input = struct {
    left: bool = false,
    right: bool = false,
    up: bool = false,
    down: bool = false,

    fn boolToI32(value: bool) i32 {
        return if (value) 1 else 0;
    }

    pub fn axisX(self: Input) i32 {
        return boolToI32(self.right) - boolToI32(self.left);
    }

    pub fn axisY(self: Input) i32 {
        return boolToI32(self.down) - boolToI32(self.up);
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

    var input = Input{};
    var game_state = GameState{};

    var running = true;
    while (running) {
        // Event polling
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
                c.SDL_EVENT_KEY_DOWN,
                c.SDL_EVENT_KEY_UP,
                => {
                    const pressed = event.type == c.SDL_EVENT_KEY_DOWN;
                    switch (event.key.key) {
                        c.SDLK_ESCAPE => if (pressed) {
                            running = false;
                        },
                        c.SDLK_A, c.SDLK_LEFT => input.left = pressed,
                        c.SDLK_D, c.SDLK_RIGHT => input.right = pressed,
                        c.SDLK_W, c.SDLK_UP => input.up = pressed,
                        c.SDLK_S, c.SDLK_DOWN => input.down = pressed,
                        else => {},
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

        const move_x = input.axisX();
        const move_y = input.axisY();

        const speed: f32 = 240.0; // units per second
        const dt_seconds: f32 = @floatCast(dt);

        game_state.x += @as(f32, @floatFromInt(move_x)) * speed * dt_seconds;
        game_state.y += @as(f32, @floatFromInt(move_y)) * speed * dt_seconds;

        if (frame_index % 30 == 0 and (move_x != 0 or move_y != 0)) {
            std.log.info("input move: {d}, {d}", .{ move_x, move_y });
            std.log.info("position: {d}, {d}", .{ game_state.x, game_state.y });
        }

        // Render frame
        const camera = render2d.Camera2D.init(render2d.Vec2.xy(0.0, 0.0), 1.0);

        const quads = [_]render2d.Quad{
            render2d.Quad.init(
                render2d.Vec2.xy(game_state.x, game_state.y),
                render2d.Vec2.xy(96.0, 96.0),
                render2d.ColorRgba.rgb(1.0, 0.0, 0.0),
            ),
            render2d.Quad.init(
                render2d.Vec2.xy(-180.0, -120.0),
                render2d.Vec2.xy(80.0, 80.0),
                render2d.ColorRgba.rgb(0.0, 1.0, 0.0),
            ),
        };
        try gpu.render(render2d.Frame.withCamera(
            render2d.ColorRgba.rgb(0.05, 0.06, 0.08),
            camera,
            quads[0..],
        ));

        // Delay to run ~60FPS
        // TODO: Handle frame pacing with a proper frame limiter
        c.SDL_Delay(16);
    }
}
