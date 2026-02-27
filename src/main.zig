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
        state.refillHand();
        if (state.isGameOver()) break;

        try stdout.print("\n--- Card Capture ---\n", .{});
        try stdout.print("Score: {} | Deck: {}\n", .{ state.captured_count, state.deck.count() });

        try stdout.print("Field: ", .{});
        for (state.field.items, 0..) |maybe_card, i| {
            if (maybe_card) |card| {
                try stdout.print("[{}] {f}  ", .{ i + 1, card });
            }
        }
        try stdout.print("\n", .{});

        try stdout.print("Hand:  ", .{});
        for (state.hand, 0..) |maybe_card, i| {
            if (maybe_card) |card| {
                try stdout.print("[{}] {f}  ", .{ i + 1, card });
            } else {
                try stdout.print("[{}] --  ", .{ i + 1 });
            }
        }
        try stdout.print("\n", .{});

        try stdout.print("Choose a card from your hand (1-4) to play: ", .{});
        try stdout.flush();

        if (try stdin.takeDelimiter('\n')) |line| {
            const trimmed = std.mem.trim(u8, line, " \r\n\t");
            if (trimmed.len == 0) continue;

            if (std.fmt.parseInt(usize, trimmed, 10)) |hand_choice| {
                if (hand_choice < 1 or hand_choice > 4 or state.hand[hand_choice - 1] == null) {
                    try stdout.print("Invalid hand choice!\n", .{});
                    continue;
                }
                
                const hand_idx = hand_choice - 1;
                const captures = try state.findCaptures(allocator, hand_idx);
                defer allocator.free(captures);

                if (captures.len > 0) {
                    try stdout.print("Capturing {} cards!\n", .{captures.len});
                } else {
                    try stdout.print("No captures. Card added to field.\n", .{});
                }
                _ = try state.applyPlay(hand_idx);
            } else |_| {
                try stdout.print("Invalid input! Enter 1-4.\n", .{});
                continue;
            }
        }
    }

    try stdout.print("\nGame Over!\nFinal Score: {}\n", .{state.captured_count});
}
