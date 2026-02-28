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
    cards: std.ArrayListUnmanaged(Card),
    rng: std.Random,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, rng: std.Random) Deck {
        return .{
            .cards = .{},
            .rng = rng,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Deck) void {
        self.cards.deinit(self.allocator);
    }

    pub fn fillStandard52(self: *Deck) !void {
        try self.cards.resize(self.allocator, 0);
        inline for (std.meta.fields(Suit)) |s_field| {
            const suit = @as(Suit, @enumFromInt(s_field.value));
            inline for (std.meta.fields(Rank)) |r_field| {
                const rank = @as(Rank, @enumFromInt(r_field.value));
                try self.cards.append(self.allocator, .{ .suit = suit, .rank = rank });
            }
        }
    }

    pub fn shuffle(self: *Deck) void {
        const slice = self.cards.items;
        if (slice.len < 2) return;
        var i: usize = slice.len - 1;
        while (i > 0) : (i -= 1) {
            const j = self.rng.uintLessThan(usize, i + 1);
            std.mem.swap(Card, &slice[i], &slice[j]);
        }
    }

    pub fn draw(self: *Deck) ?Card {
        return self.cards.pop();
    }

    pub fn putOnBottom(self: *Deck, card: Card) !void {
        try self.cards.insert(self.allocator, 0, card);
    }

    pub fn count(self: Deck) usize {
        return self.cards.items.len;
    }
};
