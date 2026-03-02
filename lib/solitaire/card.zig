const std = @import("std");

pub const Suit = enum {
    hearts,
    diamonds,
    clubs,
    spades,

    pub fn format(
        self: Suit,
        writer: anytype,
    ) !void {
        const s = switch (self) {
            .hearts => "♥",
            .diamonds => "♦",
            .clubs => "♣",
            .spades => "♠",
        };
        try writer.writeAll(s);
    }

    pub fn color(self: Suit) enum { red, black } {
        return switch (self) {
            .hearts, .diamonds => .red,
            .clubs, .spades => .black,
        };
    }
};

pub const Rank = enum(u4) {
    joker = 0,
    ace = 1,
    two,
    three,
    four,
    five,
    six,
    seven,
    eight,
    nine,
    ten,
    jack,
    queen,
    king,

    pub fn value(self: Rank) u8 {
        return switch (self) {
            .joker => 0,
            .ace => 14,
            .two => 2,
            .three => 3,
            .four => 4,
            .five => 5,
            .six => 6,
            .seven => 7,
            .eight => 8,
            .nine => 9,
            .ten => 10,
            .jack => 11,
            .queen => 12,
            .king => 13,
        };
    }

    pub fn format(
        self: Rank,
        writer: anytype,
    ) !void {
        const s = switch (self) {
            .joker => "Jkr",
            .ace => "A",
            .jack => "J",
            .queen => "Q",
            .king => "K",
            .ten => "10",
            else => |r| {
                try writer.print("{d}", .{@intFromEnum(r)});
                return;
            },
        };
        try writer.writeAll(s);
    }
};

pub const Card = struct {
    suit: Suit,
    rank: Rank,

    pub fn format(
        self: Card,
        writer: anytype,
    ) !void {
        if (self.rank == .joker) {
            try writer.writeAll("Jkr");
            return;
        }
        try self.rank.format(writer);
        try self.suit.format(writer);
    }
};

pub const Deck = struct {
    cards: [54]Card = undefined,
    len: usize = 0,
    rng: std.Random,

    pub fn init(_: std.mem.Allocator, rng: std.Random) Deck {
        return .{
            .rng = rng,
        };
    }

    pub fn deinit(_: *Deck) void {}

    pub fn shuffle(self: *Deck) void {
        if (self.len < 2) return;
        var i: usize = self.len - 1;
        while (i > 0) : (i -= 1) {
            const j = self.rng.uintLessThan(usize, i + 1);
            std.mem.swap(Card, &self.cards[i], &self.cards[j]);
        }
    }

    pub fn draw(self: *Deck) ?Card {
        if (self.len == 0) return null;
        const card = self.cards[self.len - 1];
        self.len -= 1;
        return card;
    }

    pub fn putOnBottom(self: *Deck, card: Card) !void {
        if (self.len >= 54) return error.DeckFull;
        // Shift right
        var i: usize = self.len;
        while (i > 0) : (i -= 1) {
            self.cards[i] = self.cards[i - 1];
        }
        self.cards[0] = card;
        self.len += 1;
    }

    pub fn append(self: *Deck, card: Card) !void {
        if (self.len >= 54) return error.DeckFull;
        self.cards[self.len] = card;
        self.len += 1;
    }

    pub fn count(self: Deck) usize {
        return self.len;
    }
};
