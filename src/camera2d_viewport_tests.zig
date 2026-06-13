//! Camera2D viewport and coordinate conversion tests.
//!
//! These tests use the public Yuki2D facade so they exercise the same surface
//! that future Luau bindings should mirror.

const std = @import("std");
const yuki2d = @import("yuki2d.zig");

const camera2d = yuki2d.camera;

const Camera2D = camera2d.Camera2D;
const SurfaceSize = camera2d.SurfaceSize;
const Vector2 = camera2d.Vector2;
const Viewport2D = camera2d.Viewport2D;

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
