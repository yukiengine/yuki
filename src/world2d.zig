const std = @import("std");
const render2d = @import("render2d.zig");
const tilemap = @import("tilemap.zig");

/// Maximum number of actors stored in one 2D world.
pub const max_actors = 128;

/// Errors returned by the fixed actor table.
pub const Error = error{
    ActorTableFull,
    ActorQueryFull,
};

/// Generation-checked handle for an actor slot.
pub const ActorId = extern struct {
    index: u16,
    generation: u16,

    /// Returns an invalid actor handle.
    pub fn invalid() ActorId {
        return .{
            .index = std.math.maxInt(u16),
            .generation = 0,
        };
    }

    /// Returns true when the handle can refer to a live actor.
    pub fn isValid(self: ActorId) bool {
        return self.generation != 0;
    }

    /// Returns true when two actor handles identify the same generation.
    pub fn eql(self: ActorId, other: ActorId) bool {
        return self.index == other.index and self.generation == other.generation;
    }
};

/// Lightweight category value used to query actors.
pub const ActorTag = extern struct {
    index: u16,

    /// Returns the empty tag used for untagged actors.
    pub fn none() ActorTag {
        return .{ .index = 0 };
    }

    /// Creates a non-empty actor tag.
    pub fn fromIndex(index: u16) ActorTag {
        std.debug.assert(index != 0);
        return .{ .index = index };
    }

    /// Returns true when this is the empty tag.
    pub fn isNone(self: ActorTag) bool {
        return self.index == 0;
    }

    /// Returns true when two tags are identical.
    pub fn eql(self: ActorTag, other: ActorTag) bool {
        return self.index == other.index;
    }
};

/// Maximum number of actor hits that a bounded overlap query can store.
pub const max_actor_query_hits = 32;

/// Result item for an actor overlap query.
pub const ActorHit = struct {
    id: ActorId,
    tag: ActorTag,
    bounds: render2d.Rect2D,
};

/// Filter used to query actors by rectangle, tag, and optional exclusion.
pub const ActorQuery = struct {
    rect: render2d.Rect2D,
    tag: ActorTag = ActorTag.none(),
    exclude: ActorId = ActorId.invalid(),

    /// Creates a query that accepts any actor intersecting a rectangle.
    pub fn all(rect: render2d.Rect2D) ActorQuery {
        return .{ .rect = rect };
    }

    /// Returns a copy that only accepts actors with a tag.
    pub fn withTag(self: ActorQuery, tag: ActorTag) ActorQuery {
        std.debug.assert(!tag.isNone());

        var query = self;
        query.tag = tag;
        return query;
    }

    /// Returns a copy that ignores one actor handle.
    pub fn withoutActor(self: ActorQuery, id: ActorId) ActorQuery {
        var query = self;
        query.exclude = id;
        return query;
    }

    /// Returns true when an actor satisfies this query.
    pub fn matches(self: ActorQuery, id: ActorId, actor: *const Actor) bool {
        if (self.exclude.isValid() and id.eql(self.exclude)) return false;
        if (!self.tag.isNone() and !actor.hasTag(self.tag)) return false;

        return actor.bounds().intersects(self.rect);
    }
};

/// Bounded storage for actor overlap query results.
pub const ActorQueryResult = struct {
    hits: [max_actor_query_hits]ActorHit,
    hit_count: usize = 0,

    /// Creates an empty query result.
    pub fn init() ActorQueryResult {
        return .{
            .hits = undefined,
        };
    }

    /// Adds one actor hit to the result.
    pub fn add(self: *ActorQueryResult, hit: ActorHit) !void {
        if (self.hit_count == max_actor_query_hits) {
            return Error.ActorQueryFull;
        }

        self.hits[self.hit_count] = hit;
        self.hit_count += 1;
    }

    /// Returns the recorded hits.
    pub fn items(self: *const ActorQueryResult) []const ActorHit {
        return self.hits[0..self.hit_count];
    }

    /// Returns true when no hits were recorded.
    pub fn isEmpty(self: *const ActorQueryResult) bool {
        return self.hit_count == 0;
    }
};

/// Data used when spawning an actor.
pub const ActorDesc = struct {
    position: render2d.Vector2 = .{ .x = 0.0, .y = 0.0 },
    size: render2d.Vector2 = .{ .x = 1.0, .y = 1.0 },
    sprite: render2d.Sprite = .{},
    animation: ?render2d.SpriteAnimation = null,
    rotation_radians: f32 = 0.0,
    layer: i32 = 0,
    tag: ActorTag = ActorTag.none(),
};

/// Basic renderable 2D object.
pub const Actor = struct {
    active: bool = false,
    generation: u16 = 1,

    position: render2d.Vector2 = .{ .x = 0.0, .y = 0.0 },
    size: render2d.Vector2 = .{ .x = 1.0, .y = 1.0 },
    velocity: render2d.Vector2 = .{ .x = 0.0, .y = 0.0 },
    rotation_radians: f32 = 0.0,
    layer: i32 = 0,

    static_sprite: render2d.Sprite = .{},
    animation_player: ?render2d.AnimationPlayer = null,

    tag: ActorTag = ActorTag.none(),

    /// Returns an inactive actor slot.
    pub fn empty() Actor {
        return .{};
    }

    /// Returns the current axis-aligned bounds of the actor.
    pub fn bounds(self: *const Actor) render2d.Rect2D {
        return render2d.Rect2D.fromCenterSize(self.position, self.size);
    }

    /// Returns the transform used by the renderer.
    pub fn transform(self: *const Actor) render2d.Transform2D {
        return render2d.Transform2D.rotated(
            self.position,
            self.size,
            self.rotation_radians,
        );
    }

    /// Returns the sprite for the current animation frame or the static sprite.
    pub fn currentSprite(self: *const Actor) render2d.Sprite {
        if (self.animation_player) |player| {
            return player.sprite();
        }

        return self.static_sprite;
    }

    /// Advances the actor animation if it has one.
    pub fn updateAnimation(self: *Actor, dt_seconds: f32) void {
        if (self.animation_player) |*player| {
            player.update(dt_seconds);
        }
    }

    /// Moves the actor without collision.
    pub fn moveBy(self: *Actor, delta: render2d.Vector2) void {
        self.position.x += delta.x;
        self.position.y += delta.y;
    }

    /// Moves the actor using tilemap AABB collision.
    pub fn moveWithTilemap(
        self: *Actor,
        map: tilemap.Tilemap,
        rules: tilemap.TileRules,
        origin: render2d.Vector2,
        delta: render2d.Vector2,
    ) tilemap.MoveResult {
        const result = map.moveAabb(
            rules,
            origin,
            self.position,
            self.size,
            delta,
        );

        self.position = result.position;
        return result;
    }

    /// Draws the actor into a draw list.
    pub fn draw(self: *const Actor, draw_list: *render2d.DrawList) !void {
        if (!self.active) return;

        try draw_list.drawSpriteTransformLayer(
            self.transform(),
            self.currentSprite(),
            self.layer,
        );
    }

    /// Adds to the actor rotation and wraps around tau.
    pub fn rotateBy(self: *Actor, radians: f32) void {
        self.rotation_radians += radians;

        while (self.rotation_radians >= std.math.tau) {
            self.rotation_radians -= std.math.tau;
        }

        while (self.rotation_radians < 0.0) {
            self.rotation_radians += std.math.tau;
        }
    }

    /// Resets the actor animation to the first frame.
    pub fn resetAnimation(self: *Actor) void {
        if (self.animation_player) |*player| {
            player.reset();
        }
    }

    /// Toggles the actor animation between playing and paused.
    pub fn toggleAnimation(self: *Actor) void {
        if (self.animation_player) |*player| {
            player.toggle();
        }
    }

    /// Returns true when the actor has this tag.
    pub fn hasTag(self: *const Actor, tag: ActorTag) bool {
        return self.tag.eql(tag);
    }

    /// Replaces the actor tag.
    pub fn setTag(self: *Actor, tag: ActorTag) void {
        self.tag = tag;
    }
};

/// Fixed-capacity 2D actor container.
pub const World = struct {
    actors: [max_actors]Actor,

    /// Creates an empty world.
    pub fn init() World {
        var actors: [max_actors]Actor = undefined;

        for (&actors) |*actor| {
            actor.* = Actor.empty();
        }

        return .{
            .actors = actors,
        };
    }

    /// Spawns an actor and returns its handle.
    pub fn spawn(self: *World, desc: ActorDesc) !ActorId {
        std.debug.assert(desc.size.x > 0.0);
        std.debug.assert(desc.size.y > 0.0);

        const slot = try self.reserveSlot();

        var actor = Actor.empty();
        actor.active = true;
        actor.generation = self.actors[slot].generation;
        actor.position = desc.position;
        actor.size = desc.size;
        actor.static_sprite = desc.sprite;
        actor.rotation_radians = desc.rotation_radians;
        actor.layer = desc.layer;
        actor.tag = desc.tag;

        if (desc.animation) |animation| {
            actor.animation_player = render2d.AnimationPlayer.init(animation);
        }

        self.actors[slot] = actor;

        return .{
            .index = @intCast(slot),
            .generation = actor.generation,
        };
    }

    /// Despawns an actor and invalidates old handles for that slot.
    pub fn despawn(self: *World, id: ActorId) void {
        if (self.get(id)) |actor| {
            const generation = nextGeneration(actor.generation);

            actor.* = Actor.empty();
            actor.generation = generation;
        }
    }

    /// Returns a mutable actor pointer for a valid handle.
    pub fn get(self: *World, id: ActorId) ?*Actor {
        const index: usize = @intCast(id.index);
        if (index >= max_actors) return null;

        const actor = &self.actors[index];
        if (!actor.active) return null;
        if (actor.generation != id.generation) return null;

        return actor;
    }

    /// Returns a const actor pointer for a valid handle.
    pub fn getConst(self: *const World, id: ActorId) ?*const Actor {
        const index: usize = @intCast(id.index);
        if (index >= max_actors) return null;

        const actor = &self.actors[index];
        if (!actor.active) return null;
        if (actor.generation != id.generation) return null;

        return actor;
    }

    /// Sets an actor velocity.
    pub fn setVelocity(self: *World, id: ActorId, velocity: render2d.Vector2) void {
        const actor = self.get(id) orelse unreachable;
        actor.velocity = velocity;
    }

    /// Moves an actor without collision.
    pub fn moveActor(self: *World, id: ActorId, delta: render2d.Vector2) void {
        const actor = self.get(id) orelse unreachable;
        actor.moveBy(delta);
    }

    /// Moves an actor using tilemap AABB collision.
    pub fn moveActorWithTilemap(
        self: *World,
        id: ActorId,
        map: tilemap.Tilemap,
        rules: tilemap.TileRules,
        origin: render2d.Vector2,
        delta: render2d.Vector2,
    ) tilemap.MoveResult {
        const actor = self.get(id) orelse unreachable;
        return actor.moveWithTilemap(map, rules, origin, delta);
    }

    /// Advances animations for all live actors.
    pub fn updateAnimations(self: *World, dt_seconds: f32) void {
        for (&self.actors) |*actor| {
            if (!actor.active) continue;
            actor.updateAnimation(dt_seconds);
        }
    }

    /// Draws all live actors.
    pub fn draw(self: *const World, draw_list: *render2d.DrawList) !void {
        for (&self.actors) |*actor| {
            if (!actor.active) continue;
            try actor.draw(draw_list);
        }
    }

    /// Draws live actors that intersect the visible world rectangle.
    pub fn drawVisible(
        self: *const World,
        draw_list: *render2d.DrawList,
        visible_world: render2d.Rect2D,
    ) !void {
        for (&self.actors) |*actor| {
            if (!actor.active) continue;
            if (!actor.bounds().intersects(visible_world)) continue;

            try actor.draw(draw_list);
        }
    }

    /// Finds a free actor slot.
    fn reserveSlot(self: *World) !usize {
        var index: usize = 0;
        while (index < max_actors) : (index += 1) {
            if (!self.actors[index].active) return index;
        }

        return Error.ActorTableFull;
    }

    /// Sets the tag for a live actor.
    pub fn setActorTag(self: *World, id: ActorId, tag: ActorTag) void {
        const actor = self.get(id) orelse unreachable;
        actor.setTag(tag);
    }

    /// Finds the first live actor with a tag.
    pub fn findFirstByTag(self: *const World, tag: ActorTag) ?ActorId {
        std.debug.assert(!tag.isNone());

        var index: usize = 0;
        while (index < max_actors) : (index += 1) {
            const actor = self.actors[index];
            if (!actor.active) continue;
            if (!actor.hasTag(tag)) continue;

            return self.idForIndex(index);
        }

        return null;
    }

    /// Counts live actors with a tag.
    pub fn countByTag(self: *const World, tag: ActorTag) usize {
        std.debug.assert(!tag.isNone());

        var count: usize = 0;
        var index: usize = 0;

        while (index < max_actors) : (index += 1) {
            const actor = self.actors[index];
            if (!actor.active) continue;
            if (!actor.hasTag(tag)) continue;

            count += 1;
        }

        return count;
    }

    /// Despawns every live actor with a tag.
    pub fn despawnByTag(self: *World, tag: ActorTag) usize {
        std.debug.assert(!tag.isNone());

        var removed: usize = 0;
        var index: usize = 0;

        while (index < max_actors) : (index += 1) {
            const actor = self.actors[index];
            if (!actor.active) continue;
            if (!actor.hasTag(tag)) continue;

            self.despawn(self.idForIndex(index));
            removed += 1;
        }

        return removed;
    }

    /// Draws visible live actors that have a tag.
    pub fn drawVisibleByTag(
        self: *const World,
        draw_list: *render2d.DrawList,
        visible_world: render2d.Rect2D,
        tag: ActorTag,
    ) !void {
        std.debug.assert(!tag.isNone());

        var index: usize = 0;
        while (index < max_actors) : (index += 1) {
            const actor = &self.actors[index];
            if (!actor.active) continue;
            if (!actor.hasTag(tag)) continue;
            if (!actor.bounds().intersects(visible_world)) continue;

            try actor.draw(draw_list);
        }
    }

    /// Returns the current handle for a live actor slot.
    fn idForIndex(self: *const World, index: usize) ActorId {
        std.debug.assert(index < max_actors);

        return .{
            .index = @intCast(index),
            .generation = self.actors[index].generation,
        };
    }

    /// Returns the first actor that matches an overlap query.
    pub fn firstActorInRect(self: *const World, query: ActorQuery) ?ActorHit {
        var index: usize = 0;
        while (index < max_actors) : (index += 1) {
            const actor = &self.actors[index];
            if (!actor.active) continue;

            const id = self.idForIndex(index);
            if (!query.matches(id, actor)) continue;

            return self.hitForIndex(index);
        }

        return null;
    }

    /// Writes all actors matching an overlap query into a bounded result.
    pub fn collectActorsInRect(
        self: *const World,
        query: ActorQuery,
        result: *ActorQueryResult,
    ) !void {
        var index: usize = 0;
        while (index < max_actors) : (index += 1) {
            const actor = &self.actors[index];
            if (!actor.active) continue;

            const id = self.idForIndex(index);
            if (!query.matches(id, actor)) continue;

            try result.add(self.hitForIndex(index));
        }
    }

    /// Counts live actors matching an overlap query.
    pub fn countActorsInRect(self: *const World, query: ActorQuery) usize {
        var count: usize = 0;

        var index: usize = 0;
        while (index < max_actors) : (index += 1) {
            const actor = &self.actors[index];
            if (!actor.active) continue;

            const id = self.idForIndex(index);
            if (!query.matches(id, actor)) continue;

            count += 1;
        }

        return count;
    }

    /// Returns the first actor overlapping another actor.
    pub fn firstActorOverlappingActor(
        self: *const World,
        id: ActorId,
        tag: ActorTag,
    ) ?ActorHit {
        const actor = self.getConst(id) orelse unreachable;

        return self.firstActorInRect(
            ActorQuery
                .all(actor.bounds())
                .withTag(tag)
                .withoutActor(id),
        );
    }

    /// Returns a query hit for a live actor slot.
    fn hitForIndex(self: *const World, index: usize) ActorHit {
        const actor = &self.actors[index];

        return .{
            .id = self.idForIndex(index),
            .tag = actor.tag,
            .bounds = actor.bounds(),
        };
    }
};

/// Returns the next non-zero handle generation.
fn nextGeneration(generation: u16) u16 {
    if (generation == std.math.maxInt(u16)) return 1;
    return generation + 1;
}
