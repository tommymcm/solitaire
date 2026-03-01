const std = @import("std");
const rl = @import("raylib");
const builtin = @import("builtin");
const solitaire = @import("solitaire");

const emscripten = std.os.emscripten;
const GameState = solitaire.rules.GameState;
const Card = solitaire.card.Card;

const SCREEN_WIDTH = 600;
const SCREEN_HEIGHT = 380;

const CARD_W = 80;
const CARD_H = 110;
const CARD_SPACING = 10;

const SHEET_COLS = 14;
const SHEET_ROWS = 4;

const ANIM_SPEED = 10.0;

// Layout Constants
const MARGIN_X = 25;
const MARGIN_Y = 25; // Top margin for decks and cards
const PAD_X = 2 * CARD_SPACING;
const PAD_Y = 50;

const FIELD_X = MARGIN_X + CARD_W + PAD_X;
const FIELD_Y = MARGIN_Y;
const HAND_X = FIELD_X;
const HAND_Y = FIELD_Y + CARD_H + PAD_Y;

const ENEMY_DECK_POS = rl.Vector2{ .x = MARGIN_X, .y = FIELD_Y };
const PLAYER_DECK_POS = rl.Vector2{ .x = MARGIN_X, .y = HAND_Y };
const DISCARD_POS = rl.Vector2{ .x = SCREEN_WIDTH - CARD_W - MARGIN_X, .y = HAND_Y };
const REMOVED_POS = rl.Vector2{ .x = SCREEN_WIDTH - CARD_W - MARGIN_X, .y = FIELD_Y };

// Button Constants
const BTN_W = 100;
const BTN_H = 30;
const BTN_SPACING = 20;
const BTN_ROW_Y = HAND_Y + CARD_H + 30;

const HELP_BTN_W = 80;
const HELP_BTN_X = SCREEN_WIDTH - HELP_BTN_W - MARGIN_X;

const FS_BTN_W = 100;
const FS_BTN_H = 30;
const FS_BTN_X = MARGIN_X;
const FS_BTN_Y = BTN_ROW_Y;

const SACRIFICE_BTN_X = (SCREEN_WIDTH - (BTN_W * 2 + BTN_SPACING)) / 2;
const DELAY_BTN_X = SACRIFICE_BTN_X + BTN_W + BTN_SPACING;
const CONFIRM_BTN_X = (SCREEN_WIDTH - BTN_W) / 2;

// Tutorial Constants
const TUT_BOX_W = 500;
const TUT_BOX_H = 150;
const TUT_BOX_X = (SCREEN_WIDTH - TUT_BOX_W) / 2;
const TUT_BOX_Y_CENTER = (SCREEN_HEIGHT - TUT_BOX_H) / 2;
const TUT_BOX_Y_TOP = MARGIN_Y - 10;
const TUT_BOX_Y_BOTTOM = HAND_Y - 10;
const TUT_TEXT_MARGIN = 20;
const TUT_BTN_W = 80;
const TUT_BTN_H = 30;

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

const TutBoxPos = enum { top, center, bottom };

const TutorialStep = struct {
    text: [:0]const u8,
    highlight: ?rl.Rectangle = null,
    box_pos: TutBoxPos = .center,
};

const HL_FIELD_OFF = 10;
const HL_FIELD_W = (CARD_W + CARD_SPACING) * 4 - CARD_SPACING + HL_FIELD_OFF * 2;
const HL_FIELD_H = CARD_H + HL_FIELD_OFF * 2;

const tutorial_steps = [_]TutorialStep{
    .{ .text = "Welcome to CARD CAPTURE! Click Next to learn the basics." },
    .{
        .text = "This is the ENEMY DECK. It contains cards you must CAPTURE to WIN!",
        .highlight = .{ .x = ENEMY_DECK_POS.x - 5, .y = ENEMY_DECK_POS.y - 5, .width = CARD_W + 10, .height = CARD_H + 30 },
        .box_pos = .bottom,
    },
    .{
        .text = "This is the FIELD. Your goal is to CAPTURE or REMOVE these.",
        .highlight = .{ .x = FIELD_X - HL_FIELD_OFF, .y = FIELD_Y - HL_FIELD_OFF, .width = HL_FIELD_W, .height = HL_FIELD_H },
        .box_pos = .bottom,
    },
    .{
        .text = "This is your HAND. You use these cards to interact with the field.",
        .highlight = .{ .x = HAND_X - HL_FIELD_OFF, .y = HAND_Y - HL_FIELD_OFF, .width = HL_FIELD_W, .height = HL_FIELD_H },
        .box_pos = .top,
    },
    .{
        .text = "On your TURN, you may take ONE of three actions: CAPTURE, SACRIFICE, or DELAY.",
    },
    .{
        .text = "To CAPTURE: Select cards with the same SUIT in your HAND.",
        .highlight = .{ .x = HAND_X - HL_FIELD_OFF, .y = HAND_Y - HL_FIELD_OFF, .width = HL_FIELD_W, .height = HL_FIELD_H },
        .box_pos = .top,
    },
    .{
        .text = "Then, select a card in the FIELD of equal or lesser VALUE to CAPTURE.",
        .highlight = .{ .x = FIELD_X - HL_FIELD_OFF, .y = FIELD_Y - HL_FIELD_OFF, .width = HL_FIELD_W, .height = HL_FIELD_H },
        .box_pos = .bottom,
    },
    .{
        .text = "NOTE: Jokers MIMIC the highest VALUE card in your hand of the matching SUIT.",
    },
    .{
        .text = "The CAPTURED card and all cards used from your HAND are placed in your DISCARD pile.",
        .highlight = .{ .x = DISCARD_POS.x - 5, .y = DISCARD_POS.y - 5, .width = CARD_W + 10, .height = CARD_H + 30 },
        .box_pos = .top,
    },
    .{
        .text = "To SACRIFICE: Select ONE card from your hand. Both it and the rightmost field card are REMOVED forever.",
        .highlight = .{ .x = SACRIFICE_BTN_X - 5, .y = BTN_ROW_Y - 5, .width = BTN_W + 10, .height = BTN_H + 10 },
        .box_pos = .top,
    },
    .{
        .text = "To DELAY: Select TWO cards from your hand to REMOVE, the rightmost field card goes to the bottom of the ENEMY DECK.",
        .highlight = .{ .x = DELAY_BTN_X - 5, .y = BTN_ROW_Y - 5, .width = BTN_W + 10, .height = BTN_H + 10 },
        .box_pos = .top,
    },
    .{
        .text = "After your TURN, cards in the FIELD move to the RIGHT and a new card is drawn from the ENEMY DECK.",
        .highlight = .{ .x = FIELD_X - HL_FIELD_OFF, .y = FIELD_Y - HL_FIELD_OFF, .width = HL_FIELD_W, .height = HL_FIELD_H },
        .box_pos = .bottom,
    },
    .{
        .text = "Then, you may DISCARD any number of cards from your HAND.",
        .highlight = .{ .x = HAND_X - HL_FIELD_OFF, .y = HAND_Y - HL_FIELD_OFF, .width = HL_FIELD_W, .height = HL_FIELD_H },
        .box_pos = .top,
    },
    .{
        .text = "Finally, draw from your DECK until you have FOUR cards in your HAND before taking your next TURN.",
        .highlight = .{ .x = PLAYER_DECK_POS.x - 5, .y = PLAYER_DECK_POS.y - 5, .width = CARD_W + 10, .height = CARD_H + 30 },
        .box_pos = .top,
    },
    .{
        .text = "If your DECK is empty, SHUFFLE your DISCARD PILE. It becomes your new DECK.",
        .highlight = .{ .x = DISCARD_POS.x - 5, .y = DISCARD_POS.y - 5, .width = CARD_W + 10, .height = CARD_H + 30 },
        .box_pos = .top,
    },
    .{
        .text = "To WIN: Capture all FACE CARDS (A, J, Q, K)! If a FACE CARD is REMOVED, you LOSE...",
    },
};

// GLOBALS
var gpa_instance = std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 0 }){};
var prng_instance: std.Random.DefaultPrng = undefined;
var global_state: GameState = undefined;
var card_texture: rl.Texture2D = undefined;
var game_font: rl.Font = undefined;
var is_initialized: bool = false;
var main_allocator: std.mem.Allocator = undefined;

// Selection State
var selected_hand: [4]bool = [_]bool{false} ** 4;
var selected_field: ?usize = null;

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
    rl.setTextureFilter(card_texture, .point);

    game_font = try rl.loadFont("assets/fonts/m6x11.ttf");

    try restartGame();

    if (builtin.os.tag == .emscripten) {
        rl.setTargetFPS(60);
        emscripten.emscripten_set_main_loop(updateDrawFrame, 0, 1);
    } else {
        defer rl.closeWindow();
        defer rl.unloadTexture(card_texture);
        defer rl.unloadFont(game_font);
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
        const x = @as(f32, @floatFromInt(HAND_X + @as(i32, @intCast(i)) * (CARD_W + CARD_SPACING)));
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
        const x = @as(f32, @floatFromInt(FIELD_X + @as(i32, @intCast(3 - i)) * (CARD_W + CARD_SPACING)));
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

fn getTutBoxY(pos: TutBoxPos) i32 {
    return switch (pos) {
        .top => TUT_BOX_Y_TOP,
        .center => TUT_BOX_Y_CENTER,
        .bottom => TUT_BOX_Y_BOTTOM,
    };
}

fn processInput() void {
    if (!is_initialized) return;

    if (rl.isMouseButtonPressed(.left)) {
        const mouse = rl.getMousePosition();

        // 0. Tutorial Input
        if (tutorial_active) {
            const step = tutorial_steps[current_step];
            const box_y = getTutBoxY(step.box_pos);

            const tut_next_x = TUT_BOX_X + TUT_BOX_W - TUT_BTN_W - TUT_TEXT_MARGIN;
            const tut_btn_y = box_y + TUT_BOX_H - TUT_BTN_H - TUT_TEXT_MARGIN;
            const tut_close_x = TUT_BOX_X + TUT_TEXT_MARGIN;

            if (rl.checkCollisionPointRec(mouse, .{ .x = tut_next_x, .y = @floatFromInt(tut_btn_y), .width = TUT_BTN_W, .height = TUT_BTN_H })) {
                current_step += 1;
                if (current_step >= tutorial_steps.len) {
                    tutorial_active = false;
                    current_step = 0;
                }
            }
            if (current_step > 0 and rl.checkCollisionPointRec(mouse, .{ .x = (TUT_BOX_X + TUT_BOX_W - TUT_BTN_W) / 2, .y = @floatFromInt(tut_btn_y), .width = TUT_BTN_W, .height = TUT_BTN_H })) {
                current_step -= 1;
            }
            if (rl.checkCollisionPointRec(mouse, .{ .x = tut_close_x, .y = @floatFromInt(tut_btn_y), .width = TUT_BTN_W, .height = TUT_BTN_H })) {
                tutorial_active = false;
                current_step = 0;
            }
            return;
        }

        // Fullscreen Button
        if (rl.checkCollisionPointRec(mouse, .{ .x = FS_BTN_X, .y = FS_BTN_Y, .width = FS_BTN_W, .height = FS_BTN_H })) {
            rl.toggleFullscreen();
            return;
        }

        // Help Button
        if (rl.checkCollisionPointRec(mouse, .{ .x = HELP_BTN_X, .y = BTN_ROW_Y, .width = HELP_BTN_W, .height = BTN_H })) {
            tutorial_active = true;
            current_step = 0;
            return;
        }

        if (global_state.phase == .game_over) {
            if (rl.checkCollisionPointRec(mouse, .{ .x = CONFIRM_BTN_X, .y = 250, .width = BTN_W, .height = BTN_H })) {
                restartGame() catch {};
            }
            return;
        }

        // 1. Hand Clicks
        for (0..4) |i| {
            const x = @as(f32, @floatFromInt(HAND_X + @as(i32, @intCast(i)) * (CARD_W + CARD_SPACING)));
            const rect = rl.Rectangle{ .x = x, .y = HAND_Y, .width = CARD_W, .height = CARD_H };
            if (rl.checkCollisionPointRec(mouse, rect)) {
                if (global_state.hand[i] != null) {
                    selected_hand[i] = !selected_hand[i];
                }
            }
        }

        // 2. Field Clicks
        for (0..4) |i| {
            const x = @as(f32, @floatFromInt(FIELD_X + @as(i32, @intCast(3 - i)) * (CARD_W + CARD_SPACING)));
            const rect = rl.Rectangle{ .x = x, .y = FIELD_Y, .width = CARD_W, .height = CARD_H };
            if (rl.checkCollisionPointRec(mouse, rect)) {
                if (global_state.field[i]) |_| {
                    var h_indices: [4]usize = undefined;
                    var count: usize = 0;
                    for (selected_hand, 0..) |sel, j| if (sel) {
                        h_indices[count] = j;
                        count += 1;
                    };

                    if (count > 0 and global_state.phase == .action) {
                        if (global_state.playCapture(h_indices[0..count], i, null)) |success| {
                            if (success) {
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
            if (rl.checkCollisionPointRec(mouse, .{ .x = SACRIFICE_BTN_X, .y = BTN_ROW_Y, .width = BTN_W, .height = BTN_H })) {
                handleSacrifice();
            }
            if (rl.checkCollisionPointRec(mouse, .{ .x = DELAY_BTN_X, .y = BTN_ROW_Y, .width = BTN_W, .height = BTN_H })) {
                handleDelay();
            }
        } else if (global_state.phase == .discard) {
            if (rl.checkCollisionPointRec(mouse, .{ .x = CONFIRM_BTN_X, .y = BTN_ROW_Y, .width = BTN_W, .height = BTN_H })) {
                handleDiscard();
            }
        }
    }

    if (tutorial_active) {
        if (rl.isKeyPressed(.right)) {
            current_step += 1;
            if (current_step >= tutorial_steps.len) {
                tutorial_active = false;
                current_step = 0;
            }
        }
        if (current_step > 0 and rl.isKeyPressed(.left)) {
            current_step -= 1;
        }
        if (rl.isKeyPressed(.escape)) {
            tutorial_active = false;
            current_step = 0;
        }
    }
}

fn handleSacrifice() void {
    var count: usize = 0;
    var last_idx: usize = 0;
    for (selected_hand, 0..) |sel, i| if (sel) {
        count += 1;
        last_idx = i;
    };

    if (count != 1) return;

    if (global_state.playSacrifice(last_idx)) {
        removed_count += 2;
        resetSelection();
        syncVisuals(.sacrifice);
    }
}

fn handleDelay() void {
    var h_indices: [2]usize = undefined;
    var count: usize = 0;
    for (selected_hand, 0..) |sel, i| if (sel and count < 2) {
        h_indices[count] = i;
        count += 1;
    };

    if (count != 2) return;

    if (global_state.playDelay(h_indices)) |success| {
        if (success) {
            removed_count += 2;
            resetSelection();
            syncVisuals(.delay);
        }
    } else |_| {}
}

fn handleDiscard() void {
    var h_indices: [4]usize = undefined;
    var count: usize = 0;
    for (selected_hand, 0..) |sel, i| if (sel) {
        h_indices[count] = i;
        count += 1;
    };

    global_state.playDiscard(h_indices[0..count]) catch {
        return;
    };
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
        rl.drawTextEx(game_font, "Initializing...", .{ .x = 10, .y = 10 }, 20, 1, .red);
        return;
    }

    // Slots
    for (0..4) |i| drawSlot(@as(i32, @intFromFloat(FIELD_X)) + @as(i32, @intCast(3 - i)) * (CARD_W + CARD_SPACING), @as(i32, @intFromFloat(FIELD_Y)));
    for (0..4) |i| drawSlot(@as(i32, @intFromFloat(HAND_X)) + @as(i32, @intCast(i)) * (CARD_W + CARD_SPACING), @as(i32, @intFromFloat(HAND_Y)));

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
    const label_size = 14;
    if (global_state.enemy_deck.count() > 0) {
        drawCardBack(card_texture, @as(i32, @intFromFloat(ENEMY_DECK_POS.x)), @as(i32, @intFromFloat(ENEMY_DECK_POS.y)));
    } else drawSlot(@as(i32, @intFromFloat(ENEMY_DECK_POS.x)), @as(i32, @intFromFloat(ENEMY_DECK_POS.y)));
    var enemy_label_buf: [32]u8 = undefined;
    const enemy_label = std.fmt.bufPrintZ(&enemy_label_buf, "Enemy: {d}", .{global_state.enemy_deck.count()}) catch "Enemy";
    rl.drawTextEx(game_font, enemy_label, .{ .x = ENEMY_DECK_POS.x, .y = ENEMY_DECK_POS.y + CARD_H + label_size / 2 }, label_size, 1, .light_gray);

    if (global_state.deck.count() > 0) {
        drawCardBack(card_texture, @as(i32, @intFromFloat(PLAYER_DECK_POS.x)), @as(i32, @intFromFloat(PLAYER_DECK_POS.y)));
    } else drawSlot(@as(i32, @intFromFloat(PLAYER_DECK_POS.x)), @as(i32, @intFromFloat(PLAYER_DECK_POS.y)));
    var player_label_buf: [32]u8 = undefined;
    const player_label = std.fmt.bufPrintZ(&player_label_buf, "Deck: {d}", .{global_state.deck.count()}) catch "Deck";
    rl.drawTextEx(game_font, player_label, .{ .x = PLAYER_DECK_POS.x, .y = PLAYER_DECK_POS.y + CARD_H + label_size / 2 }, label_size, 1, .light_gray);

    if (global_state.discard_pile.count() > 0) {
        const top = global_state.discard_pile.cards[global_state.discard_pile.len - 1];
        drawCard(card_texture, @as(i32, @intFromFloat(DISCARD_POS.x)), @as(i32, @intFromFloat(DISCARD_POS.y)), top);
    } else drawSlot(@as(i32, @intFromFloat(DISCARD_POS.x)), @as(i32, @intFromFloat(DISCARD_POS.y)));
    var discard_label_buf: [32]u8 = undefined;
    const discard_label = std.fmt.bufPrintZ(&discard_label_buf, "Discard: {d}", .{global_state.discard_pile.count()}) catch "Discard";
    rl.drawTextEx(game_font, discard_label, .{ .x = DISCARD_POS.x, .y = DISCARD_POS.y + CARD_H + label_size / 2 }, label_size, 1, .light_gray);

    if (removed_count > 0) drawCardBack(card_texture, @as(i32, @intFromFloat(REMOVED_POS.x)), @as(i32, @intFromFloat(REMOVED_POS.y))) else drawSlot(@as(i32, @intFromFloat(REMOVED_POS.x)), @as(i32, @intFromFloat(REMOVED_POS.y)));
    rl.drawTextEx(game_font, "Removed", .{ .x = REMOVED_POS.x, .y = REMOVED_POS.y + CARD_H + label_size / 2 }, label_size, 1, .light_gray);

    // UI
    if (global_state.phase == .action) {
        drawButton(SACRIFICE_BTN_X, BTN_ROW_Y, BTN_W, BTN_H, "SACRIFICE", .orange);
        drawButton(DELAY_BTN_X, BTN_ROW_Y, BTN_W, BTN_H, "DELAY", .dark_blue);
    } else if (global_state.phase == .discard) {
        drawButton(CONFIRM_BTN_X, BTN_ROW_Y, BTN_W, BTN_H, "CONFIRM", .dark_gray);
    } else if (global_state.phase == .game_over) {
        const msg_size = 32;
        const msg = if (global_state.is_won) "VICTORY!" else "DEFEAT";
        const col = if (global_state.is_won) rl.Color.gold else rl.Color.red;
        const tw = rl.measureTextEx(game_font, msg, msg_size, 1).x;
        rl.drawTextEx(game_font, msg, .{
            .x = @as(f32, @floatFromInt(@divTrunc(@as(i32, @intCast(SCREEN_WIDTH)) - @as(i32, @intFromFloat(tw)), 2))),
            .y = MARGIN_Y + (HAND_Y + CARD_H - MARGIN_Y - msg_size) / 2,
        }, msg_size, 1, col);
        drawButton(CONFIRM_BTN_X, BTN_ROW_Y, BTN_W + 20, BTN_H, "PLAY AGAIN?", .dark_gray);
    }

    drawButton(HELP_BTN_X, BTN_ROW_Y, HELP_BTN_W, BTN_H, "HELP", .dark_gray);
    drawButton(FS_BTN_X, FS_BTN_Y, FS_BTN_W, FS_BTN_H, "FULLSCREEN", .dark_gray);

    // Tutorial Overlay
    if (tutorial_active) {
        const step = tutorial_steps[current_step];
        const dim_color = rl.fade(.black, 0.7);

        if (step.highlight) |h| {
            const hx: i32 = @intFromFloat(h.x);
            const hy: i32 = @intFromFloat(h.y);
            const hw: i32 = @intFromFloat(h.width);
            const hh: i32 = @intFromFloat(h.height);

            rl.drawRectangle(0, 0, SCREEN_WIDTH, hy, dim_color);
            rl.drawRectangle(0, hy + hh, SCREEN_WIDTH, SCREEN_HEIGHT - (hy + hh), dim_color);
            rl.drawRectangle(0, hy, hx, hh, dim_color);
            rl.drawRectangle(hx + hw, hy, SCREEN_WIDTH - (hx + hw), hh, dim_color);

            rl.drawRectangleLinesEx(h, 3, .yellow);
        } else {
            rl.drawRectangle(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, dim_color);
        }

        const box_y = getTutBoxY(step.box_pos);
        const box_rect = rl.Rectangle{ .x = TUT_BOX_X, .y = @floatFromInt(box_y), .width = TUT_BOX_W, .height = TUT_BOX_H };
        rl.drawRectangleRec(box_rect, .dark_gray);
        rl.drawRectangleLinesEx(box_rect, 2, .ray_white);

        drawTextWrapped(step.text, @as(i32, @intFromFloat(TUT_BOX_X)) + TUT_TEXT_MARGIN, box_y + TUT_TEXT_MARGIN, TUT_BOX_W - (TUT_TEXT_MARGIN * 2), 20, .ray_white);

        const tut_btn_y = box_y + TUT_BOX_H - TUT_BTN_H - TUT_TEXT_MARGIN;
        const tut_next_btn_x = TUT_BOX_X + TUT_BOX_W - TUT_BTN_W - TUT_TEXT_MARGIN;
        const tut_prev_btn_x = tut_next_btn_x - TUT_BTN_W - TUT_TEXT_MARGIN;
        drawButton(@as(i32, @intFromFloat(TUT_BOX_X)) + TUT_TEXT_MARGIN, tut_btn_y, TUT_BTN_W, TUT_BTN_H, "CLOSE", .maroon);
        if (current_step > 0) {
            drawButton(@as(i32, @intFromFloat(tut_prev_btn_x)), tut_btn_y, TUT_BTN_W, TUT_BTN_H, "PREV", .dark_gray);
        }
        drawButton(@as(i32, @intFromFloat(tut_next_btn_x)), tut_btn_y, TUT_BTN_W, TUT_BTN_H, if (current_step == tutorial_steps.len - 1) "FINISH" else "NEXT", .dark_green);
    }
}

fn drawTextWrapped(text: [:0]const u8, x: i32, y: i32, width: i32, fontSize: i32, color: rl.Color) void {
    var cursor_x: i32 = x;
    var cursor_y: i32 = y;
    const space_width = @as(i32, @intFromFloat(rl.measureTextEx(game_font, " ", @floatFromInt(fontSize), 1).x));

    var it = std.mem.tokenizeAny(u8, text, " ");
    while (it.next()) |word| {
        var word_buf: [128:0]u8 = undefined;
        const word_z: [:0]const u8 = std.fmt.bufPrintZ(&word_buf, "{s}", .{word}) catch "err";

        const word_width = @as(i32, @intFromFloat(rl.measureTextEx(game_font, word_z, @floatFromInt(fontSize), 1).x));
        if (cursor_x + word_width > x + width) {
            cursor_x = x;
            cursor_y += fontSize + 5;
        }
        rl.drawTextEx(game_font, word_z, .{ .x = @floatFromInt(cursor_x), .y = @floatFromInt(cursor_y) }, @floatFromInt(fontSize), 1, color);
        cursor_x += word_width + space_width;
    }
}

fn drawButton(x: i32, y: i32, w: i32, h: i32, text: [:0]const u8, color: rl.Color) void {
    const font_size = 14;
    const rect = rl.Rectangle{ .x = @floatFromInt(x), .y = @floatFromInt(y), .width = @floatFromInt(w), .height = @floatFromInt(h) };
    rl.drawRectangleRec(rect, color);
    rl.drawRectangleLinesEx(rect, 2, .ray_white);
    const tw = rl.measureTextEx(game_font, text, font_size, 1).x;
    rl.drawTextEx(game_font, text, .{ .x = @floatFromInt(x + @divTrunc(w - @as(i32, @intFromFloat(tw)), 2)), .y = @floatFromInt(y + @divTrunc(h - font_size, 2)) }, font_size, 1, .ray_white);
}

fn drawSlot(x: i32, y: i32) void {
    rl.drawRectangleLines(x, y, CARD_W, CARD_H, .gray);
}

fn drawCard(tex: rl.Texture2D, x: i32, y: i32, card: Card) void {
    const sw = @as(f32, @floatFromInt(tex.width)) / SHEET_COLS;
    const sh = @as(f32, @floatFromInt(tex.height)) / SHEET_ROWS;
    var col: f32 = 0;
    var row: f32 = 0;
    if (card.rank == .joker) {
        col = 0;
        row = 2;
    } else {
        row = switch (card.suit) {
            .hearts => @as(f32, 0),
            .clubs => @as(f32, 1),
            .diamonds => @as(f32, 2),
            .spades => @as(f32, 3),
        };
        const rank_val = @intFromEnum(card.rank);
        if (card.rank == .ace) {
            col = 13;
        } else {
            col = @floatFromInt(rank_val - 1);
        }
    }
    rl.drawTexturePro(tex, .{ .x = col * sw, .y = row * sh, .width = sw, .height = sh }, .{ .x = @floatFromInt(x), .y = @floatFromInt(y), .width = CARD_W, .height = CARD_H }, .{ .x = 0, .y = 0 }, 0, .white);
}

fn drawCardBack(tex: rl.Texture2D, x: i32, y: i32) void {
    const sw = @as(f32, @floatFromInt(tex.width)) / SHEET_COLS;
    const sh = @as(f32, @floatFromInt(tex.height)) / SHEET_ROWS;
    rl.drawTexturePro(tex, .{ .x = 0, .y = 0, .width = sw, .height = sh }, .{ .x = @floatFromInt(x), .y = @floatFromInt(y), .width = CARD_W, .height = CARD_H }, .{ .x = 0, .y = 0 }, 0, .white);
}
