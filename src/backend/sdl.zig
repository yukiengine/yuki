const std = @import("std");

const c = @cImport({
    @cDefine("SDL_MAIN_HANDLED", "1");
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_main.h");
});

pub const Error = error{ InitFailed, CreateWindowFailed, CreateRendererFailed, RenderFailed };

pub fn runHelloWindow() !void {
    c.SDL_SetMainReady();

    if (!c.SDL_Init(c.SDL_INIT_VIDEO)) {
        std.log.err("SDL_Init failed: {s}", .{c.SDL_GetError()});
        return Error.InitFailed;
    }
    defer c.SDL_Quit();

    const window = c.SDL_CreateWindow("Yuki", 960, 540, 0) orelse {
        std.log.err("SDL_CreateWindow failed: {s}", .{c.SDL_GetError()});
        return Error.CreateWindowFailed;
    };
    defer c.SDL_DestroyWindow(window);

    const renderer = c.SDL_CreateRenderer(window, null) orelse {
        std.log.err("SDL_CreateRenderer failed: {s}", .{c.SDL_GetError()});
        return Error.CreateRendererFailed;
    };
    defer c.SDL_DestroyRenderer(renderer);

    var running = true;
    while (running) {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event)) {
            switch (event.type) {
                c.SDL_EVENT_QUIT => running = false,
                else => {},
            }
        }
        if (!c.SDL_SetRenderDrawColor(renderer, 18, 22, 30, 255)) {
            return Error.RenderFailed;
        }
        if (!c.SDL_RenderClear(renderer)) {
            return Error.RenderFailed;
        }
        if (!c.SDL_RenderPresent(renderer)) {
            return Error.RenderFailed;
        }

        c.SDL_Delay(16);
    }
}
