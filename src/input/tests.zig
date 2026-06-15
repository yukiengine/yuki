//! Input behavior test aggregator.
//!
//! Keep the input runtime file focused by grouping digital, mapping, and mouse
//! behavior tests by subsystem concern.

test {
    _ = @import("digital_tests.zig");
    _ = @import("action_value_tests.zig");
    _ = @import("action_map_tests.zig");
    _ = @import("action_registry_tests.zig");
    _ = @import("context_tests.zig");
    _ = @import("router_tests.zig");
    _ = @import("map_tests.zig");
    _ = @import("mouse_tests.zig");
    _ = @import("events_tests.zig");
    _ = @import("event_reader_tests.zig");
    _ = @import("frame_tests.zig");
    _ = @import("session_tests.zig");
    _ = @import("session_builder_tests.zig");
    _ = @import("named_frame_tests.zig");
    _ = @import("named_events_tests.zig");
    _ = @import("type_tests.zig");
    _ = @import("source_names_tests.zig");
    _ = @import("binding_descriptors_tests.zig");
    _ = @import("builder_tests.zig");
}
