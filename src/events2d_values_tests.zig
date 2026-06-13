//! Events2D event kind and payload tests.
//!
//! These tests target the event value types directly while using the public
//! Yuki2D facade for actor handles and tags.

const std = @import("std");
const yuki2d = @import("yuki2d.zig");
const events2d = @import("events2d.zig");

const ActorId = yuki2d.ActorId;
const ActorTag = yuki2d.ActorTag;
const ActorOverlapEvent = events2d.ActorOverlapEvent;
const Event = events2d.Event;
const EventKind = events2d.EventKind;

test "event kind classifies actor overlap kinds" {
    try std.testing.expect(EventKind.actor_overlap.isActorOverlap());
    try std.testing.expect(EventKind.actor_overlap_begin.isActorOverlap());
    try std.testing.expect(EventKind.actor_overlap_stay.isActorOverlap());
    try std.testing.expect(EventKind.actor_overlap_end.isActorOverlap());

    try std.testing.expect(!EventKind.actor_overlap.isActorOverlapTransition());
    try std.testing.expect(EventKind.actor_overlap_begin.isActorOverlapTransition());
    try std.testing.expect(EventKind.actor_overlap_stay.isActorOverlapTransition());
    try std.testing.expect(EventKind.actor_overlap_end.isActorOverlapTransition());

    try std.testing.expect(EventKind.actor_overlap.isActiveActorOverlap());
    try std.testing.expect(EventKind.actor_overlap_begin.isActiveActorOverlap());
    try std.testing.expect(EventKind.actor_overlap_stay.isActiveActorOverlap());
    try std.testing.expect(!EventKind.actor_overlap_end.isActiveActorOverlap());
}

test "actor overlap payload matches actors and tags" {
    const actor = ActorId{ .index = 1, .generation = 1 };
    const other = ActorId{ .index = 2, .generation = 1 };
    const missing = ActorId{ .index = 3, .generation = 1 };
    const actor_tag = ActorTag.fromIndex(10);
    const other_tag = ActorTag.fromIndex(11);
    const missing_tag = ActorTag.fromIndex(12);

    const payload = ActorOverlapEvent{
        .actor = actor,
        .other = other,
        .actor_tag = actor_tag,
        .other_tag = other_tag,
    };

    try std.testing.expect(payload.hasActor(actor));
    try std.testing.expect(!payload.hasActor(other));
    try std.testing.expect(!payload.hasActor(missing));

    try std.testing.expect(payload.hasOther(other));
    try std.testing.expect(!payload.hasOther(actor));
    try std.testing.expect(!payload.hasOther(missing));

    try std.testing.expect(payload.hasActorTag(actor_tag));
    try std.testing.expect(!payload.hasActorTag(other_tag));
    try std.testing.expect(!payload.hasActorTag(missing_tag));

    try std.testing.expect(payload.hasOtherTag(other_tag));
    try std.testing.expect(!payload.hasOtherTag(actor_tag));
    try std.testing.expect(!payload.hasOtherTag(missing_tag));
}

test "actor overlap event constructors set tagged union kind" {
    const actor = ActorId{ .index = 1, .generation = 1 };
    const other = ActorId{ .index = 2, .generation = 1 };
    const actor_tag = ActorTag.fromIndex(20);
    const other_tag = ActorTag.fromIndex(21);

    const overlap = Event.actorOverlap(actor, actor_tag, other, other_tag);
    const begin = Event.actorOverlapBegin(actor, actor_tag, other, other_tag);
    const stay = Event.actorOverlapStay(actor, actor_tag, other, other_tag);
    const end = Event.actorOverlapEnd(actor, actor_tag, other, other_tag);

    try std.testing.expectEqual(EventKind.actor_overlap, overlap.kind());
    try std.testing.expectEqual(EventKind.actor_overlap_begin, begin.kind());
    try std.testing.expectEqual(EventKind.actor_overlap_stay, stay.kind());
    try std.testing.expectEqual(EventKind.actor_overlap_end, end.kind());

    try std.testing.expect(overlap.isActorOverlap());
    try std.testing.expect(begin.isActorOverlap());
    try std.testing.expect(stay.isActorOverlap());
    try std.testing.expect(end.isActorOverlap());

    try std.testing.expect(!overlap.isActorOverlapTransition());
    try std.testing.expect(begin.isActorOverlapTransition());
    try std.testing.expect(stay.isActorOverlapTransition());
    try std.testing.expect(end.isActorOverlapTransition());

    try std.testing.expect(overlap.isActiveActorOverlap());
    try std.testing.expect(begin.isActiveActorOverlap());
    try std.testing.expect(stay.isActiveActorOverlap());
    try std.testing.expect(!end.isActiveActorOverlap());
}

test "actor overlap event exposes payload through helper" {
    const actor = ActorId{ .index = 4, .generation = 2 };
    const other = ActorId{ .index = 8, .generation = 3 };
    const actor_tag = ActorTag.fromIndex(30);
    const other_tag = ActorTag.fromIndex(31);

    const event = Event.actorOverlapKind(
        .actor_overlap_begin,
        actor,
        actor_tag,
        other,
        other_tag,
    );

    const payload = event.actorOverlapOrNull() orelse return error.ExpectedPayload;

    try std.testing.expectEqual(EventKind.actor_overlap_begin, event.kind());
    try std.testing.expect(payload.actor.eql(actor));
    try std.testing.expect(payload.other.eql(other));
    try std.testing.expect(payload.actor_tag.eql(actor_tag));
    try std.testing.expect(payload.other_tag.eql(other_tag));
}
