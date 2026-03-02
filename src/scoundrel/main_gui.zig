const std = @import("std");
const rl = @import("raylib");
const builtin = @import("builtin");
const solitaire = @import("solitaire");
const solitaire_gui = @import("solitaire_gui");

const emscripten = std.os.emscripten;
const ScoundrelState = solitaire.scoundrel.ScoundrelState;
const Card = solitaire.card.Card;

const gui_card = solitaire_gui.card;
const gui_ui = solitaire_gui.ui;
const gui_tutorial = solitaire_gui.tutorial;

const VisualCard = gui_card.VisualCard;

// --- Constants ---

const Config = struct {
    const screen_width = 640;
    const screen_height = 400;
    const target_fps = 60;
};

const Layout = struct {
    const card_w = 80;
    const card_h = 110;
    const card_spacing = 15;
    const margin_x = 30;
    const margin_y = 40;
    const row_spacing = 60;

    const top_y = margin_y;
    const bottom_y = top_y + card_h + row_spacing;

    const deck = rl.Vector2{ .x = margin_x, .y = top_y };
    const field_x = deck.x + card_w + card_spacing + 20;
    const removed = rl.Vector2{ .x = Config.screen_width - card_w - margin_x, .y = top_y };

    const weapon = rl.Vector2{ .x = field_x, .y = bottom_y };
    const monster_stack = rl.Vector2{ .x = weapon.x + card_w + card_spacing, .y = bottom_y };
};

// --- GLOBALS ---
var prng_instance: std.Random.DefaultPrng = undefined;
var state: ScoundrelState = undefined;
var card_texture: rl.Texture2D = undefined;
var game_font: rl.Font = undefined;
var is_initialized: bool = false;
var main_allocator: std.mem.Allocator = undefined;

// Animation State
var field_visuals: [4]?VisualCard = [_]?VisualCard{null} ** 4;
var weapon_visual: ?VisualCard = null;
var monster_visuals: [16]?VisualCard = [_]?VisualCard{null} ** 16;
var flying_visuals: [16]?VisualCard = [_]?VisualCard{null} ** 16;

pub fn main() !void {
    main_allocator = if (builtin.os.tag == .emscripten)
        std.heap.wasm_allocator
    else
        std.heap.c_allocator;

    rl.initWindow(Config.screen_width, Config.screen_height, "Scoundrel");

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
        defer state.deinit();

        rl.setTargetFPS(Config.target_fps);
        while (!rl.windowShouldClose()) {
            updateDrawFrame();
        }
    }
}

fn restartGame() !void {
    if (is_initialized) {
        state.deinit();
    }

    state = try ScoundrelState.init(main_allocator, prng_instance.random());

    for (0..4) |i| field_visuals[i] = null;
    weapon_visual = null;
    for (0..16) |i| {
        monster_visuals[i] = null;
        flying_visuals[i] = null;
    }

    syncVisuals();
    is_initialized = true;
}

fn syncVisuals() void {
    // 1. Process Field
    for (0..4) |i| {
        const target = rl.Vector2{ 
            .x = Layout.field_x + @as(f32, @floatFromInt(i)) * (Layout.card_w + Layout.card_spacing), 
            .y = Layout.top_y 
        };
        if (state.field[i]) |card| {
            if (field_visuals[i]) |*v| {
                v.card = card;
                v.target_pos = target;
            } else {
                field_visuals[i] = VisualCard{ .card = card, .pos = Layout.deck, .target_pos = target, .active = true };
            }
        } else {
            field_visuals[i] = null;
        }
    }

    // 2. Process Weapon
    if (state.active_card) |card| {
        if (weapon_visual) |*v| {
            v.card = card;
        } else {
            weapon_visual = VisualCard{ .card = card, .pos = Layout.weapon, .target_pos = Layout.weapon, .active = true };
        }
    } else {
        weapon_visual = null;
    }

    // 3. Process Monster Stack (simplification: just show top card visually for now)
    for (0..16) |i| monster_visuals[i] = null;
    if (state.monster_stack.count() > 0) {
        const count = state.monster_stack.count();
        const top_card = state.monster_stack.cards[count - 1];
        monster_visuals[0] = VisualCard{ 
            .card = top_card, 
            .pos = Layout.monster_stack, 
            .target_pos = Layout.monster_stack, 
            .active = true 
        };
    }
}

export fn updateDrawFrame() void {
    const dt = rl.getFrameTime();

    for (&field_visuals) |*maybe_v| if (maybe_v.*) |*v| v.update(dt);
    if (weapon_visual) |*v| v.update(dt);
    for (&monster_visuals) |*maybe_v| if (maybe_v.*) |*v| v.update(dt);

    rl.beginDrawing();
    defer rl.endDrawing();

    rl.clearBackground(.dark_gray);

    if (!is_initialized) return;

    // Slots
    gui_card.drawSlot(Layout.deck, Layout.card_w, Layout.card_h, .gray);
    for (0..4) |i| {
        gui_card.drawSlot(.{ 
            .x = Layout.field_x + @as(f32, @floatFromInt(i)) * (Layout.card_w + Layout.card_spacing), 
            .y = Layout.top_y 
        }, Layout.card_w, Layout.card_h, .gray);
    }
    gui_card.drawSlot(Layout.removed, Layout.card_w, Layout.card_h, .gray);
    gui_card.drawSlot(Layout.weapon, Layout.card_w, Layout.card_h, .gray);
    gui_card.drawSlot(Layout.monster_stack, Layout.card_w, Layout.card_h, .gray);

    // Deck
    if (state.deck.count() > 0) {
        gui_card.drawCardBack(card_texture, Layout.deck, Layout.card_w, Layout.card_h);
    }
    gui_ui.drawLabel(game_font, "Deck: {d}", state.deck.count(), Layout.deck, 14, .light_gray, Layout.card_h);

    // Removed Pile
    if (state.removed_pile.count() > 0) {
        gui_card.drawCardBack(card_texture, Layout.removed, Layout.card_w, Layout.card_h);
    }
    gui_ui.drawLabel(game_font, "Removed: {d}", state.removed_pile.count(), Layout.removed, 14, .light_gray, Layout.card_h);

    // Field
    for (field_visuals) |maybe_v| if (maybe_v) |v| v.draw(card_texture, Layout.card_w, Layout.card_h);

    // Weapon
    if (weapon_visual) |v| {
        v.draw(card_texture, Layout.card_w, Layout.card_h);
        gui_ui.drawLabel(game_font, "Weapon", null, Layout.weapon, 14, .gold, Layout.card_h);
    }

    // Monster Stack
    if (monster_visuals[0]) |v| {
        v.draw(card_texture, Layout.card_w, Layout.card_h);
        gui_ui.drawLabel(game_font, "Stack: {d}", state.monster_stack.count(), Layout.monster_stack, 14, .red, Layout.card_h);
    }

    // Status / HP
    var hp_buf: [32]u8 = undefined;
    const hp_text = std.fmt.bufPrintZ(&hp_buf, "HEALTH: {d}/{d}", .{ state.health, state.max_health }) catch "HP ERROR";
    rl.drawTextEx(game_font, hp_text, .{ .x = Layout.margin_x, .y = Layout.bottom_y }, 24, 1, if (state.health <= 5) .red else .ray_white);

    if (state.is_won) {
        rl.drawTextEx(game_font, "VICTORY!", .{ .x = 250, .y = 180 }, 40, 2, .gold);
    } else if (state.is_lost) {
        rl.drawTextEx(game_font, "DEFEAT", .{ .x = 250, .y = 180 }, 40, 2, .red);
    }
}
