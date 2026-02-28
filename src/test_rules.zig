const std = @import("std");
const card = @import("card.zig");
const rules = @import("rules.zig");
const Card = card.Card;
const GameState = rules.GameState;

test "capture logic: same suit, value sum >= target" {
    const allocator = std.testing.allocator;
    var prng = std.Random.DefaultPrng.init(42);
    const random = prng.random();
    
    var state = try GameState.init(allocator, random);
    defer state.deinit();

    // Clear hand and field for controlled test
    for (0..4) |i| {
        state.hand[i] = null;
        state.field[i] = null;
    }

    // Setup hand: 2, 3, 4 of Hearts
    state.hand[0] = Card{ .rank = .two, .suit = .hearts };
    state.hand[1] = Card{ .rank = .three, .suit = .hearts };
    state.hand[2] = Card{ .rank = .four, .suit = .hearts };

    // Setup field: 9 of Hearts
    state.field[0] = Card{ .rank = .nine, .suit = .hearts };

    // Can capture with all three (2+3+4 = 9 >= 9)
    const hand_indices = [_]usize{ 0, 1, 2 };
    try std.testing.expect(state.canCapture(&hand_indices, 0, null));

    // Can't capture with only two (2+3 = 5 < 9)
    const hand_indices_small = [_]usize{ 0, 1 };
    try std.testing.expect(!state.canCapture(&hand_indices_small, 0, null));

    // Can't capture with different suit (not possible here but let's test logic)
    state.field[1] = Card{ .rank = .five, .suit = .spades };
    try std.testing.expect(!state.canCapture(&hand_indices, 1, null));

    // Test applyCapture
    const success = try state.applyCapture(&hand_indices, 0, null);
    try std.testing.expect(success);
    try std.testing.expect(state.field[0] == null);
    try std.testing.expect(state.hand[0] == null);
    try std.testing.expect(state.hand[1] == null);
    try std.testing.expect(state.hand[2] == null);
    // Captured 1 field card
    try std.testing.expectEqual(@as(u32, 1), state.captured_count);
}

test "joker mimic capture" {
    const allocator = std.testing.allocator;
    var prng = std.Random.DefaultPrng.init(42);
    const random = prng.random();
    
    var state = try GameState.init(allocator, random);
    defer state.deinit();

    // Clear hand and field
    for (0..4) |i| {
        state.hand[i] = null;
        state.field[i] = null;
    }

    // Hand: Joker, 2 of Hearts
    state.hand[0] = Card{ .rank = .joker, .suit = .hearts };
    state.hand[1] = Card{ .rank = .two, .suit = .hearts };

    // Field: 10 of Hearts
    state.field[0] = Card{ .rank = .ten, .suit = .hearts };

    // Mimic Ace (value 14) of Hearts
    const mimic_ace = Card{ .rank = .ace, .suit = .hearts };
    const hand_indices = [_]usize{ 0 };

    // Joker as Ace of Hearts can capture 10 of Hearts (14 >= 10)
    try std.testing.expect(state.canCapture(&hand_indices, 0, mimic_ace));

    // Joker as 2 of Hearts cannot capture 10 of Hearts (2 < 10)
    const mimic_two = Card{ .rank = .two, .suit = .hearts };
    try std.testing.expect(!state.canCapture(&hand_indices, 0, mimic_two));

    // Joker + 2 of Hearts, mimicking 2 of Hearts: (2+2 = 4 < 10)
    const hand_indices_two = [_]usize{ 0, 1 };
    try std.testing.expect(!state.canCapture(&hand_indices_two, 0, mimic_two));

    // Joker + 2 of Hearts, mimicking Ace of Hearts: (14+2 = 16 >= 10)
    try std.testing.expect(state.canCapture(&hand_indices_two, 0, mimic_ace));

    const success = try state.applyCapture(&hand_indices_two, 0, mimic_ace);
    try std.testing.expect(success);
}

test "sacrifice logic: lose if face card is sacrificed" {
    const allocator = std.testing.allocator;
    var prng = std.Random.DefaultPrng.init(42);
    const random = prng.random();
    
    var state = try GameState.init(allocator, random);
    defer state.deinit();

    // Clear field
    for (0..4) |i| state.field[i] = null;

    state.hand[0] = Card{ .rank = .king, .suit = .diamonds }; // Face card
    state.field[0] = Card{ .rank = .ten, .suit = .hearts };

    try std.testing.expect(state.sacrifice(0));
    try std.testing.expect(state.is_lost);
    try std.testing.expect(state.isGameOver());
}

test "deck refill from discard pile" {
    const allocator = std.testing.allocator;
    var prng = std.Random.DefaultPrng.init(42);
    const random = prng.random();
    
    var state = try GameState.init(allocator, random);
    defer state.deinit();

    // Empty the deck and hand
    while (state.deck.draw()) |_| {}
    for (0..4) |i| state.hand[i] = null;

    // Put some cards in the discard pile
    try state.discard_pile.cards.append(allocator, Card{ .rank = .ace, .suit = .spades });
    try state.discard_pile.cards.append(allocator, Card{ .rank = .ten, .suit = .hearts });

    // Refill hand should move discard to deck and shuffle
    state.refillHand();

    try std.testing.expectEqual(@as(usize, 0), state.discard_pile.count());
    // 2 cards in hand, 0 in deck because we drew all available
    try std.testing.expect(state.hand[0] != null);
    try std.testing.expect(state.hand[1] != null);
    try std.testing.expectEqual(@as(usize, 0), state.deck.count());
}

test "delay logic" {
    const allocator = std.testing.allocator;
    var prng = std.Random.DefaultPrng.init(42);
    const random = prng.random();
    
    var state = try GameState.init(allocator, random);
    defer state.deinit();

    // Clear field
    for (0..4) |i| state.field[i] = null;

    state.hand[0] = Card{ .rank = .ten, .suit = .diamonds };
    state.hand[1] = Card{ .rank = .nine, .suit = .clubs };
    const target = Card{ .rank = .ace, .suit = .hearts };
    state.field[0] = target;

    const count_before = state.enemy_deck.count();
    try std.testing.expect(try state.delay(.{ 0, 1 }));
    try std.testing.expect(state.field[0] == null);
    try std.testing.expect(state.hand[0] == null);
    try std.testing.expect(state.hand[1] == null);
    try std.testing.expectEqual(count_before + 1, state.enemy_deck.count());
}
