const std = @import("std");
const memory = @import("memory.zig");

pub const schema = "zgraphy.repair-report.v1";
pub const schema_version: u32 = 1;
pub const default_name = "repair-report.json";
pub const max_artifact_bytes: usize = 1024 * 1024;
pub const max_attempts: usize = 8;

pub const Action = enum(u8) {
    none,
    rebuild_secondary_indexes,
    rebuild_checkpoint,
    replay_extraction_cache,
    widen_invalidation,
    clean_rebuild,
};

pub const Cause = enum(u8) {
    none,
    secondary_index_mismatch,
    snapshot_unavailable,
    delta_unavailable,
    active_incompatible,
    origin_invalid,
    candidate_invalid,
};

pub const Status = enum(u8) {
    not_required,
    completed,
    failed,
};

pub const Summary = struct {
    action: Action = .none,
    cause: Cause = .none,
    status: Status = .not_required,
    attempts: usize = 0,

    pub fn clean(self: Summary) bool {
        return (self.action == .none and self.status == .not_required and self.attempts == 0) or
            (self.action != .none and self.status == .completed and self.attempts > 0);
    }
};

pub const Plan = struct {
    action: Action = .none,
    cause: Cause = .none,
    replaces_generation: []const u8 = "",

    pub fn summary(self: Plan) Summary {
        return .{
            .action = self.action,
            .cause = self.cause,
            .status = if (self.action == .none) .not_required else .completed,
            .attempts = if (self.action == .none) 0 else 1,
        };
    }
};

pub const Attempt = struct {
    sequence: usize,
    action: Action,
    cause: Cause,
    status: Status,
};

pub const Report = struct {
    schema: []const u8 = schema,
    schema_version: u32 = schema_version,
    repository_id: []const u8,
    source_generation: []const u8,
    replaces_generation: []const u8,
    target_generation: []const u8,
    plan_fingerprint: []const u8,
    fingerprint: []const u8,
    attempts: []const Attempt,
    summary: Summary,
    complete: bool = true,
};

pub const Owned = struct {
    allocator: std.mem.Allocator,
    value: Report,

    pub fn deinit(self: *Owned) void {
        self.allocator.free(self.value.repository_id);
        self.allocator.free(self.value.source_generation);
        self.allocator.free(self.value.replaces_generation);
        self.allocator.free(self.value.target_generation);
        self.allocator.free(self.value.plan_fingerprint);
        self.allocator.free(self.value.fingerprint);
        self.allocator.free(self.value.attempts);
        self.value.attempts = &.{};
    }

    pub fn bindTargetGeneration(self: *Owned, target_generation: []const u8) !void {
        if (!validGenerationId(target_generation)) return error.InvalidRepairGeneration;
        self.allocator.free(self.value.target_generation);
        self.value.target_generation = try memory.copy(u8, self.allocator, target_generation);
        self.allocator.free(self.value.fingerprint);
        self.value.fingerprint = try reportFingerprintAlloc(self.allocator, self.value);
    }
};

pub fn create(
    allocator: std.mem.Allocator,
    repository_id: []const u8,
    source_generation: []const u8,
    plan: Plan,
) !Owned {
    if (repository_id.len == 0 or (source_generation.len != 0 and !validGenerationId(source_generation)) or
        (plan.replaces_generation.len != 0 and !validGenerationId(plan.replaces_generation)) or
        (plan.action == .none) != (plan.cause == .none))
    {
        return error.InvalidRepairPlan;
    }
    const attempts = try memory.slice(Attempt, allocator, if (plan.action == .none) 0 else 1);
    errdefer allocator.free(attempts);
    if (attempts.len == 1) attempts[0] = .{
        .sequence = 0,
        .action = plan.action,
        .cause = plan.cause,
        .status = .completed,
    };
    var report = Report{
        .repository_id = try memory.copy(u8, allocator, repository_id),
        .source_generation = try memory.copy(u8, allocator, source_generation),
        .replaces_generation = try memory.copy(u8, allocator, plan.replaces_generation),
        .target_generation = try memory.copy(u8, allocator, ""),
        .plan_fingerprint = "",
        .fingerprint = "",
        .attempts = attempts,
        .summary = plan.summary(),
    };
    errdefer {
        allocator.free(report.repository_id);
        allocator.free(report.source_generation);
        allocator.free(report.replaces_generation);
        allocator.free(report.target_generation);
    }
    report.plan_fingerprint = try planFingerprintAlloc(allocator, report);
    errdefer allocator.free(report.plan_fingerprint);
    report.fingerprint = try memory.copy(u8, allocator, report.plan_fingerprint);
    return .{ .allocator = allocator, .value = report };
}

pub fn validate(
    allocator: std.mem.Allocator,
    report: Report,
    target_generation: []const u8,
    replaces_generation: []const u8,
) !void {
    if (!report.complete or !std.mem.eql(u8, report.schema, schema) or report.schema_version != schema_version or
        report.repository_id.len == 0 or !validGenerationId(report.target_generation) or
        !std.mem.eql(u8, report.target_generation, target_generation) or
        !std.mem.eql(u8, report.replaces_generation, replaces_generation) or
        (report.source_generation.len != 0 and !validGenerationId(report.source_generation)) or
        (report.replaces_generation.len != 0 and !validGenerationId(report.replaces_generation)) or
        !validSha256Identity(report.plan_fingerprint) or !validSha256Identity(report.fingerprint) or
        report.attempts.len > max_attempts or !report.summary.clean())
    {
        return error.InvalidRepairReport;
    }
    if (report.summary.attempts != report.attempts.len or
        (report.summary.action == .none) != (report.summary.cause == .none)) return error.InvalidRepairSummary;
    for (report.attempts, 0..) |attempt, index| {
        if (attempt.sequence != index or attempt.action == .none or attempt.cause == .none or attempt.status != .completed) {
            return error.InvalidRepairAttempt;
        }
    }
    const plan_fingerprint = try planFingerprintAlloc(allocator, report);
    defer allocator.free(plan_fingerprint);
    if (!std.mem.eql(u8, plan_fingerprint, report.plan_fingerprint)) return error.RepairPlanFingerprintMismatch;
    const fingerprint = try reportFingerprintAlloc(allocator, report);
    defer allocator.free(fingerprint);
    if (!std.mem.eql(u8, fingerprint, report.fingerprint)) return error.RepairFingerprintMismatch;
}

pub fn encodeAlloc(allocator: std.mem.Allocator, report: Report) ![]u8 {
    const bytes = try std.json.Stringify.valueAlloc(allocator, report, .{ .whitespace = .indent_2 });
    errdefer allocator.free(bytes);
    if (bytes.len > max_artifact_bytes) return error.RepairArtifactTooLarge;
    return bytes;
}

pub fn read(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir, path: []const u8) !Owned {
    if (!validRelativePath(path)) return error.InvalidRepairArtifactPath;
    const bytes = try root.readFileAlloc(io, path, allocator, .limited(max_artifact_bytes));
    defer allocator.free(bytes);
    var parsed = std.json.parseFromSlice(Report, allocator, bytes, .{ .allocate = .alloc_always }) catch return error.CorruptRepairArtifact;
    defer parsed.deinit();
    const attempts = try memory.copy(Attempt, allocator, parsed.value.attempts);
    errdefer allocator.free(attempts);
    return .{ .allocator = allocator, .value = .{
        .repository_id = try memory.copy(u8, allocator, parsed.value.repository_id),
        .source_generation = try memory.copy(u8, allocator, parsed.value.source_generation),
        .replaces_generation = try memory.copy(u8, allocator, parsed.value.replaces_generation),
        .target_generation = try memory.copy(u8, allocator, parsed.value.target_generation),
        .plan_fingerprint = try memory.copy(u8, allocator, parsed.value.plan_fingerprint),
        .fingerprint = try memory.copy(u8, allocator, parsed.value.fingerprint),
        .attempts = attempts,
        .summary = parsed.value.summary,
        .complete = parsed.value.complete,
    } };
}

fn planFingerprintAlloc(allocator: std.mem.Allocator, report: Report) ![]u8 {
    const payload = .{
        .schema = report.schema,
        .schema_version = report.schema_version,
        .repository_id = report.repository_id,
        .source_generation = report.source_generation,
        .replaces_generation = report.replaces_generation,
        .attempts = report.attempts,
        .summary = report.summary,
        .complete = report.complete,
    };
    const bytes = try std.json.Stringify.valueAlloc(allocator, payload, .{});
    defer allocator.free(bytes);
    return sha256IdentityAlloc(allocator, bytes);
}

fn reportFingerprintAlloc(allocator: std.mem.Allocator, report: Report) ![]u8 {
    const payload = .{
        .schema = report.schema,
        .schema_version = report.schema_version,
        .repository_id = report.repository_id,
        .source_generation = report.source_generation,
        .replaces_generation = report.replaces_generation,
        .target_generation = report.target_generation,
        .plan_fingerprint = report.plan_fingerprint,
        .attempts = report.attempts,
        .summary = report.summary,
        .complete = report.complete,
    };
    const bytes = try std.json.Stringify.valueAlloc(allocator, payload, .{});
    defer allocator.free(bytes);
    return sha256IdentityAlloc(allocator, bytes);
}

fn sha256IdentityAlloc(allocator: std.mem.Allocator, bytes: []const u8) ![]u8 {
    var digest: [32]u8 = @splat(0);
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    const hex = std.fmt.bytesToHex(digest, .lower);
    return std.fmt.allocPrint(allocator, "sha256:{s}", .{hex});
}

fn validSha256Identity(value: []const u8) bool {
    if (value.len != 71 or !std.mem.startsWith(u8, value, "sha256:")) return false;
    for (value[7..]) |byte| if (!std.ascii.isDigit(byte) and !(byte >= 'a' and byte <= 'f')) return false;
    return true;
}

fn validGenerationId(value: []const u8) bool {
    if (value.len != 66 or !std.mem.startsWith(u8, value, "g-")) return false;
    for (value[2..]) |byte| if (!std.ascii.isDigit(byte) and !(byte >= 'a' and byte <= 'f')) return false;
    return true;
}

fn validRelativePath(value: []const u8) bool {
    return value.len > 0 and value[0] != '/' and std.mem.indexOf(u8, value, "..") == null and std.mem.indexOfScalar(u8, value, '\\') == null;
}
