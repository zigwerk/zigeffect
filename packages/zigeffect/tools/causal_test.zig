const std = @import("std");
const fx = @import("zigeffect");

pub const artifact_dir = ".zig-cache/causal-artifacts";
pub const report_path = artifact_dir ++ "/zigeffect-causal-dogfood.txt";
pub const json_path = artifact_dir ++ "/zigeffect-causal-dogfood.json";
pub const dot_path = artifact_dir ++ "/zigeffect-causal-dogfood.dot";

pub const ArtifactSet = struct {
    report_path: []const u8,
    json_path: []const u8,
    dot_path: []const u8,
    report: []const u8,
    json: []const u8,
    dot: []const u8,

    pub fn deinit(self: ArtifactSet, allocator: std.mem.Allocator) void {
        allocator.free(self.report);
        allocator.free(self.json);
        allocator.free(self.dot);
    }
};

fn recordDogfoodScenario(store: *fx.CausalStore) std.mem.Allocator.Error!void {
    const run_id = store.nextRunId();
    const scope_id = store.nextScopeId();
    const run_started = try store.record(.{
        .kind = .run_started,
        .run_id = run_id,
        .label = "zigeffect dogfood",
        .type_name = "DogfoodHarness",
    });
    const scope_opened = try store.record(.{
        .kind = .scope_opened,
        .run_id = run_id,
        .parent_id = run_started,
        .scope_id = scope_id,
        .label = "dogfood scope",
        .status = "opened",
    });
    _ = try store.record(.{
        .kind = .service_required,
        .run_id = run_id,
        .parent_id = scope_opened,
        .label = "Config",
        .type_name = @typeName(fx.Config),
        .status = "missing",
        .redacted_detail = "missing provider for config descriptor",
    });
    _ = try store.record(.{
        .kind = .resource_acquired,
        .run_id = run_id,
        .parent_id = scope_opened,
        .scope_id = scope_id,
        .label = "dogfood database",
        .type_name = "DogfoodDatabaseConnection",
        .status = "success",
        .redacted_detail = "resource intentionally left open by fixture",
    });
    _ = try store.record(.{
        .kind = .fiber_forked,
        .run_id = run_id,
        .parent_id = scope_opened,
        .scope_id = scope_id,
        .fiber_id = 42,
        .label = "dogfood child fiber",
        .status = "pending",
    });
    _ = try store.record(.{
        .kind = .schedule_decision,
        .run_id = run_id,
        .parent_id = run_started,
        .label = "dogfood retry policy",
        .type_name = "Schedule.exponential",
        .status = "exhausted",
        .redacted_detail = "retry budget exhausted after deterministic fixture",
    });
    _ = try store.record(.{
        .kind = .scope_closed,
        .run_id = run_id,
        .parent_id = scope_opened,
        .scope_id = scope_id,
        .label = "dogfood scope",
        .status = "closed",
    });
    _ = try store.record(.{
        .kind = .exit_recorded,
        .run_id = run_id,
        .parent_id = run_started,
        .label = "dogfood exit",
        .type_name = "DogfoodFailure",
        .status = "failure",
        .redacted_detail = "fixture records failure for artifact analysis",
    });
}

pub fn buildDogfoodArtifacts(allocator: std.mem.Allocator) std.mem.Allocator.Error!ArtifactSet {
    var store = fx.CausalStore.init(allocator);
    defer store.deinit();

    try recordDogfoodScenario(&store);

    const report = try fx.formatCausalCiReport(allocator, "zigeffect dogfood", &store);
    errdefer allocator.free(report);
    const json = try fx.formatCausalJson(allocator, &store);
    errdefer allocator.free(json);
    const dot = try fx.formatCausalDot(allocator, &store);
    errdefer allocator.free(dot);

    return .{
        .report_path = report_path,
        .json_path = json_path,
        .dot_path = dot_path,
        .report = report,
        .json = json,
        .dot = dot,
    };
}

fn writeArtifact(io: std.Io, path: []const u8, contents: []const u8) !void {
    const slash = std.mem.lastIndexOfScalar(u8, path, '/') orelse return error.InvalidArtifactPath;
    const cwd = std.Io.Dir.cwd();
    try cwd.createDirPath(io, path[0..slash]);
    try cwd.writeFile(io, .{ .sub_path = path, .data = contents });
}

fn writeArtifacts(io: std.Io, artifacts: ArtifactSet) !void {
    try writeArtifact(io, artifacts.report_path, artifacts.report);
    try writeArtifact(io, artifacts.json_path, artifacts.json);
    try writeArtifact(io, artifacts.dot_path, artifacts.dot);
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var threaded: std.Io.Threaded = .init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    const artifacts = try buildDogfoodArtifacts(allocator);
    defer artifacts.deinit(allocator);

    try writeArtifacts(io, artifacts);

    std.debug.print(
        "zigeffect causal dogfood artifacts written:\n- {s}\n- {s}\n- {s}\n",
        .{ artifacts.report_path, artifacts.json_path, artifacts.dot_path },
    );
}

test "dogfood artifacts include report json dot and stable paths" {
    const artifacts = try buildDogfoodArtifacts(std.testing.allocator);
    defer artifacts.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dogfood.txt",
        artifacts.report_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dogfood.json",
        artifacts.json_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dogfood.dot",
        artifacts.dot_path,
    );
    try std.testing.expect(std.mem.indexOf(u8, artifacts.report, "zigeffect causal ci report") != null);
    try std.testing.expect(std.mem.indexOf(u8, artifacts.report, "program: zigeffect dogfood") != null);
    try std.testing.expect(std.mem.indexOf(u8, artifacts.report, "findings: 4") != null);
    try std.testing.expect(std.mem.indexOf(u8, artifacts.report, "causal.requirements") != null);
    try std.testing.expect(std.mem.indexOf(u8, artifacts.report, "causal.resources") != null);
    try std.testing.expect(std.mem.indexOf(u8, artifacts.report, "causal.fibers pending") != null);
    try std.testing.expect(std.mem.indexOf(u8, artifacts.report, "causal.retries") != null);
    try std.testing.expect(std.mem.indexOf(u8, artifacts.json, "\"kind\": \"service_required\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, artifacts.json, "\"kind\": \"resource_acquired\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, artifacts.dot, "digraph zigeffect_causal") != null);
    try std.testing.expect(std.mem.indexOf(u8, artifacts.dot, "event_1 -> event_2") != null);
}
