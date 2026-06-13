const std = @import("std");
const events2d = @import("events2d.zig");
const world2d = @import("world2d.zig");

/// Filter used to query actor-overlap events.
pub const ActorOverlapFilter = struct {
    kind: ?events2d.EventKind = null,
    actor: ?world2d.ActorId = null,
    other: ?world2d.ActorId = null,
    actor_tag: ?world2d.ActorTag = null,
    other_tag: ?world2d.ActorTag = null,
    active_only: bool = false,

    /// Creates a filter that accepts every actor-overlap event.
    pub fn any() ActorOverlapFilter {
        return .{};
    }

    /// Creates a filter that accepts active overlap events only.
    pub fn active() ActorOverlapFilter {
        return .{
            .active_only = true,
        };
    }

    /// Returns a copy that only accepts one event kind.
    pub fn withKind(self: ActorOverlapFilter, kind: events2d.EventKind) ActorOverlapFilter {
        var filter = self;
        filter.kind = kind;
        return filter;
    }

    /// Returns a copy that only accepts events for one actor.
    pub fn withActor(self: ActorOverlapFilter, actor: world2d.ActorId) ActorOverlapFilter {
        var filter = self;
        filter.actor = actor;
        return filter;
    }

    /// Returns a copy that only accepts events for one other actor.
    pub fn withOther(self: ActorOverlapFilter, other: world2d.ActorId) ActorOverlapFilter {
        var filter = self;
        filter.other = other;
        return filter;
    }

    /// Returns a copy that only accepts events from actors with one tag.
    pub fn withActorTag(self: ActorOverlapFilter, tag: world2d.ActorTag) ActorOverlapFilter {
        var filter = self;
        filter.actor_tag = tag;
        return filter;
    }

    /// Returns a copy that only accepts events targeting actors with one tag.
    pub fn withOtherTag(self: ActorOverlapFilter, tag: world2d.ActorTag) ActorOverlapFilter {
        var filter = self;
        filter.other_tag = tag;
        return filter;
    }

    /// Returns true when an event satisfies this filter.
    pub fn matches(self: ActorOverlapFilter, event: events2d.Event) bool {
        const overlap = event.actorOverlapOrNull() orelse return false;

        if (self.active_only and !event.isActiveActorOverlap()) return false;

        if (self.kind) |kind| {
            if (event.kind() != kind) return false;
        }

        if (self.actor) |actor| {
            if (!overlap.hasActor(actor)) return false;
        }

        if (self.other) |other| {
            if (!overlap.hasOther(other)) return false;
        }

        if (self.actor_tag) |tag| {
            if (!overlap.hasActorTag(tag)) return false;
        }

        if (self.other_tag) |tag| {
            if (!overlap.hasOtherTag(tag)) return false;
        }

        return true;
    }
};

/// Filters actor spawn/despawn events by kind, actor, and tag.
pub const ActorLifecycleFilter = struct {
    kind: ?events2d.EventKind = null,
    actor: ?world2d.ActorId = null,
    tag: ?world2d.ActorTag = null,

    /// Matches all actor lifecycle events.
    pub fn any() ActorLifecycleFilter {
        return .{};
    }

    /// Matches actor spawned events.
    pub fn spawned() ActorLifecycleFilter {
        return .{ .kind = .actor_spawned };
    }

    /// Matches actor despawned events.
    pub fn despawned() ActorLifecycleFilter {
        return .{ .kind = .actor_despawned };
    }

    /// Returns a copy of this filter limited to one actor.
    pub fn withActor(self: ActorLifecycleFilter, actor: world2d.ActorId) ActorLifecycleFilter {
        var next = self;
        next.actor = actor;
        return next;
    }

    /// Returns a copy of this filter limited to one actor tag.
    pub fn withTag(self: ActorLifecycleFilter, tag: world2d.ActorTag) ActorLifecycleFilter {
        var next = self;
        next.tag = tag;
        return next;
    }

    /// Returns true when an event satisfies this filter.
    pub fn matches(self: ActorLifecycleFilter, event: events2d.Event) bool {
        const lifecycle = event.actorLifecycleOrNull() orelse return false;

        if (self.kind) |expected_kind| {
            if (event.kind() != expected_kind) return false;
        }

        if (self.actor) |expected_actor| {
            if (!lifecycle.actor.eql(expected_actor)) return false;
        }

        if (self.tag) |expected_tag| {
            if (!lifecycle.hasTag(expected_tag)) return false;
        }

        return true;
    }
};

/// Lightweight read-only view over scene events.
pub const EventReader = struct {
    events: []const events2d.Event,

    /// Creates an event reader from a slice of events.
    pub fn init(events: []const events2d.Event) EventReader {
        return .{
            .events = events,
        };
    }

    /// Creates an event reader from an event queue.
    pub fn fromQueue(queue: *const events2d.EventQueue) EventReader {
        return init(queue.items());
    }

    /// Returns all events visible to this reader.
    pub fn items(self: EventReader) []const events2d.Event {
        return self.events;
    }

    /// Returns true when there are no events.
    pub fn isEmpty(self: EventReader) bool {
        return self.events.len == 0;
    }

    /// Returns the number of events.
    pub fn count(self: EventReader) usize {
        return self.events.len;
    }

    /// Counts events of one kind.
    pub fn countKind(self: EventReader, kind: events2d.EventKind) usize {
        var total: usize = 0;

        for (self.events) |event| {
            if (event.kind() == kind) total += 1;
        }

        return total;
    }

    /// Returns the first event of one kind.
    pub fn firstKind(self: EventReader, kind: events2d.EventKind) ?events2d.Event {
        for (self.events) |event| {
            if (event.kind() == kind) return event;
        }

        return null;
    }

    /// Counts actor-overlap events matching a filter.
    pub fn countActorOverlaps(self: EventReader, filter: ActorOverlapFilter) usize {
        var total: usize = 0;

        for (self.events) |event| {
            if (filter.matches(event)) total += 1;
        }

        return total;
    }

    /// Returns the first actor-overlap event matching a filter.
    pub fn firstActorOverlap(self: EventReader, filter: ActorOverlapFilter) ?events2d.Event {
        for (self.events) |event| {
            if (filter.matches(event)) return event;
        }

        return null;
    }

    /// Returns true when at least one actor-overlap event matches a filter.
    pub fn hasActorOverlap(self: EventReader, filter: ActorOverlapFilter) bool {
        return self.firstActorOverlap(filter) != null;
    }

    /// Counts actor lifecycle events that match the filter.
    pub fn countActorLifecycle(self: EventReader, filter: ActorLifecycleFilter) usize {
        var total: usize = 0;

        for (self.events) |event| {
            if (filter.matches(event)) total += 1;
        }

        return total;
    }

    /// Returns the first actor lifecycle event that matches the filter.
    pub fn firstActorLifecycle(self: EventReader, filter: ActorLifecycleFilter) ?events2d.Event {
        for (self.events) |event| {
            if (filter.matches(event)) return event;
        }

        return null;
    }

    /// Returns true when any actor lifecycle event matches the filter.
    pub fn hasActorLifecycle(self: EventReader, filter: ActorLifecycleFilter) bool {
        return self.firstActorLifecycle(filter) != null;
    }
};
