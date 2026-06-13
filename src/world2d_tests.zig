//! World2D behavior test aggregator.
//!
//! Keep the world runtime file focused by grouping actor storage and query
//! tests by subsystem concern.

test {
    _ = @import("world2d_basics_tests.zig");
    _ = @import("world2d_query_tests.zig");
}
