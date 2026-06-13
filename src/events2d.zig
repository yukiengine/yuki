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
