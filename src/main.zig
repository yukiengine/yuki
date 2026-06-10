const std = @import("std");
const yuki = @import("yuki");
const sdl = @import("backend/sdl.zig");

pub fn main() !void {
    std.log.info("{s} {s}", .{ yuki.name, yuki.version });
    try sdl.runHelloWindow();
}
