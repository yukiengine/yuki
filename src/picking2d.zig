const std = @import("std");
const actor_view2d = @import("actor_view2d.zig");
const render2d = @import("render2d.zig");
const world2d = @import("world2d.zig");

/// Maximum actor pick hits stored by one point query.
pub const max_actor_pick_hits = actor_view2d.max_actor_snapshots;

/// Errors returned by actor picking.
pub const Error = error{
    ActorPickResultFull,
};

/// Filter used by point picking queries.
pub const ActorPickFilter = struct {
    tag: world2d.ActorTag = world2d.ActorTag.none(),
    exclude: world2d.ActorId = world2d.ActorId.invalid(),
    min_layer: ?i32 = null,
    max_layer: ?i32 = null,

    /// Creates a filter that accepts every live actor under the point.
    pub fn all() ActorPickFilter {
        return .{};
    }

    /// Returns a copy that only accepts actors with this tag.
    pub fn withTag(self: ActorPickFilter, tag: world2d.ActorTag) ActorPickFilter {
        std.debug.assert(!tag.isNone());

        var filter = self;
        filter.tag = tag;
        return filter;
    }

    /// Returns a copy that ignores one actor.
    pub fn withoutActor(self: ActorPickFilter, actor: world2d.ActorId) ActorPickFilter {
        var filter = self;
        filter.exclude = actor;
        return filter;
    }

    /// Returns a copy that only accepts actors on or above a layer.
    pub fn withMinLayer(self: ActorPickFilter, layer: i32) ActorPickFilter {
        var filter = self;
        filter.min_layer = layer;
        return filter;
    }

    /// Returns a copy that only accepts actors on or below a layer.
    pub fn withMaxLayer(self: ActorPickFilter, layer: i32) ActorPickFilter {
        var filter = self;
        filter.max_layer = layer;
        return filter;
    }

    /// Returns true when a snapshot can be picked at the point.
    pub fn matches(
        self: ActorPickFilter,
        point: render2d.Vector2,
        snapshot: actor_view2d.ActorSnapshot,
    ) bool {
        if (self.exclude.isValid() and snapshot.hasId(self.exclude)) return false;
        if (!self.tag.isNone() and !snapshot.hasTag(self.tag)) return false;

        if (self.min_layer) |layer| {
            if (snapshot.layer < layer) return false;
        }

        if (self.max_layer) |layer| {
            if (snapshot.layer > layer) return false;
        }

        return snapshot.containsPoint(point);
    }
};

/// One actor hit by a point picking query.
pub const ActorPickHit = struct {
    point: render2d.Vector2,
    snapshot: actor_view2d.ActorSnapshot,

    /// Creates a pick hit from a point and actor snapshot.
    pub fn init(point: render2d.Vector2, snapshot: actor_view2d.ActorSnapshot) ActorPickHit {
        return .{
            .point = point,
            .snapshot = snapshot,
        };
    }

    /// Returns the picked actor id.
    pub fn actor(self: ActorPickHit) world2d.ActorId {
        return self.snapshot.id;
    }

    /// Returns the picked actor tag.
    pub fn tag(self: ActorPickHit) world2d.ActorTag {
        return self.snapshot.tag;
    }

    /// Returns the picked actor layer.
    pub fn layer(self: ActorPickHit) i32 {
        return self.snapshot.layer;
    }

    /// Returns true when this hit should be considered above another hit.
    pub fn isAbove(self: ActorPickHit, other: ActorPickHit) bool {
        if (self.snapshot.layer != other.snapshot.layer) {
            return self.snapshot.layer > other.snapshot.layer;
        }

        if (self.snapshot.id.index != other.snapshot.id.index) {
            return self.snapshot.id.index > other.snapshot.id.index;
        }

        return self.snapshot.id.generation > other.snapshot.id.generation;
    }
};

/// Bounded storage for actor pick hits.
pub const ActorPickResult = struct {
    hits: [max_actor_pick_hits]ActorPickHit,
    hit_count: usize = 0,

    /// Creates an empty pick result.
    pub fn init() ActorPickResult {
        return .{
            .hits = undefined,
        };
    }

    /// Removes all stored hits.
    pub fn clear(self: *ActorPickResult) void {
        self.hit_count = 0;
    }

    /// Adds one pick hit.
    pub fn add(self: *ActorPickResult, hit: ActorPickHit) !void {
        if (self.hit_count == max_actor_pick_hits) {
            return Error.ActorPickResultFull;
        }

        self.hits[self.hit_count] = hit;
        self.hit_count += 1;
    }

    /// Returns stored pick hits.
    pub fn items(self: *const ActorPickResult) []const ActorPickHit {
        return self.hits[0..self.hit_count];
    }

    /// Returns the number of stored hits.
    pub fn count(self: *const ActorPickResult) usize {
        return self.hit_count;
    }

    /// Returns true when no hits were stored.
    pub fn isEmpty(self: *const ActorPickResult) bool {
        return self.hit_count == 0;
    }

    /// Returns the first stored hit.
    pub fn first(self: *const ActorPickResult) ?ActorPickHit {
        if (self.hit_count == 0) return null;
        return self.hits[0];
    }

    /// Returns the highest-layer hit.
    pub fn topmost(self: *const ActorPickResult) ?ActorPickHit {
        if (self.hit_count == 0) return null;

        var best = self.hits[0];

        for (self.items()[1..]) |hit| {
            if (hit.isAbove(best)) best = hit;
        }

        return best;
    }
};

test "actor pick filter matches point tag layer and exclusion" {
    const actor_id = world2d.ActorId{ .index = 1, .generation = 1 };
    const actor_tag = world2d.ActorTag.fromIndex(10);

    const snapshot = actor_view2d.ActorSnapshot{
        .id = actor_id,
        .tag = actor_tag,
        .position = render2d.Vector2.xy(0.0, 0.0),
        .size = render2d.Vector2.xy(16.0, 16.0),
        .velocity = render2d.Vector2.xy(0.0, 0.0),
        .rotation_radians = 0.0,
        .layer = 5,
        .bounds = render2d.Rect2D.fromCenterSize(
            render2d.Vector2.xy(0.0, 0.0),
            render2d.Vector2.xy(16.0, 16.0),
        ),
    };

    try std.testing.expect(ActorPickFilter.all().matches(render2d.Vector2.xy(0.0, 0.0), snapshot));
    try std.testing.expect(ActorPickFilter.all().withTag(actor_tag).matches(render2d.Vector2
        .xy(0.0, 0.0), snapshot));
    try std.testing.expect(ActorPickFilter.all().withMinLayer(5).matches(render2d.Vector2.xy(0.0, 0.0), snapshot));
    try std.testing.expect(ActorPickFilter.all().withMaxLayer(5).matches(render2d.Vector2.xy(0.0, 0.0), snapshot));
    try std.testing.expect(!ActorPickFilter.all().withoutActor(actor_id).matches(render2d.Vector2.xy(0.0, 0.0), snapshot));
    try std.testing.expect(!ActorPickFilter.all().matches(render2d.Vector2.xy(100.0, 0.0), snapshot));
}

test "actor pick result returns topmost hit" {
    const point = render2d.Vector2.xy(0.0, 0.0);

    const low = actor_view2d.ActorSnapshot{
        .id = .{ .index = 1, .generation = 1 },
        .tag = world2d.ActorTag.fromIndex(1),
        .position = point,
        .size = render2d.Vector2.xy(16.0, 16.0),
        .velocity = render2d.Vector2.xy(0.0, 0.0),
        .rotation_radians = 0.0,
        .layer = 0,
        .bounds = render2d.Rect2D.fromCenterSize(point, render2d.Vector2.xy(16.0, 16.0)),
    };

    const high = actor_view2d.ActorSnapshot{
        .id = .{ .index = 2, .generation = 1 },
        .tag = world2d.ActorTag.fromIndex(1),
        .position = point,
        .size = render2d.Vector2.xy(16.0, 16.0),
        .velocity = render2d.Vector2.xy(0.0, 0.0),
        .rotation_radians = 0.0,
        .layer = 10,
        .bounds = render2d.Rect2D.fromCenterSize(point, render2d.Vector2.xy(16.0, 16.0)),
    };

    var result = ActorPickResult.init();
    try result.add(ActorPickHit.init(point, low));
    try result.add(ActorPickHit.init(point, high));

    const top = result.topmost() orelse return error.ExpectedHit;
    try std.testing.expect(top.actor().eql(high.id));
}
