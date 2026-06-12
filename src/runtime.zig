const assets = @import("assets.zig");
const demo = @import("demo.zig");
const input = @import("input.zig");
const render2d = @import("render2d/renderer.zig");
const wgpu = @import("backend/wgpu.zig");

pub const AppConfig = struct {
    player_texture_path: [:0]const u8 = "assets/player.bmp",
    clear_color: render2d.ColorRgba = .{
        .r = 0.05,
        .g = 0.06,
        .b = 0.08,
        .a = 1.0,
    },
};

const DemoAssets = struct {
    player_animation: render2d.SpriteAnimation,
    debug_atlas: render2d.TextureAtlas,
};

pub const App = struct {
    config: AppConfig,

    texture_catalog: assets.TextureCatalog,

    input_state: input.State,
    input_map: input.InputMap,

    demo_state: demo.Demo,

    world_draw_list: render2d.DrawList,
    screen_draw_list: render2d.DrawList,

    quit_requested: bool = false,

    pub fn init(gpu: *wgpu.Gpu, config: AppConfig) !App {
        var texture_catalog = assets.TextureCatalog.init();
        const demo_assets = try loadDemoAssets(
            gpu,
            &texture_catalog,
            config.player_texture_path,
        );

        return .{
            .config = config,
            .texture_catalog = texture_catalog,
            .input_state = input.State.init(),
            .input_map = demo.Controls.defaultInputMap(),
            .demo_state = demo.Demo.init(
                demo_assets.player_animation,
                demo_assets.debug_atlas,
            ),
            .world_draw_list = render2d.DrawList.init(),
            .screen_draw_list = render2d.DrawList.init(),
        };
    }

    pub fn beginFrame(self: *App) void {
        self.input_state.beginFrame();
        self.world_draw_list.beginFrame();
        self.screen_draw_list.beginFrame();
    }

    pub fn requestQuit(self: *App) void {
        self.quit_requested = true;
    }

    pub fn shouldQuit(self: *const App) bool {
        return self.quit_requested;
    }

    pub fn releaseInput(self: *App) void {
        self.input_state.releaseAll();
    }

    pub fn applyKey(
        self: *App,
        key: input.Key,
        down: bool,
        repeated: bool,
    ) void {
        self.input_map.applyKey(
            &self.input_state,
            key,
            down,
            repeated,
        );
    }

    pub fn update(self: *App, dt_seconds: f32) void {
        if (self.input_state.actionWasPressed(demo.Controls.quit)) {
            self.requestQuit();
        }

        if (self.quit_requested) return;

        const frame_input = demo.Input.fromState(&self.input_state);
        self.demo_state.update(frame_input, dt_seconds);
    }

    pub fn render(self: *App, gpu: *wgpu.Gpu) !void {
        const camera = self.demo_state.camera();
        const visible_world = camera.visibleWorldRect(gpu.width, gpu.height);

        try self.demo_state.draw(
            &self.world_draw_list,
            &self.screen_draw_list,
            visible_world,
        );

        const frame = self.world_draw_list.sortedFrameWithScreen(
            self.config.clear_color,
            camera,
            &self.screen_draw_list,
        );

        try gpu.render(frame);
    }
};

fn loadDemoAssets(
    gpu: *wgpu.Gpu,
    texture_catalog: *assets.TextureCatalog,
    player_texture_path: [:0]const u8,
) !DemoAssets {
    const player_texture = try texture_catalog.loadBmp(
        gpu,
        "player",
        player_texture_path,
    );

    const player_animation = texture_catalog.animationGrid(
        player_texture,
        0,
        0,
        2,
        1,
        1,
        0.2,
    );

    const debug_pixels = demoDebugPixels();

    const debug_texture = try texture_catalog.createRgbaTexture(
        gpu,
        "debug texture",
        2,
        2,
        debug_pixels[0..],
    );

    return .{
        .player_animation = player_animation,
        .debug_atlas = texture_catalog.atlas(debug_texture),
    };
}

fn demoDebugPixels() [16]u8 {
    return .{
        255, 0,   255, 255,
        0,   255, 255, 255,
        0,   255, 255, 255,
        255, 0,   255, 255,
    };
}
