const sdl = @import("backend/sdl.zig");

pub const name = "Yuki";
pub const version = "0.0.0";

/// Public Zig scripting API.
pub const scripting = @import("scripting/mod.zig");

/// Runs the temporary native SDL smoke window.
///
/// This keeps `src/main.zig` as a thin executable wrapper around the `yuki`
/// module. That matters because Zig 0.16 does not allow the same source file to
/// be imported into both the executable root module and the `yuki` dependency
/// module during one compile.
pub fn runHelloWindow() !void {
    try sdl.runHelloWindow();
}
