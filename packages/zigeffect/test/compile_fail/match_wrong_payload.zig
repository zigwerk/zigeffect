const fx = @import("zigeffect");

const Event = union(enum) {
    started,
    progress: u8,
};

fn onStarted() []const u8 {
    return "started";
}

fn onProgress(_: []const u8) []const u8 {
    return "progress";
}

pub fn main() void {
    _ = fx.match.exhaustive([]const u8, @as(Event, .{ .progress = 1 }), .{
        .started = onStarted,
        .progress = onProgress,
    });
}
