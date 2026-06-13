//! Commands2D queue behavior tests.
//!
//! These tests cover deferred scene command storage separately from the command
//! value and queue implementation.

const std = @import("std");
const yuki2d = @import("yuki2d.zig");
const commands2d = @import("commands2d.zig");

const CommandQueue = commands2d.CommandQueue;
const Vector2 = yuki2d.Vector2;

test "command queue stores movement commands" {
    const actor = yuki2d.ActorId{ .index = 1, .generation = 1 };

    var queue = CommandQueue.init();
    try queue.moveActor(actor, Vector2.xy(4.0, -2.0));

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
