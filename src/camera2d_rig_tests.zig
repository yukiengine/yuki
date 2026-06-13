//! Camera2D rig behavior tests.
//!
//! These tests use the public Yuki2D facade so they exercise the same surface
//! that future Luau bindings should mirror.

const std = @import("std");
const yuki2d = @import("yuki2d.zig");

const camera2d = yuki2d.camera;

const CameraRig2D = camera2d.CameraRig2D;
const CameraRigConfig = camera2d.CameraRigConfig;
const Rect2D = camera2d.Rect2D;
const Vector2 = camera2d.Vector2;
const ZoomRange = camera2d.ZoomRange;

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
