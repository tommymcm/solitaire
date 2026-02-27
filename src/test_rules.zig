const std = @import("std");
const card = @import("card.zig");
const rules = @import("rules.zig");
const Card = card.Card;
const GameState = rules.GameState;

test "initial field deal filters aces and face cards" {
    const allocator = std.testing.allocator;
    var prng = std.Random.DefaultPrng.init(42);

    var state = try GameState.init(allocator, prng.random());
    defer state.deinit();
    
    for (state.field.items) |maybe_card| {
        if (maybe_card) |c| {
            const r = @intFromEnum(c.rank);
            try std.testing.expect(r != 1 and r < 11);
        }
    }
}

test "deck split initialization" {
    const allocator = std.testing.allocator;
    var prng = std.Random.DefaultPrng.init(42);
    var state = try GameState.init(allocator, prng.random());
    defer state.deinit();

    // Player should have: (3 ranks [2,3,4] * 4 suits) + 2 jokers = 14 cards
    // 4 cards are in hand, so 10 in deck
    try std.testing.expectEqual(@as(usize, 10), state.deck.count());
    
    // Enemy should have: 52 - 12 (ranks 2-4) = 40 cards
    // 4 cards are in field, so 36 in enemy deck
    try std.testing.expectEqual(@as(usize, 36), state.enemy_deck.count());
}

test "capture logic" {
    const allocator = std.testing.allocator;
    var prng = std.Random.DefaultPrng.init(42);
    var player_deck = card.Deck.init(allocator, prng.random());
    var enemy_deck = card.Deck.init(allocator, prng.random());
    try player_deck.fillStandard52();
    try enemy_deck.fillStandard52();

    var state = GameState{
        .deck = player_deck,
        .enemy_deck = enemy_deck,
        .field = .{},
        .hand = .{ null, null, null, null },
        .captured_count = 0,
        .allocator = allocator,
    };
    defer state.deinit();

    // Setup controlled state
    state.hand = .{
        Card{ .rank = .ace, .suit = .hearts },
        null, null, null,
    };
    try state.field.resize(state.allocator, 0);
    try state.field.append(state.allocator, Card{ .rank = .ace, .suit = .spades });
    try state.field.append(state.allocator, Card{ .rank = .two, .suit = .hearts });
    try state.field.append(state.allocator, Card{ .rank = .three, .suit = .diamonds });
    try state.field.append(state.allocator, Card{ .rank = .four, .suit = .clubs });
    state.captured_count = 0;

    const captures = try state.findCaptures(allocator, 0);
    defer allocator.free(captures);

    try std.testing.expectEqual(@as(usize, 2), captures.len);
    // Note: findCaptures might return indices in any order, but usually ascending
    try std.testing.expect(captures[0] == 0); // Same rank
    try std.testing.expect(captures[1] == 1); // Same suit

    // Test applyPlay
    const captured_any = try state.applyPlay(0);
    try std.testing.expect(captured_any);
    try std.testing.expectEqual(@as(usize, 2), state.field.items.len);
    try std.testing.expect(state.hand[0] == null);
    // Captured: hand + 2 from field = 3 cards
    try std.testing.expectEqual(@as(u32, 3), state.captured_count);

    // Test refillHand
    const total_cards = std.meta.fields(card.Suit).len * std.meta.fields(card.Rank).len;
    try std.testing.expectEqual(@as(usize, total_cards), state.deck.count());

    const deck_before = state.deck.count();
    state.refillHand();
    try std.testing.expect(state.hand[0] != null);
    try std.testing.expect(state.hand[1] != null);
    try std.testing.expect(state.hand[2] != null);
    try std.testing.expect(state.hand[3] != null);
    // state.hand[0] was null (from applyPlay), [1][2][3] were null from setup
    try std.testing.expectEqual(@as(usize, deck_before - 4), state.deck.count());
}

test "play to field" {
    const allocator = std.testing.allocator;
    var prng = std.Random.DefaultPrng.init(42);
    var player_deck = card.Deck.init(allocator, prng.random());
    var enemy_deck = card.Deck.init(allocator, prng.random());
    try player_deck.fillStandard52();
    try enemy_deck.fillStandard52();

    var state = GameState{
        .deck = player_deck,
        .enemy_deck = enemy_deck,
        .field = .{},
        .hand = .{ null, null, null, null },
        .captured_count = 0,
        .allocator = allocator,
    };
    defer state.deinit();

    state.hand = .{
        Card{ .rank = .ace, .suit = .hearts },
        null, null, null,
    };
    try state.field.resize(state.allocator, 0);
    try state.field.append(state.allocator, Card{ .rank = .king, .suit = .spades });
    try state.field.append(state.allocator, Card{ .rank = .queen, .suit = .spades });

    const captures = try state.findCaptures(allocator, 0);
    defer allocator.free(captures);
    try std.testing.expectEqual(@as(usize, 0), captures.len);
    
    const captured_any = try state.applyPlay(0);
    try std.testing.expect(!captured_any);
    try std.testing.expectEqual(@as(usize, 3), state.field.items.len);
    try std.testing.expectEqual(Card{ .rank = .ace, .suit = .hearts }, state.field.items[2].?);
    try std.testing.expect(state.hand[0] == null);

    state.refillHand();
    try std.testing.expect(state.hand[0] != null);
}
