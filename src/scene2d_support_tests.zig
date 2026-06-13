//! Scene2D support module test aggregator.
//!
//! These tests cover the small modules that back Scene2D without keeping the
//! runtime implementations tied to inline test blocks.

test {
    _ = @import("actor_view2d_tests.zig");
    _ = @import("commands2d_tests.zig");
    _ = @import("debug_draw_tests.zig");
    _ = @import("event_reader2d_tests.zig");
    _ = @import("overlaps2d_tests.zig");
    _ = @import("picking2d_tests.zig");
    _ = @import("prefab2d_tests.zig");
}
