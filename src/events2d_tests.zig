//! Events2D behavior test aggregator.
//!
//! Keep the event runtime file focused by grouping event value and queue tests
//! by subsystem concern.

test {
    _ = @import("events2d_values_tests.zig");
    _ = @import("events2d_queue_tests.zig");
}
