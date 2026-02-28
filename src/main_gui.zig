const std = @import("std");
const rl = @import("raylib");
const builtin = @import("builtin");
const solitaire = @import("solitaire");

const emscripten = std.os.emscripten;
const GameState = solitaire.rules.GameState;
const Card = solitaire.card.Card;

const SCREEN_WIDTH = 800;
const SCREEN_HEIGHT = 450;

// Card dimensions in the GUI
const CARD_W = 80;
const CARD_H = 110;
const SPACING = 20;

// Spritesheet info
// Based on the image: 14 columns (Back/Joker + A-K), 4 rows (Suits)
const SHEET_COLS = 14;
const SHEET_ROWS = 4;

// Global state
var global_state: ?*GameState = null;
var global_allocator: std.mem.Allocator = undefined;
var native_gpa = std.heap.GeneralPurposeAllocator(.{}){};
var card_texture: rl.Texture2D = undefined;

pub fn main() !void {
    // Memory allocator.
    if (builtin.os.tag == .emscripten) {
        global_allocator = std.heap.wasm_allocator;
    } else {
        global_allocator = native_gpa.allocator();
    }

    // Pseudo-random value generator.
    var seed: u64 = undefined;
    try std.posix.getrandom(std.mem.asBytes(&seed));
    var prng = std.Random.DefaultPrng.init(seed);
    const random = prng.random();

    // Initialize raylib.
    rl.initWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Card Capture - Rendering Cards");

    // Load assets
    card_texture = try rl.loadTexture("assets/cards.png");

    // Initialize game state on heap.
    const state = try global_allocator.create(GameState);
    state.* = try GameState.init(global_allocator, random);
    global_state = state;

    if (builtin.os.tag == .emscripten) {
        rl.setTargetFPS(60);
        emscripten.emscripten_set_main_loop(updateDrawFrame, 0, 1);
    } else {
        defer rl.closeWindow();
        defer rl.unloadTexture(card_texture);
        defer {
            if (global_state) |gs| {
                gs.deinit();
                global_allocator.destroy(gs);
            }
            _ = native_gpa.deinit();
        }

        rl.setTargetFPS(60);

        while (!rl.windowShouldClose()) {
            updateDrawFrame();
        }
    }
}

export fn updateDrawFrame() void {
    rl.beginDrawing();
    defer rl.endDrawing();

    rl.clearBackground(.dark_green);

    if (global_state) |state| {
        // 1. Opponent's Deck Area (Show Back)
        drawCardBack(20, 20);
        rl.drawText("Enemy Deck", 20, 20 + CARD_H + 5, 10, .light_gray);

        // 2. Field Area (4 slots)
        const field_start_x = 210;
        const field_y = 150;
        rl.drawText("Field", field_start_x, field_y - 25, 20, .light_gray);
        for (state.field, 0..) |maybe_card, i| {
            const x = field_start_x + @as(i32, @intCast(i)) * (CARD_W + SPACING);
            drawSlot(x, field_y);
            if (maybe_card) |card| {
                drawCard(x, field_y, card);
            }
        }

        // 3. Hand Area (4 slots)
        const hand_start_x = 210;
        const hand_y = 300;
        rl.drawText("Your Hand", hand_start_x, hand_y - 25, 20, .light_gray);
        for (state.hand, 0..) |maybe_card, i| {
            const x = hand_start_x + @as(i32, @intCast(i)) * (CARD_W + SPACING);
            drawSlot(x, hand_y);
            if (maybe_card) |card| {
                drawCard(x, hand_y, card);
            }
        }

        // 4. Player's Deck Area (Show Back if not empty)
        if (state.deck.count() > 0) {
            drawCardBack(20, 300);
        } else {
            drawSlot(20, 300);
        }
        rl.drawText("Your Deck", 20, 300 + CARD_H + 5, 10, .light_gray);

        // 5. Discard Pile Area (Show Top Card if not empty)
        const discard_x = 700;
        const discard_y = 300;
        drawSlot(discard_x, discard_y);
        if (state.discard_pile.count() > 0) {
            // Peek at top card (end of list)
            const items = state.discard_pile.cards.items;
            drawCard(discard_x, discard_y, items[items.len - 1]);
        }
        rl.drawText("Discard", discard_x, discard_y + CARD_H + 5, 10, .light_gray);
        
        // Info
        var buf: [64]u8 = undefined;
        const score_text = std.fmt.bufPrintZ(&buf, "Score: {d}", .{state.captured_count}) catch "Score: ERROR";
        rl.drawText(score_text, 10, SCREEN_HEIGHT - 30, 20, .ray_white);
    }
}

fn drawSlot(x: i32, y: i32) void {
    rl.drawRectangleLines(x, y, CARD_W, CARD_H, .gray);
}

fn drawCard(x: i32, y: i32, card: Card) void {
    const sw = @as(f32, @floatFromInt(card_texture.width)) / @as(f32, @floatFromInt(SHEET_COLS));
    const sh = @as(f32, @floatFromInt(card_texture.height)) / @as(f32, @floatFromInt(SHEET_ROWS));

    var col: f32 = undefined;
    var row: f32 = undefined;

    if (card.rank == .joker) {
        col = 0;
        row = 1; // Joker is Row 1, Col 0
    } else {
        col = @as(f32, @floatFromInt(@intFromEnum(card.rank))); // Ace is 1, so Col 1
        row = switch (card.suit) {
            .spades => 0,
            .hearts => 1,
            .clubs => 2,
            .diamonds => 3,
        };
    }

    const src = rl.Rectangle{
        .x = col * sw,
        .y = row * sh,
        .width = sw,
        .height = sh,
    };

    const dest = rl.Rectangle{
        .x = @as(f32, @floatFromInt(x)),
        .y = @as(f32, @floatFromInt(y)),
        .width = @as(f32, @floatFromInt(CARD_W)),
        .height = @as(f32, @floatFromInt(CARD_H)),
    };

    rl.drawTexturePro(card_texture, src, dest, .{ .x = 0, .y = 0 }, 0, .white);
}

fn drawCardBack(x: i32, y: i32) void {
    const sw = @as(f32, @floatFromInt(card_texture.width)) / @as(f32, @floatFromInt(SHEET_COLS));
    const sh = @as(f32, @floatFromInt(card_texture.height)) / @as(f32, @floatFromInt(SHEET_ROWS));

    const src = rl.Rectangle{
        .x = 0, // Card back is Row 0, Col 0
        .y = 0,
        .width = sw,
        .height = sh,
    };

    const dest = rl.Rectangle{
        .x = @as(f32, @floatFromInt(x)),
        .y = @as(f32, @floatFromInt(y)),
        .width = @as(f32, @floatFromInt(CARD_W)),
        .height = @as(f32, @floatFromInt(CARD_H)),
    };

    rl.drawTexturePro(card_texture, src, dest, .{ .x = 0, .y = 0 }, 0, .white);
}
