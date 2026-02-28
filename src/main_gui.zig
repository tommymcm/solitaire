const std = @import("std");
const rl = @import("raylib");
const builtin = @import("builtin");
const rules = @import("rules.zig");

const emscripten = std.os.emscripten;
const GameState = rules.GameState;

const SCREEN_WIDTH = 800;
const SCREEN_HEIGHT = 450;

// Global state pointer for Emscripten callback to access.
var global_state: ?*GameState = null;
var native_gpa = std.heap.GeneralPurposeAllocator(.{}){};

pub fn main() !void {
    // Memory allocator.
    const allocator = if (builtin.os.tag == .emscripten)
        std.heap.wasm_allocator
    else 
        native_gpa.allocator();

    // Pseudo-random value generator.
    var seed: u64 = undefined;
    try std.posix.getrandom(std.mem.asBytes(&seed));
    var prng = std.Random.DefaultPrng.init(seed);
    const random = prng.random();

    // Initialize raylib.
    rl.initWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Card Capture - GUI");

    // Initialize game state.
    var state = try GameState.init(allocator, random);
    global_state = &state;

    if (builtin.os.tag == .emscripten) {
        // Emscripten loop:
        // simulate_infinite_loop = 1 stops execution of main here via exception.
        emscripten.emscripten_set_main_loop(updateDrawFrame, 0, 1);
    } else {
        // Native loop:
        defer rl.closeWindow();
        defer state.deinit();
        defer _ = native_gpa.deinit();

        rl.setTargetFPS(60);

        while (!rl.windowShouldClose()) {
            updateDrawFrame();
        }
    }
}

export fn updateDrawFrame() void {
    // Update
    // if (global_state) |state| { _ = state; }

    // Draw
    rl.beginDrawing();
    defer rl.endDrawing();

    rl.clearBackground(.ray_white);

    rl.drawText("Card Capture GUI", 190, 200, 20, .dark_gray);
    rl.drawText("Window should now stay open!", 190, 230, 20, .light_gray);
}
