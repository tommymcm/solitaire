const std = @import("std");

pub fn main() !void {
    var stdout_wrap = std.fs.File.stdout().writer(&.{});
    const stdout = &stdout_wrap.interface;

    try stdout.print("Custom test runner is currently a placeholder.\n", .{});
    try stdout.print("Please use `zig build test` to run all tests.\n", .{});
}
