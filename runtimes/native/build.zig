const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const wasm3_dep = b.dependency("wasm3", .{});
    const minifb_dep = b.dependency("minifb", .{});
    const cubeb_dep = b.dependency("cubeb", .{});

    const wasm3 = wasm3_dep.artifact("wasm3");
    const minifb = minifb_dep.artifact("minifb");
    const cubeb = cubeb_dep.artifact("cubeb");

    const exe = b.addExecutable(.{
        .name = "wasm4",
        .target = target,
        .optimize = optimize,
    });
    exe.addCSourceFiles(&.{
        "src/apu.c",
        "src/framebuffer.c",
        "src/runtime.c",
        "src/util.c",
    }, &.{});

    // Build with minifb + wasm3
    exe.linkLibrary(wasm3);
    exe.linkLibrary(minifb);
    exe.linkLibrary(cubeb);
    exe.installLibraryHeaders(wasm3);
    exe.installLibraryHeaders(minifb);
    exe.installLibraryHeaders(cubeb);
    exe.addCSourceFiles(&.{
        "src/backend/main.c",
        "src/backend/wasm_wasm3.c",
        "src/backend/window_minifb.c",
    }, &.{});

    exe.install();

    const run_cmd = exe.run();

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
