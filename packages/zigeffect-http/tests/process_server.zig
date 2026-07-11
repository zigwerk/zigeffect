const std = @import("std");
const http = @import("zigeffect_http");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const port_text = args.next() orelse return error.MissingPort;
    const port = try std.fmt.parseInt(u16, port_text, 10);

    const Handler = struct {
        pub fn handleAlloc(_: *@This(), allocator: std.mem.Allocator, request: http.Http.Request) !http.Http.Response {
            if (!std.mem.eql(u8, request.url, "/process-conformance")) return error.UnexpectedPath;
            return http.Http.cloneResponseAlloc(allocator, .{ .status = 200, .body = "separate-process-ok" });
        }
    };
    var handler = Handler{};
    var server = try http.Server.init(init.gpa, init.io, .{ .port = port }, http.Handler.from(Handler, &handler));
    defer server.deinit();
    const report = try server.serveOne(init.gpa);
    if (report.status != 200 or report.requests != 1) return error.UnexpectedServeReport;
}
