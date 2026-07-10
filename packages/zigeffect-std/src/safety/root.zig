const std = @import("std");
const Project = @import("../project/root.zig");

pub const receipt = @import("receipt.zig");
pub const Benchmark = @import("benchmark.zig");
pub const SafetyReceipt = receipt.SafetyReceipt;
pub const SafetyVerdict = receipt.SafetyVerdict;
pub const GateStatus = receipt.GateStatus;
pub const GateEvidence = receipt.GateEvidence;
pub const EvidenceCompleteness = receipt.EvidenceCompleteness;
pub const StaticEvidenceSummary = receipt.StaticEvidenceSummary;
pub const MemoryEvidence = receipt.MemoryEvidence;
pub const CompilerDiagnosticSeverity = receipt.CompilerDiagnosticSeverity;
pub const CompilerDiagnostic = receipt.CompilerDiagnostic;
pub const CompilerDiagnosticSet = receipt.CompilerDiagnosticSet;
pub const parseZigDiagnostics = receipt.parseZigDiagnostics;
pub const safety_receipt_schema = receipt.safety_receipt_schema;

pub const schema_version = "zigeffect.static-safety-report.v1";

pub const SafetyError = error{
    InvalidSource,
    SourceLimitExceeded,
};

pub const SourceZone = enum {
    agent_safe,
    audited_systems,
    unmanaged,
};

pub const FindingDisposition = enum {
    forbidden,
    allowed,
    stale_allowance,
    unmanaged,
};

pub const Verdict = enum {
    passed,
    failed,
    incomplete,
    unmanaged,
};

pub const SourceInput = struct {
    component: []const u8,
    path: []const u8,
    source: [:0]const u8,
};

pub const SourceRef = struct {
    component: []const u8,
    path: []const u8,
    declaration: []const u8,
    line: usize,
    column: usize,
    fingerprint: []const u8,
    source_digest: []const u8,
};

pub const StaticSafetyFinding = struct {
    id: []const u8,
    construct: Project.GovernedConstruct,
    zone: SourceZone,
    disposition: FindingDisposition,
    source: SourceRef,
    token: []const u8,
    allowance_id: ?[]const u8 = null,
};

pub const StaticSafetyReport = struct {
    allocator: std.mem.Allocator,
    profile: Project.SafetyProfile,
    findings: std.ArrayList(StaticSafetyFinding) = .empty,
    files_analyzed: usize = 0,
    source_bytes: usize = 0,
    truncated: bool = false,

    pub fn deinit(self: *StaticSafetyReport) void {
        for (self.findings.items) |finding| deinitFinding(self.allocator, finding);
        self.findings.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn forbiddenCount(self: StaticSafetyReport) usize {
        return self.countDisposition(.forbidden);
    }

    pub fn allowedCount(self: StaticSafetyReport) usize {
        return self.countDisposition(.allowed);
    }

    pub fn staleCount(self: StaticSafetyReport) usize {
        return self.countDisposition(.stale_allowance);
    }

    pub fn hasConstruct(self: StaticSafetyReport, construct: Project.GovernedConstruct) bool {
        for (self.findings.items) |finding| if (finding.construct == construct) return true;
        return false;
    }

    pub fn fingerprintFor(self: StaticSafetyReport, construct: Project.GovernedConstruct) ?[]const u8 {
        for (self.findings.items) |finding| {
            if (finding.construct == construct) return finding.source.fingerprint;
        }
        return null;
    }

    pub fn verdict(self: StaticSafetyReport) Verdict {
        if (self.profile == .unmanaged) return .unmanaged;
        if (self.truncated) return .incomplete;
        if (self.forbiddenCount() > 0 or self.staleCount() > 0) return .failed;
        return .passed;
    }

    pub fn jsonAlloc(self: StaticSafetyReport, allocator: std.mem.Allocator) ![]u8 {
        const value = .{
            .schema = schema_version,
            .profile = self.profile,
            .verdict = self.verdict(),
            .files_analyzed = self.files_analyzed,
            .source_bytes = self.source_bytes,
            .truncated = self.truncated,
            .forbidden = self.forbiddenCount(),
            .allowed = self.allowedCount(),
            .stale = self.staleCount(),
            .findings = self.findings.items,
        };
        return std.json.Stringify.valueAlloc(allocator, value, .{});
    }

    fn countDisposition(self: StaticSafetyReport, disposition: FindingDisposition) usize {
        var count: usize = 0;
        for (self.findings.items) |finding| {
            if (finding.disposition == disposition) count += 1;
        }
        return count;
    }
};

pub fn analyze(
    allocator: std.mem.Allocator,
    policy: Project.SafetyPolicy,
    inputs: []const SourceInput,
) (SafetyError || Project.ProjectError || std.mem.Allocator.Error)!StaticSafetyReport {
    var report = StaticSafetyReport{
        .allocator = allocator,
        .profile = policy.profile,
    };
    errdefer report.deinit();

    for (inputs) |input| {
        try Project.validateIdentifier(input.component);
        try Project.validateRelativePath(input.path, false);
        if (report.source_bytes > policy.limits.max_source_bytes -| input.source.len) {
            return error.SourceLimitExceeded;
        }
        report.source_bytes += input.source.len;
        report.files_analyzed += 1;

        var tree = try std.zig.Ast.parse(allocator, input.source, .zig);
        defer tree.deinit(allocator);
        if (tree.errors.len != 0) return error.InvalidSource;

        const source_digest = try sha256Alloc(allocator, input.source);
        defer allocator.free(source_digest);
        const zone = classifyZone(policy, input.path);

        var token_index: usize = 0;
        while (token_index < tree.tokens.len) : (token_index += 1) {
            const index: std.zig.Ast.TokenIndex = @intCast(token_index);
            const construct = governedConstructAt(tree, index) orelse continue;
            if (report.findings.items.len >= policy.limits.max_findings) {
                report.truncated = true;
                break;
            }

            const location = tree.tokenLocation(0, index);
            const line = std.mem.trim(u8, input.source[location.line_start..location.line_end], " \t\r\n");
            const fingerprint = try findingFingerprintAlloc(allocator, input.path, construct, line);
            errdefer allocator.free(fingerprint);
            const disposition = allowanceDisposition(policy, input.path, construct, fingerprint, zone);
            const allowance_id = matchingAllowanceId(policy, input.path, construct, fingerprint);
            const declaration = nearestDeclaration(tree, index);
            const token = tree.tokenSlice(index);
            const finding_id = try findingIdAlloc(allocator, construct, fingerprint);
            errdefer allocator.free(finding_id);

            const owned_component = try allocator.dupe(u8, input.component);
            errdefer allocator.free(owned_component);
            const owned_path = try allocator.dupe(u8, input.path);
            errdefer allocator.free(owned_path);
            const owned_declaration = try allocator.dupe(u8, declaration);
            errdefer allocator.free(owned_declaration);
            const owned_digest = try allocator.dupe(u8, source_digest);
            errdefer allocator.free(owned_digest);
            const owned_token = try allocator.dupe(u8, token);
            errdefer allocator.free(owned_token);
            const owned_allowance_id = if (allowance_id) |id| try allocator.dupe(u8, id) else null;
            errdefer if (owned_allowance_id) |id| allocator.free(id);

            try report.findings.append(allocator, .{
                .id = finding_id,
                .construct = construct,
                .zone = zone,
                .disposition = disposition,
                .source = .{
                    .component = owned_component,
                    .path = owned_path,
                    .declaration = owned_declaration,
                    .line = location.line + 1,
                    .column = location.column + 1,
                    .fingerprint = fingerprint,
                    .source_digest = owned_digest,
                },
                .token = owned_token,
                .allowance_id = owned_allowance_id,
            });
        }
        if (report.truncated) break;
    }

    std.mem.sort(StaticSafetyFinding, report.findings.items, {}, lessThanFinding);
    return report;
}

pub fn findingFingerprintAlloc(
    allocator: std.mem.Allocator,
    path: []const u8,
    construct: Project.GovernedConstruct,
    normalized_line: []const u8,
) std.mem.Allocator.Error![]u8 {
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    hasher.update(path);
    hasher.update(&.{0});
    hasher.update(@tagName(construct));
    hasher.update(&.{0});
    hasher.update(normalized_line);
    var digest: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
    hasher.final(&digest);
    return formatDigestAlloc(allocator, digest);
}

fn sha256Alloc(allocator: std.mem.Allocator, bytes: []const u8) std.mem.Allocator.Error![]u8 {
    var digest: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    return formatDigestAlloc(allocator, digest);
}

fn formatDigestAlloc(allocator: std.mem.Allocator, digest: [std.crypto.hash.sha2.Sha256.digest_length]u8) std.mem.Allocator.Error![]u8 {
    return std.fmt.allocPrint(allocator, "sha256:{x}", .{digest});
}

fn findingIdAlloc(
    allocator: std.mem.Allocator,
    construct: Project.GovernedConstruct,
    fingerprint: []const u8,
) std.mem.Allocator.Error![]u8 {
    const digest = if (fingerprint.len > 23) fingerprint[7..23] else fingerprint;
    return std.fmt.allocPrint(allocator, "ZFX-{s}-{s}", .{ @tagName(construct), digest });
}

fn classifyZone(policy: Project.SafetyPolicy, path: []const u8) SourceZone {
    for (policy.audited_roots) |root| if (pathIsWithin(path, root)) return .audited_systems;
    for (policy.safe_roots) |root| if (pathIsWithin(path, root)) return .agent_safe;
    return .unmanaged;
}

fn allowanceDisposition(
    policy: Project.SafetyPolicy,
    path: []const u8,
    construct: Project.GovernedConstruct,
    fingerprint: []const u8,
    zone: SourceZone,
) FindingDisposition {
    if (zone == .unmanaged) return .unmanaged;
    if (zone == .agent_safe) return .forbidden;
    if (matchingAllowanceId(policy, path, construct, fingerprint) != null) return .allowed;
    for (policy.allowances) |allowance| {
        if (allowance.construct == construct and std.mem.eql(u8, allowance.path, path)) return .stale_allowance;
    }
    return .forbidden;
}

fn matchingAllowanceId(
    policy: Project.SafetyPolicy,
    path: []const u8,
    construct: Project.GovernedConstruct,
    fingerprint: []const u8,
) ?[]const u8 {
    for (policy.allowances) |allowance| {
        if (allowance.construct == construct and
            std.mem.eql(u8, allowance.path, path) and
            std.mem.eql(u8, allowance.fingerprint, fingerprint))
        {
            return allowance.id;
        }
    }
    return null;
}

fn pathIsWithin(path: []const u8, root: []const u8) bool {
    if (std.mem.eql(u8, root, ".")) return true;
    return std.mem.eql(u8, path, root) or
        (path.len > root.len and std.mem.startsWith(u8, path, root) and path[root.len] == '/');
}

fn governedConstructAt(tree: std.zig.Ast, index: std.zig.Ast.TokenIndex) ?Project.GovernedConstruct {
    const tag = tree.tokenTag(index);
    const token = tree.tokenSlice(index);
    if (tag == .builtin) {
        if (std.mem.eql(u8, token, "@ptrCast") or
            std.mem.eql(u8, token, "@alignCast") or
            std.mem.eql(u8, token, "@fieldParentPtr")) return .pointer_cast;
        if (std.mem.eql(u8, token, "@ptrFromInt") or std.mem.eql(u8, token, "@intFromPtr")) return .pointer_integer_conversion;
        if (std.mem.eql(u8, token, "@setRuntimeSafety")) return .runtime_safety_disabled;
        if (std.mem.eql(u8, token, "@cImport")) return .foreign_interface;
    }
    switch (tag) {
        .keyword_asm => return .inline_assembly,
        .keyword_extern, .keyword_export, .keyword_callconv => return .foreign_interface,
        .keyword_volatile => return .volatile_access,
        .keyword_threadlocal => return .thread_local_state,
        .keyword_unreachable => return .unchecked_unreachable,
        else => {},
    }
    if (tag == .identifier and std.mem.eql(u8, token, "anyopaque") and previousTag(tree, index, 1) == .asterisk) {
        return .opaque_pointer;
    }
    if (tag == .asterisk and previousTag(tree, index, 1) == .l_bracket) return .many_pointer;
    if (tag == .identifier and std.mem.eql(u8, token, "undefined")) return .undefined_escape;
    if (tag == .identifier and std.mem.eql(u8, token, "spawn") and
        previousSliceEquals(tree, index, 1, ".") and
        previousSliceEquals(tree, index, 2, "Thread") and
        previousSliceEquals(tree, index, 3, ".") and
        previousSliceEquals(tree, index, 4, "std"))
    {
        return .unmanaged_thread;
    }
    if (tag == .identifier and isAllocatorOperation(token) and
        previousSliceEquals(tree, index, 1, ".") and
        previousSliceEquals(tree, index, 2, "allocator"))
    {
        return .manual_allocator_escape;
    }
    return null;
}

fn previousTag(tree: std.zig.Ast, index: std.zig.Ast.TokenIndex, distance: usize) ?std.zig.Token.Tag {
    if (index < distance) return null;
    return tree.tokenTag(index - @as(std.zig.Ast.TokenIndex, @intCast(distance)));
}

fn previousSliceEquals(tree: std.zig.Ast, index: std.zig.Ast.TokenIndex, distance: usize, expected: []const u8) bool {
    if (index < distance) return false;
    return std.mem.eql(u8, tree.tokenSlice(index - @as(std.zig.Ast.TokenIndex, @intCast(distance))), expected);
}

fn isAllocatorOperation(token: []const u8) bool {
    return std.mem.eql(u8, token, "alloc") or
        std.mem.eql(u8, token, "create") or
        std.mem.eql(u8, token, "dupe") or
        std.mem.eql(u8, token, "realloc");
}

fn nearestDeclaration(tree: std.zig.Ast, index: std.zig.Ast.TokenIndex) []const u8 {
    var cursor = index;
    while (cursor > 0) {
        cursor -= 1;
        if (tree.tokenTag(cursor) != .keyword_fn) continue;
        const next = cursor + 1;
        if (next < tree.tokens.len and tree.tokenTag(next) == .identifier) return tree.tokenSlice(next);
    }
    return "root";
}

fn lessThanFinding(_: void, left: StaticSafetyFinding, right: StaticSafetyFinding) bool {
    const path_order = std.mem.order(u8, left.source.path, right.source.path);
    if (path_order != .eq) return path_order == .lt;
    if (left.source.line != right.source.line) return left.source.line < right.source.line;
    if (left.source.column != right.source.column) return left.source.column < right.source.column;
    return @intFromEnum(left.construct) < @intFromEnum(right.construct);
}

fn deinitFinding(allocator: std.mem.Allocator, finding: StaticSafetyFinding) void {
    allocator.free(finding.id);
    allocator.free(finding.source.component);
    allocator.free(finding.source.path);
    allocator.free(finding.source.declaration);
    allocator.free(finding.source.fingerprint);
    allocator.free(finding.source.source_digest);
    allocator.free(finding.token);
    if (finding.allowance_id) |id| allocator.free(id);
}

test "Safety analyzer ignores comments and strings but finds governed Zig constructs" {
    const source: [:0]const u8 =
        \\const text = "@ptrCast and std.Thread.spawn are inert";
        \\// @intFromPtr is also inert
        \\fn run(raw: *anyopaque) void {
        \\    const typed: *u32 = @ptrCast(@alignCast(raw));
        \\    _ = @intFromPtr(typed);
        \\    @setRuntimeSafety(false);
        \\    asm volatile ("nop");
        \\    _ = std.Thread.spawn(.{}, worker, .{}) catch unreachable;
        \\}
    ;
    const policy = Project.SafetyPolicy{
        .profile = .agent_safe_v1,
        .safe_roots = &.{"src"},
        .gates = &.{.{ .kind = .source_policy }},
    };

    var report = try analyze(std.testing.allocator, policy, &.{.{
        .component = "app",
        .path = "src/main.zig",
        .source = source,
    }});
    defer report.deinit();

    try std.testing.expectEqual(@as(usize, 9), report.findings.items.len);
    try std.testing.expectEqual(@as(usize, 9), report.forbiddenCount());
    try std.testing.expect(!report.truncated);
    try std.testing.expectEqual(Verdict.failed, report.verdict());
    try std.testing.expect(report.hasConstruct(.opaque_pointer));
    try std.testing.expect(report.hasConstruct(.pointer_cast));
    try std.testing.expect(report.hasConstruct(.pointer_integer_conversion));
    try std.testing.expect(report.hasConstruct(.runtime_safety_disabled));
    try std.testing.expect(report.hasConstruct(.inline_assembly));
    try std.testing.expect(report.hasConstruct(.volatile_access));
    try std.testing.expect(report.hasConstruct(.unmanaged_thread));
    try std.testing.expect(report.hasConstruct(.unchecked_unreachable));
    try std.testing.expectEqualStrings("run", report.findings.items[0].source.declaration);
    try std.testing.expect(report.findings.items[0].source.line > 0);
    try std.testing.expect(report.findings.items[0].source.column > 0);
}

test "Safety analyzer matches exact audited allowances and detects stale fingerprints" {
    const source: [:0]const u8 =
        \\fn call(raw: *anyopaque) void {
        \\    _ = @ptrCast(raw);
        \\}
    ;
    const input = SourceInput{
        .component = "app",
        .path = "src/platform/native.zig",
        .source = source,
    };

    var inventory = try analyze(std.testing.allocator, .{
        .profile = .agent_safe_v1,
        .safe_roots = &.{"src"},
        .audited_roots = &.{"src/platform"},
        .gates = &.{.{ .kind = .source_policy }},
    }, &.{input});
    defer inventory.deinit();
    try std.testing.expectEqual(@as(usize, 2), inventory.forbiddenCount());

    const pointer_cast_fingerprint = inventory.fingerprintFor(.pointer_cast).?;
    const opaque_fingerprint = inventory.fingerprintFor(.opaque_pointer).?;
    const allowances = [_]Project.UnsafeAllowance{
        .{
            .id = "native-cast",
            .path = "src/platform/native.zig",
            .construct = .pointer_cast,
            .fingerprint = pointer_cast_fingerprint,
            .justification = "audited adapter converts its private ABI pointer",
            .required_check = "check-safe",
        },
        .{
            .id = "native-opaque",
            .path = "src/platform/native.zig",
            .construct = .opaque_pointer,
            .fingerprint = opaque_fingerprint,
            .justification = "audited adapter owns its opaque ABI pointer",
            .required_check = "check-safe",
        },
    };
    var allowed = try analyze(std.testing.allocator, .{
        .profile = .agent_safe_v1,
        .safe_roots = &.{"src"},
        .audited_roots = &.{"src/platform"},
        .allowances = &allowances,
        .gates = &.{.{ .kind = .source_policy }},
    }, &.{input});
    defer allowed.deinit();
    try std.testing.expectEqual(@as(usize, 2), allowed.allowedCount());
    try std.testing.expectEqual(Verdict.passed, allowed.verdict());

    var stale_allowances = allowances;
    stale_allowances[0].fingerprint = "sha256:0000000000000000";
    var stale = try analyze(std.testing.allocator, .{
        .profile = .agent_safe_v1,
        .safe_roots = &.{"src"},
        .audited_roots = &.{"src/platform"},
        .allowances = &stale_allowances,
        .gates = &.{.{ .kind = .source_policy }},
    }, &.{input});
    defer stale.deinit();
    try std.testing.expectEqual(@as(usize, 1), stale.staleCount());
    try std.testing.expectEqual(Verdict.failed, stale.verdict());
}

test "Safety analyzer finds FFI many pointers undefined and manual allocation" {
    const source: [:0]const u8 =
        \\extern fn call(bytes: [*]const u8) void;
        \\threadlocal var active: bool = false;
        \\fn make(allocator: std.mem.Allocator) ![]u8 {
        \\    var output: [8]u8 = undefined;
        \\    return allocator.alloc(u8, output.len);
        \\}
    ;
    var report = try analyze(std.testing.allocator, .{
        .profile = .agent_safe_v1,
        .safe_roots = &.{"src"},
        .gates = &.{.{ .kind = .source_policy }},
    }, &.{.{ .component = "app", .path = "src/ffi.zig", .source = source }});
    defer report.deinit();

    try std.testing.expect(report.hasConstruct(.foreign_interface));
    try std.testing.expect(report.hasConstruct(.many_pointer));
    try std.testing.expect(report.hasConstruct(.thread_local_state));
    try std.testing.expect(report.hasConstruct(.undefined_escape));
    try std.testing.expect(report.hasConstruct(.manual_allocator_escape));
}

test "Safety analyzer fails malformed source and reports bounded truncation" {
    const malformed: [:0]const u8 = "fn broken( {";
    try std.testing.expectError(error.InvalidSource, analyze(std.testing.allocator, .{
        .profile = .agent_safe_v1,
        .safe_roots = &.{"src"},
        .gates = &.{.{ .kind = .source_policy }},
    }, &.{.{ .component = "app", .path = "src/broken.zig", .source = malformed }}));

    const noisy: [:0]const u8 = "fn run(a: *anyopaque, b: *anyopaque) void { _ = @ptrCast(a); _ = @ptrCast(b); }";
    var report = try analyze(std.testing.allocator, .{
        .profile = .agent_safe_v1,
        .safe_roots = &.{"src"},
        .gates = &.{.{ .kind = .source_policy }},
        .limits = .{ .max_findings = 2 },
    }, &.{.{ .component = "app", .path = "src/noisy.zig", .source = noisy }});
    defer report.deinit();
    try std.testing.expectEqual(@as(usize, 2), report.findings.items.len);
    try std.testing.expect(report.truncated);
    try std.testing.expectEqual(Verdict.incomplete, report.verdict());
}

test "Safety report JSON is deterministic bounded and contains no source body" {
    const source: [:0]const u8 = "fn run(raw: *anyopaque) void { _ = raw; }";
    var report = try analyze(std.testing.allocator, .{
        .profile = .agent_safe_v1,
        .safe_roots = &.{"src"},
        .gates = &.{.{ .kind = .source_policy }},
    }, &.{.{ .component = "app", .path = "src/main.zig", .source = source }});
    defer report.deinit();

    const first = try report.jsonAlloc(std.testing.allocator);
    defer std.testing.allocator.free(first);
    const second = try report.jsonAlloc(std.testing.allocator);
    defer std.testing.allocator.free(second);
    try std.testing.expectEqualStrings(first, second);
    try std.testing.expect(std.mem.indexOf(u8, first, schema_version) != null);
    try std.testing.expect(std.mem.indexOf(u8, first, "anyopaque") != null);
    try std.testing.expect(std.mem.indexOf(u8, first, "_ = raw") == null);
}

test "Safety analyzer and report release partial ownership on every allocation failure" {
    const Harness = struct {
        fn run(allocator: std.mem.Allocator) !void {
            const source: [:0]const u8 = "fn run(raw: *anyopaque) void { _ = @ptrCast(raw); }";
            var report = try analyze(allocator, .{
                .profile = .agent_safe_v1,
                .safe_roots = &.{"src"},
                .gates = &.{.{ .kind = .source_policy }},
            }, &.{.{ .component = "app", .path = "src/main.zig", .source = source }});
            defer report.deinit();
            const json = try report.jsonAlloc(allocator);
            defer allocator.free(json);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Harness.run, .{});
}
