//! EventReader2D filter behavior tests.
//!
//! These tests cover the read-only event querying helpers used by Scene2D.

const std = @import("std");
const yuki2d = @import("yuki2d.zig");
const events2d = @import("events2d.zig");
const event_reader2d = @import("event_reader2d.zig");

const ActorId = yuki2d.ActorId;
const ActorOverlapFilter = event_reader2d.ActorOverlapFilter;
const Event = events2d.Event;
const EventReader = event_reader2d.EventReader;

test "event reader filters active actor overlaps" {
    const actor = ActorId{ .index = 1, .generation = 1 };
    const other = ActorId{ .index = 2, .generation = 1 };
    const actor_tag = yuki2d.ActorTag.fromIndex(1);
    const other_tag = yuki2d.ActorTag.fromIndex(2);

    const all_events = [_]Event{
        Event.actorOverlapBegin(actor, actor_tag, other, other_tag),
        Event.actorOverlapStay(actor, actor_tag, other, other_tag),
        Event.actorOverlapEnd(actor, actor_tag, other, other_tag),
    };

    const reader = EventReader.init(all_events[0..]);
    const filter = ActorOverlapFilter
        .active()
        .withActor(actor)
        .withOtherTag(other_tag);

    try std.testing.expectEqual(@as(usize, 2), reader.countActorOverlaps(filter));
    try std.testing.expect(reader.hasActorOverlap(filter));
}

test "event reader finds first overlap by kind" {
    const actor = ActorId{ .index = 1, .generation = 1 };
    const other = ActorId{ .index = 2, .generation = 1 };
    const actor_tag = yuki2d.ActorTag.fromIndex(1);
    const other_tag = yuki2d.ActorTag.fromIndex(2);

    const all_events = [_]Event{
        Event.actorOverlapBegin(actor, actor_tag, other, other_tag),
        Event.actorOverlapEnd(actor, actor_tag, other, other_tag),
    };

    const reader = EventReader.init(all_events[0..]);
    const event = reader.firstActorOverlap(
        ActorOverlapFilter.any().withKind(.actor_overlap_end),
    ) orelse return error.ExpectedEvent;

    try std.testing.expect(event.isActorOverlapEnd());
    const overlap = event.actorOverlapOrNull().?;
    try std.testing.expect(overlap.actor.eql(actor));
}
