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

// Use a fixed buffer for the allocator to avoid any issues with global GPA initialization
var gpa_instance = std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 0 }){};

var global_state: ?*GameState = null;
var card_texture: ?rl.Texture2D = null;

pub fn main() !void {
    const allocator = if (builtin.os.tag == .emscripten)
        std.heap.wasm_allocator
    else
        gpa_instance.allocator();

    std.debug.print("Initializing window...\n", .{});
    rl.initWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Card Capture - Debugging");
    
    // Seed PRNG
    std.debug.print("Initializing PRNG...\n", .{});
    var prng = std.Random.DefaultPrng.init(42); // Hardcoded for now to avoid getrandom issues
    const random = prng.random();

    std.debug.print("Loading texture...\n", .{});
    // Load texture and handle potential failure gracefully
    const tex = rl.loadTexture("assets/cards.png") catch |err| {
        std.debug.print("Failed to load texture: {}\n", .{err});
        return err;
    };
    card_texture = tex;

    std.debug.print("Initializing game state...\n", .{});
    const state = try allocator.create(GameState);
    state.* = try GameState.init(allocator, random);
    global_state = state;

    std.debug.print("Starting main loop...\n", .{});
    if (builtin.os.tag == .emscripten) {
        rl.setTargetFPS(60);
        emscripten.emscripten_set_main_loop(updateDrawFrame, 0, 1);
    } else {
        defer rl.closeWindow();
        defer if (card_texture) |t| rl.unloadTexture(t);
        defer {
            if (global_state) |gs| {
                gs.deinit();
                allocator.destroy(gs);
            }
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

    const state = global_state orelse {
        rl.drawText("Error: Global state is null", 10, 10, 20, .red);
        return;
    };

    const tex = card_texture orelse {
        rl.drawText("Error: Texture is null", 10, 10, 20, .red);
        return;
    };

    // Draw field
    const field_start_x = 210;
    const field_y = 150;
    for (state.field, 0..) |maybe_card, i| {
        const x = field_start_x + @as(i32, @intCast(i)) * (CARD_W + SPACING);
        if (maybe_card) |card| {
            drawCard(tex, x, field_y, card);
        } else {
            rl.drawRectangleLines(x, field_y, CARD_W, CARD_H, .gray);
        }
    }

    // Draw hand
    const hand_start_x = 210;
    const hand_y = 300;
    for (state.hand, 0..) |maybe_card, i| {
        const x = hand_start_x + @as(i32, @intCast(i)) * (CARD_W + SPACING);
        if (maybe_card) |card| {
            drawCard(tex, x, hand_y, card);
        } else {
            rl.drawRectangleLines(x, hand_y, CARD_W, CARD_H, .gray);
        }
    }

    rl.drawText("Card Capture - Rendering Debug", 10, SCREEN_HEIGHT - 30, 20, .white);
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
