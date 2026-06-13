const std = @import("std");
const render2d = @import("render2d/renderer.zig");

/// Public vector type used by the 2D camera helpers.
pub const Vector2 = render2d.Vector2;

/// Public camera value consumed by the renderer.
pub const Camera2D = render2d.Camera2D;

/// Public rectangle type used for camera bounds.
pub const Rect2D = render2d.Rect2D;

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
