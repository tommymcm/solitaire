const std = @import("std");
const card = @import("card.zig");
const rules = @import("rules.zig");
const Card = card.Card;
const GameState = rules.GameState;

test "capture logic" {
    const allocator = std.testing.allocator;
    var prng = std.Random.DefaultPrng.init(42);
    var state = try GameState.init(allocator, prng.random());
    defer state.deinit();

    // Setup controlled state
    state.hand = Card{ .rank = .ace, .suit = .hearts };
    state.field[0] = Card{ .rank = .ace, .suit = .spades };
    state.field[1] = Card{ .rank = .two, .suit = .hearts };
    state.field[2] = Card{ .rank = .three, .suit = .diamonds };
    state.field[3] = Card{ .rank = .four, .suit = .clubs };
    state.captured_count = 0;

    const captures = try state.findCaptures(allocator);
    defer allocator.free(captures);

    try std.testing.expectEqual(@as(usize, 2), captures.len);
    try std.testing.expect(captures[0] == 0); // Same rank
    try std.testing.expect(captures[1] == 1); // Same suit

    // Test applyPlay
    const captured_any = try state.applyPlay();
    try std.testing.expect(captured_any);
    try std.testing.expect(state.field[0] == null);
    try std.testing.expect(state.field[1] == null);
    try std.testing.expect(state.hand == null);
    // Captured: hand + field[0] + field[1] = 3 cards
    try std.testing.expectEqual(@as(u32, 3), state.captured_count);

    // Test drawNext refills field and hand
    const deck_before = state.deck.count();
    state.drawNext();
    try std.testing.expect(state.field[0] != null);
    try std.testing.expect(state.field[1] != null);
    try std.testing.expect(state.hand != null);
    try std.testing.expectEqual(deck_before - 3, state.deck.count());
}

test "play to field" {
    const allocator = std.testing.allocator;
    var prng = std.Random.DefaultPrng.init(42);
    var state = try GameState.init(allocator, prng.random());
    defer state.deinit();

    state.hand = Card{ .rank = .ace, .suit = .hearts };
    state.field[0] = Card{ .rank = .king, .suit = .spades };
    state.field[1] = Card{ .rank = .queen, .suit = .spades };
    state.field[2] = Card{ .rank = .jack, .suit = .spades };
    state.field[3] = null;

    const captures = try state.findCaptures(allocator);
    defer allocator.free(captures);
    try std.testing.expectEqual(@as(usize, 0), captures.len);
    
    const captured_any = try state.applyPlay();
    try std.testing.expect(!captured_any);
    try std.testing.expect(state.field[3] != null);
    try std.testing.expectEqual(Card{ .rank = .ace, .suit = .hearts }, state.field[3].?);
    try std.testing.expect(state.hand == null);

    state.drawNext();
    try std.testing.expect(state.hand != null);
}
