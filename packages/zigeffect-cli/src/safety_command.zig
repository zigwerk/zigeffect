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
    const capabilities = detectCompilerCapabilities(allocator, io, base_dir);
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
                .status = .unsupported,
                .detail = capabilityDetail(gate_policy.kind, capabilities),
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
        if (gateForCommand(gates.values.items, command_id)) |existing| {
            try gates.append(.{
                .kind = gate_policy.kind,
                .required = gate_policy.required,
                .status = existing.status,
                .command_id = existing.command_id,
                .detail = existing.detail,
                .artifact_id = existing.artifact_id,
                .replay_command = existing.replay_command,
            });
            continue;
        }

        const run = std.process.run(allocator, io, .{
            .argv = command.argv,
            .cwd = .{ .dir = base_dir },
            .stdout_limit = .limited(manifest.safety.limits.max_artifact_bytes),
            .stderr_limit = .limited(manifest.safety.limits.max_artifact_bytes),
        }) catch |err| {
            const status: zstd.Safety.GateStatus = if (err == error.StreamTooLong)
                .truncated
            else if (err == error.FileNotFound)
                .unsupported
            else
                .failed;
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
        const artifact_path = try std.fmt.allocPrint(allocator, ".zigeffect/receipts/compiler-{s}.json", .{command_id});
        defer allocator.free(artifact_path);
        if (options.write_receipt) {
            const safe_stdout = try zstd.Secrets.redactAlloc(allocator, run.stdout);
            defer allocator.free(safe_stdout);
            const safe_stderr = try zstd.Secrets.redactAlloc(allocator, run.stderr);
            defer allocator.free(safe_stderr);
            const raw_artifact = try std.json.Stringify.valueAlloc(allocator, .{
                .schema = "zigeffect.compiler-artifact.v1",
                .command_id = command_id,
                .argv = command.argv,
                .exit_code = exit_code,
                .stdout = safe_stdout,
                .stderr = safe_stderr,
                .truncated = false,
            }, .{});
            defer allocator.free(raw_artifact);
            try writeAtomic(allocator, io, base_dir, artifact_path, raw_artifact);
        }
        const detail_source = if (run.stderr.len > 0) run.stderr else run.stdout;
        const detail = detail_source[0..@min(detail_source.len, 512)];
        try gates.append(.{
            .kind = gate_policy.kind,
            .required = gate_policy.required,
            .status = if (exit_code == 0) .passed else .failed,
            .command_id = command_id,
            .detail = if (detail.len > 0) detail else if (exit_code == 0) "command passed" else "command failed",
            .artifact_id = artifact_path,
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
    const baseline_diff = try readBaselineDiff(allocator, io, base_dir, finding_ids);

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
            .introduced = baseline_diff.introduced,
            .resolved = baseline_diff.resolved,
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
        try writeAtomic(allocator, io, base_dir, ".zigeffect/receipts/latest-static-safety.json", static_json);
        try writeAtomic(allocator, io, base_dir, ".zigeffect/receipts/latest-safety.json", receipt_json);
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
    try writeAtomic(allocator, io, base_dir, ".zigeffect/receipts/safety-baseline.json", content);
    const output = try std.json.Stringify.valueAlloc(allocator, .{
        .schema = "zigeffect.safety-baseline.v1",
        .source = receipt_path,
        .baseline = ".zigeffect/receipts/safety-baseline.json",
        .written = true,
    }, .{});
    return .{ .allocator = allocator, .exit_code = 0, .output = output };
}

pub fn runBenchmarkScoreAlloc(
    allocator: std.mem.Allocator,
    io: std.Io,
    base_dir: std.Io.Dir,
    fixture_path: []const u8,
) !CommandOutput {
    try zstd.Project.validateRelativePath(fixture_path, false);
    const content = try base_dir.readFileAlloc(io, fixture_path, allocator, .limited(16 * 1024 * 1024));
    defer allocator.free(content);
    var parsed = try zstd.Safety.Benchmark.parseFixture(allocator, content);
    defer parsed.deinit();
    const scores = try zstd.Safety.Benchmark.scoreFixtureAlloc(allocator, parsed.value);
    defer allocator.free(scores);
    const report = zstd.Safety.Benchmark.ScoreReport{ .task_id = parsed.value.task.id, .scores = scores };
    return .{ .allocator = allocator, .exit_code = 0, .output = try report.jsonAlloc(allocator) };
}

pub fn runConformanceScoreAlloc(
    allocator: std.mem.Allocator,
    io: std.Io,
    base_dir: std.Io.Dir,
    fixture_path: []const u8,
) !CommandOutput {
    try zstd.Project.validateRelativePath(fixture_path, false);
    const content = try base_dir.readFileAlloc(io, fixture_path, allocator, .limited(16 * 1024 * 1024));
    defer allocator.free(content);
    var parsed = try zstd.Safety.Conformance.parseSuite(allocator, content);
    defer parsed.deinit();
    const passes = try zstd.Safety.Conformance.passesGate(parsed.value);
    return .{
        .allocator = allocator,
        .exit_code = if (passes) 0 else 1,
        .output = try zstd.Safety.Conformance.reportAlloc(allocator, parsed.value),
    };
}

pub fn runProviderBenchmarkAlloc(
    allocator: std.mem.Allocator,
    io: std.Io,
    base_dir: std.Io.Dir,
    provider: []const u8,
    command_id: []const u8,
) !CommandOutput {
    _ = std.meta.stringToEnum(zstd.Safety.Conformance.Provider, provider) orelse return error.UnknownProvider;
    try zstd.Project.validateIdentifier(command_id);
    const expected_prefix = try std.fmt.allocPrint(allocator, "benchmark-{s}", .{provider});
    defer allocator.free(expected_prefix);
    if (!std.mem.startsWith(u8, command_id, expected_prefix)) return error.InvalidProviderCommand;
    base_dir.access(io, ".zigeffect/provider-benchmarks.enabled", .{}) catch |err| switch (err) {
        error.FileNotFound => {
            const unavailable = try std.json.Stringify.valueAlloc(allocator, .{
                .schema = "zigeffect.provider-benchmark-run.v1",
                .available = false,
                .executed = false,
                .provider = provider,
                .command_id = command_id,
                .reason = "create .zigeffect/provider-benchmarks.enabled to opt in; CI never creates this marker",
            }, .{});
            return .{ .allocator = allocator, .exit_code = 3, .output = unavailable };
        },
        else => return err,
    };

    var parsed = try readManifest(allocator, io, base_dir, "zigeffect.project.json");
    defer parsed.deinit();
    const command = parsed.value.command(command_id) orelse return error.MissingProjectCommand;
    const run = std.process.run(allocator, io, .{
        .argv = command.argv,
        .cwd = .{ .dir = base_dir },
        .stdout_limit = .limited(parsed.value.safety.limits.max_artifact_bytes),
        .stderr_limit = .limited(parsed.value.safety.limits.max_artifact_bytes),
    }) catch |err| switch (err) {
        error.FileNotFound => {
            const unavailable = try std.json.Stringify.valueAlloc(allocator, .{
                .schema = "zigeffect.provider-benchmark-run.v1",
                .available = false,
                .executed = false,
                .provider = provider,
                .command_id = command_id,
                .reason = "manifest-owned provider executable is unavailable",
            }, .{});
            return .{ .allocator = allocator, .exit_code = 3, .output = unavailable };
        },
        else => return err,
    };
    defer allocator.free(run.stdout);
    defer allocator.free(run.stderr);
    const exit_code: u8 = switch (run.term) {
        .exited => |code| code,
        else => 255,
    };
    const safe_stdout = try zstd.Secrets.redactAlloc(allocator, run.stdout);
    defer allocator.free(safe_stdout);
    const safe_stderr = try zstd.Secrets.redactAlloc(allocator, run.stderr);
    defer allocator.free(safe_stderr);
    const output = try std.json.Stringify.valueAlloc(allocator, .{
        .schema = "zigeffect.provider-benchmark-run.v1",
        .available = true,
        .executed = true,
        .provider = provider,
        .command_id = command_id,
        .exit_code = exit_code,
        .stdout = safe_stdout,
        .stderr = safe_stderr,
    }, .{});
    const receipt_path = try std.fmt.allocPrint(allocator, ".zigeffect/receipts/provider-benchmark-{s}.json", .{provider});
    defer allocator.free(receipt_path);
    try writeAtomic(allocator, io, base_dir, receipt_path, output);
    return .{ .allocator = allocator, .exit_code = if (exit_code == 0) 0 else 1, .output = output };
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

fn gateForCommand(gates: []const zstd.Safety.GateEvidence, command_id: []const u8) ?zstd.Safety.GateEvidence {
    for (gates) |gate| if (std.mem.eql(u8, gate.command_id, command_id)) return gate;
    return null;
}

const BaselineDiff = struct { introduced: usize = 0, resolved: usize = 0 };

fn readBaselineDiff(
    allocator: std.mem.Allocator,
    io: std.Io,
    base_dir: std.Io.Dir,
    current: []const []const u8,
) !BaselineDiff {
    const content = base_dir.readFileAlloc(io, ".zigeffect/receipts/safety-baseline.json", allocator, .limited(16 * 1024 * 1024)) catch |err| switch (err) {
        error.FileNotFound => return .{},
        else => return err,
    };
    defer allocator.free(content);
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, content, .{});
    defer parsed.deinit();
    const object = switch (parsed.value) {
        .object => |value| value,
        else => return error.InvalidBaseline,
    };
    const raw_ids = object.get("finding_ids") orelse return error.InvalidBaseline;
    const baseline = switch (raw_ids) {
        .array => |value| value,
        else => return error.InvalidBaseline,
    };

    var diff = BaselineDiff{};
    for (current) |id| {
        var found = false;
        for (baseline.items) |baseline_value| {
            const baseline_id = switch (baseline_value) {
                .string => |value| value,
                else => return error.InvalidBaseline,
            };
            if (std.mem.eql(u8, id, baseline_id)) {
                found = true;
                break;
            }
        }
        if (!found) diff.introduced += 1;
    }
    for (baseline.items) |baseline_value| {
        const baseline_id = switch (baseline_value) {
            .string => |value| value,
            else => return error.InvalidBaseline,
        };
        var found = false;
        for (current) |id| if (std.mem.eql(u8, id, baseline_id)) {
            found = true;
            break;
        };
        if (!found) diff.resolved += 1;
    }
    return diff;
}

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

const CompilerCapabilities = struct {
    thread_sanitizer: bool = false,
    c_undefined_behavior: bool = false,
    stack_protection: bool = false,
    fuzz: bool = false,
};

fn detectCompilerCapabilities(allocator: std.mem.Allocator, io: std.Io, base_dir: std.Io.Dir) CompilerCapabilities {
    const result = std.process.run(allocator, io, .{
        .argv = &.{ "zig", "build-exe", "--help" },
        .cwd = .{ .dir = base_dir },
        .stdout_limit = .limited(1024 * 1024),
        .stderr_limit = .limited(1024 * 1024),
    }) catch return .{};
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);
    const text = if (result.stdout.len > 0) result.stdout else result.stderr;
    return .{
        .thread_sanitizer = std.mem.indexOf(u8, text, "-fsanitize-thread") != null,
        .c_undefined_behavior = std.mem.indexOf(u8, text, "-fsanitize-c") != null,
        .stack_protection = std.mem.indexOf(u8, text, "-fstack-protector") != null,
        .fuzz = std.mem.indexOf(u8, text, "-ffuzz") != null,
    };
}

fn capabilityDetail(kind: zstd.Project.SafetyGateKind, capabilities: CompilerCapabilities) []const u8 {
    return switch (kind) {
        .thread_sanitizer => if (capabilities.thread_sanitizer) "toolchain advertises -fsanitize-thread; no manifest-owned target command is configured" else "toolchain does not advertise -fsanitize-thread",
        .c_undefined_behavior => if (capabilities.c_undefined_behavior) "toolchain advertises -fsanitize-c; no manifest-owned C target command is configured" else "toolchain does not advertise -fsanitize-c",
        .stack_protection => if (capabilities.stack_protection) "toolchain advertises -fstack-protector; no manifest-owned target command is configured" else "toolchain does not advertise -fstack-protector",
        .fuzz => if (capabilities.fuzz) "toolchain advertises -ffuzz; no manifest-owned fuzz target command is configured" else "toolchain does not advertise -ffuzz",
        else => "no supported manifest-owned command is configured for this platform",
    };
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

fn writeAtomic(allocator: std.mem.Allocator, io: std.Io, base_dir: std.Io.Dir, path: []const u8, content: []const u8) !void {
    const slash = std.mem.lastIndexOfScalar(u8, path, '/') orelse return error.InvalidPath;
    try base_dir.createDirPath(io, path[0..slash]);
    const temporary = try std.fmt.allocPrint(allocator, "{s}.tmp", .{path});
    defer allocator.free(temporary);
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
    const compiler_artifact = try tmp.dir.readFileAlloc(std.testing.io, ".zigeffect/receipts/compiler-check-debug.json", std.testing.allocator, .limited(1024 * 1024));
    defer std.testing.allocator.free(compiler_artifact);
    try std.testing.expect(std.mem.indexOf(u8, compiler_artifact, "zigeffect.compiler-artifact.v1") != null);
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

test "safety baseline diff reports introduced and resolved finding ids" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(std.testing.io, ".zigeffect/receipts");
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = ".zigeffect/receipts/safety-baseline.json", .data = "{\"finding_ids\":[\"one\",\"resolved\"]}" });
    const diff = try readBaselineDiff(std.testing.allocator, std.testing.io, tmp.dir, &.{ "one", "introduced" });
    try std.testing.expectEqual(@as(usize, 1), diff.introduced);
    try std.testing.expectEqual(@as(usize, 1), diff.resolved);
}

test "provider benchmark runner is unavailable until explicitly enabled" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var unavailable = try runProviderBenchmarkAlloc(std.testing.allocator, std.testing.io, tmp.dir, "codex", "benchmark-codex");
    defer unavailable.deinit();
    try std.testing.expectEqual(@as(u8, 3), unavailable.exit_code);
    try std.testing.expect(std.mem.indexOf(u8, unavailable.output, "\"available\":false") != null);
}

test "offline provider conformance suite reports an incomplete matrix as a failed gate" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const suite =
        \\{"schema":"zigeffect.provider-conformance-suite.v1","schema_version":1,"cases":[{"id":"codex-cancel","provider":"codex","scenario":"cancellation","expected_terminal":"cancelled","required_acceptance":0,"events":[{"sequence":1,"kind":"cancellation_requested","status":"requested"},{"sequence":2,"kind":"session_cancelled","status":"cancelled"}]}]}
    ;
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "suite.json", .data = suite });
    var result = try runConformanceScoreAlloc(std.testing.allocator, std.testing.io, tmp.dir, "suite.json");
    defer result.deinit();
    try std.testing.expectEqual(@as(u8, 1), result.exit_code);
    try std.testing.expect(std.mem.indexOf(u8, result.output, "zigeffect.provider-conformance-report.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.output, "\"passed\":1") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.output, "\"complete_provider_matrix\":false") != null);
}

test "provider benchmark runner executes only an opted-in manifest command" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(std.testing.io, ".zigeffect");
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = ".zigeffect/provider-benchmarks.enabled", .data = "local opt in\n" });
    const manifest = zstd.Project.Manifest{
        .name = "benchmark-app",
        .kind = .application,
        .components = &.{.{ .id = "benchmark-app", .kind = .application, .path = "." }},
        .commands = &.{.{ .id = "benchmark-codex", .argv = &.{ "zig", "version" } }},
    };
    const json = try manifest.jsonAlloc(std.testing.allocator);
    defer std.testing.allocator.free(json);
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "zigeffect.project.json", .data = json });
    var result = try runProviderBenchmarkAlloc(std.testing.allocator, std.testing.io, tmp.dir, "codex", "benchmark-codex");
    defer result.deinit();
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
    try std.testing.expect(std.mem.indexOf(u8, result.output, "\"executed\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.output, "0.16.0") != null);
    try tmp.dir.access(std.testing.io, ".zigeffect/receipts/provider-benchmark-codex.json", .{});
    try std.testing.expectError(error.UnknownProvider, runProviderBenchmarkAlloc(std.testing.allocator, std.testing.io, tmp.dir, "other", "benchmark-other"));
    try std.testing.expectError(error.InvalidProviderCommand, runProviderBenchmarkAlloc(std.testing.allocator, std.testing.io, tmp.dir, "codex", "check"));
}

test "compiler capability evidence distinguishes advertised flags from configured commands" {
    const capabilities = CompilerCapabilities{ .thread_sanitizer = true, .stack_protection = true };
    try std.testing.expect(std.mem.indexOf(u8, capabilityDetail(.thread_sanitizer, capabilities), "advertises -fsanitize-thread") != null);
    try std.testing.expect(std.mem.indexOf(u8, capabilityDetail(.c_undefined_behavior, capabilities), "does not advertise") != null);
    try std.testing.expect(std.mem.indexOf(u8, capabilityDetail(.stack_protection, capabilities), "no manifest-owned") != null);
}
