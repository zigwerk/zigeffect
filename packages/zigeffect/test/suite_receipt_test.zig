const std = @import("std");
const Suite = @import("zigeffect").testing.SuiteReceipt;

test "Testing v2 suite receipts fail closed through the public core facade" {
    const results = [_]Suite.TestResult{
        .{ .index = 0, .id = "passed", .status = .passed },
        .{ .index = 1, .id = "missing", .status = .pending },
    };
    const counts = Suite.Counts.fromResults(results.len, &results);
    var receipt = Suite.Receipt{
        .suite = "public-contract",
        .status = .failed,
        .complete = false,
        .started_ms = 1,
        .ended_ms = 2,
        .duration_ms = 1,
        .execution = .{
            .zig_version = "0.16.0",
            .target = "native",
            .optimize = "Debug",
            .seed = 42,
            .replay_command = "zig build test-raw",
        },
        .counts = counts,
        .tests = &results,
    };
    try receipt.validate();
    receipt.status = .passed;
    try std.testing.expectError(error.InvalidVerdict, receipt.validate());
}
