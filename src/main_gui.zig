const std = @import("std");
const rl = @import("raylib");
const builtin = @import("builtin");

const emscripten = std.os.emscripten;

const SCREEN_WIDTH = 800;
const SCREEN_HEIGHT = 450;

pub fn main() !void {
    // Minimal initialization.
    rl.initWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Card Capture - Minimal");

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

    rl.clearBackground(.blue); // Blue background for the minimal test
    rl.drawText("Minimal Raylib Test", 100, 100, 40, .ray_white);
    rl.drawText("If you see BLUE and this text, Raylib is working!", 100, 160, 20, .light_gray);
}
