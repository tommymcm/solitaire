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

const FIELD_X = 210;
const FIELD_Y = 150;
const HAND_X = 210;
const HAND_Y = 300;

const ANIM_SPEED = 8.0; // Lerp factor per frame

// Visual representation of a card for animation
const VisualCard = struct {
    card: Card,
    pos: rl.Vector2,
    target_pos: rl.Vector2,
    active: bool = false,

    fn lerp(self: *VisualCard, dt: f32) void {
        if (!self.active) return;
        const dx = self.target_pos.x - self.pos.x;
        const dy = self.target_pos.y - self.pos.y;
        
        const adx = if (dx < 0) -dx else dx;
        const ady = if (dy < 0) -dy else dy;

        if (adx < 0.5 and ady < 0.5) {
            self.pos = self.target_pos;
        } else {
            self.pos.x += dx * dt * ANIM_SPEED;
            self.pos.y += dy * dt * ANIM_SPEED;
        }
    }
};

// GLOBALS
var gpa_instance = std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 0 }){};
var prng_instance: std.Random.DefaultPrng = undefined;
var global_state: GameState = undefined;
var card_texture: rl.Texture2D = undefined;
var is_initialized: bool = false;

// Selection State
var selected_hand: [4]bool = [_]bool{false} ** 4;
var selected_field: ?usize = null;
var status_message: [128:0]u8 = [_:0]u8{0} ** 128;

// Animation State
var field_visuals: [4]?VisualCard = [_]?VisualCard{null} ** 4;

pub fn main() !void {
    const allocator = if (builtin.os.tag == .emscripten)
        std.heap.wasm_allocator
    else
        gpa_instance.allocator();

    rl.initWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Card Capture");
    
    prng_instance = std.Random.DefaultPrng.init(42);
    const random = prng_instance.random();

    card_texture = try rl.loadTexture("assets/cards.png");

    global_state = try GameState.init(allocator, random);
    syncVisuals();
    is_initialized = true;
    _ = std.fmt.bufPrintZ(&status_message, "Welcome! Select cards and choose an action.", .{}) catch unreachable;

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

// Synchronize visual positions with logical state
// New cards start at the enemy deck position (20, 20)
fn syncVisuals() void {
    const enemy_deck_pos = rl.Vector2{ .x = 20, .y = 20 };

    for (0..4) |i| {
        const x = @as(f32, @floatFromInt(FIELD_X + @as(i32, @intCast(3 - i)) * (CARD_W + SPACING)));
        const target = rl.Vector2{ .x = x, .y = FIELD_Y };

        if (global_state.field[i]) |card| {
            if (field_visuals[i]) |*v| {
                if (!std.meta.eql(v.card, card)) {
                    var found = false;
                    for (0..4) |prev_i| {
                        if (field_visuals[prev_i]) |prev_v| {
                            if (std.meta.eql(prev_v.card, card)) {
                                v.* = prev_v;
                                v.target_pos = target;
                                field_visuals[prev_i] = null;
                                found = true;
                                break;
                            }
                        }
                    }
                    if (!found) {
                        v.* = VisualCard{
                            .card = card,
                            .pos = enemy_deck_pos,
                            .target_pos = target,
                            .active = true,
                        };
                    }
                } else {
                    v.target_pos = target;
                }
            } else {
                var found = false;
                for (0..4) |prev_i| {
                    if (field_visuals[prev_i]) |prev_v| {
                        if (std.meta.eql(prev_v.card, card)) {
                            field_visuals[i] = prev_v;
                            field_visuals[i].?.target_pos = target;
                            field_visuals[prev_i] = null;
                            found = true;
                            break;
                        }
                    }
                }
                if (!found) {
                    field_visuals[i] = VisualCard{
                        .card = card,
                        .pos = enemy_deck_pos,
                        .target_pos = target,
                        .active = true,
                    };
                }
            }
        } else {
            field_visuals[i] = null;
        }
    }
}

fn processInput() void {
    if (!is_initialized or global_state.phase == .game_over) return;

    if (rl.isMouseButtonPressed(.left)) {
        const mouse = rl.getMousePosition();

        for (0..4) |i| {
            const x = @as(f32, @floatFromInt(HAND_X + @as(i32, @intCast(i)) * (CARD_W + SPACING)));
            const rect = rl.Rectangle{ .x = x, .y = HAND_Y, .width = CARD_W, .height = CARD_H };
            if (rl.checkCollisionPointRec(mouse, rect)) {
                if (global_state.hand[i] != null) {
                    selected_hand[i] = !selected_hand[i];
                }
            }
        }

        for (0..4) |i| {
            const x = @as(f32, @floatFromInt(FIELD_X + @as(i32, @intCast(3 - i)) * (CARD_W + SPACING)));
            const rect = rl.Rectangle{ .x = x, .y = FIELD_Y, .width = CARD_W, .height = CARD_H };
            if (rl.checkCollisionPointRec(mouse, rect)) {
                if (global_state.field[i] != null) {
                    if (selected_field == i) {
                        selected_field = null;
                    } else {
                        selected_field = i;
                    }
                }
            }
        }

        if (global_state.phase == .action) {
            if (rl.checkCollisionPointRec(mouse, .{ .x = 650, .y = 50, .width = 120, .height = 40 })) {
                handleCapture();
                syncVisuals();
            }
            if (rl.checkCollisionPointRec(mouse, .{ .x = 650, .y = 100, .width = 120, .height = 40 })) {
                handleSacrifice();
                syncVisuals();
            }
            if (rl.checkCollisionPointRec(mouse, .{ .x = 650, .y = 150, .width = 120, .height = 40 })) {
                handleDelay();
                syncVisuals();
            }
        } else if (global_state.phase == .discard) {
            if (rl.checkCollisionPointRec(mouse, .{ .x = 650, .y = 50, .width = 120, .height = 40 })) {
                handleDiscard();
                syncVisuals();
            }
        }
    }
}

fn handleCapture() void {
    var h_indices: [4]usize = undefined;
    var count: usize = 0;
    for (selected_hand, 0..) |sel, i| {
        if (sel) {
            h_indices[count] = i;
            count += 1;
        }
    }

    if (count == 0 or selected_field == null) {
        _ = std.fmt.bufPrintZ(&status_message, "Select hand card(s) and one field card!", .{}) catch unreachable;
        return;
    }

    if (global_state.playCapture(h_indices[0..count], selected_field.?, null)) |success| {
        if (success) {
            _ = std.fmt.bufPrintZ(&status_message, "Capture successful!", .{}) catch unreachable;
            resetSelection();
        } else {
            _ = std.fmt.bufPrintZ(&status_message, "Invalid capture!", .{}) catch unreachable;
        }
    } else |err| {
        _ = std.fmt.bufPrintZ(&status_message, "Error: {any}", .{err}) catch unreachable;
    }
}

fn handleSacrifice() void {
    var count: usize = 0;
    var last_idx: usize = 0;
    for (selected_hand, 0..) |sel, i| {
        if (sel) {
            count += 1;
            last_idx = i;
        }
    }

    if (count != 1) {
        _ = std.fmt.bufPrintZ(&status_message, "Select exactly ONE hand card!", .{}) catch unreachable;
        return;
    }

    if (global_state.playSacrifice(last_idx)) {
        _ = std.fmt.bufPrintZ(&status_message, "Sacrifice successful!", .{}) catch unreachable;
        resetSelection();
    } else {
        _ = std.fmt.bufPrintZ(&status_message, "Invalid sacrifice!", .{}) catch unreachable;
    }
}

fn handleDelay() void {
    var h_indices: [2]usize = undefined;
    var count: usize = 0;
    for (selected_hand, 0..) |sel, i| {
        if (sel and count < 2) {
            h_indices[count] = i;
            count += 1;
        }
    }

    if (count != 2) {
        _ = std.fmt.bufPrintZ(&status_message, "Select exactly TWO hand cards!", .{}) catch unreachable;
        return;
    }

    if (global_state.playDelay(h_indices)) |success| {
        if (success) {
            _ = std.fmt.bufPrintZ(&status_message, "Delay successful!", .{}) catch unreachable;
            resetSelection();
        } else {
            _ = std.fmt.bufPrintZ(&status_message, "Invalid delay!", .{}) catch unreachable;
        }
    } else |err| {
        _ = std.fmt.bufPrintZ(&status_message, "Error: {any}", .{err}) catch unreachable;
    }
}

fn handleDiscard() void {
    var h_indices: [4]usize = undefined;
    var count: usize = 0;
    for (selected_hand, 0..) |sel, i| {
        if (sel) {
            h_indices[count] = i;
            count += 1;
        }
    }

    global_state.playDiscard(h_indices[0..count]) catch |err| {
        _ = std.fmt.bufPrintZ(&status_message, "Discard error: {any}", .{err}) catch unreachable;
        return;
    };
    _ = std.fmt.bufPrintZ(&status_message, "Discarded {d} cards.", .{count}) catch unreachable;
    resetSelection();
}

fn resetSelection() void {
    for (0..4) |i| selected_hand[i] = false;
    selected_field = null;
}

export fn updateDrawFrame() void {
    const dt = rl.getFrameTime();
    processInput();

    for (&field_visuals) |*maybe_v| {
        if (maybe_v.*) |*v| {
            v.lerp(dt);
        }
    }

    rl.beginDrawing();
    defer rl.endDrawing();

    rl.clearBackground(.dark_green);

    if (!is_initialized) {
        rl.drawText("Initializing...", 10, 10, 20, .red);
        return;
    }

    for (0..4) |i| {
        const x = FIELD_X + @as(i32, @intCast(3 - i)) * (CARD_W + SPACING);
        drawSlot(x, FIELD_Y);
    }

    for (field_visuals, 0..) |maybe_v, i| {
        if (maybe_v) |v| {
            drawCard(card_texture, @as(i32, @intFromFloat(v.pos.x)), @as(i32, @intFromFloat(v.pos.y)), v.card);
            if (selected_field == i) {
                rl.drawRectangleLinesEx(.{ .x = v.pos.x, .y = v.pos.y, .width = CARD_W, .height = CARD_H }, 3, .yellow);
            }
        }
    }

    for (global_state.hand, 0..) |maybe_card, i| {
        const x = HAND_X + @as(i32, @intCast(i)) * (CARD_W + SPACING);
        drawSlot(x, HAND_Y);
        if (maybe_card) |card| {
            drawCard(card_texture, x, HAND_Y, card);
            if (selected_hand[i]) {
                rl.drawRectangleLinesEx(.{ .x = @floatFromInt(x), .y = HAND_Y, .width = CARD_W, .height = CARD_H }, 3, .yellow);
            }
        }
    }

    if (global_state.enemy_deck.count() > 0) {
        drawCardBack(card_texture, 20, 20);
    } else {
        drawSlot(20, 20);
    }
    rl.drawText("Enemy Deck", 20, 20 + CARD_H + 5, 10, .light_gray);

    if (global_state.deck.count() > 0) {
        drawCardBack(card_texture, 20, 300);
    } else {
        drawSlot(20, 300);
    }
    rl.drawText("Your Deck", 20, 300 + CARD_H + 5, 10, .light_gray);

    const discard_x = 700;
    const discard_y = 300;
    if (global_state.discard_pile.count() > 0) {
        const top_card = global_state.discard_pile.cards[global_state.discard_pile.len - 1];
        drawCard(card_texture, discard_x, discard_y, top_card);
    } else {
        drawSlot(discard_x, discard_y);
    }
    rl.drawText("Discard", discard_x, discard_y + CARD_H + 5, 10, .light_gray);

    if (global_state.phase == .action) {
        drawButton(650, 50, 120, 40, "CAPTURE", .maroon);
        drawButton(650, 100, 120, 40, "SACRIFICE", .orange);
        drawButton(650, 150, 120, 40, "DELAY", .dark_blue);
    } else if (global_state.phase == .discard) {
        drawButton(650, 50, 120, 40, "CONFIRM DISCARD", .dark_gray);
    } else if (global_state.phase == .game_over) {
        rl.drawText("GAME OVER", 300, 200, 40, .red);
    }

    rl.drawText(&status_message, 210, 420, 20, .ray_white);
    
    var buf: [64]u8 = undefined;
    const score_text = std.fmt.bufPrintZ(&buf, "Score: {d}", .{global_state.captured_count}) catch "Score: ERROR";
    rl.drawText(score_text, 10, 420, 20, .ray_white);

    const phase_text = switch (global_state.phase) {
        .action => "Phase: ACTION",
        .discard => "Phase: DISCARD",
        .game_over => "Phase: GAME OVER",
    };
    rl.drawText(phase_text, 10, 150, 20, .gold);
}

fn drawButton(x: i32, y: i32, w: i32, h: i32, text: [:0]const u8, color: rl.Color) void {
    const rect = rl.Rectangle{ .x = @floatFromInt(x), .y = @floatFromInt(y), .width = @floatFromInt(w), .height = @floatFromInt(h) };
    rl.drawRectangleRec(rect, color);
    rl.drawRectangleLinesEx(rect, 2, .ray_white);
    const tw = rl.measureText(text, 10);
    rl.drawText(text, x + @divTrunc(w - tw, 2), y + 15, 10, .ray_white);
}

fn drawSlot(x: i32, y: i32) void {
    rl.drawRectangleLines(x, y, CARD_W, CARD_H, .gray);
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

    const src = rl.Rectangle{ .x = col * sw, .y = row * sh, .width = sw, .height = sh };
    const dest = rl.Rectangle{ .x = @floatFromInt(x), .y = @floatFromInt(y), .width = CARD_W, .height = CARD_H };
    rl.drawTexturePro(tex, src, dest, .{ .x = 0, .y = 0 }, 0, .white);
}

fn drawCardBack(tex: rl.Texture2D, x: i32, y: i32) void {
    const sw = @as(f32, @floatFromInt(tex.width)) / @as(f32, @floatFromInt(SHEET_COLS));
    const sh = @as(f32, @floatFromInt(tex.height)) / @as(f32, @floatFromInt(SHEET_ROWS));
    const src = rl.Rectangle{ .x = 0, .y = 0, .width = sw, .height = sh };
    const dest = rl.Rectangle{ .x = @floatFromInt(x), .y = @floatFromInt(y), .width = CARD_W, .height = CARD_H };
    rl.drawTexturePro(tex, src, dest, .{ .x = 0, .y = 0 }, 0, .white);
}
