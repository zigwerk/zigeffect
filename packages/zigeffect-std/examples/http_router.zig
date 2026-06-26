const std = @import("std");
const zstd = @import("zigeffect_std");

const CreateProject = struct {
    name: []const u8,
    limit: i64,
};

const CreatedProject = struct {
    id: []const u8,
    name: []const u8,
};

fn createProject(allocator: std.mem.Allocator, input: CreateProject) !CreatedProject {
    _ = allocator;
    return .{
        .id = "project-local",
        .name = input.name,
    };
}

pub fn runHttpRouterExample(allocator: std.mem.Allocator) !zstd.Http.RouteResult {
    const endpoint = zstd.Http.jsonEndpoint(
        "POST",
        "/projects",
        zstd.Schema.derive(CreateProject, .{
            .name = zstd.Schema.string().nonEmpty(),
            .limit = zstd.Schema.integer().min(1).max(10),
        }),
        zstd.Schema.derive(CreatedProject, .{
            .id = zstd.Schema.string().nonEmpty(),
            .name = zstd.Schema.string().nonEmpty(),
        }),
        createProject,
    );
    var local_router = zstd.Http.router(.{endpoint});
    return local_router.handleAlloc(allocator, .{
        .method = "POST",
        .url = "http://localhost/projects",
        .body = "{\"name\":\"local\",\"limit\":2}",
    });
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var result = try runHttpRouterExample(allocator);
    defer result.deinit(allocator);

    std.debug.print("{s}\n{s}\n", .{ result.response.body, result.receipt_json });
}

test "http router example handles a schema-coded local request" {
    var result = try runHttpRouterExample(std.testing.allocator);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(u16, 200), result.response.status);
    try std.testing.expect(std.mem.indexOf(u8, result.response.body, "\"id\":\"project-local\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.receipt_json, "\"schema\":\"zigeffect.std.http-route-receipt.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.trace_json, "\"schema\":\"zigeffect.std.http-route-trace.v1\"") != null);
}
