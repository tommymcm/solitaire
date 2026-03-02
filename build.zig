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
        .root_source_file = b.path("lib/solitaire/root.zig"),
        .target = target,
    });

    const solitaire_gui_mod = b.addModule("solitaire_gui", .{
        .root_source_file = b.path("lib/solitaire_gui/gui_root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "solitaire", .module = solitaire_mod },
            .{ .name = "raylib", .module = raylib_dep.module("raylib") },
        },
    });

    // Loop over directories in src/ to find games
    var src_dir = try b.build_root.handle.openDir("src", .{ .iterate = true });
    defer src_dir.close();

    var iter = src_dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind != .directory) continue;

        const game_name = entry.name;
        
        // Check for GUI Version
        const main_gui_rel_path = b.fmt("src/{s}/main_gui.zig", .{game_name});
        const has_gui = if (std.fs.cwd().access(main_gui_rel_path, .{})) |_| true else |_| false;

        if (has_gui) {
            if (target.query.os_tag == .emscripten) {
                const emsdk = rlz.emsdk;
                const raylib_artifact = raylib_dep.artifact("raylib");

                const wasm = b.addLibrary(.{
                    .name = game_name,
                    .root_module = b.createModule(.{
                        .root_source_file = b.path(main_gui_rel_path),
                        .target = target,
                        .optimize = optimize,
                        .imports = &.{
                            .{ .name = "solitaire", .module = solitaire_mod },
                            .{ .name = "solitaire_gui", .module = solitaire_gui_mod },
                            .{ .name = "raylib", .module = raylib_dep.module("raylib") },
                            .{ .name = "raygui", .module = raylib_dep.module("raygui") },
                        },
                    }),
                });

                const install_dir: std.Build.InstallDir = .{ .custom = "web" };

                const emcc_flags = emsdk.emccDefaultFlags(b.allocator, .{ .optimize = optimize });
                var emcc_settings = emsdk.emccDefaultSettings(b.allocator, .{ .optimize = optimize });
                try emcc_settings.put("ALLOW_MEMORY_GROWTH", "1");

                const emcc_step = emsdk.emccStep(b, raylib_artifact, wasm, .{
                    .optimize = optimize,
                    .flags = emcc_flags,
                    .settings = emcc_settings,
                    .install_dir = install_dir,
                    .embed_paths = &.{
                        .{ .src_path = "assets/", .virtual_path = "assets/" },
                    },
                });
                b.getInstallStep().dependOn(emcc_step);

                const run_step = b.step(b.fmt("run-{s}", .{game_name}), b.fmt("Run {s}", .{game_name}));
                const html_filename = try std.fmt.allocPrint(b.allocator, "{s}.html", .{wasm.name});
                const emrun_step = emsdk.emrunStep(
                    b,
                    b.getInstallPath(install_dir, html_filename),
                    &.{},
                );
                emrun_step.dependOn(emcc_step);
                run_step.dependOn(emrun_step);

                if (std.mem.eql(u8, game_name, "card-capture")) {
                    const generic_run = b.step("run", "Run the default game");
                    generic_run.dependOn(run_step);
                }
            } else {
                const exe = b.addExecutable(.{
                    .name = b.fmt("{s}-gui", .{game_name}),
                    .root_module = b.createModule(.{
                        .root_source_file = b.path(main_gui_rel_path),
                        .target = target,
                        .optimize = optimize,
                        .imports = &.{
                            .{ .name = "solitaire", .module = solitaire_mod },
                            .{ .name = "solitaire_gui", .module = solitaire_gui_mod },
                            .{ .name = "raylib", .module = raylib_dep.module("raylib") },
                            .{ .name = "raygui", .module = raylib_dep.module("raygui") },
                        },
                    }),
                });
                b.installArtifact(exe);
            }
        }

        // Check for CLI Version
        if (target.query.os_tag != .emscripten) {
            const main_cli_rel_path = b.fmt("src/{s}/main_cli.zig", .{game_name});
            const has_cli = if (std.fs.cwd().access(main_cli_rel_path, .{})) |_| true else |_| false;

            if (has_cli) {
                const exe = b.addExecutable(.{
                    .name = b.fmt("{s}-cli", .{game_name}),
                    .root_module = b.createModule(.{
                        .root_source_file = b.path(main_cli_rel_path),
                        .target = target,
                        .optimize = optimize,
                        .imports = &.{
                            .{ .name = "solitaire", .module = solitaire_mod },
                        },
                    }),
                });

                b.installArtifact(exe);

                const run_cmd = b.addRunArtifact(exe);
                const run_step = b.step(b.fmt("run-{s}-cli", .{game_name}), b.fmt("Run the CLI version of {s}", .{game_name}));
                run_step.dependOn(&run_cmd.step);
            }
        }
    }

    // Generic test step
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
