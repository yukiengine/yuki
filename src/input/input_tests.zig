//! Input behavior test aggregator.
//!
//! Keep the input runtime file focused by grouping digital, mapping, and mouse
//! behavior tests by subsystem concern.

test {
    _ = @import("input_digital_tests.zig");
    _ = @import("input_action_value_tests.zig");
    _ = @import("input_action_map_tests.zig");
    _ = @import("input_action_registry_tests.zig");
    _ = @import("input_context_tests.zig");
    _ = @import("input_router_tests.zig");
    _ = @import("input_map_tests.zig");
    _ = @import("input_mouse_tests.zig");
    _ = @import("input_event_tests.zig");
    _ = @import("input_frame_tests.zig");
    _ = @import("input_type_tests.zig");
}
