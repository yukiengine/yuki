const assets = @import("assets.zig");
const demo = @import("demo.zig");
const input = @import("input.zig");
const render2d = @import("render2d/renderer.zig");
const wgpu = @import("backend/wgpu.zig");
const camera2d = @import("camera2d.zig");

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

    /// Advances app state by one frame.
    pub fn update(self: *App, dt_seconds: f32, surface_width: u32, surface_height: u32) void {
        if (self.input_state.actionWasPressed(demo.Controls.quit)) {
            self.requestQuit();
        }

        if (self.quit_requested) return;

        const frame_input = demo.Input.fromState(&self.input_state);
        self.demo_state.update(
            frame_input,
            dt_seconds,
            surface_width,
            surface_height,
        );
    }

    pub fn render(self: *App, gpu: *wgpu.Gpu) !void {
        const camera = self.demo_state.cameraForSurface(gpu.width, gpu.height);
        const viewport = camera2d.Viewport2D.init(camera, gpu.width, gpu.height);
        const visible_world = viewport.visibleWorldRect();

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

    /// Applies mouse motion from the platform layer.
    pub fn applyMouseMotion(self: *App, x: f32, y: f32) void {
        self.input_state.setMousePosition(input.Vector2.xy(x, y));
    }

    /// Applies one mouse button event from the platform layer.
    pub fn applyMouseButton(
        self: *App,
        button: input.MouseButton,
        down: bool,
        x: f32,
        y: f32,
    ) void {
        self.input_state.setMouseButton(
            button,
            down,
            input.Vector2.xy(x, y),
        );
    }

    /// Applies mouse wheel movement from the platform layer.
    pub fn applyMouseWheel(self: *App, x: f32, y: f32, mouse_x: f32, mouse_y: f32) void {
        self.input_state.addMouseWheel(
            input.Vector2.xy(x, y),
            input.Vector2.xy(mouse_x, mouse_y),
        );
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
