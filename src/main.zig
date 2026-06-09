const std = @import("std");
const yuki = @import("yuki");

pub fn main() !void {
    std.debug.print("{s} {s}\n", .{ yuki.name, yuki.version });
}
