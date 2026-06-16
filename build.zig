const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const mod = b.addModule("yuki", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    const exe = b.addExecutable(.{
        .name = "yuki",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "yuki", .module = mod },
            },
        }),
    });

    // SDL
    // exe.root_module.link_libc = true;
    // exe.root_module.linkSystemLibrary("SDL3", .{ .use_pkg_config = .force });

    // wgpu-native
    // exe.root_module.linkSystemLibrary("wgpu_native", .{ .use_pkg_config = .force });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });
    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const all_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/tests.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);

    const run_all_tests = b.addRunArtifact(all_tests);
    test_step.dependOn(&run_all_tests.step);

    linkNativeRuntime(b, mod);
    addLuauBridge(b, mod);

    linkNativeRuntime(b, exe.root_module);

    linkNativeRuntime(b, all_tests.root_module);
    addLuauBridge(b, all_tests.root_module);
}

/// Links Yuki's native runtime dependencies into a build module.
fn linkNativeRuntime(b: *std.Build, module: *std.Build.Module) void {
    module.link_libc = true;

    module.linkSystemLibrary("SDL3", .{ .use_pkg_config = .force });
    module.linkSystemLibrary("wgpu_native", .{ .use_pkg_config = .force });
    module.linkSystemLibrary("luau", .{ .use_pkg_config = .force });

    addCxxRuntimeObject(b, module);
}

/// Adds libstdc++.so as a positional object after Luau's static archives.
fn addCxxRuntimeObject(b: *std.Build, module: *std.Build.Module) void {
    if (b.graph.environ_map.get("YUKI_STDCXX_LIB")) |path| {
        module.addObjectFile(.{ .cwd_relative = path });
    }
}

fn addLuauBridge(b: *std.Build, module: *std.Build.Module) void {
    module.addIncludePath(b.path("src"));
    module.addCSourceFile(.{
        .file = b.path("src/backend/luau_bridge.cpp"),
        .flags = &.{
            "-std=c++17",
        },
    });
}
