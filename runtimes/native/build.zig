const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const wasm3 = build_wasm3(b, target, optimize);
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

pub fn show_includes(compile_step: *std.Build.CompileStep, depth: usize) void {
    for (0..depth) |_| {
        std.debug.print("\t", .{});
    }
    std.debug.print("{s} include directories:\n", .{compile_step.name});
    for (compile_step.include_dirs.items) |item| {
        for (0..depth) |_| {
            std.debug.print("\t", .{});
        }
        switch (item) {
            .other_step => |step| {
                show_includes(step, depth + 1);
            },
            .config_header_step => |step| {
                std.debug.print("\tConfig Header: {s}\n", .{step.include_path});
            },
            inline else => |dir_str| {
                std.debug.print("\t{s}\n", .{dir_str});
            },
        }
    }
}

pub fn build_wasm3(b: *std.Build, target: anytype, optimize: anytype) *std.Build.CompileStep {
    const wasm3 = b.addStaticLibrary(.{
        .name = "wasm3",
        .target = target,
        .optimize = optimize,
    });
    wasm3.linkLibC();
    wasm3.addCSourceFiles(&.{
        "vendor/wasm3/source/m3_api_libc.c",
        "vendor/wasm3/source/m3_api_meta_wasi.c",
        "vendor/wasm3/source/m3_api_tracer.c",
        "vendor/wasm3/source/m3_api_uvwasi.c",
        "vendor/wasm3/source/m3_api_wasi.c",
        "vendor/wasm3/source/m3_bind.c",
        "vendor/wasm3/source/m3_code.c",
        "vendor/wasm3/source/m3_compile.c",
        "vendor/wasm3/source/m3_core.c",
        "vendor/wasm3/source/m3_env.c",
        "vendor/wasm3/source/m3_exec.c",
        "vendor/wasm3/source/m3_function.c",
        "vendor/wasm3/source/m3_info.c",
        "vendor/wasm3/source/m3_module.c",
        "vendor/wasm3/source/m3_parse.c",
    }, &.{});
    wasm3.installHeader("vendor/wasm3/source/m3_bind.h", "m3_bind.h");
    wasm3.installHeader("vendor/wasm3/source/m3_code.h", "m3_code.h");
    wasm3.installHeader("vendor/wasm3/source/m3_compile.h", "m3_compile.h");
    wasm3.installHeader("vendor/wasm3/source/m3_core.h", "m3_core.h");
    wasm3.installHeader("vendor/wasm3/source/m3_env.h", "m3_env.h");
    wasm3.installHeader("vendor/wasm3/source/m3_exec.h", "m3_exec.h");
    wasm3.installHeader("vendor/wasm3/source/m3_function.h", "m3_function.h");
    wasm3.installHeader("vendor/wasm3/source/m3_info.h", "m3_info.h");
    return wasm3;
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

    const use_gl = b.option(bool, "use-gl", "Use OpenGL for minifb");

    if (use_gl orelse false) {
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

    cubeb.installHeader("exports/cubeb_export.h", "cubeb_export.h");
    cubeb.installHeadersDirectory("vendor/cubeb/include/cubeb", "cubeb");

    return cubeb;
}
