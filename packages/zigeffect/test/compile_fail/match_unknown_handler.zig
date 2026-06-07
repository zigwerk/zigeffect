const fx = @import("zigeffect");

const Event = union(enum) {
    started,
    progress: u8,
};

fn onStarted() []const u8 {
    return "started";
}

fn onProgress(_: u8) []const u8 {
    return "progress";
}

fn onDone() []const u8 {
    return "done";
}

pub fn main() void {
    _ = fx.match.exhaustive([]const u8, @as(Event, .started), .{
        .started = onStarted,
        .progress = onProgress,
        .done = onDone,
    });
}
