const std = @import("std");
const yuki = @import("yuki");

pub fn main() !void {
    std.log.info("{s} {s}", .{ yuki.name, yuki.version });
    try yuki.runHelloWindow();
}
