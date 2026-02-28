const std = @import("std");
const solitaire = @import("solitaire");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var use_cli = false;
    for (args[1..]) |arg| {
        if (std.mem.eql(u8, arg, "--cli")) {
            use_cli = true;
        }
    }

    if (use_cli) {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        var prng = std.Random.DefaultPrng.init(seed);
        const random = prng.random();

        try solitaire.cli.run(allocator, random);
    } else {
        var stdout_wrap = std.fs.File.stdout().writer(&.{});
        const stdout = &stdout_wrap.interface;
        try stdout.print("GUI mode not yet implemented. Run with --cli to play in terminal.\n", .{});
    }
}
