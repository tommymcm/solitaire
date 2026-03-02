const std = @import("std");
const rl = @import("raylib");
const solitaire = @import("solitaire");
const Card = solitaire.card.Card;

pub const Anim = struct {
    pub const speed = 10.0;
    pub const sheet_cols = 14;
    pub const sheet_rows = 4;
};

pub const VisualCard = struct {
    card: Card,
    pos: rl.Vector2,
    target_pos: rl.Vector2,
    active: bool = false,

    pub fn update(self: *VisualCard, dt: f32) void {
        if (!self.active) return;
        const dx = self.target_pos.x - self.pos.x;
        const dy = self.target_pos.y - self.pos.y;

        if (@abs(dx) < 1.0 and @abs(dy) < 1.0) {
            self.pos = self.target_pos;
        } else {
            self.pos.x += dx * dt * Anim.speed;
            self.pos.y += dy * dt * Anim.speed;
        }
    }

    pub fn isAtTarget(self: VisualCard) bool {
        const dx = self.target_pos.x - self.pos.x;
        const dy = self.target_pos.y - self.pos.y;
        return (@abs(dx) < 1.0 and @abs(dy) < 1.0);
    }

    pub fn draw(self: VisualCard, texture: rl.Texture2D, width: f32, height: f32) void {
        const sw = @as(f32, @floatFromInt(texture.width)) / Anim.sheet_cols;
        const sh = @as(f32, @floatFromInt(texture.height)) / Anim.sheet_rows;
        var col: f32 = 0;
        var row: f32 = 0;
        if (self.card.rank == .joker) {
            col = 0;
            row = 2;
        } else {
            row = switch (self.card.suit) {
                .hearts => 0,
                .clubs => 1,
                .diamonds => 2,
                .spades => 3,
            };
            const rank_val = @intFromEnum(self.card.rank);
            col = if (self.card.rank == .ace) 13 else @floatFromInt(rank_val - 1);
        }
        rl.drawTexturePro(
            texture,
            .{ .x = col * sw, .y = row * sh, .width = sw, .height = sh },
            .{ .x = self.pos.x, .y = self.pos.y, .width = width, .height = height },
            .{ .x = 0, .y = 0 },
            0,
            .white,
        );
    }
};

pub fn drawCardBack(texture: rl.Texture2D, pos: rl.Vector2, width: f32, height: f32) void {
    const sw = @as(f32, @floatFromInt(texture.width)) / Anim.sheet_cols;
    const sh = @as(f32, @floatFromInt(texture.height)) / Anim.sheet_rows;
    rl.drawTexturePro(
        texture,
        .{ .x = 0, .y = 0, .width = sw, .height = sh },
        .{ .x = pos.x, .y = pos.y, .width = width, .height = height },
        .{ .x = 0, .y = 0 },
        0,
        .white,
    );
}

pub fn drawSlot(pos: rl.Vector2, width: f32, height: f32, color: rl.Color) void {
    rl.drawRectangleLines(@intFromFloat(pos.x), @intFromFloat(pos.y), @intFromFloat(width), @intFromFloat(height), color);
}
