//! Picking2D filter and result ordering tests.
//!
//! These tests cover point-picking helpers without keeping test-only snapshot
//! setup in the picking implementation.

const std = @import("std");
const yuki2d = @import("yuki2d.zig");
const actor_view2d = @import("actor_view2d.zig");
const picking2d = @import("picking2d.zig");

const ActorPickFilter = picking2d.ActorPickFilter;
const ActorPickHit = picking2d.ActorPickHit;
const ActorPickResult = picking2d.ActorPickResult;
const ActorSnapshot = actor_view2d.ActorSnapshot;
const Rect2D = yuki2d.Rect2D;
const Vector2 = yuki2d.Vector2;

test "actor pick filter matches point tag layer and exclusion" {
    const actor_id = yuki2d.ActorId{ .index = 1, .generation = 1 };
    const actor_tag = yuki2d.ActorTag.fromIndex(10);

    const actor = snapshot(actor_id, actor_tag, 5);

    try std.testing.expect(ActorPickFilter.all().matches(Vector2.xy(0.0, 0.0), actor));
    try std.testing.expect(ActorPickFilter.all().withTag(actor_tag).matches(Vector2.xy(0.0, 0.0), actor));
    try std.testing.expect(ActorPickFilter.all().withMinLayer(5).matches(Vector2.xy(0.0, 0.0), actor));
    try std.testing.expect(ActorPickFilter.all().withMaxLayer(5).matches(Vector2.xy(0.0, 0.0), actor));
    try std.testing.expect(!ActorPickFilter.all().withoutActor(actor_id).matches(Vector2.xy(0.0, 0.0), actor));
    try std.testing.expect(!ActorPickFilter.all().matches(Vector2.xy(100.0, 0.0), actor));
}

test "actor pick result returns topmost hit" {
    const point = Vector2.xy(0.0, 0.0);
    const tag = yuki2d.ActorTag.fromIndex(1);
    const low = snapshot(.{ .index = 1, .generation = 1 }, tag, 0);
    const high = snapshot(.{ .index = 2, .generation = 1 }, tag, 10);

    var result = ActorPickResult.init();
    try result.add(ActorPickHit.init(point, low));
    try result.add(ActorPickHit.init(point, high));

    const top = result.topmost() orelse return error.ExpectedHit;
    try std.testing.expect(top.actor().eql(high.id));
}

fn snapshot(id: yuki2d.ActorId, tag: yuki2d.ActorTag, layer: i32) ActorSnapshot {
    const point = Vector2.xy(0.0, 0.0);
    const size = Vector2.xy(16.0, 16.0);

    return .{
        .id = id,
        .tag = tag,
        .position = point,
        .size = size,
        .velocity = Vector2.xy(0.0, 0.0),
        .rotation_radians = 0.0,
        .layer = layer,
        .bounds = Rect2D.fromCenterSize(point, size),
    };
}
