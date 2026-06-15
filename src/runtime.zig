const demo = @import("demo.zig");
const yuki2d = @import("yuki2d.zig");
const wgpu = @import("backend/wgpu.zig");

const assets = yuki2d.assets;
const input = yuki2d.input;
const render2d = yuki2d.render;
const camera2d = yuki2d.camera;
const input_frame = yuki2d.input_frame;

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

    input_session: input.InputSession,

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
            .input_session = demo.Controls.defaultInputSession(),
            .demo_state = demo.Demo.init(
                demo_assets.player_animation,
                demo_assets.debug_atlas,
            ),
            .world_draw_list = render2d.DrawList.init(),
            .screen_draw_list = render2d.DrawList.init(),
        };
    }

    /// Clears frame-local app state before platform events for the next frame.
    pub fn beginFrame(self: *App) void {
        self.input_session.beginFrame();
        self.world_draw_list.beginFrame();
        self.screen_draw_list.beginFrame();
    }

    pub fn requestQuit(self: *App) void {
        self.quit_requested = true;
    }

    pub fn shouldQuit(self: *const App) bool {
        return self.quit_requested;
    }

    /// Releases held input state when the platform loses focus or exits.
    pub fn releaseInput(self: *App) void {
        self.input_session.releaseAll();
    }

    /// Applies one keyboard event from the platform layer.
    pub fn applyKey(
        self: *App,
        key: input.Key,
        down: bool,
        repeated: bool,
    ) void {
        self.input_session.applyKey(
            key,
            down,
            repeated,
        ) catch unreachable;
    }

    /// Advances app state by one frame.
    pub fn update(self: *App, dt_seconds: f32, surface_width: u32, surface_height: u32) void {
        const input_view = self.demoInputMapView();

        if (input_view.digitalPressed(demo.Controls.quit_name) catch unreachable) {
            self.requestQuit();
        }

        if (self.quit_requested) return;

        const frame_input = demo.Input.fromNamedMapView(input_view) catch unreachable;
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
        self.input_session.applyMouseMotion(input.Vector2.xy(x, y));
    }

    /// Applies one mouse button event from the platform layer.
    pub fn applyMouseButton(self: *App, button: input.MouseButton, down: bool, x: f32, y: f32) void {
        self.input_session.applyMouseButton(button, down, input.Vector2.xy(x, y)) catch unreachable;
    }

    /// Applies mouse wheel movement from the platform layer.
    pub fn applyMouseWheel(self: *App, x: f32, y: f32, mouse_x: f32, mouse_y: f32) void {
        self.input_session.applyMouseWheel(
            input.Vector2.xy(x, y),
            input.Vector2.xy(mouse_x, mouse_y),
        );
    }

    /// Returns frame-local input events collected by the runtime.
    pub fn inputEvents(self: *const App) []const input.InputEvent {
        return self.input_session.inputEvents();
    }

    /// Returns the read-only input frame for the current runtime frame.
    pub fn inputFrame(self: *const App) input_frame.Frame {
        return input_frame.Frame.init(
            self.input_session.inputState(),
            self.input_session.inputEvents(),
        );
    }

    /// Returns a named input frame for the demo gameplay map.
    pub fn demoInputFrame(self: *const App) input.NamedFrame {
        return self.input_session.namedFrame(demo.Controls.gameplay_map);
    }

    /// Returns the map-scoped named input API view for the demo gameplay map.
    pub fn demoInputMapView(self: *const App) input.NamedInputMapView {
        return self.input_session.namedMapViewByName(demo.Controls.gameplay_map_name) catch unreachable;
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
