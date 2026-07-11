const std = @import("std");
const fx = @import("zigeffect");

test "thread sanitizer gate exercises bounded stream producer consumer synchronization" {
    var buffer = try fx.BoundedStreamBuffer(u32).initAlloc(std.testing.allocator, 8);
    defer buffer.deinit();

    const Producer = struct {
        buffer: *fx.BoundedStreamBuffer(u32),

        fn run(self: *@This()) void {
            for (1..1001) |number| {
                while (true) {
                    _ = self.buffer.offer(@intCast(number), .reject) catch {
                        std.Thread.yield() catch {};
                        continue;
                    };
                    break;
                }
            }
        }
    };
    const Consumer = struct {
        buffer: *fx.BoundedStreamBuffer(u32),
        sum: u64 = 0,

        fn run(self: *@This()) void {
            for (0..1000) |_| {
                while (true) {
                    if (self.buffer.take()) |value| {
                        self.sum += value;
                        break;
                    } else |_| {
                        std.Thread.yield() catch {};
                    }
                }
            }
        }
    };

    var producer = Producer{ .buffer = &buffer };
    var consumer = Consumer{ .buffer = &buffer };
    const producer_thread = try std.Thread.spawn(.{}, Producer.run, .{&producer});
    const consumer_thread = try std.Thread.spawn(.{}, Consumer.run, .{&consumer});
    producer_thread.join();
    consumer_thread.join();

    try std.testing.expectEqual(@as(u64, 500_500), consumer.sum);
    try std.testing.expectEqual(@as(usize, 0), buffer.size());
}
