const std = @import("std");
const solitaire = @import("solitaire");
const GameState = solitaire.rules.GameState;
const card_mod = solitaire.card;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var seed: u64 = undefined;
    try std.posix.getrandom(std.mem.asBytes(&seed));
    var prng = std.Random.DefaultPrng.init(seed);
    const random = prng.random();

    var state = try GameState.init(allocator, random);
    defer state.deinit();

    var stdout_buf: [4096]u8 = undefined;
    var stdout_wrap = std.fs.File.stdout().writer(&stdout_buf);
    const stdout = &stdout_wrap.interface;

    var stdin_buf: [1024]u8 = undefined;
    var stdin_wrap = std.fs.File.stdin().reader(&stdin_buf);
    const stdin = &stdin_wrap.interface;

    try stdout.print("Welcome to Menagerie!\n", .{});
    try stdout.flush();

    while (state.phase != .game_over) {
        if (state.phase == .action) {
            try stdout.print("\n==================================================\n", .{});
            try stdout.print("Score: {} | Deck: {} | Discard: {} | Enemy: {}\n", .{
                state.captured_count,
                state.deck.count(),
                state.discard_pile.count(),
                state.enemy_deck.count(),
            });

            try stdout.print("Field: ", .{});
            for (state.field, 0..) |maybe_card, i| {
                if (maybe_card) |c| {
                    try stdout.print("[{}] {f}  ", .{ i + 1, c });
                }
            }
            try stdout.print("\n", .{});

            try stdout.print("Hand:  ", .{});
            for (state.hand, 0..) |maybe_card, i| {
                if (maybe_card) |c| {
                    try stdout.print("[{}] {f}  ", .{ i + 1, c });
                } else {
                    try stdout.print("[{}] --  ", .{i + 1});
                }
            }
            try stdout.print("\n", .{});

            try stdout.print("\nOptions: (c)apture, (s)acrifice, (d)elay, (q)uit\n", .{});
            try stdout.print("Choose action: ", .{});
            try stdout.flush();

            if (try stdin.takeDelimiter('\n')) |line| {
                const trimmed = std.mem.trim(u8, line, " \r\n\t");
                if (trimmed.len == 0) continue;

                if (trimmed[0] == 'q') break;

                if (trimmed[0] == 'c') {
                    try stdout.print("Enter hand card indices to use (e.g. 1, 2): ", .{});
                    try stdout.flush();
                    const h_line = (try stdin.takeDelimiter('\n')) orelse continue;

                    var hand_indices: [4]usize = undefined;
                    var hand_count: usize = 0;

                    var it = std.mem.tokenizeAny(u8, h_line, ", ");
                    select_loop: while (it.next()) |token| {
                        if (std.fmt.parseInt(usize, token, 10)) |idx| {
                            // Ensure this is a valid index.
                            if (idx >= 1 and idx <= 4) {
                                // Skip duplicate indices.
                                for (0..hand_count) |jdx| {
                                    if (hand_indices[jdx] == idx - 1)
                                        continue :select_loop;
                                }

                                hand_indices[hand_count] = idx - 1;
                                hand_count += 1;
                            }
                        } else |_| {}
                    }

                    if (hand_count == 0) {
                        try stdout.print("No valid hand indices selected!\n", .{});
                        try stdout.flush();
                        continue;
                    }

                    var has_joker = false;
                    var has_suited_in_selection = false;
                    for (hand_indices[0..hand_count]) |idx| {
                        if (state.hand[idx].?.rank == .joker) {
                            has_joker = true;
                        } else {
                            has_suited_in_selection = true;
                        }
                    }

                    var joker_mimic: ?card_mod.Card = null;
                    if (has_joker and !has_suited_in_selection) {
                        try stdout.print("Joker selection with no suited cards! Choose a card index in hand to mimic (1-4): ", .{});
                        try stdout.flush();
                        const m_line = (try stdin.takeDelimiter('\n')) orelse continue;
                        const m_trimmed = std.mem.trim(u8, m_line, " \r\n\t");
                        if (std.fmt.parseInt(usize, m_trimmed, 10)) |m_idx_input| {
                            if (m_idx_input >= 1 and m_idx_input <= 4 and state.hand[m_idx_input - 1] != null) {
                                joker_mimic = state.hand[m_idx_input - 1];
                                if (joker_mimic.?.rank == .joker) {
                                    try stdout.print("Cannot mimic another Joker!\n", .{});
                                    try stdout.flush();
                                    continue;
                                }
                            } else {
                                try stdout.print("Invalid mimic choice!\n", .{});
                                try stdout.flush();
                                continue;
                            }
                        } else |_| {
                            try stdout.print("Invalid input!\n", .{});
                            try stdout.flush();
                            continue;
                        }
                    }

                    try stdout.print("Enter field card index to capture (1-4): ", .{});
                    try stdout.flush();
                    const f_line = (try stdin.takeDelimiter('\n')) orelse continue;
                    const f_trimmed = std.mem.trim(u8, f_line, " \r\n\t");
                    if (std.fmt.parseInt(usize, f_trimmed, 10)) |f_idx_input| {
                        if (f_idx_input >= 1 and f_idx_input <= 4) {
                            const f_idx = f_idx_input - 1;
                            if (try state.playCapture(hand_indices[0..hand_count], f_idx, joker_mimic)) {
                                try stdout.print("Successful capture!\n", .{});
                            } else {
                                try stdout.print("Invalid capture!\n", .{});
                                try stdout.flush();
                                continue;
                            }
                        } else {
                            try stdout.print("Invalid field index!\n", .{});
                            try stdout.flush();
                            continue;
                        }
                    } else |_| {
                        try stdout.print("Invalid input!\n", .{});
                        try stdout.flush();
                        continue;
                    }
                } else if (trimmed[0] == 's') {
                    try stdout.print("Enter hand card index to sacrifice (1-4): ", .{});
                    try stdout.flush();
                    const h_line = (try stdin.takeDelimiter('\n')) orelse continue;
                    const h_trimmed = std.mem.trim(u8, h_line, " \r\n\t");
                    if (std.fmt.parseInt(usize, h_trimmed, 10)) |h_idx_input| {
                        if (h_idx_input >= 1 and h_idx_input <= 4) {
                            if (state.playSacrifice(h_idx_input - 1)) {
                                try stdout.print("Card sacrificed. Field card removed.\n", .{});
                            } else {
                                try stdout.print("Invalid sacrifice.\n", .{});
                                try stdout.flush();
                                continue;
                            }
                        }
                    } else |_| {
                        try stdout.print("Invalid input!\n", .{});
                        try stdout.flush();
                        continue;
                    }
                } else if (trimmed[0] == 'd') {
                    try stdout.print("Enter two hand card indices to delay (e.g. 1, 2): ", .{});
                    try stdout.flush();
                    const h_line = (try stdin.takeDelimiter('\n')) orelse continue;
                    var hand_indices: [2]usize = undefined;
                    var count: usize = 0;
                    var it = std.mem.tokenizeAny(u8, h_line, ", ");
                    delay_loop: while (it.next()) |token| {
                        if (std.fmt.parseInt(usize, token, 10)) |idx| {
                            if (idx >= 1 and idx <= 4 and count < 2) {
                                // Skip duplicate indices.
                                for (0..count) |jdx| {
                                    if (hand_indices[jdx] == idx - 1)
                                        continue :delay_loop;
                                }

                                hand_indices[count] = idx - 1;
                                count += 1;
                            }
                        } else |_| {}
                    }
                    if (count == 2) {
                        if (try state.playDelay(hand_indices)) {
                            try stdout.print("Cards sacrificed. Target moved to bottom of enemy deck.\n", .{});
                        } else {
                            try stdout.print("Invalid delay.\n", .{});
                            try stdout.flush();
                            continue;
                        }
                    } else {
                        try stdout.print("Two cards required!\n", .{});
                        try stdout.flush();
                        continue;
                    }
                } else {
                    try stdout.print("Unknown command: {s}\n", .{trimmed});
                    try stdout.flush();
                    continue;
                }
            }
        } else if (state.phase == .discard) {
            // Discard Phase
            try stdout.print("\n--- Discard Phase ---\n", .{});
            try stdout.print("Field: ", .{});
            for (state.field, 0..) |maybe_card, i| {
                if (maybe_card) |c| {
                    try stdout.print("[{}] {f}  ", .{ i + 1, c });
                }
            }
            try stdout.print("\n", .{});

            try stdout.print("Hand:  ", .{});
            for (state.hand, 0..) |maybe_card, i| {
                if (maybe_card) |c| {
                    try stdout.print("[{}] {f}  ", .{ i + 1, c });
                } else {
                    try stdout.print("[{}] --  ", .{i + 1});
                }
            }
            try stdout.print("\nEnter indices to discard (e.g. 1, 3) or Enter to skip: ", .{});
            try stdout.flush();

            if (try stdin.takeDelimiter('\n')) |d_line| {
                var discard_indices: [4]usize = undefined;
                var d_count: usize = 0;
                var d_it = std.mem.tokenizeAny(u8, d_line, ", ");
                discard_loop: while (d_it.next()) |token| {
                    if (std.fmt.parseInt(usize, token, 10)) |idx| {
                        if (idx >= 1 and idx <= 4) {
                            // Skip duplicate indices.
                            for (0..d_count) |jdx| {
                                if (discard_indices[jdx] == idx - 1)
                                    continue :discard_loop;
                            }

                            discard_indices[d_count] = idx - 1;
                            d_count += 1;
                        }
                    } else |_| {}
                }
                try state.playDiscard(discard_indices[0..d_count]);
            }
        }
    }

    if (state.is_lost) {
        try stdout.print("\nYou lost! The enemy took a face card!\n", .{});
    } else {
        try stdout.print("\nGame Over!\nYou survived!\n", .{});
    }
    try stdout.print("Final Score: {}\n", .{state.captured_count});
    try stdout.flush();
}
