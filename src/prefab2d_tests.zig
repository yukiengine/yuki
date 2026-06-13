//! Prefab2D catalog and spawn behavior tests.
//!
//! These tests keep prefab registration and spawn override behavior covered
//! while the runtime module stays focused on the API itself.

const std = @import("std");
const render2d = @import("render2d.zig");
const world2d = @import("world2d.zig");
const prefab2d = @import("prefab2d.zig");

const ActorTag = prefab2d.ActorTag;
const Error = prefab2d.Error;
const PrefabCatalog = prefab2d.PrefabCatalog;
const Vector2 = render2d.Vector2;
const max_prefabs = prefab2d.max_prefabs;

test "catalog adds and retrieves a prefab" {
    var catalog = PrefabCatalog.init();

    const id = try catalog.add(.{
        .name = "test.actor",
        .size = Vector2.xy(16.0, 24.0),
        .layer = 7,
    });

    const prefab = catalog.get(id);

    try std.testing.expectEqual(@as(usize, 1), catalog.count());
    try std.testing.expectEqualStrings("test.actor", prefab.name);
    try std.testing.expectEqual(@as(f32, 16.0), prefab.size.x);
    try std.testing.expectEqual(@as(f32, 24.0), prefab.size.y);
    try std.testing.expectEqual(@as(i32, 7), prefab.layer);
}

test "catalog finds prefabs by name" {
    var catalog = PrefabCatalog.init();

    const player = try catalog.add(.{
        .name = "demo.player",
        .size = Vector2.xy(32.0, 32.0),
    });

    _ = try catalog.add(.{
        .name = "demo.marker",
        .size = Vector2.xy(12.0, 12.0),
    });

    try std.testing.expectEqual(player.index, catalog.findByName("demo.player").?.index);
    try std.testing.expect(catalog.containsName("demo.marker"));
    try std.testing.expect(catalog.findByName("missing") == null);
}

test "prefab spawn applies overrides" {
    var catalog = PrefabCatalog.init();
    var world = world2d.World.init();

    const id = try catalog.add(.{
        .name = "test.spawn",
        .size = Vector2.xy(10.0, 20.0),
        .layer = 3,
    });

    const actor_id = try catalog.spawn(id, &world, .{
        .position = Vector2.xy(50.0, 70.0),
        .size = Vector2.xy(30.0, 40.0),
        .layer = 9,
    });

    const actor = world.get(actor_id).?;

    try std.testing.expectEqual(@as(f32, 50.0), actor.position.x);
    try std.testing.expectEqual(@as(f32, 70.0), actor.position.y);
    try std.testing.expectEqual(@as(f32, 30.0), actor.size.x);
    try std.testing.expectEqual(@as(f32, 40.0), actor.size.y);
    try std.testing.expectEqual(@as(i32, 9), actor.layer);
}

test "spawn by name reports unknown prefab" {
    const catalog = PrefabCatalog.init();
    var world = world2d.World.init();

    try std.testing.expectError(
        Error.UnknownPrefab,
        catalog.spawnByName("missing", &world, .{}),
    );
}

test "catalog reports full capacity" {
    var catalog = PrefabCatalog.init();

    var index: usize = 0;
    while (index < max_prefabs) : (index += 1) {
        _ = try catalog.add(.{
            .name = "same.name.ok.for.now",
            .size = Vector2.xy(1.0, 1.0),
        });
    }

    try std.testing.expectError(
        Error.PrefabCatalogFull,
        catalog.add(.{
            .name = "too.many",
            .size = Vector2.xy(1.0, 1.0),
        }),
    );
}

test "prefab spawn applies tag override" {
    const default_tag = ActorTag.fromIndex(1);
    const override_tag = ActorTag.fromIndex(2);

    var catalog = PrefabCatalog.init();
    var world = world2d.World.init();

    const id = try catalog.add(.{
        .name = "tagged.actor",
        .size = Vector2.xy(10.0, 10.0),
        .tag = default_tag,
    });

    const actor_id = try catalog.spawn(id, &world, .{
        .tag = override_tag,
    });

    const actor = world.get(actor_id).?;

    try std.testing.expect(actor.hasTag(override_tag));
    try std.testing.expect(!actor.hasTag(default_tag));
}
