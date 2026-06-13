//! Tilemap behavior test aggregator.
//!
//! Keep the tilemap runtime file focused by grouping broad behavior tests by
//! subsystem concern.

test {
    _ = @import("tilemap_basics_tests.zig");
    _ = @import("tilemap_query_tests.zig");
    _ = @import("tilemap_move_tests.zig");
}
