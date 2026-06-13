//! Overlaps2D transition tracking tests.
//!
//! These tests cover begin/stay tracking without keeping frame-transition
//! examples in the overlap tracker implementation.

const std = @import("std");
const yuki2d = @import("yuki2d.zig");
const overlaps2d = @import("overlaps2d.zig");

const ActorOverlapPair = overlaps2d.ActorOverlapPair;
const ActorOverlapTracker = overlaps2d.ActorOverlapTracker;

test "overlap tracker detects begin and stay" {
    const actor = yuki2d.ActorId{ .index = 1, .generation = 1 };
    const other = yuki2d.ActorId{ .index = 2, .generation = 1 };
    const pair = ActorOverlapPair.init(
        actor,
        yuki2d.ActorTag.fromIndex(1),
        other,
        yuki2d.ActorTag.fromIndex(2),
    );

    var tracker = ActorOverlapTracker.init();

    tracker.beginFrame();
    try std.testing.expect(!tracker.wasOverlapping(pair));
    try tracker.remember(pair);
    tracker.finishFrame();

    tracker.beginFrame();
    try std.testing.expect(tracker.wasOverlapping(pair));
}
