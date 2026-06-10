const std = @import("std");
const fx = @import("zigeffect");
const message_history_generator = @import("support/message_history_generator.zig");

test "generated message histories match across memory and reopened file storage" {
    const seeds = [_]u64{ 0x22, 0x3333, 0x4444, 0x9e3779b97f4a7c15 };
    for (seeds) |seed| {
        var case_index: usize = 0;
        while (case_index < 10) : (case_index += 1) {
            var history = try message_history_generator.generateMessageHistory(
                std.testing.allocator,
                seed,
                case_index,
            );
            defer history.deinit();

            var memory_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
            defer memory_state.deinit();
            var memory_observed = try message_history_generator.applyMessageHistory(
                std.testing.allocator,
                memory_state.asMessageStorage(),
                history,
            );
            defer memory_observed.deinit();

            var tmp = std.testing.tmpDir(.{});
            defer tmp.cleanup();
            {
                var file_state = try fx.FileMessageStorage.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
                defer file_state.deinit();
                var file_observed = try message_history_generator.applyMessageHistory(
                    std.testing.allocator,
                    file_state.asMessageStorage(),
                    history,
                );
                file_observed.deinit();
            }

            var reopened_state = try fx.FileMessageStorage.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
            defer reopened_state.deinit();
            var reopened_observed = try message_history_generator.observeMessageStorage(
                std.testing.allocator,
                reopened_state.asMessageStorage(),
                memory_observed.message_ids,
                memory_observed.reply_correlation_ids,
            );
            defer reopened_observed.deinit();

            try message_history_generator.expectMessageObservationsEqual(&memory_observed, &reopened_observed);
        }
    }
}
