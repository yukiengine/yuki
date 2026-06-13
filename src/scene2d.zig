const std = @import("std");
const render2d = @import("render2d/renderer.zig");
const tilemap = @import("tilemap.zig");
const world2d = @import("world2d.zig");
const prefab2d = @import("prefab2d.zig");
const events2d = @import("events2d.zig");
const commands2d = @import("commands2d.zig");
const overlaps2d = @import("overlaps2d.zig");
const event_reader2d = @import("event_reader2d.zig");
const actor_view2d = @import("actor_view2d.zig");
const picking2d = @import("picking2d.zig");

/// Public 2D scene command.
pub const Command = commands2d.Command;

/// Public 2D scene command queue.
pub const CommandQueue = commands2d.CommandQueue;

/// Public actor tag used for scene queries.
pub const ActorTag = world2d.ActorTag;

/// Public actor handle used by 2D scenes.
pub const ActorId = world2d.ActorId;

/// Public prefab handle used by 2D scenes.
pub const PrefabId = prefab2d.PrefabId;

/// Public actor type stored by a scene.
pub const Actor = world2d.Actor;

/// Public actor prefab type registered into a scene.
pub const ActorPrefab = prefab2d.ActorPrefab;

/// Optional values used to override prefab defaults when spawning.
pub const SpawnOverride = prefab2d.SpawnOverride;

/// Public actor hit returned by scene overlap queries.
pub const ActorHit = world2d.ActorHit;

/// Public actor overlap query filter.
pub const ActorQuery = world2d.ActorQuery;

/// Public bounded result storage for actor overlap queries.
pub const ActorQueryResult = world2d.ActorQueryResult;

/// Public 2D scene event kind.
pub const EventKind = events2d.EventKind;

/// Public 2D scene event.
pub const Event = events2d.Event;

/// Public 2D scene event queue.
pub const EventQueue = events2d.EventQueue;

pub const ActorOverlapPair = overlaps2d.ActorOverlapPair;
pub const ActorOverlapTracker = overlaps2d.ActorOverlapTracker;

/// Public read-only scene event reader.
pub const EventReader = event_reader2d.EventReader;

/// Public actor-overlap event filter.
pub const ActorOverlapFilter = event_reader2d.ActorOverlapFilter;

/// Public read-only actor snapshot.
pub const ActorSnapshot = actor_view2d.ActorSnapshot;

/// Public actor snapshot filter.
pub const ActorSnapshotFilter = actor_view2d.ActorSnapshotFilter;

/// Public bounded actor snapshot list.
pub const ActorSnapshotList = actor_view2d.ActorSnapshotList;

/// Filter used by scene event readers for actor lifecycle events.
pub const ActorLifecycleFilter = event_reader2d.ActorLifecycleFilter;

/// Public actor point-picking filter.
pub const ActorPickFilter = picking2d.ActorPickFilter;

/// Public actor point-picking hit.
pub const ActorPickHit = picking2d.ActorPickHit;

/// Public bounded actor point-picking result.
pub const ActorPickResult = picking2d.ActorPickResult;

pub const Error = prefab2d.Error || events2d.Error || commands2d.Error ||
    overlaps2d.Error || actor_view2d.Error || picking2d.Error;

/// Counts frame-local scene queues.
pub const FrameQueues = struct {
    event_count: usize = 0,
    command_count: usize = 0,

    /// Creates frame queue counts from event and command totals.
    pub fn init(event_count: usize, command_count: usize) FrameQueues {
        return .{
            .event_count = event_count,
            .command_count = command_count,
        };
    }

    /// Returns empty frame queue counts.
    pub fn empty() FrameQueues {
        return .{};
    }

    /// Returns true when there are queued events.
    pub fn hasEvents(self: FrameQueues) bool {
        return self.event_count != 0;
    }

    /// Returns true when there are queued commands.
    pub fn hasCommands(self: FrameQueues) bool {
        return self.command_count != 0;
    }

    /// Returns true when either queue has pending work.
    pub fn hasWork(self: FrameQueues) bool {
        return self.hasEvents() or self.hasCommands();
    }

    /// Returns true when both queues are empty.
    pub fn isEmpty(self: FrameQueues) bool {
        return !self.hasWork();
    }
};

/// High-level 2D scene made of prefabs and actors.
pub const Scene = struct {
    world: world2d.World,
    prefabs: prefab2d.PrefabCatalog,
    events: EventQueue,
    commands: CommandQueue,
    overlaps: ActorOverlapTracker,

    /// Creates an empty 2D scene.
    pub fn init() Scene {
        return .{
            .world = world2d.World.init(),
            .prefabs = prefab2d.PrefabCatalog.init(),
            .events = EventQueue.init(),
            .commands = CommandQueue.init(),
            .overlaps = ActorOverlapTracker.init(),
        };
    }

    /// Starts a new scene frame by clearing frame-local queues.
    pub fn beginFrame(self: *Scene) void {
        self.clearEvents();
        self.clearCommands();
        self.overlaps.beginFrame();
    }

    /// Finishes a scene frame by applying deferred commands.
    pub fn finishFrame(self: *Scene) void {
        self.applyCommands();
        self.overlaps.finishFrame();
    }

    /// Returns current frame-local event and command counts.
    pub fn frameQueues(self: *const Scene) FrameQueues {
        return FrameQueues.init(
            self.events.count(),
            self.commands.count(),
        );
    }

    /// Returns true when the current frame has queued events.
    pub fn hasFrameEvents(self: *const Scene) bool {
        return !self.events.isEmpty();
    }

    /// Returns true when the current frame has queued commands.
    pub fn hasQueuedCommands(self: *const Scene) bool {
        return !self.commands.isEmpty();
    }

    /// Registers a prefab and returns its handle.
    pub fn registerPrefab(self: *Scene, actor_prefab: ActorPrefab) !PrefabId {
        return try self.prefabs.add(actor_prefab);
    }

    /// Returns true when a prefab name exists in the scene catalog.
    pub fn hasPrefab(self: *const Scene, name: []const u8) bool {
        return self.prefabs.containsName(name);
    }

    /// Finds a prefab by name.
    pub fn prefabId(self: *const Scene, name: []const u8) ?PrefabId {
        return self.prefabs.findByName(name);
    }

    /// Returns a prefab by handle.
    pub fn prefab(self: *const Scene, id: PrefabId) ActorPrefab {
        return self.prefabs.get(id);
    }

    /// Spawns an actor from a prefab handle and emits an actor-spawned event.
    pub fn spawn(self: *Scene, prefab_id: PrefabId, spawn_override: SpawnOverride) !ActorId {
        const actor_id = try self.prefabs.spawn(
            prefab_id,
            &self.world,
            spawn_override,
        );

        const actor_data = self.actorConst(actor_id) orelse unreachable;
        try self.events.pushActorSpawned(actor_id, actor_data.tag);

        return actor_id;
    }

    /// Spawns an actor from a prefab name and emits an actor-spawned event.
    pub fn spawnByName(self: *Scene, name: []const u8, spawn_override: SpawnOverride) !ActorId {
        const actor_id = try self.prefabs.spawnByName(
            name,
            &self.world,
            spawn_override,
        );

        const actor_data = self.actorConst(actor_id) orelse unreachable;
        try self.events.pushActorSpawned(actor_id, actor_data.tag);

        return actor_id;
    }

    /// Despawns an actor and emits an actor-despawned event.
    pub fn despawn(self: *Scene, id: ActorId) void {
        if (self.actorConst(id)) |actor_data| {
            self.events.pushActorDespawned(id, actor_data.tag) catch unreachable;
        }

        self.world.despawn(id);
    }

    /// Returns a mutable actor pointer for a valid handle.
    pub fn actor(self: *Scene, id: ActorId) ?*Actor {
        return self.world.get(id);
    }

    /// Returns a const actor pointer for a valid handle.
    pub fn actorConst(self: *const Scene, id: ActorId) ?*const Actor {
        return self.world.getConst(id);
    }

    /// Returns a read-only value snapshot for a valid actor handle.
    pub fn actorSnapshot(self: *const Scene, id: ActorId) ?ActorSnapshot {
        const actor_data = self.actorConst(id) orelse return null;
        return ActorSnapshot.fromActor(id, actor_data);
    }

    /// Returns the first actor snapshot matching a filter.
    pub fn firstActorSnapshot(self: *const Scene, filter: ActorSnapshotFilter) ?ActorSnapshot {
        var index: usize = 0;

        while (index < world2d.max_actors) : (index += 1) {
            const actor_data = &self.world.actors[index];
            if (!actor_data.active) continue;

            const id = ActorId{
                .index = @intCast(index),
                .generation = actor_data.generation,
            };

            const snapshot = ActorSnapshot.fromActor(id, actor_data);
            if (filter.matches(snapshot)) return snapshot;
        }

        return null;
    }

    /// Writes actor snapshots matching a filter into a bounded result list.
    pub fn collectActorSnapshots(
        self: *const Scene,
        filter: ActorSnapshotFilter,
        result: *ActorSnapshotList,
    ) !void {
        var index: usize = 0;

        while (index < world2d.max_actors) : (index += 1) {
            const actor_data = &self.world.actors[index];
            if (!actor_data.active) continue;

            const id = ActorId{
                .index = @intCast(index),
                .generation = actor_data.generation,
            };

            const snapshot = ActorSnapshot.fromActor(id, actor_data);
            if (!filter.matches(snapshot)) continue;

            try result.add(snapshot);
        }
    }

    /// Returns the topmost actor snapshot under a world-space point.
    pub fn topActorAtPoint(
        self: *const Scene,
        point: render2d.Vector2,
        filter: ActorPickFilter,
    ) ?ActorPickHit {
        var best: ?ActorPickHit = null;

        var index: usize = 0;
        while (index < world2d.max_actors) : (index += 1) {
            const actor_data = &self.world.actors[index];
            if (!actor_data.active) continue;

            const id = ActorId{
                .index = @intCast(index),
                .generation = actor_data.generation,
            };

            const snapshot = ActorSnapshot.fromActor(id, actor_data);
            if (!filter.matches(point, snapshot)) continue;

            const hit = ActorPickHit.init(point, snapshot);
            if (best == null or hit.isAbove(best.?)) {
                best = hit;
            }
        }

        return best;
    }

    /// Writes every actor under a world-space point into a bounded result.
    pub fn collectActorsAtPoint(
        self: *const Scene,
        point: render2d.Vector2,
        filter: ActorPickFilter,
        result: *ActorPickResult,
    ) !void {
        var index: usize = 0;
        while (index < world2d.max_actors) : (index += 1) {
            const actor_data = &self.world.actors[index];
            if (!actor_data.active) continue;

            const id = ActorId{
                .index = @intCast(index),
                .generation = actor_data.generation,
            };

            const snapshot = ActorSnapshot.fromActor(id, actor_data);
            if (!filter.matches(point, snapshot)) continue;

            try result.add(ActorPickHit.init(point, snapshot));
        }
    }

    /// Sets an actor velocity.
    pub fn setVelocity(self: *Scene, id: ActorId, velocity: render2d.Vector2) void {
        self.world.setVelocity(id, velocity);
    }

    /// Replaces an actor position.
    pub fn setPosition(self: *Scene, id: ActorId, position: render2d.Vector2) void {
        const target = self.actor(id) orelse return;
        target.position = position;
    }

    /// Replaces an actor rotation.
    pub fn setActorRotation(self: *Scene, id: ActorId, rotation_radians: f32) void {
        const target = self.actor(id) orelse return;
        target.rotation_radians = wrapRadians(rotation_radians);
    }

    /// Adds to an actor rotation.
    pub fn rotateActor(self: *Scene, id: ActorId, radians: f32) void {
        const target = self.actor(id) orelse return;
        target.rotateBy(radians);
    }

    /// Replaces an actor layer.
    pub fn setActorLayer(self: *Scene, id: ActorId, layer: i32) void {
        const target = self.actor(id) orelse return;
        target.layer = layer;
    }

    /// Resets an actor animation if the actor has one.
    pub fn resetActorAnimation(self: *Scene, id: ActorId) void {
        const target = self.actor(id) orelse return;
        target.resetAnimation();
    }

    /// Toggles an actor animation if the actor has one.
    pub fn toggleActorAnimation(self: *Scene, id: ActorId) void {
        const target = self.actor(id) orelse return;
        target.toggleAnimation();
    }

    /// Moves an actor directly without collision.
    pub fn moveActor(self: *Scene, id: ActorId, delta: render2d.Vector2) void {
        self.world.moveActor(id, delta);
    }

    /// Moves an actor using tilemap AABB collision.
    pub fn moveActorWithTilemap(
        self: *Scene,
        id: ActorId,
        map: tilemap.Tilemap,
        rules: tilemap.TileRules,
        origin: render2d.Vector2,
        delta: render2d.Vector2,
    ) tilemap.MoveResult {
        return self.world.moveActorWithTilemap(
            id,
            map,
            rules,
            origin,
            delta,
        );
    }

    /// Moves one actor by its velocity for a time step.
    pub fn integrateActorVelocity(self: *Scene, id: ActorId, dt_seconds: f32) void {
        std.debug.assert(dt_seconds >= 0.0);

        const target = self.actor(id) orelse unreachable;
        target.moveBy(scaledVelocity(target.velocity, dt_seconds));
    }

    /// Advances all actors with velocity and animations.
    pub fn update(self: *Scene, dt_seconds: f32) void {
        std.debug.assert(dt_seconds >= 0.0);

        for (&self.world.actors) |*target| {
            if (!target.active) continue;

            target.moveBy(scaledVelocity(target.velocity, dt_seconds));
            target.updateAnimation(dt_seconds);
        }
    }

    /// Advances animations for all live actors without applying velocity.
    pub fn updateAnimations(self: *Scene, dt_seconds: f32) void {
        self.world.updateAnimations(dt_seconds);
    }

    /// Draws every live actor.
    pub fn draw(self: *const Scene, draw_list: *render2d.DrawList) !void {
        try self.world.draw(draw_list);
    }

    /// Draws live actors that intersect the visible world rectangle.
    pub fn drawVisible(
        self: *const Scene,
        draw_list: *render2d.DrawList,
        visible_world: render2d.Rect2D,
    ) !void {
        try self.world.drawVisible(draw_list, visible_world);
    }

    /// Removes all actors while keeping registered prefabs.
    /// Calls world.despawn directly, so this doesn't emit despawn lifecycle events.
    /// TODO: Make behavior explicit
    pub fn clearActors(self: *Scene) void {
        var index: usize = 0;
        while (index < world2d.max_actors) : (index += 1) {
            if (!self.world.actors[index].active) continue;

            const id = ActorId{
                .index = @intCast(index),
                .generation = self.world.actors[index].generation,
            };

            self.world.despawn(id);
        }
    }

    /// Sets the tag for a live actor.
    pub fn setActorTag(self: *Scene, id: ActorId, tag: ActorTag) void {
        self.world.setActorTag(id, tag);
    }

    /// Finds the first live actor with a tag.
    pub fn findFirstByTag(self: *const Scene, tag: ActorTag) ?ActorId {
        return self.world.findFirstByTag(tag);
    }

    /// Counts live actors with a tag.
    pub fn countByTag(self: *const Scene, tag: ActorTag) usize {
        return self.world.countByTag(tag);
    }

    /// Despawns all live actors with a tag.
    /// Calls world.despawn directly, so this doesn't emit despawn lifecycle events.
    /// TODO: Make behavior explicit
    pub fn despawnByTag(self: *Scene, tag: ActorTag) usize {
        return self.world.despawnByTag(tag);
    }

    /// Draws visible live actors that have a tag.
    pub fn drawVisibleByTag(
        self: *const Scene,
        draw_list: *render2d.DrawList,
        visible_world: render2d.Rect2D,
        tag: ActorTag,
    ) !void {
        try self.world.drawVisibleByTag(draw_list, visible_world, tag);
    }

    /// Returns the first actor that matches an overlap query.
    pub fn firstActorInRect(self: *const Scene, query: ActorQuery) ?ActorHit {
        return self.world.firstActorInRect(query);
    }

    /// Writes all actors matching an overlap query into a bounded result.
    pub fn collectActorsInRect(
        self: *const Scene,
        query: ActorQuery,
        result: *ActorQueryResult,
    ) !void {
        try self.world.collectActorsInRect(query, result);
    }

    /// Counts actors matching an overlap query.
    pub fn countActorsInRect(self: *const Scene, query: ActorQuery) usize {
        return self.world.countActorsInRect(query);
    }

    /// Returns the first actor overlapping another actor.
    pub fn firstActorOverlappingActor(
        self: *const Scene,
        id: ActorId,
        tag: ActorTag,
    ) ?ActorHit {
        return self.world.firstActorOverlappingActor(id, tag);
    }

    /// Clears frame-local scene events.
    pub fn clearEvents(self: *Scene) void {
        self.events.clear();
    }

    /// Returns queued frame-local scene events.
    pub fn eventItems(self: *const Scene) []const Event {
        return self.events.items();
    }

    /// Returns a read-only helper for querying frame-local scene events.
    pub fn eventReader(self: *const Scene) EventReader {
        return EventReader.init(self.eventItems());
    }

    /// Emits one actor-overlap event.
    pub fn emitActorOverlap(
        self: *Scene,
        actor_id: ActorId,
        other: ActorHit,
    ) !void {
        const actor_data = self.actorConst(actor_id) orelse unreachable;

        try self.events.pushActorOverlap(
            actor_id,
            actor_data.tag,
            other.id,
            other.tag,
        );
    }

    /// Emits the first overlap event for one actor and target tag.
    pub fn emitFirstActorOverlap(
        self: *Scene,
        actor_id: ActorId,
        target_tag: ActorTag,
    ) !bool {
        const hit = self.firstActorOverlappingActor(actor_id, target_tag) orelse return false;

        try self.emitActorOverlap(actor_id, hit);
        return true;
    }

    /// Emits overlap events for all actors intersecting one actor.
    pub fn emitActorOverlaps(
        self: *Scene,
        actor_id: ActorId,
        target_tag: ActorTag,
    ) !usize {
        const actor_data = self.actorConst(actor_id) orelse unreachable;

        var result = ActorQueryResult.init();
        try self.collectActorsInRect(
            ActorQuery
                .all(actor_data.bounds())
                .withTag(target_tag)
                .withoutActor(actor_id),
            &result,
        );

        for (result.items()) |hit| {
            try self.emitActorOverlap(actor_id, hit);
        }

        return result.items().len;
    }

    /// Clears deferred scene commands.
    pub fn clearCommands(self: *Scene) void {
        self.commands.clear();
    }

    /// Returns queued deferred scene commands.
    pub fn commandItems(self: *const Scene) []const Command {
        return self.commands.items();
    }

    /// Queues an actor despawn.
    pub fn queueDespawnActor(self: *Scene, actor_id: ActorId) !void {
        try self.commands.despawnActor(actor_id);
    }

    /// Queues an actor movement without collision.
    pub fn queueMoveActor(
        self: *Scene,
        actor_id: ActorId,
        delta: render2d.Vector2,
    ) !void {
        try self.commands.moveActor(actor_id, delta);
    }

    /// Queues an actor position replacement.
    pub fn queueSetActorPosition(
        self: *Scene,
        actor_id: ActorId,
        position: render2d.Vector2,
    ) !void {
        try self.commands.setActorPosition(actor_id, position);
    }

    /// Queues an actor velocity replacement.
    pub fn queueSetActorVelocity(
        self: *Scene,
        actor_id: ActorId,
        velocity: render2d.Vector2,
    ) !void {
        try self.commands.setActorVelocity(actor_id, velocity);
    }

    /// Queues an actor rotation replacement.
    pub fn queueSetActorRotation(
        self: *Scene,
        actor_id: ActorId,
        rotation_radians: f32,
    ) !void {
        try self.commands.setActorRotation(actor_id, rotation_radians);
    }

    /// Queues an actor rotation delta.
    pub fn queueRotateActor(
        self: *Scene,
        actor_id: ActorId,
        radians: f32,
    ) !void {
        try self.commands.rotateActor(actor_id, radians);
    }

    /// Queues an actor layer replacement.
    pub fn queueSetActorLayer(self: *Scene, actor_id: ActorId, layer: i32) !void {
        try self.commands.setActorLayer(actor_id, layer);
    }

    /// Queues an actor tag replacement.
    pub fn queueSetActorTag(self: *Scene, actor_id: ActorId, tag: ActorTag) !void {
        try self.commands.setActorTag(actor_id, tag);
    }

    /// Queues an actor animation reset.
    pub fn queueResetActorAnimation(self: *Scene, actor_id: ActorId) !void {
        try self.commands.resetActorAnimation(actor_id);
    }

    /// Queues an actor animation toggle.
    pub fn queueToggleActorAnimation(self: *Scene, actor_id: ActorId) !void {
        try self.commands.toggleActorAnimation(actor_id);
    }

    /// Applies queued scene commands and clears the command queue.
    pub fn applyCommands(self: *Scene) void {
        for (self.commands.items()) |command| {
            switch (command) {
                .despawn_actor => |actor_id| {
                    self.despawn(actor_id);
                },
                .move_actor => |move| {
                    if (self.actor(move.actor)) |actor_data| {
                        actor_data.moveBy(move.delta);
                    }
                },
                .set_actor_position => |set| {
                    if (self.actor(set.actor)) |actor_data| {
                        actor_data.position = set.position;
                    }
                },
                .set_actor_velocity => |set| {
                    if (self.actor(set.actor)) |actor_data| {
                        actor_data.velocity = set.velocity;
                    }
                },
                .set_actor_rotation => |set| {
                    self.setActorRotation(set.actor, set.rotation_radians);
                },
                .rotate_actor => |rotate| {
                    self.rotateActor(rotate.actor, rotate.radians);
                },
                .set_actor_layer => |set| {
                    self.setActorLayer(set.actor, set.layer);
                },
                .set_actor_tag => |set| {
                    self.setActorTag(set.actor, set.tag);
                },
                .reset_actor_animation => |actor_id| {
                    self.resetActorAnimation(actor_id);
                },
                .toggle_actor_animation => |actor_id| {
                    self.toggleActorAnimation(actor_id);
                },
            }
        }

        self.clearCommands();
    }

    /// Emits begin/stay/end overlap events for one actor and target tag query.
    pub fn emitActorOverlapTransitions(self: *Scene, actor_id: ActorId, target_tag: ActorTag) !usize {
        const actor_data = self.actorConst(actor_id) orelse unreachable;

        var result = ActorQueryResult.init();
        try self.collectActorsInRect(
            ActorQuery.all(actor_data.bounds()).withTag(target_tag).withoutActor(actor_id),
            &result,
        );

        for (result.items()) |hit| {
            const pair = ActorOverlapPair.init(actor_id, actor_data.tag, hit.id, hit.tag);
            const kind: EventKind = if (self.overlaps.wasOverlapping(pair))
                .actor_overlap_stay
            else
                .actor_overlap_begin;

            try self.events.pushActorOverlapKind(kind, pair.actor, pair.actor_tag, pair.other, pair.other_tag);
            try self.overlaps.remember(pair);
        }

        for (self.overlaps.previousItems()) |pair| {
            if (!pair.matchesQuery(actor_id, target_tag)) continue;
            if (self.overlaps.isCurrent(pair)) continue;

            try self.events.pushActorOverlapKind(.actor_overlap_end, pair.actor, pair.actor_tag, pair.other, pair.other_tag);
        }

        return result.items().len;
    }
};

/// Returns velocity scaled by a frame delta.
fn scaledVelocity(velocity: render2d.Vector2, dt_seconds: f32) render2d.Vector2 {
    return render2d.Vector2.xy(
        velocity.x * dt_seconds,
        velocity.y * dt_seconds,
    );
}

/// Wraps radians into the 0..tau interval.
fn wrapRadians(radians: f32) f32 {
    var result = radians;

    while (result >= std.math.tau) {
        result -= std.math.tau;
    }

    while (result < 0.0) {
        result += std.math.tau;
    }

    return result;
}

test "scene registers and finds prefabs" {
    var scene = Scene.init();

    const id = try scene.registerPrefab(.{
        .name = "demo.player",
        .size = render2d.Vector2.xy(32.0, 48.0),
        .layer = 10,
    });

    try std.testing.expect(scene.hasPrefab("demo.player"));
    try std.testing.expect(scene.prefabId("missing") == null);
    try std.testing.expectEqual(id.index, scene.prefabId("demo.player").?.index);

    const prefab_value = scene.prefab(id);
    try std.testing.expectEqualStrings("demo.player", prefab_value.name);
    try std.testing.expectEqual(@as(i32, 10), prefab_value.layer);
}

test "scene spawns actors by prefab handle" {
    var scene = Scene.init();

    const prefab_id = try scene.registerPrefab(.{
        .name = "test.actor",
        .size = render2d.Vector2.xy(10.0, 20.0),
        .layer = 3,
    });

    const actor_id = try scene.spawn(prefab_id, .{
        .position = render2d.Vector2.xy(100.0, 200.0),
    });

    const target = scene.actor(actor_id).?;

    try std.testing.expectEqual(@as(f32, 100.0), target.position.x);
    try std.testing.expectEqual(@as(f32, 200.0), target.position.y);
    try std.testing.expectEqual(@as(f32, 10.0), target.size.x);
    try std.testing.expectEqual(@as(f32, 20.0), target.size.y);
    try std.testing.expectEqual(@as(i32, 3), target.layer);
}

test "scene spawns actors by prefab name" {
    var scene = Scene.init();

    _ = try scene.registerPrefab(.{
        .name = "demo.marker",
        .size = render2d.Vector2.xy(16.0, 16.0),
    });

    const actor_id = try scene.spawnByName("demo.marker", .{
        .position = render2d.Vector2.xy(-12.0, 8.0),
    });

    const target = scene.actorConst(actor_id).?;

    try std.testing.expectEqual(@as(f32, -12.0), target.position.x);
    try std.testing.expectEqual(@as(f32, 8.0), target.position.y);
}

test "scene integrates actor velocity" {
    var scene = Scene.init();

    const prefab_id = try scene.registerPrefab(.{
        .name = "moving.actor",
        .size = render2d.Vector2.xy(8.0, 8.0),
    });

    const actor_id = try scene.spawn(prefab_id, .{
        .position = render2d.Vector2.xy(1.0, 2.0),
    });

    scene.setVelocity(actor_id, render2d.Vector2.xy(10.0, -4.0));
    scene.integrateActorVelocity(actor_id, 0.5);

    const target = scene.actorConst(actor_id).?;

    try std.testing.expectEqual(@as(f32, 6.0), target.position.x);
    try std.testing.expectEqual(@as(f32, 0.0), target.position.y);
}

test "scene update applies velocity to all live actors" {
    var scene = Scene.init();

    const prefab_id = try scene.registerPrefab(.{
        .name = "moving.actor",
        .size = render2d.Vector2.xy(8.0, 8.0),
    });

    const first = try scene.spawn(prefab_id, .{
        .position = render2d.Vector2.xy(0.0, 0.0),
    });

    const second = try scene.spawn(prefab_id, .{
        .position = render2d.Vector2.xy(10.0, 10.0),
    });

    scene.setVelocity(first, render2d.Vector2.xy(2.0, 0.0));
    scene.setVelocity(second, render2d.Vector2.xy(0.0, 4.0));

    scene.update(2.0);

    try std.testing.expectEqual(@as(f32, 4.0), scene.actorConst(first).?.position.x);
    try std.testing.expectEqual(@as(f32, 18.0), scene.actorConst(second).?.position.y);
}

test "scene movement can use tilemap collision" {
    const solid = tilemap.Tile.fromAtlasIndex(0);

    const Storage = tilemap.StaticTilemap(2, 1);
    var storage = Storage.empty();
    storage.set(1, 0, solid);

    var rules = tilemap.TileRules.init();
    rules.setSolid(solid, true);

    const map = storage.view(render2d.Vector2.xy(16.0, 16.0));

    var scene = Scene.init();
    const prefab_id = try scene.registerPrefab(.{
        .name = "collider",
        .size = render2d.Vector2.xy(8.0, 8.0),
    });

    const actor_id = try scene.spawn(prefab_id, .{
        .position = render2d.Vector2.xy(4.0, 8.0),
    });

    const result = scene.moveActorWithTilemap(
        actor_id,
        map,
        rules,
        render2d.Vector2.xy(0.0, 0.0),
        render2d.Vector2.xy(20.0, 0.0),
    );

    const target = scene.actorConst(actor_id).?;

    try std.testing.expect(result.blocked_x);
    try std.testing.expectEqual(@as(f32, 12.0), target.position.x);
}

test "scene can clear actors without clearing prefabs" {
    var scene = Scene.init();

    const prefab_id = try scene.registerPrefab(.{
        .name = "clear.test",
        .size = render2d.Vector2.xy(8.0, 8.0),
    });

    const actor_id = try scene.spawn(prefab_id, .{});
    scene.clearActors();

    try std.testing.expect(scene.actor(actor_id) == null);
    try std.testing.expect(scene.hasPrefab("clear.test"));
}

test "scene clear invalidates handles before slot reuse" {
    var scene = Scene.init();

    const prefab_id = try scene.registerPrefab(.{
        .name = "reuse.test",
        .size = render2d.Vector2.xy(8.0, 8.0),
    });

    const first = try scene.spawn(prefab_id, .{});
    scene.clearActors();

    const second = try scene.spawn(prefab_id, .{});

    try std.testing.expectEqual(first.index, second.index);
    try std.testing.expect(first.generation != second.generation);
    try std.testing.expect(scene.actor(first) == null);
    try std.testing.expect(scene.actor(second) != null);
}

test "scene queries actors by tag" {
    const player_tag = ActorTag.fromIndex(1);
    const marker_tag = ActorTag.fromIndex(2);

    var scene = Scene.init();

    const player_prefab = try scene.registerPrefab(.{
        .name = "player",
        .size = render2d.Vector2.xy(8.0, 8.0),
        .tag = player_tag,
    });

    const marker_prefab = try scene.registerPrefab(.{
        .name = "marker",
        .size = render2d.Vector2.xy(8.0, 8.0),
        .tag = marker_tag,
    });

    const player = try scene.spawn(player_prefab, .{});
    _ = try scene.spawn(marker_prefab, .{});
    _ = try scene.spawn(marker_prefab, .{});

    try std.testing.expectEqual(player.index, scene.findFirstByTag(player_tag).?.index);
    try std.testing.expectEqual(@as(usize, 1), scene.countByTag(player_tag));
    try std.testing.expectEqual(@as(usize, 2), scene.countByTag(marker_tag));
}

test "scene despawns actors by tag" {
    const enemy_tag = ActorTag.fromIndex(10);

    var scene = Scene.init();

    const enemy_prefab = try scene.registerPrefab(.{
        .name = "enemy",
        .size = render2d.Vector2.xy(8.0, 8.0),
        .tag = enemy_tag,
    });

    const first = try scene.spawn(enemy_prefab, .{});
    const second = try scene.spawn(enemy_prefab, .{});

    try std.testing.expectEqual(@as(usize, 2), scene.despawnByTag(enemy_tag));
    try std.testing.expect(scene.actor(first) == null);
    try std.testing.expect(scene.actor(second) == null);
}

test "scene finds actor overlaps by rectangle" {
    const pickup_tag = ActorTag.fromIndex(20);

    var scene = Scene.init();

    const prefab_id = try scene.registerPrefab(.{
        .name = "pickup",
        .size = render2d.Vector2.xy(8.0, 8.0),
        .tag = pickup_tag,
    });

    const pickup = try scene.spawn(prefab_id, .{
        .position = render2d.Vector2.xy(12.0, 0.0),
    });

    const hit = scene.firstActorInRect(
        ActorQuery
            .all(render2d.Rect2D.fromCenterSize(
                render2d.Vector2.xy(12.0, 0.0),
                render2d.Vector2.xy(16.0, 16.0),
            ))
            .withTag(pickup_tag),
    ).?;

    try std.testing.expectEqual(pickup.index, hit.id.index);
}

test "scene collects actor overlaps" {
    const marker_tag = ActorTag.fromIndex(21);

    var scene = Scene.init();

    const prefab_id = try scene.registerPrefab(.{
        .name = "marker",
        .size = render2d.Vector2.xy(8.0, 8.0),
        .tag = marker_tag,
    });

    _ = try scene.spawn(prefab_id, .{
        .position = render2d.Vector2.xy(0.0, 0.0),
    });

    _ = try scene.spawn(prefab_id, .{
        .position = render2d.Vector2.xy(10.0, 0.0),
    });

    var result = ActorQueryResult.init();

    try scene.collectActorsInRect(
        ActorQuery
            .all(render2d.Rect2D.fromCenterSize(
                render2d.Vector2.xy(5.0, 0.0),
                render2d.Vector2.xy(32.0, 16.0),
            ))
            .withTag(marker_tag),
        &result,
    );

    try std.testing.expectEqual(@as(usize, 2), result.items().len);
}

test "scene detects actor overlap by tag" {
    const player_tag = ActorTag.fromIndex(22);
    const enemy_tag = ActorTag.fromIndex(23);

    var scene = Scene.init();

    const player_prefab = try scene.registerPrefab(.{
        .name = "player",
        .size = render2d.Vector2.xy(16.0, 16.0),
        .tag = player_tag,
    });

    const enemy_prefab = try scene.registerPrefab(.{
        .name = "enemy",
        .size = render2d.Vector2.xy(16.0, 16.0),
        .tag = enemy_tag,
    });

    const player = try scene.spawn(player_prefab, .{
        .position = render2d.Vector2.xy(0.0, 0.0),
    });

    const enemy = try scene.spawn(enemy_prefab, .{
        .position = render2d.Vector2.xy(4.0, 0.0),
    });

    const hit = scene.firstActorOverlappingActor(player, enemy_tag).?;

    try std.testing.expectEqual(enemy.index, hit.id.index);
}

test "scene emits first actor overlap event" {
    const player_tag = ActorTag.fromIndex(30);
    const pickup_tag = ActorTag.fromIndex(31);

    var scene = Scene.init();

    const player_prefab = try scene.registerPrefab(.{
        .name = "player",
        .size = render2d.Vector2.xy(16.0, 16.0),
        .tag = player_tag,
    });

    const pickup_prefab = try scene.registerPrefab(.{
        .name = "pickup",
        .size = render2d.Vector2.xy(16.0, 16.0),
        .tag = pickup_tag,
    });

    const player = try scene.spawn(player_prefab, .{
        .position = render2d.Vector2.xy(0.0, 0.0),
    });

    const pickup = try scene.spawn(pickup_prefab, .{
        .position = render2d.Vector2.xy(4.0, 0.0),
    });

    scene.beginFrame();

    try std.testing.expect(try scene.emitFirstActorOverlap(player, pickup_tag));
    try std.testing.expectEqual(@as(usize, 1), scene.eventItems().len);

    const event = scene.eventItems()[0];

    const overlap = event.actorOverlapOrNull().?;
    try std.testing.expect(overlap.actor.eql(player));
    try std.testing.expect(overlap.other.eql(pickup));
    try std.testing.expect(overlap.actor_tag.eql(player_tag));
    try std.testing.expect(overlap.other_tag.eql(pickup_tag));
}

test "scene emits all actor overlap events" {
    const player_tag = ActorTag.fromIndex(32);
    const marker_tag = ActorTag.fromIndex(33);

    var scene = Scene.init();

    const player_prefab = try scene.registerPrefab(.{
        .name = "player",
        .size = render2d.Vector2.xy(16.0, 16.0),
        .tag = player_tag,
    });

    const marker_prefab = try scene.registerPrefab(.{
        .name = "marker",
        .size = render2d.Vector2.xy(16.0, 16.0),
        .tag = marker_tag,
    });

    const player = try scene.spawn(player_prefab, .{});

    _ = try scene.spawn(marker_prefab, .{
        .position = render2d.Vector2.xy(4.0, 0.0),
    });

    _ = try scene.spawn(marker_prefab, .{
        .position = render2d.Vector2.xy(-4.0, 0.0),
    });

    scene.beginFrame();

    const emitted = try scene.emitActorOverlaps(player, marker_tag);

    try std.testing.expectEqual(@as(usize, 2), emitted);
    try std.testing.expectEqual(@as(usize, 2), scene.eventItems().len);
}

test "scene clears frame events" {
    const player_tag = ActorTag.fromIndex(34);
    const marker_tag = ActorTag.fromIndex(35);

    var scene = Scene.init();

    const player_prefab = try scene.registerPrefab(.{
        .name = "player",
        .size = render2d.Vector2.xy(16.0, 16.0),
        .tag = player_tag,
    });

    const marker_prefab = try scene.registerPrefab(.{
        .name = "marker",
        .size = render2d.Vector2.xy(16.0, 16.0),
        .tag = marker_tag,
    });

    const player = try scene.spawn(player_prefab, .{});
    _ = try scene.spawn(marker_prefab, .{});

    _ = try scene.emitActorOverlaps(player, marker_tag);
    scene.clearEvents();

    try std.testing.expectEqual(@as(usize, 0), scene.eventItems().len);
}

test "scene applies queued movement command" {
    var scene = Scene.init();

    const prefab_id = try scene.registerPrefab(.{
        .name = "command.actor",
        .size = render2d.Vector2.xy(8.0, 8.0),
    });

    const actor_id = try scene.spawn(prefab_id, .{
        .position = render2d.Vector2.xy(10.0, 20.0),
    });

    try scene.queueMoveActor(actor_id, render2d.Vector2.xy(5.0, -3.0));
    scene.applyCommands();

    const actor_data = scene.actorConst(actor_id).?;

    try std.testing.expectEqual(@as(f32, 15.0), actor_data.position.x);
    try std.testing.expectEqual(@as(f32, 17.0), actor_data.position.y);
    try std.testing.expectEqual(@as(usize, 0), scene.commandItems().len);
}

test "scene applies queued velocity command" {
    var scene = Scene.init();

    const prefab_id = try scene.registerPrefab(.{
        .name = "velocity.actor",
        .size = render2d.Vector2.xy(8.0, 8.0),
    });

    const actor_id = try scene.spawn(prefab_id, .{});

    try scene.queueSetActorVelocity(actor_id, render2d.Vector2.xy(12.0, -6.0));
    scene.applyCommands();

    const actor_data = scene.actorConst(actor_id).?;

    try std.testing.expectEqual(@as(f32, 12.0), actor_data.velocity.x);
    try std.testing.expectEqual(@as(f32, -6.0), actor_data.velocity.y);
}

test "scene applies queued despawn command" {
    var scene = Scene.init();

    const prefab_id = try scene.registerPrefab(.{
        .name = "despawn.actor",
        .size = render2d.Vector2.xy(8.0, 8.0),
    });

    const actor_id = try scene.spawn(prefab_id, .{});

    try scene.queueDespawnActor(actor_id);
    scene.applyCommands();

    try std.testing.expect(scene.actorConst(actor_id) == null);
    try std.testing.expectEqual(@as(usize, 0), scene.commandItems().len);
}

test "scene frame queues start empty" {
    var scene = Scene.init();

    const queues = scene.frameQueues();

    try std.testing.expect(queues.isEmpty());
    try std.testing.expect(!queues.hasEvents());
    try std.testing.expect(!queues.hasCommands());
    try std.testing.expect(!queues.hasWork());
    try std.testing.expectEqual(@as(usize, 0), queues.event_count);
    try std.testing.expectEqual(@as(usize, 0), queues.command_count);
}

test "scene begin frame clears events and commands" {
    const player_tag = ActorTag.fromIndex(40);
    const marker_tag = ActorTag.fromIndex(41);

    var scene = Scene.init();

    const player_prefab = try scene.registerPrefab(.{
        .name = "frame.player",
        .size = render2d.Vector2.xy(16.0, 16.0),
        .tag = player_tag,
    });

    const marker_prefab = try scene.registerPrefab(.{
        .name = "frame.marker",
        .size = render2d.Vector2.xy(16.0, 16.0),
        .tag = marker_tag,
    });

    const player = try scene.spawn(player_prefab, .{
        .position = render2d.Vector2.xy(0.0, 0.0),
    });

    const marker = try scene.spawn(marker_prefab, .{
        .position = render2d.Vector2.xy(4.0, 0.0),
    });

    scene.beginFrame();

    _ = try scene.emitActorOverlaps(player, marker_tag);
    try scene.queueMoveActor(marker, render2d.Vector2.xy(8.0, 0.0));

    const before = scene.frameQueues();

    try std.testing.expect(before.hasEvents());
    try std.testing.expect(before.hasCommands());
    try std.testing.expect(before.hasWork());
    try std.testing.expectEqual(@as(usize, 1), before.event_count);
    try std.testing.expectEqual(@as(usize, 1), before.command_count);

    scene.beginFrame();

    const after = scene.frameQueues();

    try std.testing.expect(after.isEmpty());
    try std.testing.expectEqual(@as(usize, 0), scene.eventItems().len);
    try std.testing.expectEqual(@as(usize, 0), scene.commandItems().len);
}

test "scene finish frame applies queued movement" {
    var scene = Scene.init();

    const prefab_id = try scene.registerPrefab(.{
        .name = "finish.actor",
        .size = render2d.Vector2.xy(8.0, 8.0),
    });

    const actor_id = try scene.spawn(prefab_id, .{
        .position = render2d.Vector2.xy(10.0, 20.0),
    });

    try scene.queueMoveActor(actor_id, render2d.Vector2.xy(5.0, -3.0));

    try std.testing.expect(scene.hasQueuedCommands());
    try std.testing.expectEqual(@as(usize, 1), scene.frameQueues().command_count);

    scene.finishFrame();

    const actor_data = scene.actorConst(actor_id).?;

    try std.testing.expectEqual(@as(f32, 15.0), actor_data.position.x);
    try std.testing.expectEqual(@as(f32, 17.0), actor_data.position.y);

    try std.testing.expect(!scene.hasQueuedCommands());
    try std.testing.expectEqual(@as(usize, 0), scene.commandItems().len);
}

test "scene finish frame applies queued position replacement" {
    var scene = Scene.init();

    const prefab_id = try scene.registerPrefab(.{
        .name = "position.actor",
        .size = render2d.Vector2.xy(8.0, 8.0),
    });

    const actor_id = try scene.spawn(prefab_id, .{
        .position = render2d.Vector2.xy(1.0, 2.0),
    });

    try scene.queueSetActorPosition(
        actor_id,
        render2d.Vector2.xy(100.0, 200.0),
    );

    scene.finishFrame();

    const actor_data = scene.actorConst(actor_id).?;

    try std.testing.expectEqual(@as(f32, 100.0), actor_data.position.x);
    try std.testing.expectEqual(@as(f32, 200.0), actor_data.position.y);
}

test "scene finish frame applies queued velocity replacement" {
    var scene = Scene.init();

    const prefab_id = try scene.registerPrefab(.{
        .name = "velocity.actor",
        .size = render2d.Vector2.xy(8.0, 8.0),
    });

    const actor_id = try scene.spawn(prefab_id, .{});

    try scene.queueSetActorVelocity(
        actor_id,
        render2d.Vector2.xy(30.0, -12.0),
    );

    scene.finishFrame();

    const actor_data = scene.actorConst(actor_id).?;

    try std.testing.expectEqual(@as(f32, 30.0), actor_data.velocity.x);
    try std.testing.expectEqual(@as(f32, -12.0), actor_data.velocity.y);
}

test "scene finish frame applies queued despawn" {
    var scene = Scene.init();

    const prefab_id = try scene.registerPrefab(.{
        .name = "despawn.frame.actor",
        .size = render2d.Vector2.xy(8.0, 8.0),
    });

    const actor_id = try scene.spawn(prefab_id, .{});

    try scene.queueDespawnActor(actor_id);
    scene.finishFrame();

    try std.testing.expect(scene.actorConst(actor_id) == null);
    try std.testing.expect(!scene.hasQueuedCommands());
    try std.testing.expectEqual(@as(usize, 1), scene.eventReader().countActorLifecycle(
        ActorLifecycleFilter.despawned().withActor(actor_id),
    ));
}

test "scene returns actor snapshots" {
    const player_tag = ActorTag.fromIndex(90);

    var scene = Scene.init();

    const player_prefab = try scene.registerPrefab(.{
        .name = "snapshot.player",
        .size = render2d.Vector2.xy(16.0, 24.0),
        .tag = player_tag,
        .layer = 8,
    });

    const player = try scene.spawn(player_prefab, .{
        .position = render2d.Vector2.xy(10.0, 20.0),
    });

    scene.setVelocity(player, render2d.Vector2.xy(3.0, -4.0));

    const snapshot = scene.actorSnapshot(player) orelse return error.ExpectedSnapshot;

    try std.testing.expect(snapshot.id.eql(player));
    try std.testing.expect(snapshot.hasTag(player_tag));
    try std.testing.expectEqual(@as(f32, 10.0), snapshot.position.x);
    try std.testing.expectEqual(@as(f32, 20.0), snapshot.position.y);
    try std.testing.expectEqual(@as(f32, 16.0), snapshot.size.x);
    try std.testing.expectEqual(@as(f32, 24.0), snapshot.size.y);
    try std.testing.expectEqual(@as(f32, 3.0), snapshot.velocity.x);
    try std.testing.expectEqual(@as(f32, -4.0), snapshot.velocity.y);
    try std.testing.expectEqual(@as(i32, 8), snapshot.layer);
}

test "scene collects actor snapshots by tag and rect" {
    const marker_tag = ActorTag.fromIndex(91);
    const enemy_tag = ActorTag.fromIndex(92);

    var scene = Scene.init();

    const marker_prefab = try scene.registerPrefab(.{
        .name = "snapshot.marker",
        .size = render2d.Vector2.xy(8.0, 8.0),
        .tag = marker_tag,
    });

    const enemy_prefab = try scene.registerPrefab(.{
        .name = "snapshot.enemy",
        .size = render2d.Vector2.xy(8.0, 8.0),
        .tag = enemy_tag,
    });

    _ = try scene.spawn(marker_prefab, .{
        .position = render2d.Vector2.xy(0.0, 0.0),
    });

    _ = try scene.spawn(marker_prefab, .{
        .position = render2d.Vector2.xy(10.0, 0.0),
    });

    _ = try scene.spawn(marker_prefab, .{
        .position = render2d.Vector2.xy(100.0, 0.0),
    });

    _ = try scene.spawn(enemy_prefab, .{
        .position = render2d.Vector2.xy(0.0, 0.0),
    });

    var snapshots = ActorSnapshotList.init();

    try scene.collectActorSnapshots(
        ActorSnapshotFilter
            .all()
            .withTag(marker_tag)
            .inRect(render2d.Rect2D.fromCenterSize(
            render2d.Vector2.xy(5.0, 0.0),
            render2d.Vector2.xy(32.0, 16.0),
        )),
        &snapshots,
    );

    try std.testing.expectEqual(@as(usize, 2), snapshots.count());
    try std.testing.expectEqual(@as(usize, 2), snapshots.countByTag(marker_tag));
    try std.testing.expectEqual(@as(usize, 0), snapshots.countByTag(enemy_tag));
}

test "scene actor snapshot filter can exclude actor" {
    const actor_tag = ActorTag.fromIndex(93);

    var scene = Scene.init();

    const prefab_id = try scene.registerPrefab(.{
        .name = "snapshot.exclude",
        .size = render2d.Vector2.xy(8.0, 8.0),
        .tag = actor_tag,
    });

    const first = try scene.spawn(prefab_id, .{
        .position = render2d.Vector2.xy(0.0, 0.0),
    });

    const second = try scene.spawn(prefab_id, .{
        .position = render2d.Vector2.xy(10.0, 0.0),
    });

    var snapshots = ActorSnapshotList.init();

    try scene.collectActorSnapshots(
        ActorSnapshotFilter
            .all()
            .withTag(actor_tag)
            .withoutActor(first),
        &snapshots,
    );

    try std.testing.expectEqual(@as(usize, 1), snapshots.count());

    const only = snapshots.first() orelse return error.ExpectedSnapshot;
    try std.testing.expect(only.id.eql(second));
}

test "scene direct actor mutation helpers update snapshot state" {
    const first_tag = ActorTag.fromIndex(100);
    const second_tag = ActorTag.fromIndex(101);

    var scene = Scene.init();

    const prefab_id = try scene.registerPrefab(.{
        .name = "mutation.actor",
        .size = render2d.Vector2.xy(8.0, 8.0),
        .tag = first_tag,
        .layer = 2,
    });

    const actor_id = try scene.spawn(prefab_id, .{});

    scene.setPosition(actor_id, render2d.Vector2.xy(10.0, 20.0));
    scene.setVelocity(actor_id, render2d.Vector2.xy(3.0, -4.0));
    scene.setActorRotation(actor_id, 1.0);
    scene.rotateActor(actor_id, 0.5);
    scene.setActorLayer(actor_id, 9);
    scene.setActorTag(actor_id, second_tag);

    const snapshot = scene.actorSnapshot(actor_id) orelse return error.ExpectedSnapshot;

    try std.testing.expectEqual(@as(f32, 10.0), snapshot.position.x);
    try std.testing.expectEqual(@as(f32, 20.0), snapshot.position.y);
    try std.testing.expectEqual(@as(f32, 3.0), snapshot.velocity.x);
    try std.testing.expectEqual(@as(f32, -4.0), snapshot.velocity.y);
    try std.testing.expectEqual(@as(f32, 1.5), snapshot.rotation_radians);
    try std.testing.expectEqual(@as(i32, 9), snapshot.layer);
    try std.testing.expect(snapshot.hasTag(second_tag));
}

test "scene applies queued actor transform commands" {
    const first_tag = ActorTag.fromIndex(102);
    const second_tag = ActorTag.fromIndex(103);

    var scene = Scene.init();

    const prefab_id = try scene.registerPrefab(.{
        .name = "queued.mutation.actor",
        .size = render2d.Vector2.xy(8.0, 8.0),
        .tag = first_tag,
    });

    const actor_id = try scene.spawn(prefab_id, .{});

    try scene.queueSetActorPosition(actor_id, render2d.Vector2.xy(30.0, 40.0));
    try scene.queueSetActorVelocity(actor_id, render2d.Vector2.xy(5.0, 6.0));
    try scene.queueSetActorRotation(actor_id, 0.25);
    try scene.queueRotateActor(actor_id, 0.75);
    try scene.queueSetActorLayer(actor_id, 12);
    try scene.queueSetActorTag(actor_id, second_tag);

    scene.finishFrame();

    const snapshot = scene.actorSnapshot(actor_id) orelse return error.ExpectedSnapshot;

    try std.testing.expectEqual(@as(f32, 30.0), snapshot.position.x);
    try std.testing.expectEqual(@as(f32, 40.0), snapshot.position.y);
    try std.testing.expectEqual(@as(f32, 5.0), snapshot.velocity.x);
    try std.testing.expectEqual(@as(f32, 6.0), snapshot.velocity.y);
    try std.testing.expectEqual(@as(f32, 1.0), snapshot.rotation_radians);
    try std.testing.expectEqual(@as(i32, 12), snapshot.layer);
    try std.testing.expect(snapshot.hasTag(second_tag));
    try std.testing.expectEqual(@as(usize, 0), scene.commandItems().len);
}

test "scene applies queued animation commands" {
    var scene = Scene.init();

    const atlas = render2d.TextureAtlas.init(render2d.TextureId.default(), 2, 1);
    const animation = render2d.SpriteAnimation.init(
        atlas,
        0,
        0,
        2,
        1,
        1,
        0.1,
    );

    const prefab_id = try scene.registerPrefab(.{
        .name = "animated.actor",
        .size = render2d.Vector2.xy(8.0, 8.0),
        .animation = animation,
    });

    const actor_id = try scene.spawn(prefab_id, .{});

    scene.updateAnimations(0.2);

    {
        const actor_data = scene.actorConst(actor_id) orelse return error.ExpectedActor;
        try std.testing.expect(actor_data.animation_player.?.elapsed_seconds > 0.0);
        try std.testing.expect(actor_data.animation_player.?.playing);
    }

    try scene.queueResetActorAnimation(actor_id);
    try scene.queueToggleActorAnimation(actor_id);
    scene.finishFrame();

    {
        const actor_data = scene.actorConst(actor_id) orelse return error.ExpectedActor;
        try std.testing.expectEqual(@as(f32, 0.0), actor_data.animation_player.?.elapsed_seconds);
        try std.testing.expect(!actor_data.animation_player.?.playing);
    }

    try scene.queueToggleActorAnimation(actor_id);
    scene.finishFrame();

    {
        const actor_data = scene.actorConst(actor_id) orelse return error.ExpectedActor;
        try std.testing.expect(actor_data.animation_player.?.playing);
    }
}

test "scene emits actor spawned event" {
    const player_tag = ActorTag.fromIndex(120);

    var scene = Scene.init();

    const prefab_id = try scene.registerPrefab(.{
        .name = "lifecycle.spawn",
        .size = render2d.Vector2.xy(32.0, 32.0),
        .tag = player_tag,
    });

    const actor = try scene.spawn(prefab_id, .{
        .position = render2d.Vector2.xy(0.0, 0.0),
    });

    const reader = scene.eventReader();

    try std.testing.expect(reader.hasActorLifecycle(
        ActorLifecycleFilter.spawned().withActor(actor),
    ));

    const event = reader.firstActorLifecycle(
        ActorLifecycleFilter.spawned().withTag(player_tag),
    ) orelse return error.MissingSpawnEvent;

    const payload = event.actorLifecycleOrNull() orelse return error.MissingSpawnPayload;

    try std.testing.expect(payload.actor.eql(actor));
    try std.testing.expect(payload.tag.eql(player_tag));
}

test "scene emits actor despawned event" {
    const enemy_tag = ActorTag.fromIndex(121);

    var scene = Scene.init();

    const prefab_id = try scene.registerPrefab(.{
        .name = "lifecycle.despawn",
        .size = render2d.Vector2.xy(32.0, 32.0),
        .tag = enemy_tag,
    });

    const actor = try scene.spawn(prefab_id, .{});

    scene.beginFrame();
    scene.despawn(actor);

    const reader = scene.eventReader();

    try std.testing.expect(reader.hasActorLifecycle(
        ActorLifecycleFilter.despawned().withActor(actor),
    ));

    const event = reader.firstActorLifecycle(
        ActorLifecycleFilter.despawned().withTag(enemy_tag),
    ) orelse return error.MissingDespawnEvent;

    const payload = event.actorLifecycleOrNull() orelse return error.MissingDespawnPayload;

    try std.testing.expect(payload.actor.eql(actor));
    try std.testing.expect(payload.tag.eql(enemy_tag));
}

test "scene picks top actor at point" {
    const actor_tag = ActorTag.fromIndex(130);

    var scene = Scene.init();

    const low_prefab = try scene.registerPrefab(.{
        .name = "pick.low",
        .size = render2d.Vector2.xy(32.0, 32.0),
        .layer = 0,
        .tag = actor_tag,
    });

    const high_prefab = try scene.registerPrefab(.{
        .name = "pick.high",
        .size = render2d.Vector2.xy(32.0, 32.0),
        .layer = 20,
        .tag = actor_tag,
    });

    _ = try scene.spawn(low_prefab, .{
        .position = render2d.Vector2.xy(0.0, 0.0),
    });

    const high = try scene.spawn(high_prefab, .{
        .position = render2d.Vector2.xy(0.0, 0.0),
    });

    const hit = scene.topActorAtPoint(
        render2d.Vector2.xy(0.0, 0.0),
        ActorPickFilter.all().withTag(actor_tag),
    ) orelse return error.ExpectedPickHit;

    try std.testing.expect(hit.actor().eql(high));
    try std.testing.expectEqual(@as(i32, 20), hit.layer());
}

test "scene collects actors at point" {
    const actor_tag = ActorTag.fromIndex(131);

    var scene = Scene.init();

    const prefab_id = try scene.registerPrefab(.{
        .name = "pick.collect",
        .size = render2d.Vector2.xy(32.0, 32.0),
        .tag = actor_tag,
    });

    const first = try scene.spawn(prefab_id, .{
        .position = render2d.Vector2.xy(0.0, 0.0),
    });

    const second = try scene.spawn(prefab_id, .{
        .position = render2d.Vector2.xy(8.0, 0.0),
    });

    var result = ActorPickResult.init();

    try scene.collectActorsAtPoint(
        render2d.Vector2.xy(4.0, 0.0),
        ActorPickFilter.all().withTag(actor_tag),
        &result,
    );

    try std.testing.expectEqual(@as(usize, 2), result.count());
    try std.testing.expect(result.items()[0].actor().eql(first));
    try std.testing.expect(result.items()[1].actor().eql(second));
}
