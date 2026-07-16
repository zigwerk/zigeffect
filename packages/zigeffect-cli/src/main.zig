const std = @import("std");
const cli = @import("zigeffect_cli");

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    var result = cli.runAllocWithEnvironment(init.gpa, init.io, std.Io.Dir.cwd(), args[1..], init.environ_map) catch |err| {
        const message = try std.fmt.allocPrint(init.gpa, "zigeffect: {s}\n\n{s}", .{ @errorName(err), cli.helpText() });
        defer init.gpa.free(message);
        try std.Io.File.stderr().writeStreamingAll(init.io, message);
        std.process.exit(2);
    };
    defer result.deinit();
    const stream = if (result.exit_code == 0) std.Io.File.stdout() else std.Io.File.stderr();
    try stream.writeStreamingAll(init.io, result.output);
    std.process.exit(result.exit_code);
}
