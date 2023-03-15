const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const wasm3_dep = b.dependency("wasm3", .{});

    const wasm3 = wasm3_dep.artifact("wasm3");
    const minifb = build_minifb(b, target, optimize);
    const cubeb = build_cubeb(b, target, optimize);

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
    exe.addIncludePath("vendor/wasm3/source");
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

pub fn build_minifb(b: *std.Build, target: anytype, optimize: anytype) *std.Build.CompileStep {
    const minifb = b.addStaticLibrary(.{
        .name = "minifb",
        .target = target,
        .optimize = optimize,
    });
    minifb.linkLibC();
    minifb.linkLibCpp();
    minifb.addIncludePath("vendor/minifb/src");
    minifb.addIncludePath("vendor/minifb/include");
    minifb.addCSourceFiles(&.{
        "vendor/minifb/src/MiniFB_common.c",
        "vendor/minifb/src/MiniFB_cpp.cpp",
        "vendor/minifb/src/MiniFB_internal.c",
        "vendor/minifb/src/MiniFB_timer.c",
    }, &.{});

    minifb.installHeader("vendor/minifb/include/MiniFB.h", "MiniFB.h");
    minifb.installHeader("vendor/minifb/include/MiniFB_enums.h", "MiniFB_enums.h");

    const use_gl = b.option(bool, "use-gl", "Use OpenGL for minifb") orelse false;

    if (use_gl) {
        minifb.addCSourceFiles(&.{
            "vendor/minifb/src/gl/MiniFB_GL.c",
        }, &.{});
    }

    switch (target.getOsTag()) {
        .windows => {
            minifb.addCSourceFiles(&.{
                "vendor/minifb/src/windows/WinMiniFB.c",
            }, &.{});
        },
        .macos => {
            minifb.addCSourceFiles(&.{
                "vendor/minifb/src/macosx/MacMiniFB.m",
                "vendor/minifb/src/macosx/OSXWindow.m",
                "vendor/minifb/src/macosx/OSXView.m",
                "vendor/minifb/src/macosx/OSXViewDelegate.m",
            }, &.{});
        },
        .ios => {
            minifb.addCSourceFiles(&.{
                "vendor/minifb/src/ios/iOSMiniFB.m",
                "vendor/minifb/src/ios/iOSView.m",
                "vendor/minifb/src/ios/iOSViewController.m",
                "vendor/minifb/src/ios/iOSViewDelegate.m",
            }, &.{});
        },
        .linux => {
            const use_wayland = b.option(bool, "use-wayland", "Use wayland for minifb");
            const use_x11 = b.option(bool, "use-X11", "Use X11 for minifb");
            if (use_wayland orelse false) {
                minifb.linkSystemLibrary("wayland-client");
                minifb.linkSystemLibrary("wayland-cursor");

                minifb.addCSourceFiles(&.{
                    "vendor/minifb/src/wayland/WaylandMiniFB.c",
                    "vendor/minifb/src/MiniFB_linux.c",
                }, &.{});
            }

            // Use X11 by default
            if (use_x11 orelse true) {
                minifb.linkSystemLibrary("X11");
                minifb.addCSourceFiles(&.{
                    "vendor/minifb/src/x11/X11MiniFB.c",
                    "vendor/minifb/src/MiniFB_linux.c",
                }, &.{});
            }
        },
        else => |t| {
            _ = b.addLog("Unsupported target {}", .{t});
        },
    }

    return minifb;
}

pub fn build_cubeb(b: *std.Build, target: anytype, optimize: anytype) *std.Build.CompileStep {
    const speex = b.addStaticLibrary(.{
        .name = "speex",
        .target = target,
        .optimize = optimize,
    });
    speex.force_pic = true;
    speex.disable_sanitize_c = true;
    speex.linkLibC();
    speex.defineCMacro("OUTSIDE_SPEEX", "");
    speex.defineCMacro("FLOATING_POINT", "");
    speex.defineCMacro("EXPORT", "");
    speex.defineCMacro("RANDOM_PREFIX", "speex");
    speex.addCSourceFiles(&.{
        "vendor/cubeb/subprojects/speex/resample.c",
    }, &.{});

    const cubeb = b.addStaticLibrary(.{
        .name = "cubeb",
        .target = target,
        .optimize = optimize,
    });
    cubeb.linkLibC();
    cubeb.linkLibCpp();
    cubeb.disable_sanitize_c = true;
    cubeb.linkLibrary(speex);
    cubeb.addIncludePath("exports");
    cubeb.addIncludePath("vendor/cubeb/include");
    cubeb.addIncludePath("vendor/cubeb/subprojects");
    cubeb.defineCMacro("OUTSIDE_SPEEX", "");
    cubeb.defineCMacro("FLOATING_POINT", "");
    cubeb.defineCMacro("EXPORT", "");
    cubeb.defineCMacro("RANDOM_PREFIX", "speex");
    cubeb.addCSourceFiles(&.{
        "vendor/cubeb/src/cubeb.c",
        "vendor/cubeb/src/cubeb_mixer.cpp",
        "vendor/cubeb/src/cubeb_resampler.cpp",
        "vendor/cubeb/src/cubeb_log.cpp",
        "vendor/cubeb/src/cubeb_strings.c",
        "vendor/cubeb/src/cubeb_utils.cpp",
    }, &.{});

    // TODO implement lazy load libs logic

    const use_pulse = b.option(bool, "use-pulse", "Use pulse audio") orelse true;
    cubeb.defineCMacro("USE_PULSE", if (use_pulse) "1" else "0");
    if (use_pulse) {
        cubeb.linkSystemLibrary("pulse");
        cubeb.addCSourceFile("vendor/cubeb/src/cubeb_pulse.c", &.{});
    }

    const use_alsa = b.option(bool, "use-alsa", "Use alsa audio") orelse true;
    cubeb.defineCMacro("USE_ALSA", if (use_alsa) "1" else "0");
    if (use_alsa) {
        cubeb.addCSourceFile("vendor/cubeb/src/cubeb_alsa.c", &.{});
    }

    cubeb.installHeader("exports/cubeb_export.h", "cubeb_export.h");
    cubeb.installHeadersDirectory("vendor/cubeb/include/cubeb", "cubeb");

    return cubeb;
}
