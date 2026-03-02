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

    // Hand: Joker, 2 of Hearts, Ace of Hearts
    state.hand[0] = Card{ .rank = .joker, .suit = .hearts };
    state.hand[1] = Card{ .rank = .two, .suit = .hearts };
    state.hand[2] = Card{ .rank = .ace, .suit = .hearts };

    // Field: 10 of Hearts
    state.field[0] = Card{ .rank = .ten, .suit = .hearts };

    // Selection: Joker + 2 of Hearts
    const hand_indices_two = [_]usize{ 0, 1 };
    
    // Auto-mimic will pick Ace of Hearts from hand[2]
    // Total value: 14 + 2 = 16. 16 >= 10.
    try std.testing.expect(state.canCapture(&hand_indices_two, 0, null));

    const success = try state.applyCapture(&hand_indices_two, 0, null);
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
    try state.discard_pile.append(Card{ .rank = .ace, .suit = .spades });
    try state.discard_pile.append(Card{ .rank = .ten, .suit = .hearts });

    // Refill hand should move discard to deck and shuffle
    state.refillHand();

    try std.testing.expectEqual(@as(usize, 0), state.discard_pile.count());
    // 2 cards in hand, 0 in deck because we drew all available
    try std.testing.expect(state.hand[0] != null);
    try std.testing.expect(state.hand[1] != null);
    try std.testing.expectEqual(@as(usize, 0), state.deck.count());
}

test "automated joker mimic" {
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

    // Hand: Joker, 2 of Hearts, 4 of Hearts, 10 of Spades
    state.hand[0] = Card{ .rank = .joker, .suit = .hearts };
    state.hand[1] = Card{ .rank = .two, .suit = .hearts };
    state.hand[2] = Card{ .rank = .four, .suit = .hearts };
    state.hand[3] = Card{ .rank = .ten, .suit = .spades };

    // Field: 6 of Hearts
    state.field[0] = Card{ .rank = .six, .suit = .hearts };

    // Select: Joker + 2 of Hearts.
    // Joker should mimic 4 of Hearts (highest heart in hand).
    // Total value: 4 + 2 = 6. 6 >= 6. Should capture.
    const hand_indices = [_]usize{ 0, 1 };
    
    // Pass null for joker_mimic to ensure auto-mimic kicks in
    try std.testing.expect(state.canCapture(&hand_indices, 0, null));

    const success = try state.applyCapture(&hand_indices, 0, null);
    try std.testing.expect(success);
    try std.testing.expect(state.field[0] == null);
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

test "phase machine transitions" {
    const allocator = std.testing.allocator;
    var prng = std.Random.DefaultPrng.init(42);
    const random = prng.random();
    
    var state = try GameState.init(allocator, random);
    defer state.deinit();

    try std.testing.expectEqual(rules.Phase.action, state.phase);

    // Setup for a capture
    for (0..4) |i| {
        state.hand[i] = null;
        state.field[i] = null;
    }
    state.hand[0] = Card{ .rank = .ace, .suit = .hearts };
    state.field[0] = Card{ .rank = .two, .suit = .hearts };

    const hand_indices = [_]usize{ 0 };
    _ = try state.playCapture(&hand_indices, 0, null);

    try std.testing.expectEqual(rules.Phase.discard, state.phase);

    // playDiscard should move to action
    _ = try state.playDiscard(&[_]usize{});
    try std.testing.expectEqual(rules.Phase.action, state.phase);
    }

    test "playDelay field update" {
        const allocator = std.testing.allocator;
        var prng = std.Random.DefaultPrng.init(42);
        const random = prng.random();

        var state = try GameState.init(allocator, random);
        defer state.deinit();

        // Clear field and hand for controlled test
        for (0..4) |i| {
            state.field[i] = null;
            state.hand[i] = null;
        }

        // Hand: 2, 3 of Hearts
        state.hand[0] = Card{ .rank = .two, .suit = .hearts };
        state.hand[1] = Card{ .rank = .three, .suit = .hearts };

        // Field: [0]=4H, [1]=5H, [2]=6H, [3]=7H
        state.field[0] = Card{ .rank = .four, .suit = .hearts };
        state.field[1] = Card{ .rank = .five, .suit = .hearts };
        state.field[2] = Card{ .rank = .six, .suit = .hearts };
        state.field[3] = Card{ .rank = .seven, .suit = .hearts };

        const enemy_count_before = state.enemy_deck.count();

        // Perform delay action
        try std.testing.expect(try state.playDelay(.{ 0, 1 }));

        // Verify target (4H) is at the bottom of enemy deck
        // One card was added to bottom, one card was drawn to refill field.
        // So net change to enemy deck count should be 0.
        try std.testing.expectEqual(@as(usize, enemy_count_before), state.enemy_deck.count());
        try std.testing.expectEqual(Card{ .rank = .four, .suit = .hearts }, state.enemy_deck.cards[0]);

        // Verify field state after refill
        // Slot [0] should now be 5H
        try std.testing.expect(state.field[0] != null);
        try std.testing.expectEqual(Card{ .rank = .five, .suit = .hearts }, state.field[0].?);
        // Slot [1] should now be 6H
        try std.testing.expect(state.field[1] != null);
        try std.testing.expectEqual(Card{ .rank = .six, .suit = .hearts }, state.field[1].?);
        // Slot [2] should now be 7H
        try std.testing.expect(state.field[2] != null);
        try std.testing.expectEqual(Card{ .rank = .seven, .suit = .hearts }, state.field[2].?);
        // Slot [3] should be a new card from enemy deck (not null)
        try std.testing.expect(state.field[3] != null);
    }

