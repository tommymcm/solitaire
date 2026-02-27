const std = @import("std");
const card_mod = @import("card.zig");
const Card = card_mod.Card;
const Deck = card_mod.Deck;

pub const GameState = struct {
    deck: Deck,
    field: [4]?Card,
    hand: ?Card,
    captured_count: u32,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, rng: std.Random) !GameState {
        var deck = Deck.init(allocator, rng);
        try deck.fillStandard52();
        deck.shuffle();

        var state = GameState{
            .deck = deck,
            .field = .{ null, null, null, null },
            .hand = null,
            .captured_count = 0,
            .allocator = allocator,
        };

        // Initial deal to field
        for (0..4) |i| {
            state.field[i] = state.deck.draw();
        }
        // Initial draw to hand
        state.hand = state.deck.draw();

        return state;
    }

    pub fn deinit(self: *GameState) void {
        self.deck.deinit();
    }

    /// Finds all indices in the field that can be captured by the hand card.
    /// Returns an allocated slice of indices. Caller must free.
    pub fn findCaptures(self: GameState, allocator: std.mem.Allocator) ![]usize {
        const hand = self.hand orelse return &[_]usize{};
        var indices = std.ArrayList(usize){};
        errdefer indices.deinit(allocator);

        for (self.field, 0..) |maybe_card, i| {
            if (maybe_card) |target| {
                if (target.rank == hand.rank or target.suit == hand.suit) {
                    try indices.append(allocator, i);
                }
            }
        }
        return indices.toOwnedSlice(allocator);
    }

    /// Applies the play: if captures are possible, capture them all.
    /// If not, play the hand card to the first empty field slot.
    /// Returns true if any captures occurred.
    pub fn applyPlay(self: *GameState) !bool {
        const captures = try self.findCaptures(self.allocator);
        defer self.allocator.free(captures);

        if (captures.len > 0) {
            for (captures) |idx| {
                self.field[idx] = null;
                self.captured_count += 1;
            }
            self.captured_count += 1; // Plus the hand card itself
            self.hand = null;
            return true;
        } else {
            // No captures, play to field
            for (0..4) |i| {
                if (self.field[i] == null) {
                    self.field[i] = self.hand;
                    self.hand = null;
                    return false;
                }
            }
            // If field is full and no captures, the card is just "lost" or discarded?
            // The rules are a bit vague here, but let's just discard it for now
            // to avoid crashing, and increment count? No, usually it just goes away.
            self.hand = null;
            return false;
        }
    }

    pub fn drawNext(self: *GameState) void {
        if (self.hand == null) {
            self.hand = self.deck.draw();
        }
        // Optional: Refill field? The rules don't say. 
        // Let's refill empty slots if deck has cards, to keep the game moving.
        for (0..4) |i| {
            if (self.field[i] == null) {
                self.field[i] = self.deck.draw();
            }
        }
    }

    pub fn isGameOver(self: GameState) bool {
        return self.hand == null and self.deck.count() == 0;
    }
};
