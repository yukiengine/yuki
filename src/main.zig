const std = @import("std");
const yuki = @import("yuki");
const sdl = @import("backend/sdl.zig");

pub fn main() !void {
    std.debug.print("{s} {s}\n", .{ yuki.name, yuki.version });
    try sdl.runHelloWindow();
}
