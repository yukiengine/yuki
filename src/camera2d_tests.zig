//! Camera2D behavior test aggregator.
//!
//! Keep the camera runtime file focused by grouping rig and viewport tests by
//! subsystem concern.

test {
    _ = @import("camera2d_rig_tests.zig");
    _ = @import("camera2d_viewport_tests.zig");
}
