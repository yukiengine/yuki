const std = @import("std");
const yuki2d = @import("yuki2d.zig");

const render2d = yuki2d.render;
const input = yuki2d.input;
const tilemap = yuki2d.tilemap;
const debug_draw = yuki2d.debug_draw;
const scene2d = yuki2d.scene;
const camera2d = yuki2d.camera;

const layer_background: i32 = -20;
const layer_tilemap: i32 = -10;
const layer_world: i32 = 0;
const layer_player: i32 = 10;
const layer_overlay: i32 = 100;
const layer_debug: i32 = 1000;

const demo_map_width: u32 = 10;
const demo_map_height: u32 = 8;
const demo_tile_size = render2d.Vector2.xy(48.0, 48.0);
const demo_map_origin = render2d.Vector2.xy(-240.0, -192.0);

const player_size = render2d.Vector2.xy(80.0, 80.0);
const player_speed: f32 = 240.0;

const tag_player = scene2d.ActorTag.fromIndex(1);
const tag_marker = scene2d.ActorTag.fromIndex(2);

const DemoTilemap = tilemap.StaticTilemap(demo_map_width, demo_map_height);

const tile_empty = tilemap.Tile.empty();
const tile_a = tilemap.Tile.fromAtlasIndex(0);
const tile_b = tilemap.Tile.fromAtlasIndex(1);
const tile_c = tilemap.Tile.fromAtlasIndex(2);
const tile_d = tilemap.Tile.fromAtlasIndex(3);

const debug_map_bounds_color = render2d.ColorRgba.rgba(1.0, 1.0, 1.0, 0.75);
const debug_solid_fill_color = render2d.ColorRgba.rgba(1.0, 0.1, 0.1, 0.20);
const debug_solid_outline_color = render2d.ColorRgba.rgba(1.0, 0.1, 0.1, 0.90);
const debug_player_color = render2d.ColorRgba.rgba(0.1, 1.0, 0.3, 0.95);
const debug_marker_color = render2d.ColorRgba.rgba(0.2, 0.7, 1.0, 0.95);
const debug_cursor_color = render2d.ColorRgba.rgba(1.0, 1.0, 0.2, 0.95);
const debug_hover_color = render2d.ColorRgba.rgba(1.0, 1.0, 0.2, 0.95);
const debug_selected_color = render2d.ColorRgba.rgba(0.2, 1.0, 0.9, 0.95);

const marker_push_speed: f32 = 96.0;

fn buildDemoMap() DemoTilemap {
    var map = DemoTilemap.filled(tile_empty);

    map.setBorder(tile_a);

    map.fillRect(1, 1, 3, 3, tile_b);
    map.fillRect(6, 1, 3, 3, tile_c);
    map.fillRect(3, 3, 4, 2, tile_b);
    map.fillRect(1, 5, 3, 2, tile_c);
    map.fillRect(6, 5, 3, 2, tile_b);

    map.clearRect(4, 1, 2, 2);
    map.clearRect(1, 4, 2, 1);
    map.clearRect(7, 4, 2, 1);
    map.clearRect(4, 5, 2, 2);

    map.set(2, 2, tile_d);
    map.set(7, 2, tile_d);
    map.set(2, 6, tile_d);
    map.set(7, 6, tile_d);

    return map;
}

pub const Controls = struct {
    pub const move_left = input.ActionId.fromIndex(0);
    pub const move_right = input.ActionId.fromIndex(1);
    pub const move_up = input.ActionId.fromIndex(2);
    pub const move_down = input.ActionId.fromIndex(3);
    pub const zoom_in = input.ActionId.fromIndex(4);
    pub const zoom_out = input.ActionId.fromIndex(5);
    pub const pause_animation = input.ActionId.fromIndex(6);
    pub const reset_animation = input.ActionId.fromIndex(7);
    pub const quit = input.ActionId.fromIndex(8);
    pub const toggle_debug = input.ActionId.fromIndex(9);

    pub fn defaultInputMap() input.InputMap {
        var map = input.InputMap.init();

        map.bind(.escape, quit) catch unreachable;
        map.bind(.space, pause_animation) catch unreachable;
        map.bind(.r, reset_animation) catch unreachable;

        map.bind(.a, move_left) catch unreachable;
        map.bind(.left, move_left) catch unreachable;

        map.bind(.d, move_right) catch unreachable;
        map.bind(.right, move_right) catch unreachable;

        map.bind(.w, move_up) catch unreachable;
        map.bind(.up, move_up) catch unreachable;

        map.bind(.s, move_down) catch unreachable;
        map.bind(.down, move_down) catch unreachable;

        map.bind(.q, zoom_out) catch unreachable;
        map.bind(.e, zoom_in) catch unreachable;

        map.bind(.f1, toggle_debug) catch unreachable;

        return map;
    }
};

pub const Input = struct {
    move_x: i32 = 0,
    move_y: i32 = 0,
    zoom_in: bool = false,
    zoom_out: bool = false,
    pause_animation_pressed: bool = false,
    reset_animation_pressed: bool = false,
    toggle_debug_pressed: bool = false,
    mouse_screen: render2d.Vector2 = render2d.Vector2.xy(0.0, 0.0),
    mouse_delta_screen: render2d.Vector2 = render2d.Vector2.xy(0.0, 0.0),
    mouse_wheel: render2d.Vector2 = render2d.Vector2.xy(0.0, 0.0),
    mouse_left_down: bool = false,
    mouse_left_pressed: bool = false,
    mouse_left_released: bool = false,
    mouse_inside_surface: bool = false,

    pub fn fromState(state: *const input.State) Input {
        return .{
            .move_x = state.axis(Controls.move_left, Controls.move_right),
            .move_y = state.axis(Controls.move_up, Controls.move_down),
            .zoom_in = state.isActionDown(Controls.zoom_in),
            .zoom_out = state.isActionDown(Controls.zoom_out),
            .pause_animation_pressed = state.actionWasPressed(Controls.pause_animation),
            .reset_animation_pressed = state.actionWasPressed(Controls.reset_animation),
            .toggle_debug_pressed = state.actionWasPressed(Controls.toggle_debug),
            .mouse_screen = state.mousePosition(),
            .mouse_delta_screen = state.mouseDelta(),
            .mouse_wheel = state.mouseWheel(),
            .mouse_left_down = state.isMouseButtonDown(.left),
            .mouse_left_pressed = state.wasMouseButtonPressed(.left),
            .mouse_left_released = state.wasMouseButtonReleased(.left),
            .mouse_inside_surface = state.isMouseInsideWindow(),
        };
    }
};

pub const Demo = struct {
    scene: scene2d.Scene,
    player: scene2d.ActorId,
    camera_rig: camera2d.CameraRig2D,
    tile_storage: DemoTilemap,
    tile_rules: tilemap.TileRules,
    tileset: tilemap.Tileset,
    show_collision_debug: bool = false,
    cursor_world: render2d.Vector2 = render2d.Vector2.xy(0.0, 0.0),
    cursor_on_screen: bool = false,
    cursor_left_down: bool = false,
    hovered_actor: ?scene2d.ActorId = null,
    selected_actor: ?scene2d.ActorId = null,

    /// Creates the demo scene, prefab catalog, and initial actors.
    pub fn init(player_animation: render2d.SpriteAnimation, debug_atlas: render2d.TextureAtlas) Demo {
        var scene = scene2d.Scene.init();

        const player_prefab = scene.registerPrefab(.{
            .name = "demo.player",
            .size = player_size,
            .animation = player_animation,
            .layer = layer_player,
            .tag = tag_player,
        }) catch unreachable;

        const marker_prefab = scene.registerPrefab(.{
            .name = "demo.marker",
            .size = player_size,
            .sprite = debug_atlas.spritePixels(0, 0, 1, 1),
            .layer = layer_world,
            .tag = tag_marker,
        }) catch unreachable;

        const player = scene.spawn(player_prefab, .{
            .position = render2d.Vector2.xy(0.0, 0.0),
        }) catch unreachable;

        _ = scene.spawn(marker_prefab, .{
            .position = render2d.Vector2.xy(-96.0, 0.0),
        }) catch unreachable;

        const tile_storage = buildDemoMap();
        const map_bounds = tile_storage
            .view(demo_tile_size)
            .worldBounds(demo_map_origin);

        const camera_rig = camera2d.CameraRig2D
            .init(render2d.Vector2.xy(0.0, 0.0))
            .withConfig(camera2d.CameraRigConfig.default()
            .withSmoothing(10.0)
            .withSnapDistance(0.001)
            .withZoomRange(camera2d.ZoomRange.init(0.25, 4.0))
            .withBounds(map_bounds));

        return .{
            .scene = scene,
            .player = player,
            .tile_storage = tile_storage,
            .camera_rig = camera_rig,
            .tile_rules = buildTileRules(),
            .tileset = tilemap.Tileset.init(debug_atlas, 1, 1),
        };
    }

    /// Advances demo simulation for one frame.
    pub fn update(
        self: *Demo,
        input_state: Input,
        dt_seconds: f32,
        surface_width: u32,
        surface_height: u32,
    ) void {
        self.scene.beginFrame();

        if (input_state.toggle_debug_pressed) {
            self.show_collision_debug = !self.show_collision_debug;
        }

        const movement = render2d.Vector2.xy(
            @as(f32, @floatFromInt(input_state.move_x)) * player_speed * dt_seconds,
            @as(f32, @floatFromInt(input_state.move_y)) * player_speed * dt_seconds,
        );

        const map = self.tile_storage.view(demo_tile_size);

        _ = self.scene.moveActorWithTilemap(
            self.player,
            map,
            self.tile_rules,
            demo_map_origin,
            movement,
        );

        if (input_state.pause_animation_pressed) {
            self.scene.toggleActorAnimation(self.player);
        }

        if (input_state.reset_animation_pressed) {
            self.scene.resetActorAnimation(self.player);
        }

        self.scene.rotateActor(self.player, 2.0 * dt_seconds);

        self.scene.updateAnimations(dt_seconds);

        _ = self.scene.emitActorOverlapTransitions(self.player, tag_marker) catch unreachable;
        self.handleSceneEvents(dt_seconds);
        self.scene.finishFrame();

        if (self.scene.actorSnapshot(self.player)) |player| {
            self.camera_rig.follow(player.position);
        }

        const keyboard_zoom_speed: f32 = 1.5;
        if (input_state.zoom_in) {
            self.camera_rig.zoomTargetBy(keyboard_zoom_speed * dt_seconds);
        }
        if (input_state.zoom_out) {
            self.camera_rig.zoomTargetBy(-keyboard_zoom_speed * dt_seconds);
        }

        if (input_state.mouse_wheel.y != 0.0) {
            const wheel_zoom_step: f32 = 0.25;
            self.camera_rig.zoomAroundScreenPoint(
                input_state.mouse_screen,
                surface_width,
                surface_height,
                self.camera_rig.target_zoom + input_state.mouse_wheel.y *
                    wheel_zoom_step,
            );
        }

        self.camera_rig.update(dt_seconds);

        self.cursor_on_screen = input_state.mouse_inside_surface;
        self.cursor_left_down = input_state.mouse_left_down;
        self.cursor_world = self.camera_rig.screenToWorld(
            input_state.mouse_screen,
            surface_width,
            surface_height,
        );

        self.hovered_actor = null;

        if (self.cursor_on_screen) {
            if (self.scene.topActorAtPoint(
                self.cursor_world,
                scene2d.ActorPickFilter.all(),
            )) |hit| {
                self.hovered_actor = hit.actor();

                if (input_state.mouse_left_pressed) {
                    self.selected_actor = hit.actor();
                }
            } else if (input_state.mouse_left_pressed) {
                self.selected_actor = null;
            }
        }
    }

    /// Returns the current unclamped camera.
    pub fn camera(self: Demo) render2d.Camera2D {
        return self.camera_rig.camera();
    }

    /// Returns the current camera clamped for the render surface.
    pub fn cameraForSurface(
        self: Demo,
        surface_width: u32,
        surface_height: u32,
    ) render2d.Camera2D {
        return self.camera_rig.cameraForSurface(surface_width, surface_height);
    }

    pub fn draw(
        self: *const Demo,
        world: *render2d.DrawList,
        screen: *render2d.DrawList,
        visible_world: render2d.Rect2D,
    ) !void {
        const map = self.tile_storage.view(demo_tile_size);

        try map.drawVisible(
            world,
            self.tileset,
            demo_map_origin,
            visible_world,
            layer_tilemap,
        );

        try world.drawRectLayer(
            render2d.Vector2.xy(0.0, 0.0),
            render2d.Vector2.xy(360.0, 220.0),
            render2d.ColorRgba.rgb(0.15, 0.18, 0.24),
            layer_background,
        );

        try screen.drawRectLayer(
            render2d.Vector2.xy(80.0, 0.0),
            render2d.Vector2.xy(360.0, 140.0),
            render2d.ColorRgba.rgba(1.0, 0.1, 0.1, 0.35),
            layer_overlay,
        );

        try self.scene.drawVisible(world, visible_world);

        if (self.show_collision_debug) {
            try self.drawCollisionDebug(world, map, visible_world);
        }
    }

    /// Draws debug overlays for collision tiles, player bounds, and map bounds.
    fn drawCollisionDebug(
        self: *const Demo,
        world: *render2d.DrawList,
        map: tilemap.Tilemap,
        visible_world: render2d.Rect2D,
    ) !void {
        const player_id = self.scene.findFirstByTag(tag_player) orelse return;
        const player = self.scene.actorSnapshot(player_id) orelse return;

        const debug = debug_draw.DebugDraw
            .init(world, layer_debug)
            .withThickness(2.0);

        try debug.rectOutline(
            map.worldBounds(demo_map_origin),
            debug_map_bounds_color,
        );

        const range = map.visibleRange(demo_map_origin, visible_world);
        if (!range.isEmpty()) {
            var y = range.min_y;
            while (y < range.max_y) : (y += 1) {
                var x = range.min_x;
                while (x < range.max_x) : (x += 1) {
                    const tile = map.tileAt(x, y);
                    if (!self.tile_rules.isSolid(tile)) continue;

                    const bounds = map.tileBounds(demo_map_origin, x, y);

                    try debug.fillRect(bounds, debug_solid_fill_color);
                    try debug.rectOutline(bounds, debug_solid_outline_color);
                }
            }
        }

        var marker_snapshots = scene2d.ActorSnapshotList.init();

        try self.scene.collectActorSnapshots(
            scene2d.ActorSnapshotFilter
                .all()
                .withTag(tag_marker)
                .inRect(visible_world),
            &marker_snapshots,
        );

        for (marker_snapshots.items()) |marker| {
            try debug.rectOutline(
                marker.bounds,
                debug_marker_color,
            );
        }

        const reader = self.scene.eventReader();
        const filter = scene2d.ActorOverlapFilter
            .active()
            .withOtherTag(tag_marker);

        for (reader.items()) |event| {
            if (!filter.matches(event)) continue;

            const overlap = event.actorOverlapOrNull() orelse continue;
            const other = self.scene.actorSnapshot(overlap.other) orelse continue;

            try debug.cross(
                other.position,
                24.0,
                debug_marker_color,
            );
        }

        try debug.rectOutline(
            player.bounds,
            debug_player_color,
        );

        try debug.cross(
            player.position,
            16.0,
            debug_player_color,
        );

        if (self.cursor_on_screen) {
            const cursor_size: f32 = if (self.cursor_left_down) 18.0 else 10.0;

            // Cursor cross
            try debug.cross(
                self.cursor_world,
                cursor_size,
                debug_cursor_color,
            );

            if (self.hovered_actor) |actor_id| {
                if (self.scene.actorSnapshot(actor_id)) |hovered| {
                    try debug.rectOutline(
                        hovered.bounds,
                        debug_hover_color,
                    );
                }
            }

            if (self.selected_actor) |actor_id| {
                if (self.scene.actorSnapshot(actor_id)) |selected| {
                    try debug.rectOutline(
                        selected.bounds,
                        debug_selected_color,
                    );

                    try debug.cross(
                        selected.position,
                        28.0,
                        debug_selected_color,
                    );
                }
            }
        }
    }

    /// Converts scene events into deferred demo commands.
    fn handleSceneEvents(self: *Demo, dt_seconds: f32) void {
        const reader = self.scene.eventReader();
        const filter = scene2d.ActorOverlapFilter.active().withOtherTag(tag_marker);

        for (reader.items()) |event| {
            if (!filter.matches(event)) continue;

            const overlap = event.actorOverlapOrNull() orelse continue;
            const push = render2d.Vector2.xy(marker_push_speed * dt_seconds, 0.0);

            self.scene.queueMoveActor(overlap.other, push) catch unreachable;
        }
    }
};

fn buildTileRules() tilemap.TileRules {
    var rules = tilemap.TileRules.init();

    rules.setSolid(tile_a, true);
    rules.setSolid(tile_d, true);

    return rules;
}
