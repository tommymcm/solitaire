const std = @import("std");
const rlz = @import("raylib_zig");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
    });

    const solitaire_mod = b.addModule("solitaire", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    if (target.query.os_tag == .emscripten) {
        const emsdk = rlz.emsdk;
        const raylib_artifact = raylib_dep.artifact("raylib");

        const wasm = b.addLibrary(.{
            .name = "solitaire-wasm",
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/main_gui.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "solitaire", .module = solitaire_mod },
                    .{ .name = "raylib", .module = raylib_dep.module("raylib") },
                    .{ .name = "raygui", .module = raylib_dep.module("raygui") },
                },
            }),
        });

        const install_dir: std.Build.InstallDir = .{ .custom = "web" };
        
        // Add --preload-file assets to emcc flags
        var emcc_flags = emsdk.emccDefaultFlags(b.allocator, .{ .optimize = optimize });
        try emcc_flags.put("--preload-file", {});
        try emcc_flags.put("assets", {});

        var emcc_settings = emsdk.emccDefaultSettings(b.allocator, .{ .optimize = optimize });
        try emcc_settings.put("ALLOW_MEMORY_GROWTH", "1");

        const emcc_step = emsdk.emccStep(b, raylib_artifact, wasm, .{
            .optimize = optimize,
            .flags = emcc_flags,
            .settings = emcc_settings,
            .install_dir = install_dir,
        });
        b.getInstallStep().dependOn(emcc_step);

        const run_step = b.step("run", "Run the app");
        const html_filename = try std.fmt.allocPrint(b.allocator, "{s}.html", .{wasm.name});
        const emrun_step = emsdk.emrunStep(
            b,
            b.getInstallPath(install_dir, html_filename),
            &.{},
        );
        emrun_step.dependOn(emcc_step);
        run_step.dependOn(emrun_step);
    } else {
        const exe = b.addExecutable(.{
            .name = "solitaire",
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/main_cli.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "solitaire", .module = solitaire_mod },
                },
            }),
        });

        b.installArtifact(exe);

        const run_cmd = b.addRunArtifact(exe);
        const run_step = b.step("run", "Run the CLI app");
        run_step.dependOn(&run_cmd.step);

        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        const test_step = b.step("test", "Run tests");
        const mod_tests = b.addTest(.{
            .root_module = solitaire_mod,
        });
        const run_mod_tests = b.addRunArtifact(mod_tests);
        test_step.dependOn(&run_mod_tests.step);

        const test_runner = b.addExecutable(.{
            .name = "test_runner",
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/run_tests.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "solitaire", .module = solitaire_mod },
                },
            }),
        });

        const run_tests_step = b.step("run_tests", "Run custom test runner");
        const run_test_runner = b.addRunArtifact(test_runner);
        run_tests_step.dependOn(&run_test_runner.step);
    }
}
