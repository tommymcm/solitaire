const std = @import("std");
const card_mod = @import("card.zig");
const Card = card_mod.Card;
const Deck = card_mod.Deck;

// Game rules for "Card Capture".
// Card Capture is a deck-building solitaire game where the player 'purchases'
// cards from the enemy queue. If they aren't able to purchase a card, they
// must sacrifice card(s). But watch out! If the enemy ever takes a face card,
// you lose!

pub const Phase = enum {
    action,
    discard,
    game_over,
};

pub const GameState = struct {
    deck: Deck, // Player's deck
    enemy_deck: Deck,
    discard_pile: Deck,
    field: [4]?Card,
    hand: [4]?Card,
    captured_count: u32,
    allocator: std.mem.Allocator,
    is_lost: bool = false,
    is_won: bool = false,
    phase: Phase = .action,

    pub fn emptyHand(self: GameState) bool {
        for (self.hand) |maybe_card| {
            if (maybe_card != null) return false;
        }
        return true;
    }

    fn isFaceCard(c: Card) bool {
        return switch (c.rank) {
            .ace, .jack, .queen, .king => true,
            else => false,
        };
    }

    pub fn init(allocator: std.mem.Allocator, rng: std.Random) !GameState {
        var player_deck = Deck.init(allocator, rng);
        var enemy_deck = Deck.init(allocator, rng);

        // Populate decks based on rules:
        // Player: 2-4 of each suit + 2 jokers
        // Enemy: everything else
        for (std.enums.values(card_mod.Suit)) |suit| {
            for (std.enums.values(card_mod.Rank)) |rank| {
                if (rank == .joker) continue; // Handle jokers separately

                const c = Card{ .suit = suit, .rank = rank };
                const rank_int = @intFromEnum(rank);
                if (rank_int >= 2 and rank_int <= 4) {
                    try player_deck.append(c);
                } else {
                    try enemy_deck.append(c);
                }
            }
        }

        // Add 2 jokers to player deck
        try player_deck.append(.{ .suit = .hearts, .rank = .joker });
        try player_deck.append(.{ .suit = .spades, .rank = .joker });

        enemy_deck.shuffle();
        player_deck.shuffle();

        var state = GameState{
            .deck = player_deck,
            .enemy_deck = enemy_deck,
            .discard_pile = Deck.init(allocator, rng),
            .field = .{ null, null, null, null },
            .hand = .{ null, null, null, null },
            .captured_count = 0,
            .allocator = allocator,
        };

        // Initial deal to field (4 cards from ENEMY deck)
        var dealt: usize = 0;
        while (dealt < 4) {
            if (state.enemy_deck.draw()) |c| {
                const rank_int = @intFromEnum(c.rank);
                if (rank_int == 1 or rank_int >= 11) {
                    try state.enemy_deck.putOnBottom(c);
                } else {
                    var i: usize = 0;
                    while (i < 4) : (i += 1) {
                        if (state.field[i] == null) {
                            state.field[i] = c;
                            break;
                        }
                    }
                    dealt += 1;
                }
            } else break;
        }

        state.refillHand();
        return state;
    }

    pub fn deinit(self: *GameState) void {
        self.deck.deinit();
        self.enemy_deck.deinit();
        self.discard_pile.deinit();
    }

    pub fn marchField(self: *GameState) void {
        var i: u8 = 0;
        while (i < 4) : (i += 1) {
            if (self.field[i] == null) {
                var j: u8 = i + 1;
                while (j < 4) : (j += 1) {
                    if (self.field[j] != null) {
                        self.field[i] = self.field[j];
                        self.field[j] = null;
                        break;
                    }
                }
            }
        }
    }

    pub fn sacrifice(self: *GameState, hand_idx: usize) bool {
        if (hand_idx >= 4) return false;
        const h_card = self.hand[hand_idx] orelse return false;
        const f_card = self.field[0] orelse return false;

        if (isFaceCard(h_card) or isFaceCard(f_card)) {
            self.is_lost = true;
        }

        self.hand[hand_idx] = null;
        self.field[0] = null;
        return true;
    }

    pub fn delay(self: *GameState, hand_indices: [2]usize) !bool {
        if (hand_indices[0] >= 4 or hand_indices[1] >= 4) return false;
        if (hand_indices[0] == hand_indices[1]) return false;
        const h1 = self.hand[hand_indices[0]] orelse return false;
        const h2 = self.hand[hand_indices[1]] orelse return false;
        if (self.field[0] == null) return false;

        if (isFaceCard(h1) or isFaceCard(h2)) {
            self.is_lost = true;
        }

        const target = self.field[0].?;
        self.field[0] = null;
        try self.enemy_deck.putOnBottom(target);

        self.hand[hand_indices[0]] = null;
        self.hand[hand_indices[1]] = null;
        return true;
    }

    pub fn refillHand(self: *GameState) void {
        for (0..4) |i| {
            if (self.hand[i] == null) {
                if (self.deck.draw()) |c| {
                    self.hand[i] = c;
                } else {
                    if (self.discard_pile.count() > 0) {
                        while (self.discard_pile.draw()) |c| {
                            self.deck.append(c) catch {};
                        }
                        self.deck.shuffle();
                        self.hand[i] = self.deck.draw();
                    }
                }
            }
        }
    }

    pub fn canCapture(self: GameState, hand_indices: []const usize, field_idx: usize, joker_mimic: ?card_mod.Card) bool {
        if (field_idx >= 4) return false;
        const target = self.field[field_idx] orelse return false;
        if (hand_indices.len == 0) return false;

        var common_suit: ?card_mod.Suit = null;
        var has_suited_card = false;

        for (hand_indices) |idx| {
            const h_card = self.hand[idx] orelse return false;
            if (h_card.rank != .joker) {
                has_suited_card = true;
                if (common_suit == null) {
                    common_suit = h_card.suit;
                } else if (common_suit != h_card.suit) {
                    return false;
                }
            }
        }

        var effective_mimic = joker_mimic;
        if (has_suited_card) {
            const suit = common_suit.?;
            var max_val: u8 = 0;
            var best_card: ?card_mod.Card = null;
            for (self.hand) |maybe_card| {
                if (maybe_card) |c| {
                    if (c.suit == suit and c.rank != .joker) {
                        const v = c.rank.value();
                        if (v > max_val) {
                            max_val = v;
                            best_card = c;
                        }
                    }
                }
            }
            effective_mimic = best_card;
        }

        var total_value: u32 = 0;
        var final_suit: ?card_mod.Suit = null;

        for (hand_indices) |idx| {
            const h_card = self.hand[idx] orelse return false;
            var effective_card = h_card;
            if (h_card.rank == .joker) {
                if (effective_mimic) |m| {
                    effective_card = m;
                } else {
                    return false;
                }
            }
            if (final_suit == null) {
                final_suit = effective_card.suit;
            } else if (final_suit != effective_card.suit) {
                return false;
            }
            total_value += effective_card.rank.value();
        }

        if (final_suit != target.suit) return false;
        return total_value >= target.rank.value();
    }

    pub fn applyCapture(self: *GameState, hand_indices: []const usize, field_idx: usize, joker_mimic: ?card_mod.Card) !bool {
        if (!self.canCapture(hand_indices, field_idx, joker_mimic)) return false;

        const target = self.field[field_idx].?;
        self.field[field_idx] = null;
        try self.discard_pile.append(target);
        self.captured_count += 1;

        for (hand_indices) |idx| {
            const h_card = self.hand[idx].?;
            self.hand[idx] = null;
            try self.discard_pile.append(h_card);
        }

        return true;
    }

    pub fn discardFromHand(self: *GameState, indices: []const usize) !void {
        for (indices) |idx| {
            if (idx < 4) {
                if (self.hand[idx]) |c| {
                    try self.discard_pile.append(c);
                    self.hand[idx] = null;
                }
            }
        }
    }

    pub fn drawNextEnemy(self: *GameState) !void {
        self.marchField();
        self.field[3] = self.enemy_deck.draw();
    }

    pub fn playCapture(self: *GameState, hand_indices: []const usize, field_idx: usize, joker_mimic: ?Card) !bool {
        if (self.phase != .action) return false;
        if (try self.applyCapture(hand_indices, field_idx, joker_mimic)) {
            try self.endActionPhase();
            return true;
        }
        return false;
    }

    pub fn playSacrifice(self: *GameState, hand_idx: usize) bool {
        if (self.phase != .action) return false;
        if (self.sacrifice(hand_idx)) {
            self.endActionPhase() catch {};
            return true;
        }
        return false;
    }

    pub fn playDelay(self: *GameState, hand_indices: [2]usize) !bool {
        if (self.phase != .action) return false;
        if (try self.delay(hand_indices)) {
            try self.endActionPhase();
            return true;
        }
        return false;
    }

    pub fn playDiscard(self: *GameState, indices: []const usize) !void {
        if (self.phase != .discard) return;
        try self.discardFromHand(indices);
        self.refillHand();
        self.checkGameOver();
        if (self.phase != .game_over) self.phase = .action;
    }

    pub fn endActionPhase(self: *GameState) !void {
        try self.drawNextEnemy();
        self.checkGameOver();
        if (self.phase != .game_over) self.phase = .discard;
    }

    pub fn checkGameOver(self: *GameState) void {
        if (self.is_lost) {
            self.phase = .game_over;
            return;
        }

        // Win condition: Enemy deck empty AND field empty
        var field_empty = true;
        for (self.field) |f| if (f != null) { field_empty = false; };
        
        if (self.enemy_deck.count() == 0 and field_empty) {
            self.is_won = true;
            self.phase = .game_over;
            return;
        }

        // Standard lose condition: Out of options
        // If player deck and discard are empty AND hand empty
        var hand_empty = true;
        for (self.hand) |h| if (h != null) { hand_empty = false; };

        if (hand_empty and self.deck.count() == 0 and self.discard_pile.count() == 0) {
            self.is_lost = true;
            self.phase = .game_over;
        }
    }
};
