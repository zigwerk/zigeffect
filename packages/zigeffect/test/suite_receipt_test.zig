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

test "Testing v2 suite receipt publication advances past another writer temporary slot" {
    const results = [_]Suite.TestResult{.{ .index = 0, .id = "passed", .status = .passed }};
    const receipt = Suite.Receipt{
        .suite = "public-contract",
        .status = .passed,
        .complete = true,
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
        .counts = Suite.Counts.fromResults(results.len, &results),
        .tests = &results,
    };
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(std.testing.io, "nested");
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "nested/receipt.json.tmp.0", .data = "occupied-by-another-writer" });
    try Suite.writeAtomic(std.testing.allocator, std.testing.io, tmp.dir, "nested/receipt.json", receipt);
    const occupied = try tmp.dir.readFileAlloc(std.testing.io, "nested/receipt.json.tmp.0", std.testing.allocator, .limited(64));
    defer std.testing.allocator.free(occupied);
    try std.testing.expectEqualStrings("occupied-by-another-writer", occupied);
}
