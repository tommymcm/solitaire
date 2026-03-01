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

const ENEMY_DECK_POS = rl.Vector2{ .x = 20, .y = 150 };
const PLAYER_DECK_POS = rl.Vector2{ .x = 20, .y = 300 };
const DISCARD_POS = rl.Vector2{ .x = 700, .y = 300 };
const REMOVED_POS = rl.Vector2{ .x = 700, .y = 150 };

const ANIM_SPEED = 10.0;

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

        if (adx < 1.0 and ady < 1.0) {
            self.pos = self.target_pos;
        } else {
            self.pos.x += dx * dt * ANIM_SPEED;
            self.pos.y += dy * dt * ANIM_SPEED;
        }
    }

    fn isAtTarget(self: VisualCard) bool {
        const dx = self.target_pos.x - self.pos.x;
        const dy = self.target_pos.y - self.pos.y;
        const adx = if (dx < 0) -dx else dx;
        const ady = if (dy < 0) -dy else dy;
        return (adx < 1.0 and ady < 1.0);
    }
};

const TutorialStep = struct {
    text: [:0]const u8,
    highlight: ?rl.Rectangle = null,
};

const tutorial_steps = [_]TutorialStep{
    .{ .text = "Welcome to Card Capture! Click Next to learn the basics." },
    .{ 
        .text = "This is the Enemy Deck. It contains cards you must capture to win.",
        .highlight = .{ .x = 15, .y = 145, .width = CARD_W + 10, .height = CARD_H + 30 }
    },
    .{ 
        .text = "This is the Field. Opponent cards move here. You want to clear these!",
        .highlight = .{ .x = FIELD_X - 10, .y = FIELD_Y - 10, .width = (CARD_W + SPACING) * 4, .height = CARD_H + 20 }
    },
    .{ 
        .text = "This is your Hand. You use these cards to interact with the field.",
        .highlight = .{ .x = HAND_X - 10, .y = HAND_Y - 10, .width = (CARD_W + SPACING) * 4, .height = CARD_H + 20 }
    },
    .{ 
        .text = "To CAPTURE: Select cards in hand that match the field card's SUIT and sum to its VALUE, then click the field card.",
        .highlight = .{ .x = FIELD_X - 10, .y = FIELD_Y - 10, .width = (CARD_W + SPACING) * 4, .height = CARD_H + 200 }
    },
    .{ 
        .text = "To SACRIFICE: Select ONE hand card and click this. Both it and the rightmost field card are REMOVED forever.",
        .highlight = .{ .x = 285, .y = 405, .width = 110, .height = 40 }
    },
    .{ 
        .text = "To DELAY: Select TWO hand cards and click this. They are REMOVED, and the field card goes back to the deck.",
        .highlight = .{ .x = 405, .y = 405, .width = 110, .height = 40 }
    },
    .{ 
        .text = "Goal: Capture all cards! If you lose a Face Card (A, J, Q, K) via sacrifice, you lose immediately.",
    },
};

// GLOBALS
var gpa_instance = std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 0 }){};
var prng_instance: std.Random.DefaultPrng = undefined;
var global_state: GameState = undefined;
var card_texture: rl.Texture2D = undefined;
var is_initialized: bool = false;
var main_allocator: std.mem.Allocator = undefined;

// Selection State
var selected_hand: [4]bool = [_]bool{false} ** 4;
var selected_field: ?usize = null;
var status_message: [128:0]u8 = [_:0]u8{0} ** 128;

// Animation State
var field_visuals: [4]?VisualCard = [_]?VisualCard{null} ** 4;
var hand_visuals: [4]?VisualCard = [_]?VisualCard{null} ** 4;
var flying_visuals: [16]?VisualCard = [_]?VisualCard{null} ** 16;
var removed_count: usize = 0;

// Tutorial State
var tutorial_active: bool = false;
var current_step: usize = 0;

pub fn main() !void {
    main_allocator = if (builtin.os.tag == .emscripten)
        std.heap.wasm_allocator
    else
        gpa_instance.allocator();

    rl.initWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Card Capture");
    
    var seed: u64 = undefined;
    try std.posix.getrandom(std.mem.asBytes(&seed));
    prng_instance = std.Random.DefaultPrng.init(seed);

    card_texture = try rl.loadTexture("assets/cards.png");

    try restartGame();

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

fn restartGame() !void {
    if (is_initialized) {
        global_state.deinit();
    }
    
    const random = prng_instance.random();
    global_state = try GameState.init(main_allocator, random);
    
    for (0..4) |i| selected_hand[i] = false;
    selected_field = null;
    
    for (0..4) |i| {
        field_visuals[i] = null;
        hand_visuals[i] = null;
    }
    for (0..16) |i| flying_visuals[i] = null;
    removed_count = 0;
    
    syncVisuals(.none);
    is_initialized = true;
    _ = std.fmt.bufPrintZ(&status_message, "Welcome! Select hand cards then click a field card to capture.", .{}) catch unreachable;
}

const ActionType = enum { none, capture, sacrifice, delay, discard };

fn spawnFlying(card: Card, start: rl.Vector2, end: rl.Vector2) void {
    for (&flying_visuals) |*v| {
        if (v.* == null) {
            v.* = VisualCard{
                .card = card,
                .pos = start,
                .target_pos = end,
                .active = true,
            };
            return;
        }
    }
}

fn syncVisuals(action: ActionType) void {
    const action_name = switch (action) {
        .none => "NONE",
        .capture => "CAPTURE",
        .sacrifice => "SACRIFICE",
        .delay => "DELAY",
        .discard => "DISCARD",
    };
    rl.traceLog(.info, "syncVisuals: action=%s", .{action_name.ptr});

    // 1. Process Hand
    var old_hand = hand_visuals;
    for (0..4) |i| {
        const x = @as(f32, @floatFromInt(HAND_X + @as(i32, @intCast(i)) * (CARD_W + SPACING)));
        const target = rl.Vector2{ .x = x, .y = HAND_Y };

        if (global_state.hand[i]) |card| {
            var found_prev = false;
            for (0..4) |prev_i| {
                if (old_hand[prev_i]) |prev_v| {
                    if (std.meta.eql(prev_v.card, card)) {
                        hand_visuals[i] = prev_v;
                        hand_visuals[i].?.target_pos = target;
                        old_hand[prev_i] = null;
                        found_prev = true;
                        break;
                    }
                }
            }
            if (!found_prev) {
                hand_visuals[i] = VisualCard{ .card = card, .pos = PLAYER_DECK_POS, .target_pos = target, .active = true };
            }
        } else {
            hand_visuals[i] = null;
        }
    }

    for (old_hand) |maybe_v| {
        if (maybe_v) |v| {
            const end_pos = if (action == .sacrifice or action == .delay) REMOVED_POS else DISCARD_POS;
            spawnFlying(v.card, v.pos, end_pos);
        }
    }

    // 2. Process Field
    var old_field = field_visuals;
    for (0..4) |i| {
        const x = @as(f32, @floatFromInt(FIELD_X + @as(i32, @intCast(3 - i)) * (CARD_W + SPACING)));
        const target = rl.Vector2{ .x = x, .y = FIELD_Y };

        if (global_state.field[i]) |card| {
            var found_prev = false;
            for (0..4) |prev_i| {
                if (old_field[prev_i]) |prev_v| {
                    if (std.meta.eql(prev_v.card, card)) {
                        field_visuals[i] = prev_v;
                        field_visuals[i].?.target_pos = target;
                        old_field[prev_i] = null;
                        found_prev = true;
                        break;
                    }
                }
            }
            if (!found_prev) {
                field_visuals[i] = VisualCard{ .card = card, .pos = ENEMY_DECK_POS, .target_pos = target, .active = true };
            }
        } else {
            field_visuals[i] = null;
        }
    }

    for (old_field) |maybe_v| {
        if (maybe_v) |v| {
            var end_pos = DISCARD_POS;
            if (action == .delay) {
                end_pos = ENEMY_DECK_POS;
            } else if (action == .sacrifice) {
                end_pos = REMOVED_POS;
            }
            spawnFlying(v.card, v.pos, end_pos);
        }
    }
}

fn processInput() void {
    if (!is_initialized) return;

    if (rl.isMouseButtonPressed(.left)) {
        const mouse = rl.getMousePosition();

        // 0. Tutorial Input
        if (tutorial_active) {
            if (rl.checkCollisionPointRec(mouse, .{ .x = 550, .y = 250, .width = 80, .height = 30 })) {
                current_step += 1;
                if (current_step >= tutorial_steps.len) {
                    tutorial_active = false;
                    current_step = 0;
                }
            }
            if (rl.checkCollisionPointRec(mouse, .{ .x = 170, .y = 250, .width = 80, .height = 30 })) {
                tutorial_active = false;
                current_step = 0;
            }
            return;
        }

        if (rl.checkCollisionPointRec(mouse, .{ .x = 690, .y = 10, .width = 100, .height = 30 })) {
            tutorial_active = true;
            current_step = 0;
            return;
        }

        if (global_state.phase == .game_over) {
            if (rl.checkCollisionPointRec(mouse, .{ .x = 350, .y = 300, .width = 100, .height = 30 })) {
                restartGame() catch {};
            }
            return;
        }

        // 1. Hand Clicks
        for (0..4) |i| {
            const x = @as(f32, @floatFromInt(HAND_X + @as(i32, @intCast(i)) * (CARD_W + SPACING)));
            const rect = rl.Rectangle{ .x = x, .y = HAND_Y, .width = CARD_W, .height = CARD_H };
            if (rl.checkCollisionPointRec(mouse, rect)) {
                if (global_state.hand[i] != null) {
                    selected_hand[i] = !selected_hand[i];
                }
            }
        }

        // 2. Field Clicks
        for (0..4) |i| {
            const x = @as(f32, @floatFromInt(FIELD_X + @as(i32, @intCast(3 - i)) * (CARD_W + SPACING)));
            const rect = rl.Rectangle{ .x = x, .y = FIELD_Y, .width = CARD_W, .height = CARD_H };
            if (rl.checkCollisionPointRec(mouse, rect)) {
                if (global_state.field[i]) |_| {
                    var h_indices: [4]usize = undefined;
                    var count: usize = 0;
                    for (selected_hand, 0..) |sel, j| if (sel) { h_indices[count] = j; count += 1; };

                    if (count > 0 and global_state.phase == .action) {
                        if (global_state.playCapture(h_indices[0..count], i, null)) |success| {
                            if (success) {
                                _ = std.fmt.bufPrintZ(&status_message, "Capture successful!", .{}) catch unreachable;
                                resetSelection();
                                syncVisuals(.capture);
                                return; 
                            }
                        } else |_| {}
                    }
                    
                    if (selected_field == i) {
                        selected_field = null;
                    } else {
                        selected_field = i;
                    }
                }
            }
        }

        // 3. Action Buttons
        if (global_state.phase == .action) {
            if (rl.checkCollisionPointRec(mouse, .{ .x = 290, .y = 410, .width = 100, .height = 30 })) {
                handleSacrifice();
            }
            if (rl.checkCollisionPointRec(mouse, .{ .x = 410, .y = 410, .width = 100, .height = 30 })) {
                handleDelay();
            }
        } else if (global_state.phase == .discard) {
            if (rl.checkCollisionPointRec(mouse, .{ .x = 350, .y = 410, .width = 100, .height = 30 })) {
                handleDiscard();
            }
        }
    }
}

fn handleSacrifice() void {
    var count: usize = 0;
    var last_idx: usize = 0;
    for (selected_hand, 0..) |sel, i| if (sel) { count += 1; last_idx = i; };

    if (count != 1) {
        _ = std.fmt.bufPrintZ(&status_message, "Select exactly ONE hand card!", .{}) catch unreachable;
        return;
    }

    if (global_state.playSacrifice(last_idx)) {
        _ = std.fmt.bufPrintZ(&status_message, "Sacrifice successful!", .{}) catch unreachable;
        removed_count += 2;
        resetSelection();
        syncVisuals(.sacrifice);
    } else _ = std.fmt.bufPrintZ(&status_message, "Invalid sacrifice!", .{}) catch unreachable;
}

fn handleDelay() void {
    var h_indices: [2]usize = undefined;
    var count: usize = 0;
    for (selected_hand, 0..) |sel, i| if (sel and count < 2) { h_indices[count] = i; count += 1; };

    if (count != 2) {
        _ = std.fmt.bufPrintZ(&status_message, "Select exactly TWO hand cards!", .{}) catch unreachable;
        return;
    }

    if (global_state.playDelay(h_indices)) |success| {
        if (success) {
            _ = std.fmt.bufPrintZ(&status_message, "Delay successful!", .{}) catch unreachable;
            removed_count += 2;
            resetSelection();
            syncVisuals(.delay);
        } else _ = std.fmt.bufPrintZ(&status_message, "Invalid delay!", .{}) catch unreachable;
    } else |err| _ = std.fmt.bufPrintZ(&status_message, "Error: {any}", .{err}) catch unreachable;
}

fn handleDiscard() void {
    var h_indices: [4]usize = undefined;
    var count: usize = 0;
    for (selected_hand, 0..) |sel, i| if (sel) { h_indices[count] = i; count += 1; };

    global_state.playDiscard(h_indices[0..count]) catch |err| {
        _ = std.fmt.bufPrintZ(&status_message, "Discard error: {any}", .{err}) catch unreachable;
        return;
    };
    _ = std.fmt.bufPrintZ(&status_message, "Discarded {d} cards.", .{count}) catch unreachable;
    resetSelection();
    syncVisuals(.discard);
}

fn resetSelection() void {
    for (0..4) |i| selected_hand[i] = false;
    selected_field = null;
}

export fn updateDrawFrame() void {
    const dt = rl.getFrameTime();
    processInput();

    // Update animations
    for (&field_visuals) |*maybe_v| if (maybe_v.*) |*v| v.lerp(dt);
    for (&hand_visuals) |*maybe_v| if (maybe_v.*) |*v| v.lerp(dt);
    for (&flying_visuals) |*maybe_v| {
        if (maybe_v.*) |*v| {
            v.lerp(dt);
            if (v.isAtTarget()) maybe_v.* = null;
        }
    }

    rl.beginDrawing();
    defer rl.endDrawing();

    rl.clearBackground(.dark_green);

    if (!is_initialized) {
        rl.drawText("Initializing...", 10, 10, 20, .red);
        return;
    }

    // Slots
    for (0..4) |i| drawSlot(@as(i32, @intFromFloat(FIELD_X)) + @as(i32, @intCast(3 - i)) * (CARD_W + SPACING), @as(i32, @intFromFloat(FIELD_Y)));
    for (0..4) |i| drawSlot(@as(i32, @intFromFloat(HAND_X)) + @as(i32, @intCast(i)) * (CARD_W + SPACING), @as(i32, @intFromFloat(HAND_Y)));

    // Cards
    for (field_visuals, 0..) |maybe_v, i| if (maybe_v) |v| {
        drawCard(card_texture, @as(i32, @intFromFloat(v.pos.x)), @as(i32, @intFromFloat(v.pos.y)), v.card);
        if (selected_field == i) rl.drawRectangleLinesEx(.{ .x = v.pos.x, .y = v.pos.y, .width = CARD_W, .height = CARD_H }, 3, .yellow);
    };
    for (hand_visuals, 0..) |maybe_v, i| if (maybe_v) |v| {
        drawCard(card_texture, @as(i32, @intFromFloat(v.pos.x)), @as(i32, @intFromFloat(v.pos.y)), v.card);
        if (selected_hand[i]) rl.drawRectangleLinesEx(.{ .x = v.pos.x, .y = v.pos.y, .width = CARD_W, .height = CARD_H }, 3, .yellow);
    };
    for (flying_visuals) |maybe_v| if (maybe_v) |v| drawCard(card_texture, @as(i32, @intFromFloat(v.pos.x)), @as(i32, @intFromFloat(v.pos.y)), v.card);

    // Decks & Piles
    if (global_state.enemy_deck.count() > 0) {
        drawCardBack(card_texture, @as(i32, @intFromFloat(ENEMY_DECK_POS.x)), @as(i32, @intFromFloat(ENEMY_DECK_POS.y)));
        var count_buf: [16]u8 = undefined;
        const count_text = std.fmt.bufPrintZ(&count_buf, "{d}", .{global_state.enemy_deck.count()}) catch "!";
        const tw = rl.measureText(count_text, 20);
        rl.drawText(count_text, @as(i32, @intFromFloat(ENEMY_DECK_POS.x)) + @divTrunc(CARD_W - tw, 2), @as(i32, @intFromFloat(ENEMY_DECK_POS.y)) + @divTrunc(CARD_H - 20, 2), 20, .white);
    } else drawSlot(@as(i32, @intFromFloat(ENEMY_DECK_POS.x)), @as(i32, @intFromFloat(ENEMY_DECK_POS.y)));
    rl.drawText("Enemy Deck", @as(i32, @intFromFloat(ENEMY_DECK_POS.x)), @as(i32, @intFromFloat(ENEMY_DECK_POS.y)) + CARD_H + 5, 10, .light_gray);
    
    if (global_state.deck.count() > 0) {
        drawCardBack(card_texture, @as(i32, @intFromFloat(PLAYER_DECK_POS.x)), @as(i32, @intFromFloat(PLAYER_DECK_POS.y)));
        var count_buf: [16]u8 = undefined;
        const count_text = std.fmt.bufPrintZ(&count_buf, "{d}", .{global_state.deck.count()}) catch "!";
        const tw = rl.measureText(count_text, 20);
        rl.drawText(count_text, @as(i32, @intFromFloat(PLAYER_DECK_POS.x)) + @divTrunc(CARD_W - tw, 2), @as(i32, @intFromFloat(PLAYER_DECK_POS.y)) + @divTrunc(CARD_H - 20, 2), 20, .white);
    } else drawSlot(@as(i32, @intFromFloat(PLAYER_DECK_POS.x)), @as(i32, @intFromFloat(PLAYER_DECK_POS.y)));
    rl.drawText("Your Deck", @as(i32, @intFromFloat(PLAYER_DECK_POS.x)), @as(i32, @intFromFloat(PLAYER_DECK_POS.y)) + CARD_H + 5, 10, .light_gray);

    if (global_state.discard_pile.count() > 0) {
        const top = global_state.discard_pile.cards[global_state.discard_pile.len - 1];
        drawCard(card_texture, @as(i32, @intFromFloat(DISCARD_POS.x)), @as(i32, @intFromFloat(DISCARD_POS.y)), top);
        var count_buf: [16]u8 = undefined;
        const count_text = std.fmt.bufPrintZ(&count_buf, "{d}", .{global_state.discard_pile.count()}) catch "!";
        const tw = rl.measureText(count_text, 20);
        rl.drawText(count_text, @as(i32, @intFromFloat(DISCARD_POS.x)) + @divTrunc(CARD_W - tw, 2), @as(i32, @intFromFloat(DISCARD_POS.y)) + @divTrunc(CARD_H - 20, 2), 20, .white);
    } else drawSlot(@as(i32, @intFromFloat(DISCARD_POS.x)), @as(i32, @intFromFloat(DISCARD_POS.y)));
    rl.drawText("Discard", @as(i32, @intFromFloat(DISCARD_POS.x)), @as(i32, @intFromFloat(DISCARD_POS.y)) + CARD_H + 5, 10, .light_gray);

    if (removed_count > 0) drawCardBack(card_texture, @as(i32, @intFromFloat(REMOVED_POS.x)), @as(i32, @intFromFloat(REMOVED_POS.y)))
    else drawSlot(@as(i32, @intFromFloat(REMOVED_POS.x)), @as(i32, @intFromFloat(REMOVED_POS.y)));
    rl.drawText("Removed", @as(i32, @intFromFloat(REMOVED_POS.x)), @as(i32, @intFromFloat(REMOVED_POS.y)) + CARD_H + 5, 10, .light_gray);

    // UI
    if (global_state.phase == .action) {
        drawButton(290, 410, 100, 30, "SACRIFICE", .orange);
        drawButton(410, 410, 100, 30, "DELAY", .dark_blue);
    } else if (global_state.phase == .discard) drawButton(350, 410, 100, 30, "CONFIRM", .dark_gray)
    else if (global_state.phase == .game_over) {
        const msg = if (global_state.is_won) "VICTORY!" else "DEFEAT";
        const col = if (global_state.is_won) rl.Color.gold else rl.Color.red;
        rl.drawText(msg, @divTrunc(SCREEN_WIDTH - rl.measureText(msg, 40), 2), 200, 40, col);
        drawButton(350, 300, 100, 30, "PLAY AGAIN", .dark_gray);
    }

    drawButton(690, 10, 100, 30, "TOOLTIP", .dark_gray);

    if (global_state.phase != .game_over) {
        const sw_msg = rl.measureText(&status_message, 20);
        rl.drawText(&status_message, @divTrunc(SCREEN_WIDTH - sw_msg, 2), 20, 20, .ray_white);
        rl.drawText(if (global_state.phase == .action) "ACTION" else "DISCARD", 10, 150, 20, .gold);
    }
    
    var score_buf: [64]u8 = undefined;
    rl.drawText(std.fmt.bufPrintZ(&score_buf, "Score: {d}", .{global_state.captured_count}) catch "Score: ERROR", 10, 420, 20, .ray_white);

    // Tutorial Overlay
    if (tutorial_active) {
        rl.drawRectangle(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, rl.fade(.black, 0.7));
        const step = tutorial_steps[current_step];
        
        if (step.highlight) |rect| {
            rl.drawRectangleLinesEx(rect, 3, .yellow);
        }

        const box_rect = rl.Rectangle{ .x = 150, .y = 150, .width = 500, .height = 150 };
        rl.drawRectangleRec(box_rect, .dark_gray);
        rl.drawRectangleLinesEx(box_rect, 2, .ray_white);
        
        drawTextWrapped(step.text, 170, 170, 460, 20, .ray_white);

        drawButton(170, 250, 80, 30, "CLOSE", .maroon);
        drawButton(550, 250, 80, 30, if (current_step == tutorial_steps.len - 1) "FINISH" else "NEXT", .dark_green);
    }
}

fn drawTextWrapped(text: [:0]const u8, x: i32, y: i32, width: i32, fontSize: i32, color: rl.Color) void {
    var cursor_x: i32 = x;
    var cursor_y: i32 = y;
    const space_width = rl.measureText(" ", fontSize);

    var it = std.mem.tokenizeAny(u8, text, " ");
    while (it.next()) |word| {
        // Use a local buffer for the word to add null terminator
        var word_buf: [128:0]u8 = undefined;
        const word_z: [:0]const u8 = std.fmt.bufPrintZ(&word_buf, "{s}", .{word}) catch "err";
        
        const word_width = rl.measureText(word_z, fontSize);
        if (cursor_x + word_width > x + width) {
            cursor_x = x;
            cursor_y += fontSize + 5;
        }
        rl.drawText(word_z, cursor_x, cursor_y, fontSize, color);
        cursor_x += word_width + space_width;
    }
}

fn drawButton(x: i32, y: i32, w: i32, h: i32, text: [:0]const u8, color: rl.Color) void {
    const rect = rl.Rectangle{ .x = @floatFromInt(x), .y = @floatFromInt(y), .width = @floatFromInt(w), .height = @floatFromInt(h) };
    rl.drawRectangleRec(rect, color);
    rl.drawRectangleLinesEx(rect, 2, .ray_white);
    const tw = rl.measureText(text, 10);
    rl.drawText(text, x + @divTrunc(w - tw, 2), y + @divTrunc(h - 10, 2), 10, .ray_white);
}

fn drawSlot(x: i32, y: i32) void { rl.drawRectangleLines(x, y, CARD_W, CARD_H, .gray); }

fn drawCard(tex: rl.Texture2D, x: i32, y: i32, card: Card) void {
    const sw = @as(f32, @floatFromInt(tex.width)) / SHEET_COLS;
    const sh = @as(f32, @floatFromInt(tex.height)) / SHEET_ROWS;
    var col: f32 = 0; var row: f32 = 0;
    if (card.rank == .joker) { col = 0; row = 2; } 
    else { 
        row = switch (card.suit) { .hearts => @as(f32, 0), .clubs => @as(f32, 1), .diamonds => @as(f32, 2), .spades => @as(f32, 3) };
        const rank_val = @intFromEnum(card.rank);
        if (card.rank == .ace) { col = 13; } else { col = @floatFromInt(rank_val - 1); }
    }
    rl.drawTexturePro(tex, .{ .x = col * sw, .y = row * sh, .width = sw, .height = sh }, .{ .x = @floatFromInt(x), .y = @floatFromInt(y), .width = CARD_W, .height = CARD_H }, .{ .x = 0, .y = 0 }, 0, .white);
}

fn drawCardBack(tex: rl.Texture2D, x: i32, y: i32) void {
    const sw = @as(f32, @floatFromInt(tex.width)) / SHEET_COLS;
    const sh = @as(f32, @floatFromInt(tex.height)) / SHEET_ROWS;
    rl.drawTexturePro(tex, .{ .x = 0, .y = 0, .width = sw, .height = sh }, .{ .x = @floatFromInt(x), .y = @floatFromInt(y), .width = CARD_W, .height = CARD_H }, .{ .x = 0, .y = 0 }, 0, .white);
}
