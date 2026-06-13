const std = @import("std");
const render2d = @import("render2d.zig");
const world2d = @import("world2d.zig");

/// Maximum number of actor prefabs stored in one catalog.
pub const max_prefabs = 64;

/// Public actor tag type used by prefabs.
pub const ActorTag = world2d.ActorTag;

/// Errors returned by the prefab catalog.
pub const Error = world2d.Error || error{
    PrefabCatalogFull,
    UnknownPrefab,
};

/// Stable handle to a prefab catalog entry.
pub const PrefabId = extern struct {
    index: u16,

    /// Creates a prefab handle from a catalog index.
    pub fn fromIndex(index: u16) PrefabId {
        std.debug.assert(index < max_prefabs);
        return .{ .index = index };
    }

    /// Returns an invalid prefab handle.
    pub fn invalid() PrefabId {
        return .{ .index = std.math.maxInt(u16) };
    }

    /// Returns true when the handle can point into a prefab catalog.
    pub fn isValid(self: PrefabId) bool {
        return self.index < max_prefabs;
    }
};

/// Optional per-spawn values that override prefab defaults.
pub const SpawnOverride = struct {
    position: ?render2d.Vector2 = null,
    size: ?render2d.Vector2 = null,
    sprite: ?render2d.Sprite = null,
    animation: ?render2d.SpriteAnimation = null,
    rotation_radians: ?f32 = null,
    layer: ?i32 = null,
    tag: ?ActorTag = null,
};

/// Reusable actor template used to spawn actors into a world.
pub const ActorPrefab = struct {
    name: [:0]const u8,
    size: render2d.Vector2,
    sprite: render2d.Sprite = .{},
    animation: ?render2d.SpriteAnimation = null,
    rotation_radians: f32 = 0.0,
    layer: i32 = 0,
    tag: ActorTag = ActorTag.none(),

    /// Builds a plain actor spawn descriptor from this prefab.
    pub fn actorDesc(self: ActorPrefab, spawn_override: SpawnOverride) world2d.ActorDesc {
        const position = spawn_override.position orelse render2d.Vector2.xy(0.0, 0.0);
        const size = spawn_override.size orelse self.size;
        const sprite = spawn_override.sprite orelse self.sprite;
        const animation = spawn_override.animation orelse self.animation;
        const rotation_radians = spawn_override.rotation_radians orelse self.rotation_radians;
        const layer = spawn_override.layer orelse self.layer;
        const tag = spawn_override.tag orelse self.tag;

        std.debug.assert(size.x > 0.0);
        std.debug.assert(size.y > 0.0);

        return .{
            .position = position,
            .size = size,
            .sprite = sprite,
            .animation = animation,
            .rotation_radians = rotation_radians,
            .layer = layer,
            .tag = tag,
        };
    }

    /// Spawns this prefab into a world.
    pub fn spawn(
        self: ActorPrefab,
        world: *world2d.World,
        spawn_override: SpawnOverride,
    ) !world2d.ActorId {
        return world.spawn(self.actorDesc(spawn_override));
    }
};

/// Fixed-capacity registry of 2D actor prefabs.
pub const PrefabCatalog = struct {
    prefabs: [max_prefabs]ActorPrefab,
    prefab_count: usize,

    /// Creates an empty prefab catalog.
    pub fn init() PrefabCatalog {
        return .{
            .prefabs = undefined,
            .prefab_count = 0,
        };
    }

    /// Returns the number of registered prefabs.
    pub fn count(self: *const PrefabCatalog) usize {
        return self.prefab_count;
    }

    /// Adds a prefab and returns its handle.
    pub fn add(self: *PrefabCatalog, prefab: ActorPrefab) !PrefabId {
        std.debug.assert(prefab.size.x > 0.0);
        std.debug.assert(prefab.size.y > 0.0);

        if (self.prefab_count == max_prefabs) {
            return Error.PrefabCatalogFull;
        }

        const id = PrefabId.fromIndex(@intCast(self.prefab_count));
        self.prefabs[self.prefab_count] = prefab;
        self.prefab_count += 1;

        return id;
    }

    /// Returns a prefab by handle.
    pub fn get(self: *const PrefabCatalog, id: PrefabId) ActorPrefab {
        const index = prefabIndex(id);
        std.debug.assert(index < self.prefab_count);

        return self.prefabs[index];
    }

    /// Finds a prefab by name.
    pub fn findByName(self: *const PrefabCatalog, name: []const u8) ?PrefabId {
        var index: usize = 0;
        while (index < self.prefab_count) : (index += 1) {
            if (std.mem.eql(u8, self.prefabs[index].name, name)) {
                return PrefabId.fromIndex(@intCast(index));
            }
        }

        return null;
    }

    /// Returns true when a prefab with this name exists.
    pub fn containsName(self: *const PrefabCatalog, name: []const u8) bool {
        return self.findByName(name) != null;
    }

    /// Spawns a prefab by handle.
    pub fn spawn(
        self: *const PrefabCatalog,
        id: PrefabId,
        world: *world2d.World,
        spawn_override: SpawnOverride,
    ) !world2d.ActorId {
        return try self.get(id).spawn(world, spawn_override);
    }

    /// Spawns a prefab by name.
    pub fn spawnByName(
        self: *const PrefabCatalog,
        name: []const u8,
        world: *world2d.World,
        spawn_override: SpawnOverride,
    ) !world2d.ActorId {
        const id = self.findByName(name) orelse return Error.UnknownPrefab;
        return try self.spawn(id, world, spawn_override);
    }
};

/// Converts a prefab handle into an array index.
fn prefabIndex(id: PrefabId) usize {
    std.debug.assert(id.isValid());
    return @intCast(id.index);
}
