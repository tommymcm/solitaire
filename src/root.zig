const std = @import("std");

pub const card = @import("card.zig");
pub const rules = @import("rules.zig");

test {
    std.testing.refAllDecls(@This());
    _ = @import("test_rules.zig");
}
