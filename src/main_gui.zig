const std = @import("std");
const rl = @import("raylib");
const builtin = @import("builtin");
const rules = @import("rules.zig");

const emscripten = std.os.emscripten;
const GameState = rules.GameState;

const SCREEN_WIDTH = 800;
const SCREEN_HEIGHT = 450;

pub fn main() !void {
    // Memory allocator.
    const allocator = if (builtin.os.tag == .emscripten)
        std.heap.wasm_allocator
    else l: {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        // Note: in a real app you'd want to handle deinit, 
        // but for this scaffold we'll keep it simple.
        break :l gpa.allocator();
    };

    // Pseudo-random value generator.
    var seed: u64 = undefined;
    try std.posix.getrandom(std.mem.asBytes(&seed));
    var prng = std.Random.DefaultPrng.init(seed);
    const random = prng.random();

    // Initialize raylib.
    rl.initWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "raylib-zig [core] example - basic window");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(60);

    // Initialize game.
    var state = try GameState.init(allocator, random);
    defer state.deinit();

    if (builtin.os.tag == .emscripten) {
        emscripten.emscripten_set_main_loop(@ptrCast(&updateDrawFrame), 0, 1);
    } else {
        rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second

        // Main game loop
        while (!rl.windowShouldClose()) { // Detect window close button or ESC key
            updateDrawFrame();
        }
    }
}

fn updateDrawFrame() void {
    // Update
    // TODO: Update your variables here

    // Draw
    rl.beginDrawing();
    defer rl.endDrawing();

    rl.clearBackground(.white);

    rl.drawText("Congrats! You created your first window!", 190, 200, 20, .light_gray);
}
