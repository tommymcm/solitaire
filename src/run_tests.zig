const std = @import("std");
const test_rules = @import("test_rules.zig");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    var success = true;

    // Manually call tests and report results.
    // This is a simplified runner. A real one would use a list of tests.
    
    inline for (std.meta.declarations(test_rules)) |decl| {
        if (decl.is_test) {
            const test_fn = @field(test_rules, decl.name);
            const TestError = @typeInfo(@TypeOf(test_fn)).Fn.return_type.?;
            
            try stdout.print("Running test "{}"... ", .{decl.name});

            const result = comptime catch |err| {
                if (@errorName(err) == "TestFailed") {
                    try stdout.print("FAIL
", .{});
                    success = false;
                } else {
                    return err;
                }
            };

            if(result) |_| {
                 try stdout.print("OK
", .{});
            }
        }
    }


    if (!success) {
        std.process.exit(1);
    }
}
