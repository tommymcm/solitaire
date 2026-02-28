const std = @import("std");
const solitaire = @import("solitaire");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const allocator = init.gpa;

    var args_it = std.process.Args.Iterator.init(init.minimal.args);
    // Skip executable name
    _ = args_it.next();

    var use_cli = false;
    while (args_it.next()) |arg| {
        if (std.mem.eql(u8, arg, "--cli")) {
            use_cli = true;
        }
    }

    if (use_cli) {
        var seed: u64 = undefined;
        io.random(@ptrCast(&seed));
        var prng = std.Random.DefaultPrng.init(seed);
        const random = prng.random();

        try solitaire.cli.run(io, allocator, random);
    } else {
        var stdout_buf: [128]u8 = undefined;
        var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buf);
        const stdout = &stdout_writer.interface;
        try stdout.print("GUI mode not yet implemented. Run with --cli to play in terminal.\n", .{});
        try stdout.flush();
    }
}
