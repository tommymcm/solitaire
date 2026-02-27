const std = @import("std");
const solitaire = @import("solitaire");
const GameState = solitaire.rules.GameState;
const Io = std.Io;

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    var prng = std.Random.DefaultPrng.init(42);
    const random = prng.random();

    var state = try GameState.init(allocator, random);
    defer state.deinit();

    var stdout_buf: [4096]u8 = undefined;
    var stdout_writer = Io.File.stdout().writer(io, &stdout_buf);
    const stdout = &stdout_writer.interface;

    var stdin_buf: [1024]u8 = undefined;
    var stdin_reader = Io.File.stdin().reader(io, &stdin_buf);
    const stdin = &stdin_reader.interface;

    try stdout.print("Welcome to Card Capture!\n", .{});
    try stdout.flush();

    while (!state.isGameOver()) {
        try stdout.print("\n--- Card Capture ---\n", .{});
        try stdout.print("Score: {} | Deck: {}\n", .{ state.captured_count, state.deck.count() });

        try stdout.print("Field: ", .{});
        for (state.field, 0..) |maybe_card, i| {
            if (maybe_card) |card| {
                try stdout.print("[{}] {f}  ", .{ i + 1, card });
            } else {
                try stdout.print("[{}] --  ", .{ i + 1 });
            }
        }
        try stdout.print("\n", .{});

        const hand = state.hand orelse {
            state.drawNext();
            if (state.hand == null) break;
            continue;
        };
        try stdout.print("Your card: {f}\n", .{hand});

        const captures = try state.findCaptures(allocator);
        defer allocator.free(captures);

        try stdout.print("Enter index (1-4) to capture or 'p' to pass: ", .{});
        try stdout.flush();

        if (try stdin.takeDelimiter('\n')) |line| {
            const trimmed = std.mem.trim(u8, line, " \r\n\t");
            if (trimmed.len == 0) {
                continue;
            }

            if (std.mem.eql(u8, trimmed, "p")) {
                if (captures.len > 0) {
                    try stdout.print("Captures are possible! You must capture.\n", .{});
                } else {
                    _ = try state.applyPlay();
                }
            } else if (std.fmt.parseInt(usize, trimmed, 10)) |choice| {
                if (choice < 1 or choice > 4) {
                    try stdout.print("Choice out of range (1-4)!\n", .{});
                } else {
                    var is_valid_capture = false;
                    for (captures) |c_idx| {
                        if (c_idx == choice - 1) {
                            is_valid_capture = true;
                            break;
                        }
                    }

                    if (is_valid_capture) {
                        _ = try state.applyPlay();
                    } else {
                        try stdout.print("Card at index {} does not match your hand!\n", .{choice});
                    }
                }
            } else |_| {
                try stdout.print("Invalid input! Enter a number (1-4) or 'p'.\n", .{});
            }
        }

        state.drawNext();
    }

    try stdout.print("\nGame Over!\nFinal Score: {}\n", .{state.captured_count});
}
