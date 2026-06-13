const std = @import("std");
const world2d = @import("world2d.zig");

/// Maximum number of scene events stored for one frame.
pub const max_events = 64;

/// Errors returned by the scene event queue.
pub const Error = error{
    EventQueueFull,
};

/// Type of scene event emitted by 2D systems.
pub const EventKind = enum(u8) {
    actor_overlap,
    actor_overlap_begin,
    actor_overlap_stay,
    actor_overlap_end,
};

/// Event emitted when one actor overlaps another actor.
pub const ActorOverlapEvent = struct {
    actor: world2d.ActorId,
    other: world2d.ActorId,
    actor_tag: world2d.ActorTag,
    other_tag: world2d.ActorTag,
};

/// Single event emitted by a 2D scene.
pub const Event = struct {
    kind: EventKind,
    actor_overlap: ActorOverlapEvent,

    /// Creates an actor-overlap event.
    pub fn actorOverlap(
        actor: world2d.ActorId,
        actor_tag: world2d.ActorTag,
        other: world2d.ActorId,
        other_tag: world2d.ActorTag,
    ) Event {
        return .{
            .kind = .actor_overlap,
            .actor_overlap = .{
                .actor = actor,
                .other = other,
                .actor_tag = actor_tag,
                .other_tag = other_tag,
            },
        };
    }

    /// Creates an actor-overlap event with a specific transition kind.
    pub fn actorOverlapKind(
        kind: EventKind,
        actor: world2d.ActorId,
        actor_tag: world2d.ActorTag,
        other: world2d.ActorId,
        other_tag: world2d.ActorTag,
    ) Event {
        return .{
            .kind = kind,
            .actor_overlap = .{
                .actor = actor,
                .other = other,
                .actor_tag = actor_tag,
                .other_tag = other_tag,
            },
        };
    }

    /// Creates an actor-overlap begin event.
    pub fn actorOverlapBegin(actor: world2d.ActorId, actor_tag: world2d.ActorTag, other: world2d.ActorId, other_tag: world2d.ActorTag) Event {
        return actorOverlapKind(.actor_overlap_begin, actor, actor_tag, other, other_tag);
    }

    /// Creates an actor-overlap stay event.
    pub fn actorOverlapStay(actor: world2d.ActorId, actor_tag: world2d.ActorTag, other: world2d.ActorId, other_tag: world2d.ActorTag) Event {
        return actorOverlapKind(.actor_overlap_stay, actor, actor_tag, other, other_tag);
    }

    /// Creates an actor-overlap end event.
    pub fn actorOverlapEnd(actor: world2d.ActorId, actor_tag: world2d.ActorTag, other: world2d.ActorId, other_tag: world2d.ActorTag) Event {
        return actorOverlapKind(.actor_overlap_end, actor, actor_tag, other, other_tag);
    }
};

/// Bounded event queue cleared once per frame.
pub const EventQueue = struct {
    events: [max_events]Event,
    event_count: usize = 0,

    /// Creates an empty event queue.
    pub fn init() EventQueue {
        return .{
            .events = undefined,
        };
    }

    /// Removes all queued events.
    pub fn clear(self: *EventQueue) void {
        self.event_count = 0;
    }

    /// Adds one event to the queue.
    pub fn push(self: *EventQueue, event: Event) !void {
        if (self.event_count == max_events) {
            return Error.EventQueueFull;
        }

        self.events[self.event_count] = event;
        self.event_count += 1;
    }

    /// Adds an actor-overlap event to the queue.
    pub fn pushActorOverlap(
        self: *EventQueue,
        actor: world2d.ActorId,
        actor_tag: world2d.ActorTag,
        other: world2d.ActorId,
        other_tag: world2d.ActorTag,
    ) !void {
        try self.push(Event.actorOverlapKind(
            .actor_overlap,
            actor,
            actor_tag,
            other,
            other_tag,
        ));
    }

    /// Returns queued events.
    pub fn items(self: *const EventQueue) []const Event {
        return self.events[0..self.event_count];
    }

    /// Returns true when the queue has no events.
    pub fn isEmpty(self: *const EventQueue) bool {
        return self.event_count == 0;
    }

    /// Counts events of a specific kind.
    pub fn countKind(self: *const EventQueue, kind: EventKind) usize {
        var count_kind: usize = 0;

        for (self.items()) |event| {
            if (event.kind == kind) count_kind += 1;
        }

        return count_kind;
    }

    /// Returns the first event of a specific kind.
    pub fn firstKind(self: *const EventQueue, kind: EventKind) ?Event {
        for (self.items()) |event| {
            if (event.kind == kind) return event;
        }

        return null;
    }

    /// Returns the number of queued events.
    pub fn count(self: *const EventQueue) usize {
        return self.event_count;
    }

    /// Adds an actor-overlap transition event to the queue.
    pub fn pushActorOverlapKind(
        self: *EventQueue,
        kind: EventKind,
        actor: world2d.ActorId,
        actor_tag: world2d.ActorTag,
        other: world2d.ActorId,
        other_tag: world2d.ActorTag,
    ) !void {
        try self.push(Event.actorOverlapKind(kind, actor, actor_tag, other, other_tag));
    }
};

test "event queue stores actor overlap events" {
    const actor = world2d.ActorId{ .index = 1, .generation = 1 };
    const other = world2d.ActorId{ .index = 2, .generation = 1 };
    const actor_tag = world2d.ActorTag.fromIndex(10);
    const other_tag = world2d.ActorTag.fromIndex(11);

    var queue = EventQueue.init();

    try queue.pushActorOverlap(actor, actor_tag, other, other_tag);

    try std.testing.expect(!queue.isEmpty());
    try std.testing.expectEqual(@as(usize, 1), queue.items().len);
    try std.testing.expectEqual(@as(usize, 1), queue.countKind(.actor_overlap));

    const event = queue.firstKind(.actor_overlap).?;
    try std.testing.expect(event.actor_overlap.actor.eql(actor));
    try std.testing.expect(event.actor_overlap.other.eql(other));
    try std.testing.expect(event.actor_overlap.actor_tag.eql(actor_tag));
    try std.testing.expect(event.actor_overlap.other_tag.eql(other_tag));
}

test "event queue clears events" {
    var queue = EventQueue.init();

    try queue.pushActorOverlap(
        .{ .index = 1, .generation = 1 },
        world2d.ActorTag.fromIndex(1),
        .{ .index = 2, .generation = 1 },
        world2d.ActorTag.fromIndex(2),
    );

    queue.clear();

    try std.testing.expect(queue.isEmpty());
    try std.testing.expectEqual(@as(usize, 0), queue.items().len);
}
