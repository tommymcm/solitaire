const std = @import("std");
const solitaire = @import("solitaire");
const ScoundrelState = solitaire.scoundrel.ScoundrelState;
const card_mod = solitaire.card;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var seed: u64 = undefined;
    try std.posix.getrandom(std.mem.asBytes(&seed));
    var prng = std.Random.DefaultPrng.init(seed);
    const random = prng.random();

    var state = try ScoundrelState.init(allocator, random);
    defer state.deinit();

    var stdout_buf: [4096]u8 = undefined;
    var stdout_wrap = std.fs.File.stdout().writer(&stdout_buf);
    const stdout = &stdout_wrap.interface;

    var stdin_buf: [1024]u8 = undefined;
    var stdin_wrap = std.fs.File.stdin().reader(&stdin_buf);
    const stdin = &stdin_wrap.interface;

    try stdout.print("Welcome to Scoundrel!\n", .{});
    try stdout.flush();

    while (!state.is_won and !state.is_lost) {
        try stdout.print("\n==================================================\n", .{});
        try stdout.print("HP: {d}/{d} | Deck: {d} | Removed: {d}\n", .{
            state.health,
            state.max_health,
            state.deck.count(),
            state.removed_pile.count(),
        });

        if (state.active_card) |weapon| {
            if (state.monster_stack.count() > 0) {
                const top_monster = state.monster_stack.cards[state.monster_stack.len - 1];
                try stdout.print("Weapon: {f} (Last Monster: {f}, Stack: {d})\n", .{ weapon, top_monster, state.monster_stack.count() });
            } else {
                try stdout.print("Weapon: {f} (Monster Stack: empty)\n", .{ weapon });
            }
        } else {
            try stdout.print("Weapon: None (Unarmed)\n", .{});
        }

        try stdout.print("\nField (Room):\n", .{});
        for (state.field, 0..) |maybe_card, i| {
            if (maybe_card) |c| {
                try stdout.print("[{d}] {f}  ", .{ i + 1, c });
            } else {
                try stdout.print("[{d}] --  ", .{i + 1});
            }
        }
        try stdout.print("\n", .{});

        // Auto-advance if room is cleared or player must advance
        if (state.canAdvanceRoom()) {
            if (state.deck.count() == 0 and state.canAdvanceRoom()) {
                // If deck is empty, we still need to finish the current field
                var all_done = true;
                for (state.field) |slot| if (slot != null) {
                    all_done = false;
                    break;
                };
                if (all_done) break;
            } else {
                try stdout.print("\nRoom interaction limit reached (3 cards) or cleared! Press Enter to deal next room...", .{});
                try stdout.flush();
                _ = (try stdin.takeDelimiter('\n')) orelse break;
                try state.dealRoom();
                continue;
            }
        }

        try stdout.print("\nOptions: (1-4) Use Card, (e)scape, (q)uit\n", .{});
        try stdout.print("Choose action: ", .{});
        try stdout.flush();

        if (try stdin.takeDelimiter('\n')) |line| {
            const trimmed = std.mem.trim(u8, line, " \r\n\t");
            if (trimmed.len == 0) continue;

            if (trimmed[0] == 'q') break;
            if (trimmed[0] == 'e') {
                if (try state.escape()) {
                    try stdout.print("Escaped to a new room!\n", .{});
                } else {
                    try stdout.print("Cannot escape! You must clear the room or you already escaped once.\n", .{});
                }
                try stdout.flush();
                continue;
            }

            if (trimmed[0] >= '1' and trimmed[0] <= '4') {
                const idx = @as(usize, trimmed[0] - '1');
                const card = state.field[idx] orelse {
                    try stdout.print("Slot is empty!\n", .{});
                    try stdout.flush();
                    continue;
                };

                var use_weapon = false;
                if (card.suit == .spades or card.suit == .clubs) {
                    if (state.active_card != null) {
                        try stdout.print("Fight with weapon? (y/n): ", .{});
                        try stdout.flush();
                        if (try stdin.takeDelimiter('\n')) |fight_line| {
                            const fight_trimmed = std.mem.trim(u8, fight_line, " \r\n\t");
                            if (fight_trimmed.len > 0 and fight_trimmed[0] == 'y') {
                                use_weapon = true;
                            }
                        }
                    }
                }

                state.useCard(idx, use_weapon) catch |err| {
                    try stdout.print("Action failed: {any}\n", .{err});
                    try stdout.flush();
                    continue;
                };
            } else {
                try stdout.print("Unknown command: {s}\n", .{trimmed});
                try stdout.flush();
            }
        } else break;
    }

    try stdout.print("\n==================================================\n", .{});
    if (state.is_won) {
        try stdout.print("VICTORY! You cleared the dungeon!\n", .{});
    } else if (state.is_lost) {
        try stdout.print("DEFEAT... You died in the dungeon.\n", .{});
    }
    try stdout.print("Final HP: {d}\n", .{state.health});
    try stdout.flush();
}
