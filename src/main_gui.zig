const std = @import("std");
const rl = @import("raylib");
const builtin = @import("builtin");
const solitaire = @import("solitaire");

const emscripten = std.os.emscripten;
const GameState = solitaire.rules.GameState;
const Card = solitaire.card.Card;

const SCREEN_WIDTH = 800;
const SCREEN_HEIGHT = 450;

const CARD_W = 80;
const CARD_H = 110;
const SPACING = 20;

const SHEET_COLS = 14;
const SHEET_ROWS = 4;

// GLOBALS are necessary for Emscripten because the main() stack is unrolled
var gpa_instance = std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 0 }){};
var prng_instance: std.Random.DefaultPrng = undefined;
var global_state: GameState = undefined;
var card_texture: rl.Texture2D = undefined;
var is_initialized: bool = false;

pub fn main() !void {
    const allocator = if (builtin.os.tag == .emscripten)
        std.heap.wasm_allocator
    else
        gpa_instance.allocator();

    rl.traceLog(.info, "GUI: Initializing window", .{});
    rl.initWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Card Capture");
    
    rl.traceLog(.info, "GUI: Initializing PRNG", .{});
    prng_instance = std.Random.DefaultPrng.init(42);
    const random = prng_instance.random();

    rl.traceLog(.info, "GUI: Loading texture", .{});
    card_texture = try rl.loadTexture("assets/cards.png");

    rl.traceLog(.info, "GUI: Initializing game state", .{});
    // Initialize into the global variable
    global_state = try GameState.init(allocator, random);
    is_initialized = true;

    rl.traceLog(.info, "GUI: Starting main loop", .{});
    if (builtin.os.tag == .emscripten) {
        rl.setTargetFPS(60);
        emscripten.emscripten_set_main_loop(updateDrawFrame, 0, 1);
    } else {
        defer rl.closeWindow();
        defer rl.unloadTexture(card_texture);
        defer {
            global_state.deinit();
            _ = gpa_instance.deinit();
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

    if (!is_initialized) {
        rl.drawText("Initializing...", 10, 10, 20, .red);
        return;
    }

    // Draw field
    const field_start_x = 210;
    const field_y = 150;
    for (global_state.field, 0..) |maybe_card, i| {
        const x = field_start_x + @as(i32, @intCast(i)) * (CARD_W + SPACING);
        if (maybe_card) |card| {
            drawCard(card_texture, x, field_y, card);
        } else {
            rl.drawRectangleLines(x, field_y, CARD_W, CARD_H, .gray);
        }
    }

    // Draw hand
    const hand_start_x = 210;
    const hand_y = 300;
    for (global_state.hand, 0..) |maybe_card, i| {
        const x = hand_start_x + @as(i32, @intCast(i)) * (CARD_W + SPACING);
        if (maybe_card) |card| {
            drawCard(card_texture, x, hand_y, card);
        } else {
            rl.drawRectangleLines(x, hand_y, CARD_W, CARD_H, .gray);
        }
    }

    rl.drawText("Card Capture - Rendering Cards", 10, SCREEN_HEIGHT - 30, 20, .white);
}

fn drawCard(tex: rl.Texture2D, x: i32, y: i32, card: Card) void {
    const sw = @as(f32, @floatFromInt(tex.width)) / @as(f32, @floatFromInt(SHEET_COLS));
    const sh = @as(f32, @floatFromInt(tex.height)) / @as(f32, @floatFromInt(SHEET_ROWS));

    var col: f32 = undefined;
    var row: f32 = undefined;

    if (card.rank == .joker) {
        col = 0;
        row = 1;
    } else {
        col = @as(f32, @floatFromInt(@intFromEnum(card.rank)));
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

    rl.drawTexturePro(tex, src, dest, .{ .x = 0, .y = 0 }, 0, .white);
}
