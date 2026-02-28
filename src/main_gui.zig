const std = @import("std");
const rl = @import("raylib");
const builtin = @import("builtin");
const rules = @import("rules.zig");

const emscripten = std.os.emscripten;
const GameState = rules.GameState;

const SCREEN_WIDTH = 800;
const SCREEN_HEIGHT = 450;

// Global state to ensure they live as long as the application.
var global_state: ?*GameState = null;
var global_allocator: std.mem.Allocator = undefined;
var native_gpa = std.heap.GeneralPurposeAllocator(.{}){};
var prng: std.Random.DefaultPrng = undefined;

pub fn main() !void {
    // Memory allocator.
    if (builtin.os.tag == .emscripten) {
        global_allocator = std.heap.wasm_allocator;
    } else {
        global_allocator = native_gpa.allocator();
    }

    // Initialize PRNG globally.
    var seed: u64 = undefined;
    try std.posix.getrandom(std.mem.asBytes(&seed));
    prng = std.Random.DefaultPrng.init(seed);
    const random = prng.random();

    // Initialize raylib.
    std.debug.print("Initializing window...\n", .{});
    rl.initWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Card Capture - GUI");

    // Initialize game state on heap.
    std.debug.print("Initializing game state...\n", .{});
    const state = try global_allocator.create(GameState);
    state.* = try GameState.init(global_allocator, random);
    global_state = state;

    if (builtin.os.tag == .emscripten) {
        std.debug.print("Starting Emscripten main loop...\n", .{});
        rl.setTargetFPS(60);
        emscripten.emscripten_set_main_loop(updateDrawFrame, 0, 1);
    } else {
        std.debug.print("Starting native main loop...\n", .{});
        defer rl.closeWindow();
        defer {
            if (global_state) |gs| {
                gs.deinit();
                global_allocator.destroy(gs);
            }
            _ = native_gpa.deinit();
        }

        rl.setTargetFPS(60);

        while (!rl.windowShouldClose()) {
            updateDrawFrame();
        }
    }
}

export fn updateDrawFrame() void {
    // Draw
    rl.beginDrawing();
    defer rl.endDrawing();

    rl.clearBackground(.red);

    rl.drawText("Card Capture GUI", 190, 200, 20, .white);
    rl.drawText("Memory Growth and PRNG fix!", 190, 230, 20, .light_gray);
    
    if (global_state) |state| {
        var buf: [64]u8 = undefined;
        const score_text = std.fmt.bufPrintZ(&buf, "Score: {d}", .{state.captured_count}) catch "Score: ERROR";
        rl.drawText(score_text, 10, 10, 20, .white);
    }
}
