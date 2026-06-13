const std = @import("std");
const render2d = @import("render2d/renderer.zig");
const world2d = @import("world2d.zig");

/// Maximum number of deferred scene commands stored for one frame.
pub const max_commands = 64;

/// Errors returned by the scene command queue.
pub const Error = error{
    CommandQueueFull,
};

/// Command payload used to move one actor without collision.
pub const MoveActorCommand = struct {
    actor: world2d.ActorId,
    delta: render2d.Vector2,
};

/// Command payload used to replace one actor position.
pub const SetActorPositionCommand = struct {
    actor: world2d.ActorId,
    position: render2d.Vector2,
};

/// Command payload used to replace one actor velocity.
pub const SetActorVelocityCommand = struct {
    actor: world2d.ActorId,
    velocity: render2d.Vector2,
};

/// Command payload used to replace one actor rotation.
pub const SetActorRotationCommand = struct {
    actor: world2d.ActorId,
    rotation_radians: f32,
};

/// Command payload used to add to one actor rotation.
pub const RotateActorCommand = struct {
    actor: world2d.ActorId,
    radians: f32,
};

/// Command payload used to replace one actor layer.
pub const SetActorLayerCommand = struct {
    actor: world2d.ActorId,
    layer: i32,
};

/// Command payload used to replace one actor tag.
pub const SetActorTagCommand = struct {
    actor: world2d.ActorId,
    tag: world2d.ActorTag,
};

/// Deferred scene mutation applied after gameplay/event handling.
pub const Command = union(enum) {
    despawn_actor: world2d.ActorId,
    move_actor: MoveActorCommand,
    set_actor_position: SetActorPositionCommand,
    set_actor_velocity: SetActorVelocityCommand,
    set_actor_rotation: SetActorRotationCommand,
    rotate_actor: RotateActorCommand,
    set_actor_layer: SetActorLayerCommand,
    set_actor_tag: SetActorTagCommand,
    reset_actor_animation: world2d.ActorId,
    toggle_actor_animation: world2d.ActorId,

    /// Creates a command that despawns one actor.
    pub fn despawnActor(actor: world2d.ActorId) Command {
        return .{ .despawn_actor = actor };
    }

    /// Creates a command that moves one actor by a delta.
    pub fn moveActor(actor: world2d.ActorId, delta: render2d.Vector2) Command {
        return .{
            .move_actor = .{ .actor = actor, .delta = delta },
        };
    }

    /// Creates a command that sets one actor position.
    pub fn setActorPosition(actor: world2d.ActorId, position: render2d.Vector2) Command {
        return .{
            .set_actor_position = .{ .actor = actor, .position = position },
        };
    }

    /// Creates a command that sets one actor velocity.
    pub fn setActorVelocity(actor: world2d.ActorId, velocity: render2d.Vector2) Command {
        return .{
            .set_actor_velocity = .{ .actor = actor, .velocity = velocity },
        };
    }

    /// Creates a command that sets one actor rotation.
    pub fn setActorRotation(actor: world2d.ActorId, rotation_radians: f32) Command {
        return .{ .set_actor_rotation = .{ .actor = actor, .rotation_radians = rotation_radians } };
    }

    /// Creates a command that rotates one actor.
    pub fn rotateActor(actor: world2d.ActorId, radians: f32) Command {
        return .{ .rotate_actor = .{ .actor = actor, .radians = radians } };
    }

    /// Creates a command that sets one actor layer.
    pub fn setActorLayer(actor: world2d.ActorId, layer: i32) Command {
        return .{ .set_actor_layer = .{ .actor = actor, .layer = layer } };
    }

    /// Creates a command that sets one actor tag.
    pub fn setActorTag(actor: world2d.ActorId, tag: world2d.ActorTag) Command {
        return .{ .set_actor_tag = .{ .actor = actor, .tag = tag } };
    }

    /// Creates a command that resets one actor animation.
    pub fn resetActorAnimation(actor: world2d.ActorId) Command {
        return .{ .reset_actor_animation = actor };
    }

    /// Creates a command that toggles one actor animation.
    pub fn toggleActorAnimation(actor: world2d.ActorId) Command {
        return .{ .toggle_actor_animation = actor };
    }
};

/// Bounded queue of scene commands applied explicitly by Scene.
pub const CommandQueue = struct {
    commands: [max_commands]Command,
    command_count: usize = 0,

    /// Creates an empty command queue.
    pub fn init() CommandQueue {
        return .{
            .commands = undefined,
        };
    }

    /// Removes all queued commands.
    pub fn clear(self: *CommandQueue) void {
        self.command_count = 0;
    }

    /// Adds one command to the queue.
    pub fn push(self: *CommandQueue, command: Command) !void {
        if (self.command_count == max_commands) {
            return Error.CommandQueueFull;
        }

        self.commands[self.command_count] = command;
        self.command_count += 1;
    }

    /// Queues an actor despawn command.
    pub fn despawnActor(self: *CommandQueue, actor: world2d.ActorId) !void {
        try self.push(Command.despawnActor(actor));
    }

    /// Queues an actor movement command.
    pub fn moveActor(
        self: *CommandQueue,
        actor: world2d.ActorId,
        delta: render2d.Vector2,
    ) !void {
        try self.push(Command.moveActor(actor, delta));
    }

    /// Queues an actor position replacement command.
    pub fn setActorPosition(
        self: *CommandQueue,
        actor: world2d.ActorId,
        position: render2d.Vector2,
    ) !void {
        try self.push(Command.setActorPosition(actor, position));
    }

    /// Queues an actor velocity replacement command.
    pub fn setActorVelocity(
        self: *CommandQueue,
        actor: world2d.ActorId,
        velocity: render2d.Vector2,
    ) !void {
        try self.push(Command.setActorVelocity(actor, velocity));
    }

    /// Returns queued commands.
    pub fn items(self: *const CommandQueue) []const Command {
        return self.commands[0..self.command_count];
    }

    /// Returns true when the queue has no commands.
    pub fn isEmpty(self: *const CommandQueue) bool {
        return self.command_count == 0;
    }

    /// Returns the number of queued commands.
    pub fn count(self: *const CommandQueue) usize {
        return self.command_count;
    }

    /// Queues an actor rotation replacement command.
    pub fn setActorRotation(
        self: *CommandQueue,
        actor: world2d.ActorId,
        rotation_radians: f32,
    ) !void {
        try self.push(Command.setActorRotation(actor, rotation_radians));
    }

    /// Queues an actor rotation delta command.
    pub fn rotateActor(
        self: *CommandQueue,
        actor: world2d.ActorId,
        radians: f32,
    ) !void {
        try self.push(Command.rotateActor(actor, radians));
    }

    /// Queues an actor layer replacement command.
    pub fn setActorLayer(
        self: *CommandQueue,
        actor: world2d.ActorId,
        layer: i32,
    ) !void {
        try self.push(Command.setActorLayer(actor, layer));
    }

    /// Queues an actor tag replacement command.
    pub fn setActorTag(
        self: *CommandQueue,
        actor: world2d.ActorId,
        tag: world2d.ActorTag,
    ) !void {
        try self.push(Command.setActorTag(actor, tag));
    }

    /// Queues an actor animation reset command.
    pub fn resetActorAnimation(self: *CommandQueue, actor: world2d.ActorId) !void {
        try self.push(Command.resetActorAnimation(actor));
    }

    /// Queues an actor animation toggle command.
    pub fn toggleActorAnimation(self: *CommandQueue, actor: world2d.ActorId) !void {
        try self.push(Command.toggleActorAnimation(actor));
    }
};

test "command queue stores movement commands" {
    const actor = world2d.ActorId{ .index = 1, .generation = 1 };

    var queue = CommandQueue.init();
    try queue.moveActor(actor, render2d.Vector2.xy(4.0, -2.0));

    try std.testing.expect(!queue.isEmpty());
    try std.testing.expectEqual(@as(usize, 1), queue.items().len);

    switch (queue.items()[0]) {
        .move_actor => |command| {
            try std.testing.expect(command.actor.eql(actor));
            try std.testing.expectEqual(@as(f32, 4.0), command.delta.x);
            try std.testing.expectEqual(@as(f32, -2.0), command.delta.y);
        },
        else => return error.UnexpectedCommand,
    }
}

test "command queue clears commands" {
    var queue = CommandQueue.init();

    try queue.despawnActor(.{ .index = 1, .generation = 1 });
    queue.clear();

    try std.testing.expect(queue.isEmpty());
    try std.testing.expectEqual(@as(usize, 0), queue.items().len);
}
