const std = @import("std");
const zstd = @import("zigeffect_std");

const SmokeRequest = struct {
    name: []const u8,
    limit: i64,
};

pub fn handleSmokeRequest(
    allocator: std.mem.Allocator,
    request: zstd.Http.Request,
) !zstd.Http.Response {
    if (!std.mem.eql(u8, request.method, "POST")) {
        return responseAlloc(allocator, 405, "method not allowed");
    }

    const schema = zstd.Schema.derive(SmokeRequest, .{
        .name = zstd.Schema.string().nonEmpty(),
        .limit = zstd.Schema.integer().min(1).max(10),
    });
    var decoded = try zstd.Schema.decodeDetailedJsonAlloc(allocator, schema, request.body);
    defer decoded.deinit();

    if (!decoded.ok()) {
        const issues = try decoded.issues.jsonAlloc(allocator);
        defer allocator.free(issues);
        return responseAlloc(allocator, 400, issues);
    }

    const value = decoded.value.?;
    const fields = [_]zstd.Sql.Field{
        .{ .name = "project", .value = .{ .text = value.name } },
    };
    const rows = [_]zstd.Sql.Row{
        .{ .fields = fields[0..] },
    };
    var database = zstd.Sql.FakeDatabase.init(.{ .rows = rows[0..] });
    var query_result = try database.queryAlloc(allocator, .{
        .sql = "select project from local_projects where name = $1",
        .binds = &.{.{ .text = value.name }},
    });
    defer query_result.deinit(allocator);

    const rows_text = try std.fmt.allocPrint(allocator, "{d}", .{query_result.rows.len});
    defer allocator.free(rows_text);

    const body = try zstd.Json.objectFromFieldsAlloc(allocator, &.{
        .{ .name = "project", .value = value.name },
        .{ .name = "rows", .value = rows_text },
    });
    defer allocator.free(body);

    return responseAlloc(allocator, 200, body);
}

fn responseAlloc(allocator: std.mem.Allocator, status: u16, body: []const u8) !zstd.Http.Response {
    const headers = try allocator.alloc(zstd.Http.Header, 0);
    errdefer allocator.free(headers);
    const owned_body = try allocator.dupe(u8, body);
    errdefer allocator.free(owned_body);
    return .{
        .status = status,
        .headers = headers,
        .body = owned_body,
    };
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var response = try handleSmokeRequest(allocator, .{
        .method = "POST",
        .url = "http://localhost/projects",
        .body = "{\"name\":\"local-project\",\"limit\":2}",
    });
    defer response.deinit(allocator);
    std.debug.print("{s}\n", .{response.body});
}

test "HTTP SQL smoke validates request and returns deterministic JSON" {
    var response = try handleSmokeRequest(std.testing.allocator, .{
        .method = "POST",
        .url = "http://localhost/projects",
        .body = "{\"name\":\"local-project\",\"limit\":2}",
    });
    defer response.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(u16, 200), response.status);
    try std.testing.expect(std.mem.indexOf(u8, response.body, "\"project\":\"local-project\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, response.body, "\"rows\":\"1\"") != null);
}

test "HTTP SQL smoke returns redacted schema issues" {
    var response = try handleSmokeRequest(std.testing.allocator, .{
        .method = "POST",
        .url = "http://localhost/projects",
        .body = "{\"name\":\"token=abc123\",\"limit\":9999}",
    });
    defer response.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(u16, 400), response.status);
    try std.testing.expect(std.mem.indexOf(u8, response.body, "$.limit") != null);
    try std.testing.expect(std.mem.indexOf(u8, response.body, "abc123") == null);
}
