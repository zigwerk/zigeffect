const std = @import("std");
const builtin = @import("builtin");
const zstd = @import("zigeffect_std");

pub const project_validation_schema = "zigeffect.project-validation.v1";

pub const CommandOutput = struct {
    allocator: std.mem.Allocator,
    exit_code: u8,
    output: []u8,

    pub fn deinit(self: *CommandOutput) void {
        self.allocator.free(self.output);
        self.* = undefined;
    }
};

pub const CheckOptions = struct {
    manifest_path: []const u8 = "zigeffect.project.json",
    write_receipt: bool = true,
};

pub fn runProjectValidateAlloc(
    allocator: std.mem.Allocator,
    io: std.Io,
    base_dir: std.Io.Dir,
    manifest_path: []const u8,
) !CommandOutput {
    var parsed = try readManifest(allocator, io, base_dir, manifest_path);
    defer parsed.deinit();
    const output = try std.json.Stringify.valueAlloc(allocator, .{
        .schema = project_validation_schema,
        .valid = true,
        .project = parsed.value.name,
        .kind = parsed.value.kind,
        .profile = parsed.value.safety.profile,
        .components = parsed.value.components.len,
        .commands = parsed.value.commands.len,
        .requirements = parsed.value.requirements.len,
        .acceptance_checks = parsed.value.acceptance_checks.len,
    }, .{});
    return .{ .allocator = allocator, .exit_code = 0, .output = output };
}

pub fn runProjectCheckAlloc(
    allocator: std.mem.Allocator,
    io: std.Io,
    base_dir: std.Io.Dir,
    options: CheckOptions,
) !CommandOutput {
    var parsed = try readManifest(allocator, io, base_dir, options.manifest_path);
    defer parsed.deinit();
    const manifest = parsed.value;

    var sources = try collectSources(allocator, io, base_dir, manifest);
    defer sources.deinit();
    const inputs = try sources.inputsAlloc(allocator);
    defer allocator.free(inputs);
    var static_report = try zstd.Safety.analyze(allocator, manifest.safety, inputs);
    defer static_report.deinit();

    const source_revision = try sources.revisionAlloc(allocator);
    defer allocator.free(source_revision);
    const zig_version = try zigVersionAlloc(allocator, io, base_dir);
    defer allocator.free(zig_version);
    const target = try std.fmt.allocPrint(allocator, "{s}-{s}", .{ @tagName(builtin.cpu.arch), @tagName(builtin.os.tag) });
    defer allocator.free(target);

    var diagnostics = zstd.Safety.CompilerDiagnosticSet{ .allocator = allocator };
    defer diagnostics.deinit();
    var gates = GateCollection.init(allocator);
    defer gates.deinit();
    var completeness = zstd.Safety.EvidenceCompleteness{};

    for (manifest.safety.gates) |gate_policy| {
        if (gate_policy.kind == .source_policy) {
            const status: zstd.Safety.GateStatus = switch (static_report.verdict()) {
                .passed, .unmanaged => .passed,
                .failed => .failed,
                .incomplete => .truncated,
            };
            try gates.append(.{
                .kind = gate_policy.kind,
                .required = gate_policy.required,
                .status = status,
                .detail = if (status == .passed) "static source policy passed" else "static source policy found governed constructs",
                .artifact_id = ".zigeffect/receipts/latest-static-safety.json",
                .replay_command = "zigeffect project check --agent --json",
            });
            continue;
        }

        const command_id = gate_policy.command orelse {
            try gates.append(.{
                .kind = gate_policy.kind,
                .required = gate_policy.required,
                .status = .not_run,
                .detail = "gate has no manifest-owned command",
            });
            continue;
        };
        const command = manifest.command(command_id) orelse {
            try gates.append(.{
                .kind = gate_policy.kind,
                .required = gate_policy.required,
                .status = .not_run,
                .command_id = command_id,
                .detail = "manifest-owned command is missing",
            });
            continue;
        };

        const run = std.process.run(allocator, io, .{
            .argv = command.argv,
            .cwd = .{ .dir = base_dir },
            .stdout_limit = .limited(manifest.safety.limits.max_artifact_bytes),
            .stderr_limit = .limited(manifest.safety.limits.max_artifact_bytes),
        }) catch |err| {
            const status: zstd.Safety.GateStatus = if (err == error.StreamTooLong) .truncated else .failed;
            if (status == .truncated) completeness.truncated_artifacts += 1;
            try gates.append(.{
                .kind = gate_policy.kind,
                .required = gate_policy.required,
                .status = status,
                .command_id = command_id,
                .detail = @errorName(err),
                .artifact_id = command_id,
                .replay_command = command_id,
            });
            continue;
        };
        defer allocator.free(run.stdout);
        defer allocator.free(run.stderr);

        const exit_code: u8 = switch (run.term) {
            .exited => |code| code,
            else => 255,
        };
        const detail_source = if (run.stderr.len > 0) run.stderr else run.stdout;
        const detail = detail_source[0..@min(detail_source.len, 512)];
        try gates.append(.{
            .kind = gate_policy.kind,
            .required = gate_policy.required,
            .status = if (exit_code == 0) .passed else .failed,
            .command_id = command_id,
            .detail = if (detail.len > 0) detail else if (exit_code == 0) "command passed" else "command failed",
            .artifact_id = command_id,
            .replay_command = command_id,
        });

        const remaining = manifest.safety.limits.max_diagnostics -| diagnostics.items.items.len;
        var parsed_diagnostics = try zstd.Safety.parseZigDiagnostics(allocator, run.stderr, remaining);
        defer parsed_diagnostics.deinit();
        for (parsed_diagnostics.items.items) |item| {
            try appendDiagnosticClone(allocator, &diagnostics, item);
        }
        if (parsed_diagnostics.truncated) {
            diagnostics.truncated = true;
            completeness.dropped_diagnostics += 1;
        }
    }

    if (static_report.truncated) completeness.dropped_findings += 1;
    const finding_ids = try allocator.alloc([]const u8, static_report.findings.items.len);
    defer allocator.free(finding_ids);
    for (static_report.findings.items, 0..) |finding, index| finding_ids[index] = finding.id;

    const receipt = zstd.Safety.SafetyReceipt{
        .project = manifest.name,
        .source_revision = source_revision,
        .profile = manifest.safety.profile,
        .zig_version = std.mem.trim(u8, zig_version, " \t\r\n"),
        .target = target,
        .gates = gates.values.items,
        .static = .{
            .files = static_report.files_analyzed,
            .source_bytes = static_report.source_bytes,
            .forbidden = static_report.forbiddenCount(),
            .allowed = static_report.allowedCount(),
            .stale = static_report.staleCount(),
        },
        .completeness = completeness,
        .diagnostics = diagnostics.items.items,
        .finding_ids = finding_ids,
    };
    const receipt_json = try receipt.jsonAlloc(allocator);
    errdefer allocator.free(receipt_json);

    if (options.write_receipt) {
        const static_json = try static_report.jsonAlloc(allocator);
        defer allocator.free(static_json);
        try writeAtomic(io, base_dir, ".zigeffect/receipts/latest-static-safety.json", static_json);
        try writeAtomic(io, base_dir, ".zigeffect/receipts/latest-safety.json", receipt_json);
    }

    const exit_code: u8 = switch (receipt.verdict()) {
        .passed => 0,
        .failed => 1,
        .incomplete => 4,
        .unmanaged => 3,
    };
    return .{ .allocator = allocator, .exit_code = exit_code, .output = receipt_json };
}

pub fn runSafetyExplainAlloc(
    allocator: std.mem.Allocator,
    io: std.Io,
    base_dir: std.Io.Dir,
    manifest_path: []const u8,
    finding_id: []const u8,
) !CommandOutput {
    var parsed = try readManifest(allocator, io, base_dir, manifest_path);
    defer parsed.deinit();
    var sources = try collectSources(allocator, io, base_dir, parsed.value);
    defer sources.deinit();
    const inputs = try sources.inputsAlloc(allocator);
    defer allocator.free(inputs);
    var report = try zstd.Safety.analyze(allocator, parsed.value.safety, inputs);
    defer report.deinit();

    for (report.findings.items) |finding| {
        if (!std.mem.eql(u8, finding.id, finding_id)) continue;
        const output = try std.json.Stringify.valueAlloc(allocator, .{
            .schema = "zigeffect.safety-explanation.v1",
            .found = true,
            .finding = finding,
            .repair = repairForConstruct(finding.construct),
            .replay_command = "zigeffect project check --agent --json",
        }, .{});
        return .{ .allocator = allocator, .exit_code = 0, .output = output };
    }
    const output = try std.json.Stringify.valueAlloc(allocator, .{
        .schema = "zigeffect.safety-explanation.v1",
        .found = false,
        .finding_id = finding_id,
    }, .{});
    return .{ .allocator = allocator, .exit_code = 2, .output = output };
}

pub fn runSafetyReplayAlloc(
    allocator: std.mem.Allocator,
    receipt_path: []const u8,
    finding_id: []const u8,
) !CommandOutput {
    try zstd.Project.validateRelativePath(receipt_path, false);
    const output = try std.json.Stringify.valueAlloc(allocator, .{
        .schema = "zigeffect.safety-replay-proposal.v1",
        .receipt = receipt_path,
        .finding_id = finding_id,
        .approved = false,
        .executed = false,
        .command = "zigeffect project check --agent --json",
        .reason = "replay remains a manifest-owned local command and requires explicit execution",
    }, .{});
    return .{ .allocator = allocator, .exit_code = 0, .output = output };
}

pub fn runSafetyBaselineAlloc(
    allocator: std.mem.Allocator,
    io: std.Io,
    base_dir: std.Io.Dir,
    receipt_path: []const u8,
) !CommandOutput {
    try zstd.Project.validateRelativePath(receipt_path, false);
    const content = try base_dir.readFileAlloc(io, receipt_path, allocator, .limited(16 * 1024 * 1024));
    defer allocator.free(content);
    if (zstd.Secrets.containsSecret(content)) return error.SecretDetected;
    try writeAtomic(io, base_dir, ".zigeffect/receipts/safety-baseline.json", content);
    const output = try std.json.Stringify.valueAlloc(allocator, .{
        .schema = "zigeffect.safety-baseline.v1",
        .source = receipt_path,
        .baseline = ".zigeffect/receipts/safety-baseline.json",
        .written = true,
    }, .{});
    return .{ .allocator = allocator, .exit_code = 0, .output = output };
}

const OwnedSource = struct {
    component: []u8,
    path: [:0]u8,
    source: [:0]u8,
};

const SourceCollection = struct {
    allocator: std.mem.Allocator,
    items: std.ArrayList(OwnedSource) = .empty,

    fn deinit(self: *SourceCollection) void {
        for (self.items.items) |item| {
            self.allocator.free(item.component);
            self.allocator.free(item.path);
            self.allocator.free(item.source);
        }
        self.items.deinit(self.allocator);
        self.* = undefined;
    }

    fn inputsAlloc(self: SourceCollection, allocator: std.mem.Allocator) std.mem.Allocator.Error![]zstd.Safety.SourceInput {
        const inputs = try allocator.alloc(zstd.Safety.SourceInput, self.items.items.len);
        for (self.items.items, 0..) |item, index| {
            inputs[index] = .{ .component = item.component, .path = item.path, .source = item.source };
        }
        return inputs;
    }

    fn revisionAlloc(self: SourceCollection, allocator: std.mem.Allocator) std.mem.Allocator.Error![]u8 {
        var hasher = std.crypto.hash.sha2.Sha256.init(.{});
        for (self.items.items) |item| {
            hasher.update(item.path);
            hasher.update(&.{0});
            hasher.update(item.source);
            hasher.update(&.{0});
        }
        var digest: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
        hasher.final(&digest);
        return std.fmt.allocPrint(allocator, "sha256:{x}", .{digest});
    }
};

fn collectSources(
    allocator: std.mem.Allocator,
    io: std.Io,
    base_dir: std.Io.Dir,
    manifest: zstd.Project.Manifest,
) !SourceCollection {
    var output = SourceCollection{ .allocator = allocator };
    errdefer output.deinit();
    var walker = try base_dir.walk(allocator);
    defer walker.deinit();
    var total_bytes: usize = 0;
    while (try walker.next(io)) |entry| {
        if (entry.kind == .directory and shouldSkipDirectory(entry.basename)) {
            walker.leave(io);
            continue;
        }
        if (entry.kind != .file or !std.mem.endsWith(u8, entry.path, ".zig")) continue;
        if (!pathDeclaredBySafety(manifest.safety, entry.path)) continue;
        if (zstd.Secrets.containsSecret(entry.path)) return error.SecretDetected;

        const remaining = manifest.safety.limits.max_source_bytes -| total_bytes;
        if (remaining == 0) return error.SourceLimitExceeded;
        const source = try base_dir.readFileAllocOptions(io, entry.path, allocator, .limited(remaining + 1), .of(u8), 0);
        errdefer allocator.free(source);
        total_bytes += source.len;
        if (total_bytes > manifest.safety.limits.max_source_bytes) return error.SourceLimitExceeded;
        const path = try allocator.dupeZ(u8, entry.path);
        errdefer allocator.free(path);
        const component = try allocator.dupe(u8, componentForPath(manifest, entry.path));
        errdefer allocator.free(component);
        try output.items.append(allocator, .{ .component = component, .path = path, .source = source });
    }
    std.mem.sort(OwnedSource, output.items.items, {}, lessThanSource);
    return output;
}

const GateCollection = struct {
    allocator: std.mem.Allocator,
    values: std.ArrayList(zstd.Safety.GateEvidence) = .empty,

    fn init(allocator: std.mem.Allocator) GateCollection {
        return .{ .allocator = allocator };
    }

    fn deinit(self: *GateCollection) void {
        for (self.values.items) |gate| {
            self.allocator.free(gate.command_id);
            self.allocator.free(gate.detail);
            self.allocator.free(gate.artifact_id);
            self.allocator.free(gate.replay_command);
        }
        self.values.deinit(self.allocator);
    }

    fn append(self: *GateCollection, gate: zstd.Safety.GateEvidence) std.mem.Allocator.Error!void {
        const command_id = try self.allocator.dupe(u8, gate.command_id);
        errdefer self.allocator.free(command_id);
        const detail = try self.allocator.dupe(u8, gate.detail);
        errdefer self.allocator.free(detail);
        const artifact_id = try self.allocator.dupe(u8, gate.artifact_id);
        errdefer self.allocator.free(artifact_id);
        const replay_command = try self.allocator.dupe(u8, gate.replay_command);
        errdefer self.allocator.free(replay_command);
        try self.values.append(self.allocator, .{
            .kind = gate.kind,
            .required = gate.required,
            .status = gate.status,
            .command_id = command_id,
            .detail = detail,
            .artifact_id = artifact_id,
            .replay_command = replay_command,
        });
    }
};

fn readManifest(
    allocator: std.mem.Allocator,
    io: std.Io,
    base_dir: std.Io.Dir,
    manifest_path: []const u8,
) !zstd.Project.ParsedManifest {
    try zstd.Project.validateRelativePath(manifest_path, false);
    const content = try base_dir.readFileAlloc(io, manifest_path, allocator, .limited(4 * 1024 * 1024));
    defer allocator.free(content);
    return zstd.Project.parseManifest(allocator, content);
}

fn zigVersionAlloc(allocator: std.mem.Allocator, io: std.Io, base_dir: std.Io.Dir) ![]u8 {
    const result = try std.process.run(allocator, io, .{
        .argv = &.{ "zig", "version" },
        .cwd = .{ .dir = base_dir },
        .stdout_limit = .limited(1024),
        .stderr_limit = .limited(1024),
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);
    switch (result.term) {
        .exited => |code| if (code != 0) return error.CompilerUnavailable,
        else => return error.CompilerUnavailable,
    }
    return allocator.dupe(u8, result.stdout);
}

fn appendDiagnosticClone(
    allocator: std.mem.Allocator,
    output: *zstd.Safety.CompilerDiagnosticSet,
    item: zstd.Safety.CompilerDiagnostic,
) std.mem.Allocator.Error!void {
    const file = try allocator.dupe(u8, item.file);
    errdefer allocator.free(file);
    const message = try allocator.dupe(u8, item.message);
    errdefer allocator.free(message);
    try output.items.append(allocator, .{
        .severity = item.severity,
        .file = file,
        .line = item.line,
        .column = item.column,
        .message = message,
    });
}

fn writeAtomic(io: std.Io, base_dir: std.Io.Dir, path: []const u8, content: []const u8) !void {
    const slash = std.mem.lastIndexOfScalar(u8, path, '/') orelse return error.InvalidPath;
    try base_dir.createDirPath(io, path[0..slash]);
    const temporary = try std.fmt.allocPrint(std.heap.page_allocator, "{s}.tmp", .{path});
    defer std.heap.page_allocator.free(temporary);
    base_dir.writeFile(io, .{ .sub_path = temporary, .data = content }) catch |err| {
        base_dir.deleteFile(io, temporary) catch {};
        return err;
    };
    base_dir.rename(temporary, base_dir, path, io) catch |err| {
        base_dir.deleteFile(io, temporary) catch {};
        return err;
    };
}

fn pathDeclaredBySafety(policy: zstd.Project.SafetyPolicy, path: []const u8) bool {
    for (policy.audited_roots) |root| if (pathIsWithin(path, root)) return true;
    for (policy.safe_roots) |root| if (pathIsWithin(path, root)) return true;
    return false;
}

fn pathIsWithin(path: []const u8, root: []const u8) bool {
    if (std.mem.eql(u8, root, ".")) return true;
    return std.mem.eql(u8, path, root) or
        (path.len > root.len and std.mem.startsWith(u8, path, root) and path[root.len] == '/');
}

fn componentForPath(manifest: zstd.Project.Manifest, path: []const u8) []const u8 {
    var selected = manifest.name;
    var selected_len: usize = 0;
    for (manifest.components) |component| {
        if (!pathIsWithin(path, component.path)) continue;
        if (component.path.len >= selected_len) {
            selected = component.id;
            selected_len = component.path.len;
        }
    }
    return selected;
}

fn shouldSkipDirectory(name: []const u8) bool {
    return std.mem.eql(u8, name, ".git") or
        std.mem.eql(u8, name, ".zig-cache") or
        std.mem.eql(u8, name, "zig-out") or
        std.mem.eql(u8, name, "zig-pkg") or
        std.mem.eql(u8, name, "node_modules") or
        std.mem.eql(u8, name, ".zigeffect");
}

fn lessThanSource(_: void, left: OwnedSource, right: OwnedSource) bool {
    return std.mem.order(u8, left.path, right.path) == .lt;
}

fn repairForConstruct(construct: zstd.Project.GovernedConstruct) []const u8 {
    return switch (construct) {
        .pointer_cast, .pointer_integer_conversion, .opaque_pointer, .many_pointer => "move the operation into an audited adapter and expose an owned value or generational handle",
        .unmanaged_thread => "use a zigeffect executor with a value-only agent-sendable message",
        .manual_allocator_escape => "use a scoped resource, ResourceTable, or TrackedAllocator source-aware helper",
        .unchecked_unreachable => "return a typed error or prove exhaustiveness through a checked API",
        else => "remove the governed construct or add a reviewed audited allowance with an exact fingerprint",
    };
}

test "project safety check joins static policy compiler gates diagnostics and receipt files" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(std.testing.io, "src");
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "src/main.zig", .data = "pub fn main() void {}\n" });
    const manifest = zstd.Project.Manifest{
        .name = "safe-app",
        .kind = .application,
        .components = &.{.{ .id = "safe-app", .kind = .application, .path = "." }},
        .commands = &.{.{ .id = "check-debug", .argv = &.{ "zig", "ast-check", "src/main.zig" } }},
        .safety = .{
            .profile = .agent_safe_v1,
            .safe_roots = &.{"src"},
            .gates = &.{
                .{ .kind = .source_policy },
                .{ .kind = .compile_debug, .command = "check-debug" },
            },
        },
    };
    const manifest_json = try manifest.jsonAlloc(std.testing.allocator);
    defer std.testing.allocator.free(manifest_json);
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "zigeffect.project.json", .data = manifest_json });

    var result = try runProjectCheckAlloc(std.testing.allocator, std.testing.io, tmp.dir, .{});
    defer result.deinit();
    if (result.exit_code != 0) std.debug.print("unexpected safety receipt: {s}\n", .{result.output});
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
    try std.testing.expect(std.mem.indexOf(u8, result.output, "\"verdict\":\"passed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.output, "\"zig_version\":\"0.16.0") != null);
    const persisted = try tmp.dir.readFileAlloc(std.testing.io, ".zigeffect/receipts/latest-safety.json", std.testing.allocator, .limited(1024 * 1024));
    defer std.testing.allocator.free(persisted);
    try std.testing.expectEqualStrings(result.output, persisted);
}

test "project safety check fails unsafe source and compiler diagnostics are source linked" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(std.testing.io, "src");
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "src/main.zig",
        .data = "pub fn main() void { const raw: *anyopaque = undefined; _ = @ptrCast(raw); }\n",
    });
    const manifest = zstd.Project.Manifest{
        .name = "unsafe-app",
        .kind = .application,
        .components = &.{.{ .id = "unsafe-app", .kind = .application, .path = "." }},
        .commands = &.{.{ .id = "check-debug", .argv = &.{ "zig", "ast-check", "src/main.zig" } }},
        .safety = .{
            .profile = .agent_safe_v1,
            .safe_roots = &.{"src"},
            .gates = &.{
                .{ .kind = .source_policy },
                .{ .kind = .compile_debug, .command = "check-debug" },
            },
        },
    };
    const manifest_json = try manifest.jsonAlloc(std.testing.allocator);
    defer std.testing.allocator.free(manifest_json);
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "zigeffect.project.json", .data = manifest_json });

    var result = try runProjectCheckAlloc(std.testing.allocator, std.testing.io, tmp.dir, .{});
    defer result.deinit();
    if (result.exit_code != 1) std.debug.print("unexpected unsafe receipt: {s}\n", .{result.output});
    try std.testing.expectEqual(@as(u8, 1), result.exit_code);
    try std.testing.expect(std.mem.indexOf(u8, result.output, "\"verdict\":\"failed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.output, "ZFX-pointer_cast") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.output, "\"line\":1") != null);
}
