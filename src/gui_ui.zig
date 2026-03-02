const std = @import("std");
const rl = @import("raylib");

pub fn drawButton(font: rl.Font, x: i32, y: i32, w: i32, h: i32, text: [:0]const u8, color: rl.Color) void {
    const font_size = 14;
    const rect = rl.Rectangle{ .x = @floatFromInt(x), .y = @floatFromInt(y), .width = @floatFromInt(w), .height = @floatFromInt(h) };
    rl.drawRectangleRec(rect, color);
    rl.drawRectangleLinesEx(rect, 2, .ray_white);
    const tw = rl.measureTextEx(font, text, font_size, 1).x;
    rl.drawTextEx(font, text, .{ .x = @floatFromInt(x + @divTrunc(w - @as(i32, @intFromFloat(tw)), 2)), .y = @floatFromInt(y + @divTrunc(h - font_size, 2)) }, font_size, 1, .ray_white);
}

pub fn drawLabel(font: rl.Font, comptime fmt: []const u8, val: ?usize, pos: rl.Vector2, size: f32, color: rl.Color, card_h: f32) void {
    if (comptime std.mem.indexOf(u8, fmt, "{") != null) {
        if (val) |v| {
            var buf: [32]u8 = undefined;
            const text = std.fmt.bufPrintZ(&buf, fmt, .{v}) catch "err";
            rl.drawTextEx(font, text, .{ .x = pos.x, .y = pos.y + card_h + size / 2 }, size, 1, color);
            return;
        }
    }
    rl.drawTextEx(font, @ptrCast(fmt), .{ .x = pos.x, .y = pos.y + card_h + size / 2 }, size, 1, color);
}

pub fn drawTextWrapped(font: rl.Font, text: [:0]const u8, x: i32, y: i32, width: i32, fontSize: i32, color: rl.Color) void {
    var cursor_x: i32 = x;
    var cursor_y: i32 = y;
    const space_width = @as(i32, @intFromFloat(rl.measureTextEx(font, " ", @as(f32, @floatFromInt(fontSize)), 1).x));

    var it = std.mem.tokenizeAny(u8, text, " ");
    while (it.next()) |word| {
        var word_buf: [128:0]u8 = undefined;
        const word_z: [:0]const u8 = std.fmt.bufPrintZ(&word_buf, "{s}", .{word}) catch "err";

        const word_width = @as(i32, @intFromFloat(rl.measureTextEx(font, word_z, @as(f32, @floatFromInt(fontSize)), 1).x));
        if (cursor_x + word_width > x + width) {
            cursor_x = x;
            cursor_y += fontSize + 5;
        }
        rl.drawTextEx(font, word_z, .{ .x = @as(f32, @floatFromInt(cursor_x)), .y = @as(f32, @floatFromInt(cursor_y)) }, @as(f32, @floatFromInt(fontSize)), 1, color);
        cursor_x += word_width + space_width;
    }
}
