const std = @import("std");
const rl = @import("raylib");
const gui_ui = @import("gui_ui.zig");

pub const TutBoxPos = enum { top, center, bottom };

pub const TutorialStep = struct {
    text: [:0]const u8,
    highlight: ?rl.Rectangle = null,
    box_pos: TutBoxPos = .center,
};

pub const TutorialState = struct {
    active: bool = false,
    current_step: usize = 0,
    steps: []const TutorialStep,

    pub fn draw(self: TutorialState, font: rl.Font, screen_w: i32, screen_height: i32, box_config: anytype) void {
        if (!self.active) return;
        const step = self.steps[self.current_step];
        const dim_color = rl.fade(.black, 0.7);

        if (step.highlight) |h| {
            const hx: i32 = @as(i32, @intFromFloat(h.x));
            const hy: i32 = @as(i32, @intFromFloat(h.y));
            const hw: i32 = @as(i32, @intFromFloat(h.width));
            const hh: i32 = @as(i32, @intFromFloat(h.height));

            rl.drawRectangle(0, 0, screen_w, hy, dim_color);
            rl.drawRectangle(0, hy + hh, screen_w, screen_height - (hy + hh), dim_color);
            rl.drawRectangle(0, hy, hx, hh, dim_color);
            rl.drawRectangle(hx + hw, hy, screen_w - (hx + hw), hh, dim_color);

            rl.drawRectangleLinesEx(h, 3, .yellow);
        } else {
            rl.drawRectangle(0, 0, screen_w, screen_height, dim_color);
        }

        const box_y = switch (step.box_pos) {
            .top => box_config.y_top,
            .center => box_config.y_center,
            .bottom => box_config.y_bottom,
        };

        const box_rect = rl.Rectangle{ .x = box_config.x, .y = @as(f32, @floatFromInt(box_y)), .width = box_config.w, .height = box_config.h };
        rl.drawRectangleRec(box_rect, .dark_gray);
        rl.drawRectangleLinesEx(box_rect, 2, .ray_white);

        gui_ui.drawTextWrapped(font, step.text, @as(i32, @intFromFloat(box_config.x)) + box_config.text_margin, box_y + box_config.text_margin, @as(i32, @intFromFloat(box_config.w)) - (box_config.text_margin * 2), 20, .ray_white);

        const tut_btn_y = @as(f32, @floatFromInt(box_y)) + box_config.h - box_config.btn_h - @as(f32, @floatFromInt(box_config.text_margin));
        const tut_next_btn_x = box_config.x + box_config.w - box_config.btn_w - @as(f32, @floatFromInt(box_config.text_margin));
        const tut_prev_btn_x = tut_next_btn_x - box_config.btn_w - @as(f32, @floatFromInt(box_config.text_margin));

        gui_ui.drawButton(font, @as(i32, @intFromFloat(box_config.x)) + box_config.text_margin, @as(i32, @intFromFloat(tut_btn_y)), @as(i32, @intFromFloat(box_config.btn_w)), @as(i32, @intFromFloat(box_config.btn_h)), "CLOSE", .maroon);
        if (self.current_step > 0) {
            gui_ui.drawButton(font, @as(i32, @intFromFloat(tut_prev_btn_x)), @as(i32, @intFromFloat(tut_btn_y)), @as(i32, @intFromFloat(box_config.btn_w)), @as(i32, @intFromFloat(box_config.btn_h)), "PREV", .dark_gray);
        }
        gui_ui.drawButton(font, @as(i32, @intFromFloat(tut_next_btn_x)), @as(i32, @intFromFloat(tut_btn_y)), @as(i32, @intFromFloat(box_config.btn_w)), @as(i32, @intFromFloat(box_config.btn_h)), if (self.current_step == self.steps.len - 1) "FINISH" else "NEXT", .dark_green);
    }

    pub fn handleInput(self: *TutorialState, mouse: rl.Vector2, box_config: anytype) bool {
        if (!self.active) return false;
        const step = self.steps[self.current_step];
        const box_y = switch (step.box_pos) {
            .top => box_config.y_top,
            .center => box_config.y_center,
            .bottom => box_config.y_bottom,
        };

        const tut_btn_y = @as(f32, @floatFromInt(box_y)) + box_config.h - box_config.btn_h - @as(f32, @floatFromInt(box_config.text_margin));
        const tut_next_btn_x = box_config.x + box_config.w - box_config.btn_w - @as(f32, @floatFromInt(box_config.text_margin));
        const tut_prev_btn_x = tut_next_btn_x - box_config.btn_w - @as(f32, @floatFromInt(box_config.text_margin));
        const tut_close_x = box_config.x + @as(f32, @floatFromInt(box_config.text_margin));

        if (rl.checkCollisionPointRec(mouse, .{ .x = tut_next_btn_x, .y = tut_btn_y, .width = box_config.btn_w, .height = box_config.btn_h })) {
            self.current_step += 1;
            if (self.current_step >= self.steps.len) {
                self.active = false;
                self.current_step = 0;
            }
            return true;
        }
        if (self.current_step > 0 and rl.checkCollisionPointRec(mouse, .{ .x = tut_prev_btn_x, .y = tut_btn_y, .width = box_config.btn_w, .height = box_config.btn_h })) {
            self.current_step -= 1;
            return true;
        }
        if (rl.checkCollisionPointRec(mouse, .{ .x = tut_close_x, .y = tut_btn_y, .width = box_config.btn_w, .height = box_config.btn_h })) {
            self.active = false;
            self.current_step = 0;
            return true;
        }
        return true; // Consume all clicks when tutorial is active
    }
};
