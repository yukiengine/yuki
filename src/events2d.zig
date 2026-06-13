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
    actor_spawned,
    actor_despawned,
    actor_overlap,
    actor_overlap_begin,
    actor_overlap_stay,
    actor_overlap_end,

    /// Returns true for actor lifecycle events.
    pub fn isActorLifecycle(self: EventKind) bool {
        return switch (self) {
            .actor_spawned,
            .actor_despawned,
            => true,

            else => false,
        };
    }

    /// Returns true when this kind carries actor-overlap data.
    pub fn isActorOverlap(self: EventKind) bool {
        return switch (self) {
            .actor_overlap,
            .actor_overlap_begin,
            .actor_overlap_stay,
            .actor_overlap_end,
            => true,

            .actor_spawned,
            .actor_despawned,
            => false,
        };
    }

    /// Returns true when this kind is an overlap transition.
    pub fn isActorOverlapTransition(self: EventKind) bool {
        return switch (self) {
            .actor_overlap_begin,
            .actor_overlap_stay,
            .actor_overlap_end,
            => true,

            .actor_spawned,
            .actor_despawned,
            .actor_overlap,
            => false,
        };
    }

    /// Returns true while the overlap is active this frame.
    pub fn isActiveActorOverlap(self: EventKind) bool {
        return switch (self) {
            .actor_overlap,
            .actor_overlap_begin,
            .actor_overlap_stay,
            => true,

            .actor_spawned,
            .actor_despawned,
            .actor_overlap_end,
            => false,
        };
    }
};

/// Event payload emitted when an actor enters or leaves the world.
pub const ActorLifecycleEvent = struct {
    actor: world2d.ActorId,
    tag: world2d.ActorTag,

    /// Returns true when this event belongs to the given actor.
    pub fn hasActor(self: ActorLifecycleEvent, actor: world2d.ActorId) bool {
        return self.actor.eql(actor);
    }

    /// Returns true when this event belongs to the given actor tag.
    pub fn hasTag(self: ActorLifecycleEvent, tag: world2d.ActorTag) bool {
        return self.tag.eql(tag);
    }
};

/// Event emitted when one actor overlaps another actor.
pub const ActorOverlapEvent = struct {
    actor: world2d.ActorId,
    other: world2d.ActorId,
    actor_tag: world2d.ActorTag,
    other_tag: world2d.ActorTag,

    /// Returns true when this event belongs to the actor.
    pub fn hasActor(self: ActorOverlapEvent, actor: world2d.ActorId) bool {
        return self.actor.eql(actor);
    }

    /// Returns true when this event targets the other actor.
    pub fn hasOther(self: ActorOverlapEvent, other: world2d.ActorId) bool {
        return self.other.eql(other);
    }

    /// Returns true when this event actor has the tag.
    pub fn hasActorTag(self: ActorOverlapEvent, tag: world2d.ActorTag) bool {
        return self.actor_tag.eql(tag);
    }

    /// Returns true when this event other actor has the tag.
    pub fn hasOtherTag(self: ActorOverlapEvent, tag: world2d.ActorTag) bool {
        return self.other_tag.eql(tag);
    }
};

/// Single typed event emitted by a 2D scene.
pub const Event = union(EventKind) {
    actor_spawned: ActorLifecycleEvent,
    actor_despawned: ActorLifecycleEvent,
    actor_overlap: ActorOverlapEvent,
    actor_overlap_begin: ActorOverlapEvent,
    actor_overlap_stay: ActorOverlapEvent,
    actor_overlap_end: ActorOverlapEvent,

    /// Creates an actor spawned event.
    pub fn actorSpawned(actor: world2d.ActorId, tag: world2d.ActorTag) Event {
        return .{ .actor_spawned = .{ .actor = actor, .tag = tag } };
    }

    /// Creates an actor despawned event.
    pub fn actorDespawned(actor: world2d.ActorId, tag: world2d.ActorTag) Event {
        return .{ .actor_despawned = .{ .actor = actor, .tag = tag } };
    }

    /// Creates an actor-overlap event.
    pub fn actorOverlap(
        actor: world2d.ActorId,
        actor_tag: world2d.ActorTag,
        other: world2d.ActorId,
        other_tag: world2d.ActorTag,
    ) Event {
        return actorOverlapKind(.actor_overlap, actor, actor_tag, other, other_tag);
    }

    /// Creates an actor-overlap event with a specific transition kind.
    pub fn actorOverlapKind(
        event_kind: EventKind,
        actor: world2d.ActorId,
        actor_tag: world2d.ActorTag,
        other: world2d.ActorId,
        other_tag: world2d.ActorTag,
    ) Event {
        const payload = ActorOverlapEvent{
            .actor = actor,
            .other = other,
            .actor_tag = actor_tag,
            .other_tag = other_tag,
        };

        return switch (event_kind) {
            .actor_overlap => .{ .actor_overlap = payload },
            .actor_overlap_begin => .{ .actor_overlap_begin = payload },
            .actor_overlap_stay => .{ .actor_overlap_stay = payload },
            .actor_overlap_end => .{ .actor_overlap_end = payload },

            .actor_spawned,
            .actor_despawned,
            => unreachable,
        };
    }

    /// Returns the event kind.
    pub fn kind(self: Event) EventKind {
        return switch (self) {
            .actor_spawned => .actor_spawned,
            .actor_despawned => .actor_despawned,
            .actor_overlap => .actor_overlap,
            .actor_overlap_begin => .actor_overlap_begin,
            .actor_overlap_stay => .actor_overlap_stay,
            .actor_overlap_end => .actor_overlap_end,
        };
    }

    /// Creates an actor-overlap begin event.
    pub fn actorOverlapBegin(
        actor: world2d.ActorId,
        actor_tag: world2d.ActorTag,
        other: world2d.ActorId,
        other_tag: world2d.ActorTag,
    ) Event {
        return actorOverlapKind(.actor_overlap_begin, actor, actor_tag, other, other_tag);
    }

    /// Creates an actor-overlap stay event.
    pub fn actorOverlapStay(
        actor: world2d.ActorId,
        actor_tag: world2d.ActorTag,
        other: world2d.ActorId,
        other_tag: world2d.ActorTag,
    ) Event {
        return actorOverlapKind(.actor_overlap_stay, actor, actor_tag, other, other_tag);
    }

    /// Creates an actor-overlap end event.
    pub fn actorOverlapEnd(
        actor: world2d.ActorId,
        actor_tag: world2d.ActorTag,
        other: world2d.ActorId,
        other_tag: world2d.ActorTag,
    ) Event {
        return actorOverlapKind(.actor_overlap_end, actor, actor_tag, other, other_tag);
    }

    /// Returns true when this is an actor lifecycle event.
    pub fn isActorLifecycle(self: Event) bool {
        return self.kind().isActorLifecycle();
    }

    /// Returns the lifecycle payload when this is a lifecycle event.
    pub fn actorLifecycleOrNull(self: Event) ?ActorLifecycleEvent {
        return switch (self) {
            .actor_spawned => |payload| payload,
            .actor_despawned => |payload| payload,
            else => null,
        };
    }

    /// Returns true when this event carries actor-overlap data.
    pub fn isActorOverlap(self: Event) bool {
        return self.kind().isActorOverlap();
    }

    /// Returns true when this event is begin/stay/end overlap data.
    pub fn isActorOverlapTransition(self: Event) bool {
        return self.kind().isActorOverlapTransition();
    }

    /// Returns true while this overlap is active this frame.
    pub fn isActiveActorOverlap(self: Event) bool {
        return self.kind().isActiveActorOverlap();
    }

    /// Returns true when this event kind is actor-overlap begin.
    pub fn isActorOverlapBegin(self: Event) bool {
        return self.kind() == .actor_overlap_begin;
    }

    /// Returns true when this event kind is actor-overlap stay.
    pub fn isActorOverlapStay(self: Event) bool {
        return self.kind() == .actor_overlap_stay;
    }

    /// Returns true when this event kind is actor-overlap end.
    pub fn isActorOverlapEnd(self: Event) bool {
        return self.kind() == .actor_overlap_end;
    }

    /// Returns the actor-overlap payload when this event carries one.
    pub fn actorOverlapOrNull(self: Event) ?ActorOverlapEvent {
        return switch (self) {
            .actor_overlap => |payload| payload,
            .actor_overlap_begin => |payload| payload,
            .actor_overlap_stay => |payload| payload,
            .actor_overlap_end => |payload| payload,
            else => null,
        };
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

    /// Adds an actor-spawned event to the queue.
    pub fn pushActorSpawned(self: *EventQueue, actor: world2d.ActorId, tag: world2d.ActorTag) !void {
        try self.push(Event.actorSpawned(actor, tag));
    }

    /// Adds an actor-despawned event to the queue.
    pub fn pushActorDespawned(self: *EventQueue, actor: world2d.ActorId, tag: world2d.ActorTag) !void {
        try self.push(Event.actorDespawned(actor, tag));
    }

    /// Adds an actor-overlap event to the queue.
    pub fn pushActorOverlap(
        self: *EventQueue,
        actor: world2d.ActorId,
        actor_tag: world2d.ActorTag,
        other: world2d.ActorId,
        other_tag: world2d.ActorTag,
    ) !void {
        try self.push(Event.actorOverlap(actor, actor_tag, other, other_tag));
    }

    /// Adds an actor-overlap transition event to the queue.
    pub fn pushActorOverlapKind(
        self: *EventQueue,
        event_kind: EventKind,
        actor: world2d.ActorId,
        actor_tag: world2d.ActorTag,
        other: world2d.ActorId,
        other_tag: world2d.ActorTag,
    ) !void {
        try self.push(Event.actorOverlapKind(event_kind, actor, actor_tag, other, other_tag));
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
    pub fn countKind(self: *const EventQueue, event_kind: EventKind) usize {
        var total: usize = 0;

        for (self.items()) |event| {
            if (event.kind() == event_kind) total += 1;
        }

        return total;
    }

    /// Returns the first event of a specific kind.
    pub fn firstKind(self: *const EventQueue, event_kind: EventKind) ?Event {
        for (self.items()) |event| {
            if (event.kind() == event_kind) return event;
        }

        return null;
    }

    /// Returns the number of queued events.
    pub fn count(self: *const EventQueue) usize {
        return self.event_count;
    }
};

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
    const actor = world2d.ActorId{ .index = 1, .generation = 1 };
    const other = world2d.ActorId{ .index = 2, .generation = 1 };
    const missing = world2d.ActorId{ .index = 3, .generation = 1 };
    const actor_tag = world2d.ActorTag.fromIndex(10);
    const other_tag = world2d.ActorTag.fromIndex(11);
    const missing_tag = world2d.ActorTag.fromIndex(12);

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
    const actor = world2d.ActorId{ .index = 1, .generation = 1 };
    const other = world2d.ActorId{ .index = 2, .generation = 1 };
    const actor_tag = world2d.ActorTag.fromIndex(20);
    const other_tag = world2d.ActorTag.fromIndex(21);

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
    const actor = world2d.ActorId{ .index = 4, .generation = 2 };
    const other = world2d.ActorId{ .index = 8, .generation = 3 };
    const actor_tag = world2d.ActorTag.fromIndex(30);
    const other_tag = world2d.ActorTag.fromIndex(31);

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

test "event queue stores actor overlap events" {
    const actor = world2d.ActorId{ .index = 1, .generation = 1 };
    const other = world2d.ActorId{ .index = 2, .generation = 1 };
    const actor_tag = world2d.ActorTag.fromIndex(40);
    const other_tag = world2d.ActorTag.fromIndex(41);

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
    const actor = world2d.ActorId{ .index = 1, .generation = 1 };
    const other = world2d.ActorId{ .index = 2, .generation = 1 };
    const actor_tag = world2d.ActorTag.fromIndex(50);
    const other_tag = world2d.ActorTag.fromIndex(51);

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
        world2d.ActorTag.fromIndex(60),
        .{ .index = 2, .generation = 1 },
        world2d.ActorTag.fromIndex(61),
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
            world2d.ActorTag.fromIndex(70),
            .{ .index = @intCast(index + 1), .generation = 1 },
            world2d.ActorTag.fromIndex(71),
        );
    }

    try std.testing.expectEqual(max_events, queue.count());

    try std.testing.expectError(
        Error.EventQueueFull,
        queue.pushActorOverlap(
            .{ .index = 1000, .generation = 1 },
            world2d.ActorTag.fromIndex(70),
            .{ .index = 1001, .generation = 1 },
            world2d.ActorTag.fromIndex(71),
        ),
    );
}
