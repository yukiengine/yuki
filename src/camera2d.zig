const std = @import("std");
const render2d = @import("render2d/renderer.zig");

/// Public vector type used by the 2D camera helpers.
pub const Vector2 = render2d.Vector2;

/// Public camera value consumed by the renderer.
pub const Camera2D = render2d.Camera2D;

/// Public rectangle type used for camera bounds.
pub const Rect2D = render2d.Rect2D;

/// Pixel size of a render surface or viewport.
pub const SurfaceSize = extern struct {
    width: u32,
    height: u32,

    /// Creates a checked surface size.
    pub fn init(width: u32, height: u32) SurfaceSize {
        std.debug.assert(width > 0);
        std.debug.assert(height > 0);

        return .{
            .width = width,
            .height = height,
        };
    }

    /// Returns the viewport center in screen pixels.
    pub fn center(self: SurfaceSize) Vector2 {
        return Vector2.xy(
            @as(f32, @floatFromInt(self.width)) * 0.5,
            @as(f32, @floatFromInt(self.height)) * 0.5,
        );
    }

    /// Returns the surface width as f32.
    pub fn widthF32(self: SurfaceSize) f32 {
        return @floatFromInt(self.width);
    }

    /// Returns the surface height as f32.
    pub fn heightF32(self: SurfaceSize) f32 {
        return @floatFromInt(self.height);
    }
};

/// Camera plus surface size used for coordinate conversion.
pub const Viewport2D = struct {
    camera: Camera2D,
    surface: SurfaceSize,

    /// Creates a viewport from a camera and surface dimensions.
    pub fn init(camera: Camera2D, surface_width: u32, surface_height: u32) Viewport2D {
        return .{
            .camera = camera,
            .surface = SurfaceSize.init(surface_width, surface_height),
        };
    }

    /// Returns the visible world rectangle.
    pub fn visibleWorldRect(self: Viewport2D) Rect2D {
        return self.camera.visibleWorldRect(self.surface.width, self.surface.height);
    }

    /// Converts a world-space position into screen-space pixels.
    pub fn worldToScreen(self: Viewport2D, world: Vector2) Vector2 {
        std.debug.assert(self.camera.zoom > 0.0);

        const center = self.surface.center();

        return Vector2.xy(
            (world.x - self.camera.position.x) * self.camera.zoom + center.x,
            (world.y - self.camera.position.y) * self.camera.zoom + center.y,
        );
    }

    /// Converts a screen-space pixel position into world-space.
    pub fn screenToWorld(self: Viewport2D, screen: Vector2) Vector2 {
        std.debug.assert(self.camera.zoom > 0.0);

        const center = self.surface.center();

        return Vector2.xy(
            (screen.x - center.x) / self.camera.zoom + self.camera.position.x,
            (screen.y - center.y) / self.camera.zoom + self.camera.position.y,
        );
    }

    /// Returns true when a screen-space point is inside this viewport.
    pub fn containsScreenPoint(self: Viewport2D, screen: Vector2) bool {
        return screen.x >= 0.0 and
            screen.y >= 0.0 and
            screen.x < self.surface.widthF32() and
            screen.y < self.surface.heightF32();
    }

    /// Returns true when a world-space point is currently visible.
    pub fn containsWorldPoint(self: Viewport2D, world: Vector2) bool {
        return self.visibleWorldRect().containsPoint(world);
    }

    /// Returns a camera moved so a screen point keeps pointing at the same world point after zooming.
    pub fn cameraZoomedAroundScreenPoint(
        self: Viewport2D,
        screen: Vector2,
        next_zoom: f32,
    ) Camera2D {
        std.debug.assert(next_zoom > 0.0);

        const world_before = self.screenToWorld(screen);
        const center = self.surface.center();

        const next_position = Vector2.xy(
            world_before.x - (screen.x - center.x) / next_zoom,
            world_before.y - (screen.y - center.y) / next_zoom,
        );

        return Camera2D.init(next_position, next_zoom);
    }
};

/// Allowed zoom range for a camera rig.
pub const ZoomRange = struct {
    min: f32 = 0.25,
    max: f32 = 4.0,

    /// Returns a checked zoom range.
    pub fn init(min: f32, max: f32) ZoomRange {
        std.debug.assert(min > 0.0);
        std.debug.assert(max >= min);

        return .{
            .min = min,
            .max = max,
        };
    }

    /// Clamps a zoom value into this range.
    pub fn clamp(self: ZoomRange, zoom: f32) f32 {
        std.debug.assert(self.min > 0.0);
        std.debug.assert(self.max >= self.min);

        return clampF32(zoom, self.min, self.max);
    }
};

/// Runtime behavior settings for a smooth 2D camera.
pub const CameraRigConfig = struct {
    smoothing: f32 = 12.0,
    snap_distance: f32 = 0.01,
    zoom_range: ZoomRange = .{},
    bounds: ?Rect2D = null,

    /// Returns the default camera rig config.
    pub fn default() CameraRigConfig {
        return .{};
    }

    /// Returns a copy with a different smoothing speed.
    pub fn withSmoothing(self: CameraRigConfig, smoothing: f32) CameraRigConfig {
        std.debug.assert(smoothing >= 0.0);

        var config = self;
        config.smoothing = smoothing;
        return config;
    }

    /// Returns a copy with a different snap distance.
    pub fn withSnapDistance(self: CameraRigConfig, snap_distance: f32) CameraRigConfig {
        std.debug.assert(snap_distance >= 0.0);

        var config = self;
        config.snap_distance = snap_distance;
        return config;
    }

    /// Returns a copy with a different zoom range.
    pub fn withZoomRange(self: CameraRigConfig, zoom_range: ZoomRange) CameraRigConfig {
        var config = self;
        config.zoom_range = zoom_range;
        return config;
    }

    /// Returns a copy with world-space camera bounds.
    pub fn withBounds(self: CameraRigConfig, bounds: Rect2D) CameraRigConfig {
        var config = self;
        config.bounds = bounds;
        return config;
    }
};

/// Stateful camera controller that follows a target and produces Camera2D values.
pub const CameraRig2D = struct {
    position: Vector2,
    target: Vector2,
    zoom: f32 = 1.0,
    target_zoom: f32 = 1.0,
    config: CameraRigConfig = .{},

    /// Creates a camera rig centered on an initial position.
    pub fn init(position: Vector2) CameraRig2D {
        return .{
            .position = position,
            .target = position,
        };
    }

    /// Returns a copy of the rig with new behavior config.
    pub fn withConfig(self: CameraRig2D, config: CameraRigConfig) CameraRig2D {
        var rig = self;
        rig.config = config;
        rig.zoom = config.zoom_range.clamp(rig.zoom);
        rig.target_zoom = config.zoom_range.clamp(rig.target_zoom);
        return rig;
    }

    /// Replaces the current camera position and target immediately.
    pub fn jumpTo(self: *CameraRig2D, position: Vector2) void {
        self.position = position;
        self.target = position;
    }

    /// Sets the target that the camera should follow.
    pub fn follow(self: *CameraRig2D, target: Vector2) void {
        self.target = target;
    }

    /// Replaces the current zoom and target zoom immediately.
    pub fn jumpToZoom(self: *CameraRig2D, zoom: f32) void {
        const clamped = self.config.zoom_range.clamp(zoom);

        self.zoom = clamped;
        self.target_zoom = clamped;
    }

    /// Sets the target zoom that the camera should approach.
    pub fn setTargetZoom(self: *CameraRig2D, zoom: f32) void {
        self.target_zoom = self.config.zoom_range.clamp(zoom);
    }

    /// Adds a delta to the target zoom.
    pub fn zoomTargetBy(self: *CameraRig2D, delta: f32) void {
        self.setTargetZoom(self.target_zoom + delta);
    }

    /// Replaces the optional world-space camera bounds.
    pub fn setBounds(self: *CameraRig2D, bounds: Rect2D) void {
        self.config.bounds = bounds;
    }

    /// Clears world-space camera bounds.
    pub fn clearBounds(self: *CameraRig2D) void {
        self.config.bounds = null;
    }

    /// Moves the camera toward its target for one frame.
    pub fn update(self: *CameraRig2D, dt_seconds: f32) void {
        std.debug.assert(dt_seconds >= 0.0);

        self.target_zoom = self.config.zoom_range.clamp(self.target_zoom);

        const step = smoothingStep(self.config.smoothing, dt_seconds);

        self.position = lerpVector2(self.position, self.target, step);
        self.zoom = lerpF32(self.zoom, self.target_zoom, step);

        if (self.config.snap_distance > 0.0) {
            const snap_distance_sq = self.config.snap_distance *
                self.config.snap_distance;

            if (distanceSquared(self.position, self.target) <= snap_distance_sq) {
                self.position = self.target;
            }

            const zoom_delta = self.zoom - self.target_zoom;
            if (zoom_delta * zoom_delta <= snap_distance_sq) {
                self.zoom = self.target_zoom;
            }
        }
    }

    /// Returns an unclamped renderer camera.
    pub fn camera(self: CameraRig2D) Camera2D {
        return Camera2D.init(self.position, self.zoom);
    }

    /// Returns a renderer camera clamped to bounds for a surface size.
    pub fn cameraForSurface(
        self: CameraRig2D,
        surface_width: u32,
        surface_height: u32,
    ) Camera2D {
        const zoom = self.config.zoom_range.clamp(self.zoom);
        const position = if (self.config.bounds) |bounds|
            clampPositionToBounds(self.position, bounds, surface_width, surface_height, zoom)
        else
            self.position;

        return Camera2D.init(position, zoom);
    }

    /// Returns the visible world rectangle for a surface size.
    pub fn visibleWorldRect(
        self: CameraRig2D,
        surface_width: u32,
        surface_height: u32,
    ) Rect2D {
        return self.cameraForSurface(surface_width, surface_height)
            .visibleWorldRect(surface_width, surface_height);
    }

    /// Returns a viewport using the unclamped camera.
    pub fn viewport(
        self: CameraRig2D,
        surface_width: u32,
        surface_height: u32,
    ) Viewport2D {
        return Viewport2D.init(self.camera(), surface_width, surface_height);
    }

    /// Returns a viewport using the bounds-clamped camera.
    pub fn viewportForSurface(
        self: CameraRig2D,
        surface_width: u32,
        surface_height: u32,
    ) Viewport2D {
        return Viewport2D.init(
            self.cameraForSurface(surface_width, surface_height),
            surface_width,
            surface_height,
        );
    }

    /// Converts screen-space pixels to world-space using the clamped camera.
    pub fn screenToWorld(
        self: CameraRig2D,
        screen: Vector2,
        surface_width: u32,
        surface_height: u32,
    ) Vector2 {
        return self.viewportForSurface(surface_width, surface_height)
            .screenToWorld(screen);
    }

    /// Converts world-space to screen-space pixels using the clamped camera.
    pub fn worldToScreen(
        self: CameraRig2D,
        world: Vector2,
        surface_width: u32,
        surface_height: u32,
    ) Vector2 {
        return self.viewportForSurface(surface_width, surface_height)
            .worldToScreen(world);
    }

    /// Changes zoom while keeping a screen point anchored to the same world point.
    pub fn zoomAroundScreenPoint(
        self: *CameraRig2D,
        screen: Vector2,
        surface_width: u32,
        surface_height: u32,
        next_zoom: f32,
    ) void {
        const viewport_value = self.viewportForSurface(surface_width, surface_height);
        const next_camera = viewport_value.cameraZoomedAroundScreenPoint(
            screen,
            self.config.zoom_range.clamp(next_zoom),
        );

        self.position = next_camera.position;
        self.target = next_camera.position;
        self.zoom = next_camera.zoom;
        self.target_zoom = next_camera.zoom;
    }
};

/// Returns a frame interpolation amount from a smoothing speed.
fn smoothingStep(smoothing: f32, dt_seconds: f32) f32 {
    std.debug.assert(smoothing >= 0.0);
    std.debug.assert(dt_seconds >= 0.0);

    return clampF32(smoothing * dt_seconds, 0.0, 1.0);
}

/// Linearly interpolates between two scalar values.
fn lerpF32(from: f32, to: f32, amount: f32) f32 {
    return from + (to - from) * amount;
}

/// Linearly interpolates between two vectors.
fn lerpVector2(from: Vector2, to: Vector2, amount: f32) Vector2 {
    return Vector2.xy(
        lerpF32(from.x, to.x, amount),
        lerpF32(from.y, to.y, amount),
    );
}

/// Returns squared distance between two vectors.
fn distanceSquared(a: Vector2, b: Vector2) f32 {
    const dx = a.x - b.x;
    const dy = a.y - b.y;

    return dx * dx + dy * dy;
}

/// Clamps a scalar into an inclusive range.
fn clampF32(value: f32, min: f32, max: f32) f32 {
    return @max(min, @min(max, value));
}

/// Returns the center point of a rectangle.
fn rectCenter(rect: Rect2D) Vector2 {
    return Vector2.xy(
        (rect.min.x + rect.max.x) * 0.5,
        (rect.min.y + rect.max.y) * 0.5,
    );
}

/// Clamps camera position so the visible view remains inside bounds.
fn clampPositionToBounds(
    position: Vector2,
    bounds: Rect2D,
    surface_width: u32,
    surface_height: u32,
    zoom: f32,
) Vector2 {
    std.debug.assert(surface_width > 0);
    std.debug.assert(surface_height > 0);
    std.debug.assert(zoom > 0.0);

    const view_width = @as(f32, @floatFromInt(surface_width)) / zoom;
    const view_height = @as(f32, @floatFromInt(surface_height)) / zoom;

    const half_width = view_width * 0.5;
    const half_height = view_height * 0.5;

    const min_x = bounds.min.x + half_width;
    const max_x = bounds.max.x - half_width;
    const min_y = bounds.min.y + half_height;
    const max_y = bounds.max.y - half_height;

    const center = rectCenter(bounds);

    const x = if (min_x > max_x)
        center.x
    else
        clampF32(position.x, min_x, max_x);

    const y = if (min_y > max_y)
        center.y
    else
        clampF32(position.y, min_y, max_y);

    return Vector2.xy(x, y);
}

test "camera rig moves toward its target" {
    var rig = CameraRig2D
        .init(Vector2.xy(0.0, 0.0))
        .withConfig(CameraRigConfig.default().withSmoothing(5.0));

    rig.follow(Vector2.xy(10.0, 0.0));
    rig.update(0.1);

    try std.testing.expect(rig.position.x > 0.0);
    try std.testing.expect(rig.position.x < 10.0);
    try std.testing.expectEqual(@as(f32, 0.0), rig.position.y);
}

test "camera rig can snap to its target" {
    var rig = CameraRig2D
        .init(Vector2.xy(0.0, 0.0))
        .withConfig(CameraRigConfig.default()
        .withSmoothing(100.0)
        .withSnapDistance(0.01));

    rig.follow(Vector2.xy(4.0, -2.0));
    rig.update(1.0);

    try std.testing.expectEqual(@as(f32, 4.0), rig.position.x);
    try std.testing.expectEqual(@as(f32, -2.0), rig.position.y);
}

test "camera rig clamps zoom target" {
    var rig = CameraRig2D
        .init(Vector2.xy(0.0, 0.0))
        .withConfig(CameraRigConfig.default()
        .withZoomRange(ZoomRange.init(0.5, 2.0)));

    rig.setTargetZoom(99.0);
    rig.update(1.0);

    try std.testing.expectEqual(@as(f32, 2.0), rig.zoom);

    rig.setTargetZoom(0.01);
    rig.update(1.0);

    try std.testing.expectEqual(@as(f32, 0.5), rig.zoom);
}

test "camera rig clamps visible view inside bounds" {
    const bounds = Rect2D.fromMinMax(
        Vector2.xy(-100.0, -50.0),
        Vector2.xy(100.0, 50.0),
    );

    var rig = CameraRig2D
        .init(Vector2.xy(1000.0, 1000.0))
        .withConfig(CameraRigConfig.default()
        .withBounds(bounds));

    rig.jumpToZoom(2.0);

    const camera_value = rig.cameraForSurface(100, 50);
    const visible = camera_value.visibleWorldRect(100, 50);

    try std.testing.expect(visible.min.x >= bounds.min.x);
    try std.testing.expect(visible.max.x <= bounds.max.x);
    try std.testing.expect(visible.min.y >= bounds.min.y);
    try std.testing.expect(visible.max.y <= bounds.max.y);
}

test "surface size exposes center" {
    const surface = SurfaceSize.init(800, 600);
    const center = surface.center();

    try std.testing.expectEqual(@as(f32, 400.0), center.x);
    try std.testing.expectEqual(@as(f32, 300.0), center.y);
    try std.testing.expectEqual(@as(f32, 800.0), surface.widthF32());
    try std.testing.expectEqual(@as(f32, 600.0), surface.heightF32());
}

test "viewport maps camera position to screen center" {
    const camera_value = Camera2D.init(Vector2.xy(100.0, 50.0), 2.0);
    const viewport_value = Viewport2D.init(camera_value, 800, 600);

    const screen = viewport_value.worldToScreen(Vector2.xy(100.0, 50.0));

    try std.testing.expectEqual(@as(f32, 400.0), screen.x);
    try std.testing.expectEqual(@as(f32, 300.0), screen.y);
}

test "viewport converts world to screen with zoom" {
    const camera_value = Camera2D.init(Vector2.xy(100.0, 50.0), 2.0);
    const viewport_value = Viewport2D.init(camera_value, 800, 600);

    const screen = viewport_value.worldToScreen(Vector2.xy(110.0, 40.0));

    try std.testing.expectEqual(@as(f32, 420.0), screen.x);
    try std.testing.expectEqual(@as(f32, 280.0), screen.y);
}

test "viewport converts screen to world with zoom" {
    const camera_value = Camera2D.init(Vector2.xy(100.0, 50.0), 2.0);
    const viewport_value = Viewport2D.init(camera_value, 800, 600);

    const world = viewport_value.screenToWorld(Vector2.xy(420.0, 280.0));

    try std.testing.expectEqual(@as(f32, 110.0), world.x);
    try std.testing.expectEqual(@as(f32, 40.0), world.y);
}

test "viewport round trips world and screen coordinates" {
    const camera_value = Camera2D.init(Vector2.xy(-20.0, 90.0), 1.5);
    const viewport_value = Viewport2D.init(camera_value, 1280, 720);
    const world_before = Vector2.xy(32.0, -16.0);

    const screen = viewport_value.worldToScreen(world_before);
    const world_after = viewport_value.screenToWorld(screen);

    try std.testing.expectApproxEqAbs(world_before.x, world_after.x, 0.001);
    try std.testing.expectApproxEqAbs(world_before.y, world_after.y, 0.001);
}

test "viewport detects screen points inside surface" {
    const camera_value = Camera2D.init(Vector2.xy(0.0, 0.0), 1.0);
    const viewport_value = Viewport2D.init(camera_value, 320, 180);

    try std.testing.expect(viewport_value.containsScreenPoint(Vector2.xy(0.0, 0.0)));
    try std.testing.expect(viewport_value.containsScreenPoint(Vector2.xy(319.0, 179.0)));
    try std.testing.expect(!viewport_value.containsScreenPoint(Vector2.xy(320.0, 179.0)));
    try std.testing.expect(!viewport_value.containsScreenPoint(Vector2.xy(319.0, 180.0)));
    try std.testing.expect(!viewport_value.containsScreenPoint(Vector2.xy(-1.0, 0.0)));
}

test "viewport detects visible world points" {
    const camera_value = Camera2D.init(Vector2.xy(0.0, 0.0), 1.0);
    const viewport_value = Viewport2D.init(camera_value, 100, 100);

    try std.testing.expect(viewport_value.containsWorldPoint(Vector2.xy(0.0, 0.0)));
    try std.testing.expect(viewport_value.containsWorldPoint(Vector2.xy(49.0, 49.0)));
    try std.testing.expect(!viewport_value.containsWorldPoint(Vector2.xy(51.0, 0.0)));
}

test "zoom around screen point keeps that world point anchored" {
    const camera_value = Camera2D.init(Vector2.xy(0.0, 0.0), 1.0);
    const viewport_before = Viewport2D.init(camera_value, 800, 600);
    const screen_point = Vector2.xy(600.0, 300.0);
    const world_before = viewport_before.screenToWorld(screen_point);

    const camera_after = viewport_before.cameraZoomedAroundScreenPoint(screen_point, 2.0);
    const viewport_after = Viewport2D.init(camera_after, 800, 600);
    const world_after = viewport_after.screenToWorld(screen_point);

    try std.testing.expectApproxEqAbs(world_before.x, world_after.x, 0.001);
    try std.testing.expectApproxEqAbs(world_before.y, world_after.y, 0.001);
}

test "camera rig exposes clamped viewport conversion" {
    const bounds = Rect2D.fromMinMax(
        Vector2.xy(-100.0, -100.0),
        Vector2.xy(100.0, 100.0),
    );

    var rig = CameraRig2D
        .init(Vector2.xy(1000.0, 0.0))
        .withConfig(CameraRigConfig.default().withBounds(bounds));

    rig.jumpToZoom(2.0);

    const viewport_value = rig.viewportForSurface(100, 100);
    const visible = viewport_value.visibleWorldRect();

    try std.testing.expect(visible.max.x <= bounds.max.x);
    try std.testing.expect(visible.min.x >= bounds.min.x);
}

test "camera rig zoom around screen point updates position and zoom immediately" {
    var rig = CameraRig2D.init(Vector2.xy(0.0, 0.0));

    const screen_point = Vector2.xy(600.0, 300.0);
    const world_before = rig.screenToWorld(screen_point, 800, 600);

    rig.zoomAroundScreenPoint(screen_point, 800, 600, 2.0);

    const world_after = rig.screenToWorld(screen_point, 800, 600);

    try std.testing.expectEqual(@as(f32, 2.0), rig.zoom);
    try std.testing.expectEqual(@as(f32, 2.0), rig.target_zoom);
    try std.testing.expectApproxEqAbs(world_before.x, world_after.x, 0.001);
    try std.testing.expectApproxEqAbs(world_before.y, world_after.y, 0.001);
}
