const std = @import("std");
const render2d = @import("render2d/renderer.zig");
const world2d = @import("world2d.zig");

/// Maximum actor snapshots that can be collected in one query.
pub const max_actor_snapshots = world2d.max_actors;

/// Errors returned by actor snapshot collection.
pub const Error = error{
    ActorSnapshotListFull,
};

/// Read-only value copy of the public actor state.
pub const ActorSnapshot = struct {
    id: world2d.ActorId,
    tag: world2d.ActorTag,
    position: render2d.Vector2,
    size: render2d.Vector2,
    velocity: render2d.Vector2,
    rotation_radians: f32,
    layer: i32,
    bounds: render2d.Rect2D,

    /// Creates a snapshot from a live actor.
    pub fn fromActor(id: world2d.ActorId, actor: *const world2d.Actor) ActorSnapshot {
        std.debug.assert(actor.active);

        return .{
            .id = id,
            .tag = actor.tag,
            .position = actor.position,
            .size = actor.size,
            .velocity = actor.velocity,
            .rotation_radians = actor.rotation_radians,
            .layer = actor.layer,
            .bounds = actor.bounds(),
        };
    }

    /// Returns true when this snapshot has the tag.
    pub fn hasTag(self: ActorSnapshot, tag: world2d.ActorTag) bool {
        return self.tag.eql(tag);
    }

    /// Returns true when this snapshot has the actor id.
    pub fn hasId(self: ActorSnapshot, id: world2d.ActorId) bool {
        return self.id.eql(id);
    }

    /// Returns true when this snapshot intersects a rectangle.
    pub fn intersects(self: ActorSnapshot, rect: render2d.Rect2D) bool {
        return self.bounds.intersects(rect);
    }

    /// Returns true when this snapshot contains a point.
    pub fn containsPoint(self: ActorSnapshot, point: render2d.Vector2) bool {
        return self.bounds.containsPoint(point);
    }
};

/// Filter used to collect actor snapshots.
pub const ActorSnapshotFilter = struct {
    tag: world2d.ActorTag = world2d.ActorTag.none(),
    rect: ?render2d.Rect2D = null,
    exclude: world2d.ActorId = world2d.ActorId.invalid(),

    /// Creates a filter that accepts every live actor.
    pub fn all() ActorSnapshotFilter {
        return .{};
    }

    /// Returns a copy that only accepts actors with a tag.
    pub fn withTag(self: ActorSnapshotFilter, tag: world2d.ActorTag) ActorSnapshotFilter {
        std.debug.assert(!tag.isNone());

        var filter = self;
        filter.tag = tag;
        return filter;
    }

    /// Returns a copy that only accepts actors intersecting a rectangle.
    pub fn inRect(self: ActorSnapshotFilter, rect: render2d.Rect2D) ActorSnapshotFilter {
        var filter = self;
        filter.rect = rect;
        return filter;
    }

    /// Returns a copy that ignores one actor.
    pub fn withoutActor(self: ActorSnapshotFilter, id: world2d.ActorId) ActorSnapshotFilter {
        var filter = self;
        filter.exclude = id;
        return filter;
    }

    /// Returns true when a snapshot satisfies this filter.
    pub fn matches(self: ActorSnapshotFilter, snapshot: ActorSnapshot) bool {
        if (self.exclude.isValid() and snapshot.hasId(self.exclude)) return false;
        if (!self.tag.isNone() and !snapshot.hasTag(self.tag)) return false;

        if (self.rect) |rect| {
            if (!snapshot.intersects(rect)) return false;
        }

        return true;
    }
};

/// Bounded actor snapshot result storage.
pub const ActorSnapshotList = struct {
    snapshots: [max_actor_snapshots]ActorSnapshot,
    snapshot_count: usize = 0,

    /// Creates an empty snapshot list.
    pub fn init() ActorSnapshotList {
        return .{
            .snapshots = undefined,
        };
    }

    /// Removes all stored snapshots.
    pub fn clear(self: *ActorSnapshotList) void {
        self.snapshot_count = 0;
    }

    /// Adds one snapshot.
    pub fn add(self: *ActorSnapshotList, snapshot: ActorSnapshot) !void {
        if (self.snapshot_count == max_actor_snapshots) {
            return Error.ActorSnapshotListFull;
        }

        self.snapshots[self.snapshot_count] = snapshot;
        self.snapshot_count += 1;
    }

    /// Returns stored snapshots.
    pub fn items(self: *const ActorSnapshotList) []const ActorSnapshot {
        return self.snapshots[0..self.snapshot_count];
    }

    /// Returns the number of stored snapshots.
    pub fn count(self: *const ActorSnapshotList) usize {
        return self.snapshot_count;
    }

    /// Returns true when no snapshots were stored.
    pub fn isEmpty(self: *const ActorSnapshotList) bool {
        return self.snapshot_count == 0;
    }

    /// Returns the first stored snapshot.
    pub fn first(self: *const ActorSnapshotList) ?ActorSnapshot {
        if (self.snapshot_count == 0) return null;
        return self.snapshots[0];
    }

    /// Counts snapshots with a tag.
    pub fn countByTag(self: *const ActorSnapshotList, tag: world2d.ActorTag) usize {
        var total: usize = 0;

        for (self.items()) |snapshot| {
            if (snapshot.hasTag(tag)) total += 1;
        }

        return total;
    }

    /// Returns the first snapshot with a tag.
    pub fn firstByTag(self: *const ActorSnapshotList, tag: world2d.ActorTag) ?ActorSnapshot {
        for (self.items()) |snapshot| {
            if (snapshot.hasTag(tag)) return snapshot;
        }

        return null;
    }
};

test "actor snapshot copies live actor state" {
    const actor_id = world2d.ActorId{ .index = 3, .generation = 2 };
    const actor_tag = world2d.ActorTag.fromIndex(10);

    var actor = world2d.Actor.empty();
    actor.active = true;
    actor.generation = actor_id.generation;
    actor.position = render2d.Vector2.xy(12.0, 24.0);
    actor.size = render2d.Vector2.xy(32.0, 48.0);
    actor.velocity = render2d.Vector2.xy(4.0, -8.0);
    actor.rotation_radians = 1.5;
    actor.layer = 7;
    actor.tag = actor_tag;

    const snapshot = ActorSnapshot.fromActor(actor_id, &actor);

    try std.testing.expect(snapshot.hasId(actor_id));
    try std.testing.expect(snapshot.hasTag(actor_tag));
    try std.testing.expectEqual(@as(f32, 12.0), snapshot.position.x);
    try std.testing.expectEqual(@as(f32, 24.0), snapshot.position.y);
    try std.testing.expectEqual(@as(f32, 32.0), snapshot.size.x);
    try std.testing.expectEqual(@as(f32, 48.0), snapshot.size.y);
    try std.testing.expectEqual(@as(i32, 7), snapshot.layer);
}

test "actor snapshot filter matches tag rect and exclusion" {
    const actor_id = world2d.ActorId{ .index = 1, .generation = 1 };
    const actor_tag = world2d.ActorTag.fromIndex(20);

    const snapshot = ActorSnapshot{
        .id = actor_id,
        .tag = actor_tag,
        .position = render2d.Vector2.xy(0.0, 0.0),
        .size = render2d.Vector2.xy(16.0, 16.0),
        .velocity = render2d.Vector2.xy(0.0, 0.0),
        .rotation_radians = 0.0,
        .layer = 0,
        .bounds = render2d.Rect2D.fromCenterSize(
            render2d.Vector2.xy(0.0, 0.0),
            render2d.Vector2.xy(16.0, 16.0),
        ),
    };

    const visible = render2d.Rect2D.fromCenterSize(
        render2d.Vector2.xy(4.0, 0.0),
        render2d.Vector2.xy(16.0, 16.0),
    );

    try std.testing.expect(ActorSnapshotFilter.all().matches(snapshot));
    try std.testing.expect(ActorSnapshotFilter.all().withTag(actor_tag).matches(snapshot));
    try std.testing.expect(ActorSnapshotFilter.all().inRect(visible).matches(snapshot));
    try std.testing.expect(!ActorSnapshotFilter.all().withoutActor(actor_id).matches(snapshot));
}
