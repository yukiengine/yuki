//! DebugDraw public behavior tests.
//!
//! These tests verify submitted draw commands rather than private helper
//! functions, so debug drawing can keep its helpers private.

const std = @import("std");
const yuki2d = @import("yuki2d.zig");
const debug_draw = @import("debug_draw.zig");

const ColorRgba = yuki2d.ColorRgba;
const DebugDraw = debug_draw.DebugDraw;
const DrawList = yuki2d.render.DrawList;
const Rect2D = yuki2d.Rect2D;
const Vector2 = yuki2d.Vector2;

test "debug draw fills rectangle as centered quad" {
    var draw_list = DrawList.init();
    const helper = DebugDraw.init(&draw_list, 7);
    const color = ColorRgba.rgb(1.0, 0.0, 0.5);
    const rect = Rect2D.fromMinMax(Vector2.xy(10.0, 20.0), Vector2.xy(30.0, 60.0));

    try helper.fillRect(rect, color);

    const quad = draw_list.items()[0];
    try std.testing.expectEqual(@as(usize, 1), draw_list.items().len);
    try std.testing.expectEqual(@as(f32, 20.0), quad.transform.position.x);
    try std.testing.expectEqual(@as(f32, 40.0), quad.transform.position.y);
    try std.testing.expectEqual(@as(f32, 20.0), quad.transform.size.x);
    try std.testing.expectEqual(@as(f32, 40.0), quad.transform.size.y);
    try std.testing.expectEqual(@as(i32, 7), quad.layer);
    try std.testing.expectEqual(@as(f32, color.r), quad.color.r);
    try std.testing.expectEqual(@as(f32, color.g), quad.color.g);
    try std.testing.expectEqual(@as(f32, color.b), quad.color.b);
    try std.testing.expectEqual(@as(f32, color.a), quad.color.a);
}

test "debug draw outline submits four border quads" {
    var draw_list = DrawList.init();
    const helper = DebugDraw.init(&draw_list, 3).withThickness(2.0);
    const rect = Rect2D.fromMinMax(Vector2.xy(10.0, 20.0), Vector2.xy(30.0, 60.0));

    try helper.rectOutline(rect, ColorRgba.rgb(0.0, 1.0, 0.0));

    const quads = draw_list.items();
    try std.testing.expectEqual(@as(usize, 4), quads.len);
    try std.testing.expectEqual(@as(f32, 20.0), quads[0].transform.size.x);
    try std.testing.expectEqual(@as(f32, 2.0), quads[0].transform.size.y);
    try std.testing.expectEqual(@as(f32, 2.0), quads[2].transform.size.x);
    try std.testing.expectEqual(@as(f32, 40.0), quads[2].transform.size.y);
    try std.testing.expectEqual(@as(i32, 3), quads[0].layer);
    try std.testing.expectEqual(@as(i32, 3), quads[3].layer);
}
