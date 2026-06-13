//! ActorView2D snapshot behavior tests.
//!
//! These tests cover read-only actor snapshot values and filters outside the
//! runtime snapshot module.

const std = @import("std");
const yuki2d = @import("yuki2d.zig");
const world2d = @import("world2d.zig");
const actor_view2d = @import("actor_view2d.zig");

const ActorSnapshot = actor_view2d.ActorSnapshot;
const ActorSnapshotFilter = actor_view2d.ActorSnapshotFilter;
const Rect2D = yuki2d.Rect2D;
const Vector2 = yuki2d.Vector2;

test "actor snapshot copies live actor state" {
    const actor_id = yuki2d.ActorId{ .index = 3, .generation = 2 };
    const actor_tag = yuki2d.ActorTag.fromIndex(10);

    var actor = world2d.Actor.empty();
    actor.active = true;
    actor.generation = actor_id.generation;
    actor.position = Vector2.xy(12.0, 24.0);
    actor.size = Vector2.xy(32.0, 48.0);
    actor.velocity = Vector2.xy(4.0, -8.0);
    actor.rotation_radians = 1.5;
    actor.layer = 7;
    actor.tag = actor_tag;

    const snapshot_value = ActorSnapshot.fromActor(actor_id, &actor);

    try std.testing.expect(snapshot_value.hasId(actor_id));
    try std.testing.expect(snapshot_value.hasTag(actor_tag));
    try std.testing.expectEqual(@as(f32, 12.0), snapshot_value.position.x);
    try std.testing.expectEqual(@as(f32, 24.0), snapshot_value.position.y);
    try std.testing.expectEqual(@as(f32, 32.0), snapshot_value.size.x);
    try std.testing.expectEqual(@as(f32, 48.0), snapshot_value.size.y);
    try std.testing.expectEqual(@as(i32, 7), snapshot_value.layer);
}

test "actor snapshot filter matches tag rect and exclusion" {
    const actor_id = yuki2d.ActorId{ .index = 1, .generation = 1 };
    const actor_tag = yuki2d.ActorTag.fromIndex(20);
    const snapshot_value = actorSnapshot(actor_id, actor_tag);
    const visible = Rect2D.fromCenterSize(
        Vector2.xy(4.0, 0.0),
        Vector2.xy(16.0, 16.0),
    );

    try std.testing.expect(ActorSnapshotFilter.all().matches(snapshot_value));
    try std.testing.expect(ActorSnapshotFilter.all().withTag(actor_tag).matches(snapshot_value));
    try std.testing.expect(ActorSnapshotFilter.all().inRect(visible).matches(snapshot_value));
    try std.testing.expect(!ActorSnapshotFilter.all().withoutActor(actor_id).matches(snapshot_value));
}

fn actorSnapshot(id: yuki2d.ActorId, tag: yuki2d.ActorTag) ActorSnapshot {
    const point = Vector2.xy(0.0, 0.0);
    const size = Vector2.xy(16.0, 16.0);

    return .{
        .id = id,
        .tag = tag,
        .position = point,
        .size = size,
        .velocity = Vector2.xy(0.0, 0.0),
        .rotation_radians = 0.0,
        .layer = 0,
        .bounds = Rect2D.fromCenterSize(point, size),
    };
}
