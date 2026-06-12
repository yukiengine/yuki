const std = @import("std");
const render2d = @import("render2d/renderer.zig");

/// Debug draw helper
pub const DebugDraw = struct {
    draw_list: *render2d.DrawList,
    layer: i32,
    thickness: f32 = 2.0,

    /// Creates a debug draw helper that submits quads into a draw list.
    pub fn init(draw_list: *render2d.DrawList, layer: i32) DebugDraw {
        return .{
            .draw_list = draw_list,
            .layer = layer,
        };
    }

    /// Returns a copy that draws outlines with a different thickness.
    pub fn withThickness(self: DebugDraw, thickness: f32) DebugDraw {
        std.debug.assert(thickness > 0.0);

        var copy = self;
        copy.thickness = thickness;
        return copy;
    }

    /// Draws a filled rectangle using the configured layer.
    pub fn fillRect(
        self: DebugDraw,
        rect: render2d.Rect2D,
        color: render2d.ColorRgba,
    ) !void {
        try self.draw_list.drawRectLayer(
            rectCenter(rect),
            rectSize(rect),
            color,
            self.layer,
        );
    }

    /// Draws an outlined rectangle using four thin filled quads.
    pub fn rectOutline(
        self: DebugDraw,
        rect: render2d.Rect2D,
        color: render2d.ColorRgba,
    ) !void {
        try self.rectOutlineThickness(rect, color, self.thickness);
    }

    /// Draws an outlined rectangle with an explicit line thickness.
    pub fn rectOutlineThickness(
        self: DebugDraw,
        rect: render2d.Rect2D,
        color: render2d.ColorRgba,
        thickness: f32,
    ) !void {
        std.debug.assert(thickness > 0.0);

        const width = rect.width();
        const height = rect.height();
        if (width <= 0.0 or height <= 0.0) return;

        const half_t = thickness * 0.5;

        try self.draw_list.drawRectLayer(
            render2d.Vector2.xy(rect.min.x + width * 0.5, rect.min.y + half_t),
            render2d.Vector2.xy(width, thickness),
            color,
            self.layer,
        );

        try self.draw_list.drawRectLayer(
            render2d.Vector2.xy(rect.min.x + width * 0.5, rect.max.y - half_t),
            render2d.Vector2.xy(width, thickness),
            color,
            self.layer,
        );

        try self.draw_list.drawRectLayer(
            render2d.Vector2.xy(rect.min.x + half_t, rect.min.y + height * 0.5),
            render2d.Vector2.xy(thickness, height),
            color,
            self.layer,
        );

        try self.draw_list.drawRectLayer(
            render2d.Vector2.xy(rect.max.x - half_t, rect.min.y + height * 0.5),
            render2d.Vector2.xy(thickness, height),
            color,
            self.layer,
        );
    }

    /// Draws a small cross centered on a world position.
    pub fn cross(
        self: DebugDraw,
        center: render2d.Vector2,
        size: f32,
        color: render2d.ColorRgba,
    ) !void {
        std.debug.assert(size > 0.0);

        const thickness = self.thickness;
        try self.draw_list.drawRectLayer(
            center,
            render2d.Vector2.xy(size, thickness),
            color,
            self.layer,
        );
        try self.draw_list.drawRectLayer(
            center,
            render2d.Vector2.xy(thickness, size),
            color,
            self.layer,
        );
    }
};

/// Returns the center point of a rectangle.
fn rectCenter(rect: render2d.Rect2D) render2d.Vector2 {
    return render2d.Vector2.xy(
        rect.min.x + rect.width() * 0.5,
        rect.min.y + rect.height() * 0.5,
    );
}

/// Returns the size of a rectangle.
fn rectSize(rect: render2d.Rect2D) render2d.Vector2 {
    return render2d.Vector2.xy(rect.width(), rect.height());
}

test "rect center uses midpoint" {
    const rect = render2d.Rect2D.fromMinMax(
        render2d.Vector2.xy(10.0, 20.0),
        render2d.Vector2.xy(30.0, 60.0),
    );

    const center = rectCenter(rect);

    try std.testing.expectEqual(@as(f32, 20.0), center.x);
    try std.testing.expectEqual(@as(f32, 40.0), center.y);
}

test "rect size uses width and height" {
    const rect = render2d.Rect2D.fromMinMax(
        render2d.Vector2.xy(10.0, 20.0),
        render2d.Vector2.xy(30.0, 60.0),
    );

    const size = rectSize(rect);

    try std.testing.expectEqual(@as(f32, 20.0), size.x);
    try std.testing.expectEqual(@as(f32, 40.0), size.y);
}
