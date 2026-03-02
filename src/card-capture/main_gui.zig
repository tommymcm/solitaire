const std = @import("std");
const rl = @import("raylib");
const builtin = @import("builtin");
const solitaire = @import("solitaire");
const solitaire_gui = @import("solitaire_gui");

const emscripten = std.os.emscripten;
const GameState = solitaire.rules.GameState;
const Card = solitaire.card.Card;

const gui_card = solitaire_gui.card;
const gui_ui = solitaire_gui.ui;
const gui_tutorial = solitaire_gui.tutorial;

const VisualCard = gui_card.VisualCard;
const TutorialStep = gui_tutorial.TutorialStep;
const TutorialState = gui_tutorial.TutorialState;

// --- Constants ---

const Config = struct {
    const screen_width = 600;
    const screen_height = 380;
    const target_fps = 60;
};

const Layout = struct {
    const card_w = 80;
    const card_h = 110;
    const card_spacing = 10;
    const margin_x = 25;
    const margin_y = 25; // Top margin for decks and cards
    const pad_x = 2 * card_spacing;
    const pad_y = 50;

    const field_x = margin_x + card_w + pad_x;
    const field_y = margin_y;
    const hand_x = field_x;
    const hand_y = field_y + card_h + pad_y;

    const enemy_deck = rl.Vector2{ .x = margin_x, .y = field_y };
    const player_deck = rl.Vector2{ .x = margin_x, .y = hand_y };
    const discard = rl.Vector2{ .x = Config.screen_width - card_w - margin_x, .y = hand_y };
    const removed = rl.Vector2{ .x = Config.screen_width - card_w - margin_x, .y = field_y };
};

const UI = struct {
    // Button Constants
    const btn_w = 100;
    const btn_h = 30;
    const btn_spacing = 20;
    const btn_row_y = Layout.hand_y + Layout.card_h + 30;

    const help_btn_w = 80;
    const help_btn_x = Config.screen_width - help_btn_w - Layout.margin_x;

    const fs_btn_w = 100;
    const fs_btn_h = 30;
    const fs_btn_x = Layout.margin_x;
    const fs_btn_y = btn_row_y;

    const sacrifice_btn_x = (Config.screen_width - (btn_w * 2 + btn_spacing)) / 2;
    const delay_btn_x = sacrifice_btn_x + btn_w + btn_spacing;
    const confirm_btn_x = (Config.screen_width - btn_w) / 2;

    // Tutorial Constants
    const tut_box_w = 500;
    const tut_box_h = 150;
    const tut_box_x = (Config.screen_width - tut_box_w) / 2;
    const tut_box_y_center = (Config.screen_height - tut_box_h) / 2;
    const tut_box_y_top = Layout.margin_y - 10;
    const tut_box_y_bottom = Layout.hand_y - 10;
    const tut_text_margin = 20;
    const tut_btn_w = 80;
    const tut_btn_h = 30;

    const hl_field_off = 10;
    const hl_field_w = (Layout.card_w + Layout.card_spacing) * 4 - Layout.card_spacing + hl_field_off * 2;
    const hl_field_h = Layout.card_h + hl_field_off * 2;

    const tut_config = .{
        .x = tut_box_x,
        .y_top = tut_box_y_top,
        .y_center = tut_box_y_center,
        .y_bottom = tut_box_y_bottom,
        .w = tut_box_w,
        .h = tut_box_h,
        .text_margin = tut_text_margin,
        .btn_w = tut_btn_w,
        .btn_h = tut_btn_h,
    };
};

const ActionType = enum { none, capture, sacrifice, delay, discard };

const tutorial_steps = [_]TutorialStep{
    .{ .text = "Welcome to CARD CAPTURE! Click Next to learn the basics." },
    .{
        .text = "This is the ENEMY DECK. It contains cards you must CAPTURE to WIN!",
        .highlight = .{ .x = Layout.enemy_deck.x - 5, .y = Layout.enemy_deck.y - 5, .width = Layout.card_w + 10, .height = Layout.card_h + 30 },
        .box_pos = .bottom,
    },
    .{
        .text = "This is the FIELD. Your goal is to CAPTURE or REMOVE these.",
        .highlight = .{ .x = Layout.field_x - UI.hl_field_off, .y = Layout.field_y - UI.hl_field_off, .width = UI.hl_field_w, .height = UI.hl_field_h },
        .box_pos = .bottom,
    },
    .{
        .text = "This is your HAND. You use these cards to interact with the field.",
        .highlight = .{ .x = Layout.hand_x - UI.hl_field_off, .y = Layout.hand_y - UI.hl_field_off, .width = UI.hl_field_w, .height = UI.hl_field_h },
        .box_pos = .top,
    },
    .{
        .text = "On your TURN, you may take ONE of three actions: CAPTURE, SACRIFICE, or DELAY.",
    },
    .{
        .text = "To CAPTURE: Select cards with the same SUIT in your HAND.",
        .highlight = .{ .x = Layout.hand_x - UI.hl_field_off, .y = Layout.hand_y - UI.hl_field_off, .width = UI.hl_field_w, .height = UI.hl_field_h },
        .box_pos = .top,
    },
    .{
        .text = "Then, select a card in the FIELD of equal or lesser VALUE to CAPTURE.",
        .highlight = .{ .x = Layout.field_x - UI.hl_field_off, .y = Layout.field_y - UI.hl_field_off, .width = UI.hl_field_w, .height = UI.hl_field_h },
        .box_pos = .bottom,
    },
    .{
        .text = "NOTE: Jokers MIMIC the highest VALUE card in your hand of the matching SUIT.",
    },
    .{
        .text = "The CAPTURED card and all cards used from your HAND are placed in your DISCARD pile.",
        .highlight = .{ .x = Layout.discard.x - 5, .y = Layout.discard.y - 5, .width = Layout.card_w + 10, .height = Layout.card_h + 30 },
        .box_pos = .top,
    },
    .{
        .text = "To SACRIFICE: Select ONE card from your hand. Both it and the rightmost field card are REMOVED forever.",
        .highlight = .{ .x = UI.sacrifice_btn_x - 5, .y = UI.btn_row_y - 5, .width = UI.btn_w + 10, .height = UI.btn_h + 10 },
        .box_pos = .top,
    },
    .{
        .text = "To DELAY: Select TWO cards from your hand to REMOVE, the rightmost field card goes to the bottom of the ENEMY DECK.",
        .highlight = .{ .x = UI.delay_btn_x - 5, .y = UI.btn_row_y - 5, .width = UI.btn_w + 10, .height = UI.btn_h + 10 },
        .box_pos = .top,
    },
    .{
        .text = "After your TURN, cards in the FIELD move to the RIGHT and a new card is drawn from the ENEMY DECK.",
        .highlight = .{ .x = Layout.field_x - UI.hl_field_off, .y = Layout.field_y - UI.hl_field_off, .width = UI.hl_field_w, .height = UI.hl_field_h },
        .box_pos = .bottom,
    },
    .{
        .text = "Then, you may DISCARD any number of cards from your HAND.",
        .highlight = .{ .x = Layout.hand_x - UI.hl_field_off, .y = Layout.hand_y - UI.hl_field_off, .width = UI.hl_field_w, .height = UI.hl_field_h },
        .box_pos = .top,
    },
    .{
        .text = "Finally, draw from your DECK until you have FOUR cards in your HAND before taking your next TURN.",
        .highlight = .{ .x = Layout.player_deck.x - 5, .y = Layout.player_deck.y - 5, .width = Layout.card_w + 10, .height = Layout.card_h + 30 },
        .box_pos = .top,
    },
    .{
        .text = "If your DECK is empty, SHUFFLE your DISCARD PILE. It becomes your new DECK.",
        .highlight = .{ .x = Layout.discard.x - 5, .y = Layout.discard.y - 5, .width = Layout.card_w + 10, .height = Layout.card_h + 30 },
        .box_pos = .top,
    },
    .{
        .text = "To WIN: Capture all FACE CARDS (A, J, Q, K)! If a FACE CARD is REMOVED, you LOSE...",
    },
};

// --- GLOBALS ---
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
var tut_state: TutorialState = .{ .steps = &tutorial_steps };

// --- FUNCTIONS ---

pub fn main() !void {
    main_allocator = if (builtin.os.tag == .emscripten)
        std.heap.wasm_allocator
    else
        std.heap.c_allocator;

    rl.initWindow(Config.screen_width, Config.screen_height, "Card Capture");

    var seed: u64 = undefined;
    try std.posix.getrandom(std.mem.asBytes(&seed));
    prng_instance = std.Random.DefaultPrng.init(seed);

    card_texture = try rl.loadTexture("assets/cards.png");
    rl.setTextureFilter(card_texture, .point);

    game_font = try rl.loadFont("assets/fonts/m6x11.ttf");

    try restartGame();

    if (builtin.os.tag == .emscripten) {
        rl.setTargetFPS(Config.target_fps);
        emscripten.emscripten_set_main_loop(updateDrawFrame, 0, 1);
    } else {
        defer rl.closeWindow();
        defer rl.unloadTexture(card_texture);
        defer rl.unloadFont(game_font);
        defer global_state.deinit();

        rl.setTargetFPS(Config.target_fps);
        while (!rl.windowShouldClose()) {
            updateDrawFrame();
        }
    }
}

fn restartGame() !void {
    if (is_initialized) {
        global_state.deinit();
    }

    global_state = try GameState.init(main_allocator, prng_instance.random());

    for (0..4) |i| selected_hand[i] = false;
    selected_field = null;

    for (0..4) |i| {
        field_visuals[i] = null;
        hand_visuals[i] = null;
    }
    for (0..16) |i| flying_visuals[i] = null;
    removed_count = 0;
    tut_state.active = false;
    tut_state.current_step = 0;

    syncVisuals(.none);
    is_initialized = true;
}

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
    // 1. Process Hand
    var old_hand = hand_visuals;
    for (0..4) |i| {
        const x = @as(f32, @floatFromInt(Layout.hand_x + @as(i32, @intCast(i)) * (Layout.card_w + Layout.card_spacing)));
        const target = rl.Vector2{ .x = x, .y = Layout.hand_y };

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
                hand_visuals[i] = VisualCard{ .card = card, .pos = Layout.player_deck, .target_pos = target, .active = true };
            }
        } else {
            hand_visuals[i] = null;
        }
    }

    for (old_hand) |maybe_v| {
        if (maybe_v) |v| {
            const end_pos = if (action == .sacrifice or action == .delay) Layout.removed else Layout.discard;
            spawnFlying(v.card, v.pos, end_pos);
        }
    }

    // 2. Process Field
    var old_field = field_visuals;
    for (0..4) |i| {
        const x = @as(f32, @floatFromInt(Layout.field_x + @as(i32, @intCast(3 - i)) * (Layout.card_w + Layout.card_spacing)));
        const target = rl.Vector2{ .x = x, .y = Layout.field_y };

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
                field_visuals[i] = VisualCard{ .card = card, .pos = Layout.enemy_deck, .target_pos = target, .active = true };
            }
        } else {
            field_visuals[i] = null;
        }
    }

    for (old_field) |maybe_v| {
        if (maybe_v) |v| {
            var end_pos = Layout.discard;
            if (action == .delay) {
                end_pos = Layout.enemy_deck;
            } else if (action == .sacrifice) {
                end_pos = Layout.removed;
            }
            spawnFlying(v.card, v.pos, end_pos);
        }
    }
}

fn processInput() void {
    if (!is_initialized) return;

    if (rl.isMouseButtonPressed(.left)) {
        const mouse = rl.getMousePosition();

        if (tut_state.handleInput(mouse, UI.tut_config)) {
            return;
        }

        // Global Buttons
        if (rl.checkCollisionPointRec(mouse, .{ .x = UI.fs_btn_x, .y = UI.fs_btn_y, .width = UI.fs_btn_w, .height = UI.fs_btn_h })) {
            rl.toggleFullscreen();
            return;
        }
        if (rl.checkCollisionPointRec(mouse, .{ .x = UI.help_btn_x, .y = UI.btn_row_y, .width = UI.help_btn_w, .height = UI.btn_h })) {
            tut_state.active = true;
            tut_state.current_step = 0;
            return;
        }

        if (global_state.phase == .game_over) {
            if (rl.checkCollisionPointRec(mouse, .{ .x = UI.confirm_btn_x, .y = UI.btn_row_y, .width = UI.btn_w, .height = UI.btn_h })) {
                restartGame() catch {};
            }
            return;
        }

        // 1. Hand Clicks
        for (0..4) |i| {
            const x = @as(f32, @floatFromInt(Layout.hand_x + @as(i32, @intCast(i)) * (Layout.card_w + Layout.card_spacing)));
            const rect = rl.Rectangle{ .x = x, .y = Layout.hand_y, .width = Layout.card_w, .height = Layout.card_h };
            if (rl.checkCollisionPointRec(mouse, rect)) {
                if (global_state.hand[i] != null) {
                    selected_hand[i] = !selected_hand[i];
                }
            }
        }

        // 2. Field Clicks
        for (0..4) |i| {
            const x = @as(f32, @floatFromInt(Layout.field_x + @as(i32, @intCast(3 - i)) * (Layout.card_w + Layout.card_spacing)));
            const rect = rl.Rectangle{ .x = x, .y = Layout.field_y, .width = Layout.card_w, .height = Layout.card_h };
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
                    selected_field = if (selected_field == i) null else i;
                }
            }
        }

        // 3. Action Buttons
        if (global_state.phase == .action) {
            if (rl.checkCollisionPointRec(mouse, .{ .x = UI.sacrifice_btn_x, .y = UI.btn_row_y, .width = UI.btn_w, .height = UI.btn_h })) {
                handleSacrifice();
            }
            if (rl.checkCollisionPointRec(mouse, .{ .x = UI.delay_btn_x, .y = UI.btn_row_y, .width = UI.btn_w, .height = UI.btn_h })) {
                handleDelay();
            }
        } else if (global_state.phase == .discard) {
            if (rl.checkCollisionPointRec(mouse, .{ .x = UI.confirm_btn_x, .y = UI.btn_row_y, .width = UI.btn_w, .height = UI.btn_h })) {
                handleDiscard();
            }
        }
    }

    if (tut_state.active) {
        if (rl.isKeyPressed(.right)) {
            tut_state.current_step += 1;
            if (tut_state.current_step >= tutorial_steps.len) {
                tut_state.active = false;
                tut_state.current_step = 0;
            }
        }
        if (tut_state.current_step > 0 and rl.isKeyPressed(.left)) {
            tut_state.current_step -= 1;
        }
        if (rl.isKeyPressed(.escape)) {
            tut_state.active = false;
            tut_state.current_step = 0;
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

    for (&field_visuals) |*maybe_v| if (maybe_v.*) |*v| v.update(dt);
    for (&hand_visuals) |*maybe_v| if (maybe_v.*) |*v| v.update(dt);
    for (&flying_visuals) |*maybe_v| {
        if (maybe_v.*) |*v| {
            v.update(dt);
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
    for (0..4) |i| gui_card.drawSlot(.{ .x = Layout.field_x + @as(f32, @floatFromInt(@as(i32, @intCast(3 - i)) * (Layout.card_w + Layout.card_spacing))), .y = Layout.field_y }, Layout.card_w, Layout.card_h, .gray);
    for (0..4) |i| gui_card.drawSlot(.{ .x = Layout.hand_x + @as(f32, @floatFromInt(@as(i32, @intCast(i)) * (Layout.card_w + Layout.card_spacing))), .y = Layout.hand_y }, Layout.card_w, Layout.card_h, .gray);

    // Cards
    for (field_visuals, 0..) |maybe_v, i| if (maybe_v) |v| {
        v.draw(card_texture, Layout.card_w, Layout.card_h);
        if (selected_field == i) rl.drawRectangleLinesEx(.{ .x = v.pos.x, .y = v.pos.y, .width = Layout.card_w, .height = Layout.card_h }, 3, .yellow);
    };
    for (hand_visuals, 0..) |maybe_v, i| if (maybe_v) |v| {
        v.draw(card_texture, Layout.card_w, Layout.card_h);
        if (selected_hand[i]) rl.drawRectangleLinesEx(.{ .x = v.pos.x, .y = v.pos.y, .width = Layout.card_w, .height = Layout.card_h }, 3, .yellow);
    };
    for (flying_visuals) |maybe_v| if (maybe_v) |v| v.draw(card_texture, Layout.card_w, Layout.card_h);

    // Decks & Piles
    const label_size = 14;
    if (global_state.enemy_deck.count() > 0) {
        gui_card.drawCardBack(card_texture, Layout.enemy_deck, Layout.card_w, Layout.card_h);
    } else gui_card.drawSlot(Layout.enemy_deck, Layout.card_w, Layout.card_h, .gray);
    gui_ui.drawLabel(game_font, "Enemy: {d}", global_state.enemy_deck.count(), Layout.enemy_deck, label_size, .light_gray, Layout.card_h);

    if (global_state.deck.count() > 0) {
        gui_card.drawCardBack(card_texture, Layout.player_deck, Layout.card_w, Layout.card_h);
    } else gui_card.drawSlot(Layout.player_deck, Layout.card_w, Layout.card_h, .gray);
    gui_ui.drawLabel(game_font, "Deck: {d}", global_state.deck.count(), Layout.player_deck, label_size, .light_gray, Layout.card_h);

    if (global_state.discard_pile.count() > 0) {
        const top = global_state.discard_pile.cards[global_state.discard_pile.len - 1];
        (VisualCard{ .card = top, .pos = Layout.discard, .target_pos = Layout.discard }).draw(card_texture, Layout.card_w, Layout.card_h);
    } else gui_card.drawSlot(Layout.discard, Layout.card_w, Layout.card_h, .gray);
    gui_ui.drawLabel(game_font, "Discard: {d}", global_state.discard_pile.count(), Layout.discard, label_size, .light_gray, Layout.card_h);

    if (removed_count > 0) gui_card.drawCardBack(card_texture, Layout.removed, Layout.card_w, Layout.card_h) else gui_card.drawSlot(Layout.removed, Layout.card_w, Layout.card_h, .gray);
    gui_ui.drawLabel(game_font, "Removed", null, Layout.removed, label_size, .light_gray, Layout.card_h);

    // UI
    if (global_state.phase == .action) {
        gui_ui.drawButton(game_font, UI.sacrifice_btn_x, UI.btn_row_y, UI.btn_w, UI.btn_h, "SACRIFICE", .orange);
        gui_ui.drawButton(game_font, UI.delay_btn_x, UI.btn_row_y, UI.btn_w, UI.btn_h, "DELAY", .dark_blue);
    } else if (global_state.phase == .discard) {
        gui_ui.drawButton(game_font, UI.confirm_btn_x, UI.btn_row_y, UI.btn_w, UI.btn_h, "CONFIRM", .dark_gray);
    } else if (global_state.phase == .game_over) {
        const msg_size = 32;
        const msg = if (global_state.is_won) "VICTORY!" else "DEFEAT";
        const col = if (global_state.is_won) rl.Color.gold else rl.Color.red;
        const tw = rl.measureTextEx(game_font, msg, msg_size, 1).x;
        rl.drawTextEx(game_font, msg, .{
            .x = (Config.screen_width - tw) / 2,
            .y = Layout.margin_y + (Layout.hand_y + Layout.card_h - Layout.margin_y - msg_size) / 2,
        }, msg_size, 1, col);
        gui_ui.drawButton(game_font, UI.confirm_btn_x, UI.btn_row_y, UI.btn_w + 20, UI.btn_h, "PLAY AGAIN?", .dark_gray);
    }

    gui_ui.drawButton(game_font, UI.help_btn_x, UI.btn_row_y, UI.help_btn_w, UI.btn_h, "HELP", .dark_gray);
    gui_ui.drawButton(game_font, UI.fs_btn_x, UI.fs_btn_y, UI.fs_btn_w, UI.fs_btn_h, "FULLSCREEN", .dark_gray);

    // Tutorial Overlay
    if (tut_state.active) {
        tut_state.draw(game_font, Config.screen_width, Config.screen_height, UI.tut_config);
    }
}
