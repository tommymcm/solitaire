const std = @import("std");
const card_mod = @import("card.zig");
const Card = card_mod.Card;
const Deck = card_mod.Deck;

pub const GameState = struct {
    deck: Deck, // Player's deck
    enemy_deck: Deck,
    field: std.ArrayList(?Card),
    hand: [4]?Card,
    captured_count: u32,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, rng: std.Random) !GameState {
        var player_deck = Deck.init(allocator, rng);
        var enemy_deck = Deck.init(allocator, rng);

        // Populate decks based on rules:
        // Player: 2-4 of each suit + 2 jokers
        // Enemy: everything else
        inline for (std.meta.fields(card_mod.Suit)) |s_field| {
            const suit = @as(card_mod.Suit, @enumFromInt(s_field.value));
            inline for (std.meta.fields(card_mod.Rank)) |r_field| {
                const rank = @as(card_mod.Rank, @enumFromInt(r_field.value));
                if (rank == .joker) continue; // Handle jokers separately

                const c = Card{ .suit = suit, .rank = rank };
                const rank_int = @intFromEnum(rank);
                if (rank_int >= 2 and rank_int <= 4) {
                    try player_deck.cards.append(allocator, c);
                } else {
                    try enemy_deck.cards.append(allocator, c);
                }
            }
        }
        
        // Add 2 jokers to player deck (suit doesn't matter for jokers usually)
        try player_deck.cards.append(allocator, .{ .suit = .hearts, .rank = .joker });
        try player_deck.cards.append(allocator, .{ .suit = .spades, .rank = .joker });

        player_deck.shuffle();
        enemy_deck.shuffle();

        var state = GameState{
            .deck = player_deck,
            .enemy_deck = enemy_deck,
            .field = .{},
            .hand = .{ null, null, null, null },
            .captured_count = 0,
            .allocator = allocator,
        };

        // Initial deal to field (4 cards from ENEMY deck?)
        // Usually if there's an enemy, the field might come from their deck.
        for (0..4) |_| {
            try state.field.append(allocator, state.enemy_deck.draw());
        }
        
        // Initial draw to hand (4 cards from PLAYER deck)
        state.refillHand();

        return state;
    }

    pub fn deinit(self: *GameState) void {
        self.deck.deinit();
        self.enemy_deck.deinit();
        self.field.deinit(self.allocator);
    }

    pub fn refillHand(self: *GameState) void {
        for (0..4) |i| {
            if (self.hand[i] == null) {
                self.hand[i] = self.deck.draw();
            }
        }
    }

    /// Finds all indices in the field that can be captured by the card at hand_index.
    pub fn findCaptures(self: GameState, allocator: std.mem.Allocator, hand_index: usize) ![]usize {
        const card = self.hand[hand_index] orelse return &[_]usize{};
        var indices = std.ArrayList(usize){};
        errdefer indices.deinit(allocator);

        for (self.field.items, 0..) |maybe_card, i| {
            if (maybe_card) |target| {
                if (target.rank == card.rank or target.suit == card.suit) {
                    try indices.append(allocator, i);
                }
            }
        }
        return indices.toOwnedSlice(allocator);
    }

    /// Applies the play for a specific hand card.
    pub fn applyPlay(self: *GameState, hand_index: usize) !bool {
        const card = self.hand[hand_index] orelse return false;
        const captures = try self.findCaptures(self.allocator, hand_index);
        defer self.allocator.free(captures);

        if (captures.len > 0) {
            // Sort indices in descending order to safely remove from ArrayList
            // Actually, we are using ?Card, so we can just set to null, 
            // but the rule usually says they are removed from the field.
            // If we remove them, the field shrinks.
            
            // For now, let's keep the null-out behavior or actually remove them?
            // "removed from field" usually means the row gets shorter.
            
            // To avoid shifting indices while iterating:
            var i: usize = captures.len;
            while (i > 0) {
                i -= 1;
                const field_idx = captures[i];
                _ = self.field.orderedRemove(field_idx);
                self.captured_count += 1;
            }
            self.captured_count += 1; // Plus the hand card itself
            self.hand[hand_index] = null;
            return true;
        } else {
            // No captures, play to field
            try self.field.append(self.allocator, card);
            self.hand[hand_index] = null;
            return false;
        }
    }

    /// Refills the field from the enemy deck.
    pub fn drawNextEnemy(self: *GameState) !void {
        while (self.field.items.len < 4) {
            if (self.enemy_deck.draw()) |card| {
                try self.field.append(self.allocator, card);
            } else break;
        }
    }

    pub fn isGameOver(self: GameState) bool {
        // Hand empty and deck empty
        for (self.hand) |h| {
            if (h != null) return false;
        }
        return self.deck.count() == 0;
    }
};
