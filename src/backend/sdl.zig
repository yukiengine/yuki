const std = @import("std");
const wgpu = @import("wgpu.zig");
const c = @import("sdl_c.zig").c;
const render2d = @import("../render2d/renderer.zig");
const assets = @import("../assets.zig");
const demo = @import("../demo.zig");
const input = @import("../input.zig");

pub const Error = error{
    InitFailed,
    CreateWindowFailed,
    CreateRendererFailed,
    RenderFailed,
    GetWindowSizeFailed,
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

    // BMP texture
    const player_texture = try assets.loadBmpTexture(&gpu, "assets/player.bmp");
    const player_atlas = player_texture.atlas();
    const player_animation = render2d.SpriteAnimation.init(player_atlas, 0, 0, 2, 1, 1, 0.2);

    const debug_pixels = [_]u8{
        255, 0, 255, 255, // pink
        0, 255, 255, 255, // cyan
        0, 255, 255, 255, // cyan
        255, 0, 255, 255, // pink
    };

    const debug_texture = try gpu.createTextureFromRgbaPixels("debug texture", 2, 2, debug_pixels[0..]);
    const debug_atlas = render2d.TextureAtlas.init(debug_texture, 2, 2);

    var clock = FrameClock.init();
    var frame_index: u64 = 0;

    var input_state = input.State.init();
    var demo_state = demo.Demo.init(player_animation, debug_atlas);

    var world_draw_list = render2d.DrawList.init();
    var screen_draw_list = render2d.DrawList.init();

    var running = true;
    while (running) {
        input_state.beginFrame();

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
                    const repeated = event.key.repeat;

                    switch (event.key.key) {
                        c.SDLK_ESCAPE => if (!repeated) {
                            input_state.set(.quit, pressed);
                        },
                        c.SDLK_SPACE => if (!repeated) {
                            input_state.set(.pause_animation, pressed);
                        },
                        c.SDLK_R => if (!repeated) {
                            input_state.set(.reset_animation, pressed);
                        },
                        c.SDLK_A, c.SDLK_LEFT => {
                            input_state.set(.move_left, pressed);
                        },
                        c.SDLK_D, c.SDLK_RIGHT => {
                            input_state.set(.move_right, pressed);
                        },
                        c.SDLK_W, c.SDLK_UP => {
                            input_state.set(.move_up, pressed);
                        },
                        c.SDLK_S, c.SDLK_DOWN => {
                            input_state.set(.move_down, pressed);
                        },
                        c.SDLK_Q => {
                            input_state.set(.zoom_out, pressed);
                        },
                        c.SDLK_E => {
                            input_state.set(.zoom_in, pressed);
                        },
                        else => {},
                    }
                },

                else => {},
            }
        }

        if (input_state.wasPressed(.quit)) {
            running = false;
        }

        // Delta time calculations
        const dt = clock.tick();
        frame_index += 1;

        const dt_seconds: f32 = @floatCast(dt);

        // Logging every 120 FPS
        if (frame_index % 120 == 0) {
            std.log.info("frame dt: {d:.4}s", .{dt});
        }

        const frame_input = demo.Input.fromState(&input_state);
        demo_state.update(frame_input, dt_seconds);

        // Render frame
        world_draw_list.beginFrame();
        screen_draw_list.beginFrame();

        try demo_state.draw(&world_draw_list, &screen_draw_list);

        try gpu.render(world_draw_list.sortedFrameWithScreen(
            render2d.ColorRgba.rgb(0.05, 0.06, 0.08),
            demo_state.camera(),
            &screen_draw_list,
        ));

        // Delay to run ~60FPS
        // TODO: Handle frame pacing with a proper frame limiter
        c.SDL_Delay(16);
    }
}
