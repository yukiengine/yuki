//! Events2D event queue tests.
//!
//! These tests target the event queue directly while using the public Yuki2D
//! facade for actor handles and tags.

const std = @import("std");
const yuki2d = @import("yuki2d.zig");
const events2d = @import("events2d.zig");

const ActorId = yuki2d.ActorId;
const ActorTag = yuki2d.ActorTag;
const Error = events2d.Error;
const EventQueue = events2d.EventQueue;
const max_events = events2d.max_events;

test "event queue stores actor overlap events" {
    const actor = ActorId{ .index = 1, .generation = 1 };
    const other = ActorId{ .index = 2, .generation = 1 };
    const actor_tag = ActorTag.fromIndex(40);
    const other_tag = ActorTag.fromIndex(41);

    var queue = EventQueue.init();

    try std.testing.expect(queue.isEmpty());
    try std.testing.expectEqual(@as(usize, 0), queue.count());

    try queue.pushActorOverlap(actor, actor_tag, other, other_tag);

    try std.testing.expect(!queue.isEmpty());
    try std.testing.expectEqual(@as(usize, 1), queue.count());
    try std.testing.expectEqual(@as(usize, 1), queue.items().len);
    try std.testing.expectEqual(@as(usize, 1), queue.countKind(.actor_overlap));

    const event = queue.firstKind(.actor_overlap) orelse return error.ExpectedEvent;
    const payload = event.actorOverlapOrNull() orelse return error.ExpectedPayload;

    try std.testing.expect(payload.actor.eql(actor));
    try std.testing.expect(payload.other.eql(other));
    try std.testing.expect(payload.actor_tag.eql(actor_tag));
    try std.testing.expect(payload.other_tag.eql(other_tag));
}

test "event queue stores overlap transition events" {
    const actor = ActorId{ .index = 1, .generation = 1 };
    const other = ActorId{ .index = 2, .generation = 1 };
    const actor_tag = ActorTag.fromIndex(50);
    const other_tag = ActorTag.fromIndex(51);

    var queue = EventQueue.init();

    try queue.pushActorOverlapKind(.actor_overlap_begin, actor, actor_tag, other, other_tag);
    try queue.pushActorOverlapKind(.actor_overlap_stay, actor, actor_tag, other, other_tag);
    try queue.pushActorOverlapKind(.actor_overlap_end, actor, actor_tag, other, other_tag);

    try std.testing.expectEqual(@as(usize, 3), queue.count());
    try std.testing.expectEqual(@as(usize, 1), queue.countKind(.actor_overlap_begin));
    try std.testing.expectEqual(@as(usize, 1), queue.countKind(.actor_overlap_stay));
    try std.testing.expectEqual(@as(usize, 1), queue.countKind(.actor_overlap_end));
    try std.testing.expectEqual(@as(usize, 0), queue.countKind(.actor_overlap));

    const begin = queue.firstKind(.actor_overlap_begin) orelse return error.ExpectedEvent;
    const stay = queue.firstKind(.actor_overlap_stay) orelse return error.ExpectedEvent;
    const end = queue.firstKind(.actor_overlap_end) orelse return error.ExpectedEvent;

    try std.testing.expect(begin.isActorOverlapBegin());
    try std.testing.expect(stay.isActorOverlapStay());
    try std.testing.expect(end.isActorOverlapEnd());
}

test "event queue clears events" {
    var queue = EventQueue.init();

    try queue.pushActorOverlap(
        .{ .index = 1, .generation = 1 },
        ActorTag.fromIndex(60),
        .{ .index = 2, .generation = 1 },
        ActorTag.fromIndex(61),
    );

    try std.testing.expectEqual(@as(usize, 1), queue.count());

    queue.clear();

    try std.testing.expect(queue.isEmpty());
    try std.testing.expectEqual(@as(usize, 0), queue.count());
    try std.testing.expectEqual(@as(usize, 0), queue.items().len);
    try std.testing.expect(queue.firstKind(.actor_overlap) == null);
}

test "event queue reports full capacity" {
    var queue = EventQueue.init();

    var index: usize = 0;
    while (index < max_events) : (index += 1) {
        try queue.pushActorOverlap(
            .{ .index = @intCast(index), .generation = 1 },
            ActorTag.fromIndex(70),
            .{ .index = @intCast(index + 1), .generation = 1 },
            ActorTag.fromIndex(71),
        );
    }

    try std.testing.expectEqual(max_events, queue.count());

    try std.testing.expectError(
        Error.EventQueueFull,
        queue.pushActorOverlap(
            .{ .index = 1000, .generation = 1 },
            ActorTag.fromIndex(70),
            .{ .index = 1001, .generation = 1 },
            ActorTag.fromIndex(71),
        ),
    );
}
