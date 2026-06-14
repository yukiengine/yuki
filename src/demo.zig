const std = @import("std");
const yuki2d = @import("yuki2d.zig");

const render2d = yuki2d.render;
const input = yuki2d.input;
const tilemap = yuki2d.tilemap;
const debug_draw = yuki2d.debug_draw;
const scene2d = yuki2d.scene;
const camera2d = yuki2d.camera;
const input_frame = yuki2d.input_frame;

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
    /// Main demo gameplay action map.
    pub const gameplay_map = input.ActionMapId.fromIndex(0);

    /// Player movement and camera actions.
    pub const move_left = input.DigitalActionId.fromIndex(0);
    pub const move_right = input.DigitalActionId.fromIndex(1);
    pub const move_up = input.DigitalActionId.fromIndex(2);
    pub const move_down = input.DigitalActionId.fromIndex(3);
    pub const zoom_in = input.DigitalActionId.fromIndex(4);
    pub const zoom_out = input.DigitalActionId.fromIndex(5);
    pub const pause_animation = input.DigitalActionId.fromIndex(6);
    pub const reset_animation = input.DigitalActionId.fromIndex(7);
    pub const quit = input.DigitalActionId.fromIndex(8);
    pub const toggle_debug = input.DigitalActionId.fromIndex(9);
    pub const select = input.DigitalActionId.fromIndex(10);

    /// Gameplay action map name.
    pub const gameplay_map_name = "gameplay";

    /// Named gameplay actions.
    pub const move_left_name = "player.move_left";
    pub const move_right_name = "player.move_right";
    pub const move_up_name = "player.move_up";
    pub const move_down_name = "player.move_down";
    pub const zoom_in_name = "camera.zoom_in";
    pub const zoom_out_name = "camera.zoom_out";
    pub const pause_animation_name = "player.pause_animation";
    pub const reset_animation_name = "player.reset_animation";
    pub const quit_name = "app.quit";
    pub const toggle_debug_name = "debug.toggle";
    pub const select_name = "pointer.select";

    /// Builds the named action registry for the demo controls.
    pub fn defaultActionRegistry() input.ActionRegistry {
        var registry = input.ActionRegistry.init();

        const gameplay = registry.addMap(gameplay_map_name) catch unreachable;
        std.debug.assert(gameplay.eql(gameplay_map));

        const registered_move_left = registry.addDigital(gameplay, move_left_name) catch unreachable;
        std.debug.assert(registered_move_left.index == move_left.index);

        const registered_move_right = registry.addDigital(gameplay, move_right_name) catch unreachable;
        std.debug.assert(registered_move_right.index == move_right.index);

        const registered_move_up = registry.addDigital(gameplay, move_up_name) catch unreachable;
        std.debug.assert(registered_move_up.index == move_up.index);

        const registered_move_down = registry.addDigital(gameplay, move_down_name) catch unreachable;
        std.debug.assert(registered_move_down.index == move_down.index);

        const registered_zoom_in = registry.addDigital(gameplay, zoom_in_name) catch unreachable;
        std.debug.assert(registered_zoom_in.index == zoom_in.index);

        const registered_zoom_out = registry.addDigital(gameplay, zoom_out_name) catch unreachable;
        std.debug.assert(registered_zoom_out.index == zoom_out.index);

        const registered_pause_animation = registry.addDigital(gameplay, pause_animation_name) catch unreachable;
        std.debug.assert(registered_pause_animation.index == pause_animation.index);

        const registered_reset_animation = registry.addDigital(gameplay, reset_animation_name) catch unreachable;
        std.debug.assert(registered_reset_animation.index == reset_animation.index);

        const registered_quit = registry.addDigital(gameplay, quit_name) catch unreachable;
        std.debug.assert(registered_quit.index == quit.index);

        const registered_toggle_debug = registry.addDigital(gameplay, toggle_debug_name) catch unreachable;
        std.debug.assert(registered_toggle_debug.index == toggle_debug.index);

        const registered_select = registry.addDigital(gameplay, select_name) catch unreachable;
        std.debug.assert(registered_select.index == select.index);

        return registry;
    }

    /// Builds the demo gameplay action map using an existing action registry.
    pub fn defaultActionMapFromRegistry(registry: *const input.ActionRegistry) input.ActionMap {
        var builder = input.ActionMapBuilder.fromMapName(
            registry,
            gameplay_map_name,
        ) catch unreachable;

        builder.bindDigitalKey(registry, quit_name, .escape) catch unreachable;
        builder.bindDigitalKey(registry, pause_animation_name, .space) catch unreachable;
        builder.bindDigitalKey(registry, reset_animation_name, .r) catch unreachable;

        builder.bindDigitalKey(registry, move_left_name, .a) catch unreachable;
        builder.bindDigitalKey(registry, move_left_name, .left) catch unreachable;

        builder.bindDigitalKey(registry, move_right_name, .d) catch unreachable;
        builder.bindDigitalKey(registry, move_right_name, .right) catch unreachable;

        builder.bindDigitalKey(registry, move_up_name, .w) catch unreachable;
        builder.bindDigitalKey(registry, move_up_name, .up) catch unreachable;

        builder.bindDigitalKey(registry, move_down_name, .s) catch unreachable;
        builder.bindDigitalKey(registry, move_down_name, .down) catch unreachable;

        builder.bindDigitalKey(registry, zoom_out_name, .q) catch unreachable;
        builder.bindDigitalKey(registry, zoom_in_name, .e) catch unreachable;

        builder.bindDigitalKey(registry, toggle_debug_name, .f1) catch unreachable;
        builder.bindMouseButton(registry, select_name, .left) catch unreachable;

        return builder.build();
    }

    /// Builds the demo gameplay action map from named control definitions.
    pub fn defaultActionMap() input.ActionMap {
        const registry = defaultActionRegistry();
        return defaultActionMapFromRegistry(&registry);
    }

    /// Builds the demo input router with the gameplay map active.
    pub fn defaultInputRouter() input.InputRouter {
        const registry = defaultActionRegistry();

        var router = input.InputRouter.init();
        router.putMap(gameplay_map, defaultActionMapFromRegistry(&registry)) catch unreachable;
        router.pushMap(gameplay_map) catch unreachable;

        return router;
    }

    /// Builds the demo input session with registry, router, state, and events.
    pub fn defaultInputSession() input.InputSession {
        const registry = defaultActionRegistry();

        var router = input.InputRouter.init();
        router.putMap(gameplay_map, defaultActionMapFromRegistry(&registry)) catch unreachable;
        router.pushMap(gameplay_map) catch unreachable;

        return input.InputSession.init(registry, router);
    }
};

pub const Input = struct {
    move_x: f32 = 0.0,
    move_y: f32 = 0.0,
    zoom_in: bool = false,
    zoom_out: bool = false,
    pause_animation_pressed: bool = false,
    reset_animation_pressed: bool = false,
    toggle_debug_pressed: bool = false,
    mouse_screen: render2d.Vector2 = render2d.Vector2.xy(0.0, 0.0),
    mouse_delta_screen: render2d.Vector2 = render2d.Vector2.xy(0.0, 0.0),
    mouse_wheel: render2d.Vector2 = render2d.Vector2.xy(0.0, 0.0),
    select_down: bool = false,
    select_pressed: bool = false,
    select_released: bool = false,
    mouse_inside_surface: bool = false,

    /// Builds the frame input snapshot from the read-only input frame.
    pub fn fromFrame(frame: input_frame.Frame) Input {
        const move = frame.digitalAxis2(
            Controls.move_left,
            Controls.move_right,
            Controls.move_up,
            Controls.move_down,
        );

        return .{
            .move_x = move.x,
            .move_y = move.y,
            .zoom_in = frame.digitalDown(Controls.zoom_in),
            .zoom_out = frame.digitalDown(Controls.zoom_out),
            .pause_animation_pressed = frame.digitalPressed(Controls.pause_animation),
            .reset_animation_pressed = frame.digitalPressed(Controls.reset_animation),
            .toggle_debug_pressed = frame.digitalPressed(Controls.toggle_debug),
            .mouse_screen = frame.mousePosition(),
            .mouse_delta_screen = frame.mouseDelta(),
            .mouse_wheel = frame.mouseWheel(),
            .select_down = frame.digitalDown(Controls.select),
            .select_pressed = frame.digitalPressed(Controls.select),
            .select_released = frame.digitalReleased(Controls.select),
            .mouse_inside_surface = frame.mouseInsideSurface(),
        };
    }

    /// Compatibility helper for tests and older state-based call sites.
    pub fn fromState(state: *const input.State) Input {
        return fromFrame(input_frame.Frame.init(
            state,
            &[_]input.InputEvent{},
        ));
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
    cursor_select_down: bool = false,
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
            input_state.move_x * player_speed * dt_seconds,
            input_state.move_y * player_speed * dt_seconds,
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
        self.cursor_select_down = input_state.select_down;
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

                if (input_state.select_pressed) {
                    self.selected_actor = hit.actor();
                }
            } else if (input_state.select_pressed) {
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
            const cursor_size: f32 = if (self.cursor_select_down) 18.0 else 10.0;

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
