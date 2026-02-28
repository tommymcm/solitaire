const std = @import("std");
const rl = @import("raylib");
const builtin = @import("builtin");

const emscripten = std.os.emscripten;

const SCREEN_WIDTH = 800;
const SCREEN_HEIGHT = 450;

const CARD_W = 80;
const CARD_H = 110;
const SPACING = 20;

pub fn main() !void {
    rl.initWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Card Capture - Board Layout");

    if (builtin.os.tag == .emscripten) {
        rl.setTargetFPS(60);
        emscripten.emscripten_set_main_loop(updateDrawFrame, 0, 1);
    } else {
        defer rl.closeWindow();
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

    // 1. Opponent's Deck Area
    drawArea(20, 20, "Enemy Deck");

    // 2. Field Area (4 slots)
    const field_start_x = 210;
    const field_y = 150;
    rl.drawText("Field", field_start_x, field_y - 25, 20, .light_gray);
    for (0..4) |i| {
        const x = field_start_x + @as(i32, @intCast(i)) * (CARD_W + SPACING);
        drawSlot(x, field_y);
    }

    // 3. Hand Area (4 slots)
    const hand_start_x = 210;
    const hand_y = 300;
    rl.drawText("Your Hand", hand_start_x, hand_y - 25, 20, .light_gray);
    for (0..4) |i| {
        const x = hand_start_x + @as(i32, @intCast(i)) * (CARD_W + SPACING);
        drawSlot(x, hand_y);
    }

    // 4. Player's Deck Area
    drawArea(20, 300, "Your Deck");

    // 5. Discard Pile Area
    drawArea(700, 300, "Discard");
}

fn drawArea(x: i32, y: i32, label: [:0]const u8) void {
    rl.drawRectangleLines(x, y, CARD_W, CARD_H, .light_gray);
    rl.drawText(label, x, y + CARD_H + 5, 10, .light_gray);
}

fn drawSlot(x: i32, y: i32) void {
    rl.drawRectangleLines(x, y, CARD_W, CARD_H, .gray);
}
