//! Scene2D behavior test aggregator.
//!
//! Keep the scene runtime file focused by grouping broad behavior tests by
//! subsystem concern.

test {
    _ = @import("scene2d_basics_tests.zig");
    _ = @import("scene2d_query_tests.zig");
    _ = @import("scene2d_frame_tests.zig");
    _ = @import("scene2d_state_tests.zig");
}
