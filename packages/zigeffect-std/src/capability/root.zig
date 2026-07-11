const std = @import("std");
const Secrets = @import("../secrets/root.zig");

pub const schema = "zigeffect.capability-descriptor.v1";

pub const Maturity = enum(u8) {
    fake = 0,
    deterministic_model = 1,
    local_development = 2,
    production_candidate = 3,
    production_verified = 4,

    pub fn satisfies(self: Maturity, minimum: Maturity) bool {
        return @intFromEnum(self) >= @intFromEnum(minimum);
    }
};

pub const Kind = enum {
    http_client,
    http_server,
    sql_database,
    workflow_journal,
    message_storage,
    lease_storage,
    cluster_transport,
    stream,
    config,
    clock,
    randomness,
    ids,
    secrets,
    telemetry,
    cache,
    broker,
    object_storage,
    filesystem,
    process_runner,
    web_transport,
};

pub const SideEffects = enum {
    none,
    modeled,
    local_process,
    real,
};

pub const ConformanceAuthority = enum {
    deterministic_model,
    local_process,
    live_external,
};

pub const Conformance = struct {
    schema: []const u8,
    version: u32,
    receipt: []const u8,
    authority: ConformanceAuthority,
    observed_at_ms: i64 = 0,
    valid_until_ms: i64 = 0,
    content_sha256: []const u8 = "",
};

pub const Descriptor = struct {
    contract_schema: []const u8 = schema,
    id: []const u8,
    kind: Kind,
    maturity: Maturity,
    package: []const u8,
    version: []const u8,
    features: []const []const u8 = &.{},
    targets: []const []const u8 = &.{"any"},
    side_effects: SideEffects = .none,
    conformance: ?Conformance = null,
    limitations: []const []const u8 = &.{},

    pub fn validate(self: Descriptor) !void {
        if (!std.mem.eql(u8, self.contract_schema, schema)) return error.UnsupportedSchema;
        try validateIdentifier(self.id);
        try validateIdentifier(self.package);
        if (self.version.len == 0) return error.InvalidVersion;
        try rejectSecret(self.version);
        try validateUniqueValues(self.features, true);
        if (self.targets.len == 0) return error.EmptyTargets;
        try validateUniqueValues(self.targets, false);
        try validateValues(self.limitations, false);

        if (self.maturity == .fake and self.side_effects == .real) {
            return error.InvalidSideEffectPosture;
        }

        if (self.conformance) |conformance| {
            try validateIdentifier(conformance.schema);
            if (conformance.version == 0) return error.InvalidConformanceVersion;
            if (conformance.receipt.len == 0) return error.InvalidReceiptReference;
            if (!validReceiptReference(conformance.receipt)) return error.InvalidReceiptReference;
            try rejectSecret(conformance.receipt);
            if (conformance.authority == .live_external and
                (conformance.observed_at_ms <= 0 or conformance.valid_until_ms < conformance.observed_at_ms))
            {
                return error.InvalidConformanceWindow;
            }
            if (conformance.authority == .live_external and !validSha256Reference(conformance.content_sha256)) return error.InvalidConformanceDigest;
        }

        if (self.maturity.satisfies(.production_candidate)) {
            if (self.side_effects != .real) return error.InvalidSideEffectPosture;
            const conformance = self.conformance orelse return error.LiveConformanceRequired;
            if (conformance.authority != .live_external) return error.LiveConformanceRequired;
        }
    }

    pub fn jsonAlloc(self: Descriptor, allocator: std.mem.Allocator) ![]u8 {
        try self.validate();
        const json = try std.json.Stringify.valueAlloc(allocator, self, .{
            .whitespace = .minified,
            .emit_null_optional_fields = false,
        });
        if (Secrets.containsSecret(json)) {
            allocator.free(json);
            return error.SecretDetected;
        }
        return json;
    }
};

fn validSha256Reference(value: []const u8) bool {
    if (!std.mem.startsWith(u8, value, "sha256:") or value.len != 71) return false;
    for (value[7..]) |byte| if (!std.ascii.isHex(byte) or std.ascii.isUpper(byte)) return false;
    return true;
}

fn validReceiptReference(value: []const u8) bool {
    if (value.len == 0 or std.fs.path.isAbsolute(value) or std.mem.indexOfScalar(u8, value, '\\') != null) return false;
    var segments = std.mem.splitScalar(u8, value, '/');
    while (segments.next()) |segment| {
        if (segment.len == 0 or std.mem.eql(u8, segment, ".") or std.mem.eql(u8, segment, "..")) return false;
    }
    return true;
}

pub const Requirement = struct {
    kind: Kind,
    minimum_maturity: Maturity = .fake,
    features: []const []const u8 = &.{},
    target: ?[]const u8 = null,
    requires_live_conformance: bool = false,
    evidence_time_ms: ?i64 = null,
};

pub const Match = enum {
    matched,
    adapter_not_found,
    wrong_kind,
    insufficient_maturity,
    missing_feature,
    unsupported_target,
    missing_live_conformance,
    stale_conformance,
};

pub const Resolution = struct {
    descriptor: ?Descriptor,
    best_failure: Match,
};

pub const AdapterEvidence = struct {
    profile_id: []const u8,
    requirement_id: []const u8,
    target: []const u8,
    adapter_id: []const u8,
    kind: Kind,
    maturity: Maturity,
    result: Match,
    conformance_schema: []const u8 = "",
    conformance_version: u32 = 0,
    conformance_receipt: []const u8 = "",
    conformance_authority: ?ConformanceAuthority = null,
    observed_at_ms: i64 = 0,
    valid_until_ms: i64 = 0,
    content_sha256: []const u8 = "",

    pub fn fromDescriptor(
        profile_id: []const u8,
        requirement_id: []const u8,
        target: []const u8,
        descriptor: Descriptor,
        result: Match,
    ) AdapterEvidence {
        const conformance = descriptor.conformance;
        return .{
            .profile_id = profile_id,
            .requirement_id = requirement_id,
            .target = target,
            .adapter_id = descriptor.id,
            .kind = descriptor.kind,
            .maturity = descriptor.maturity,
            .result = result,
            .conformance_schema = if (conformance) |value| value.schema else "",
            .conformance_version = if (conformance) |value| value.version else 0,
            .conformance_receipt = if (conformance) |value| value.receipt else "",
            .conformance_authority = if (conformance) |value| value.authority else null,
            .observed_at_ms = if (conformance) |value| value.observed_at_ms else 0,
            .valid_until_ms = if (conformance) |value| value.valid_until_ms else 0,
            .content_sha256 = if (conformance) |value| value.content_sha256 else "",
        };
    }

    pub fn validate(self: AdapterEvidence) !void {
        try validateIdentifier(self.profile_id);
        try validateIdentifier(self.requirement_id);
        try validateIdentifier(self.adapter_id);
        if (self.target.len == 0 or self.target.len > 128) return error.InvalidTarget;
        try rejectSecret(self.target);
        if (self.conformance_schema.len != 0) try validateIdentifier(self.conformance_schema);
        if (self.conformance_receipt.len != 0) {
            if (!validReceiptReference(self.conformance_receipt)) return error.InvalidReceiptReference;
            try rejectSecret(self.conformance_receipt);
        }
        if (self.result == .matched and self.maturity.satisfies(.production_candidate)) {
            if (self.conformance_authority != .live_external or
                self.conformance_schema.len == 0 or
                self.conformance_version == 0 or
                self.conformance_receipt.len == 0 or
                !validSha256Reference(self.content_sha256) or
                self.observed_at_ms <= 0 or
                self.valid_until_ms < self.observed_at_ms)
            {
                return error.LiveConformanceRequired;
            }
        }
    }
};

pub fn match(descriptor: Descriptor, requirement: Requirement) Match {
    if (descriptor.kind != requirement.kind) return .wrong_kind;
    if (!descriptor.maturity.satisfies(requirement.minimum_maturity)) return .insufficient_maturity;
    for (requirement.features) |feature| {
        if (!contains(descriptor.features, feature)) return .missing_feature;
    }
    if (requirement.target) |target| {
        if (!contains(descriptor.targets, "any") and !contains(descriptor.targets, target)) {
            return .unsupported_target;
        }
    }
    if (requirement.requires_live_conformance) {
        const conformance = descriptor.conformance orelse return .missing_live_conformance;
        if (conformance.authority != .live_external or conformance.receipt.len == 0) {
            return .missing_live_conformance;
        }
        const evidence_time_ms = requirement.evidence_time_ms orelse return .stale_conformance;
        if (evidence_time_ms < conformance.observed_at_ms or evidence_time_ms > conformance.valid_until_ms) {
            return .stale_conformance;
        }
    }
    return .matched;
}

pub fn resolve(descriptors: []const Descriptor, requirement: Requirement) !Resolution {
    for (descriptors, 0..) |descriptor, index| {
        try descriptor.validate();
        for (descriptors[0..index]) |previous| {
            if (std.mem.eql(u8, descriptor.id, previous.id)) return error.DuplicateAdapterId;
        }
    }

    var best_failure: Match = .adapter_not_found;
    for (descriptors) |descriptor| {
        const result = match(descriptor, requirement);
        if (result == .matched) return .{ .descriptor = descriptor, .best_failure = .matched };
        if (failurePriority(result) > failurePriority(best_failure)) best_failure = result;
    }
    return .{ .descriptor = null, .best_failure = best_failure };
}

pub fn parseDescriptor(allocator: std.mem.Allocator, input: []const u8) !std.json.Parsed(Descriptor) {
    if (Secrets.containsSecret(input)) return error.SecretDetected;
    var parsed = try std.json.parseFromSlice(Descriptor, allocator, input, .{
        .allocate = .alloc_always,
        .ignore_unknown_fields = false,
    });
    errdefer parsed.deinit();
    try parsed.value.validate();
    return parsed;
}

fn failurePriority(value: Match) u8 {
    return switch (value) {
        .matched => 6,
        .stale_conformance => 5,
        .missing_live_conformance => 5,
        .unsupported_target => 4,
        .missing_feature => 3,
        .insufficient_maturity => 2,
        .wrong_kind => 1,
        .adapter_not_found => 0,
    };
}

fn contains(values: []const []const u8, needle: []const u8) bool {
    for (values) |value| {
        if (std.mem.eql(u8, value, needle)) return true;
    }
    return false;
}

fn validateIdentifier(value: []const u8) !void {
    if (value.len == 0 or value.len > 128) return error.InvalidIdentifier;
    try rejectSecret(value);
    for (value) |byte| {
        if (std.ascii.isLower(byte) or std.ascii.isDigit(byte)) continue;
        if (byte == '.' or byte == '-' or byte == '_' or byte == ':') continue;
        return error.InvalidIdentifier;
    }
}

fn validateUniqueValues(values: []const []const u8, require_identifier: bool) !void {
    try validateValues(values, require_identifier);
    for (values, 0..) |value, index| {
        for (values[0..index]) |previous| {
            if (std.mem.eql(u8, value, previous)) return error.DuplicateValue;
        }
    }
}

fn validateValues(values: []const []const u8, require_identifier: bool) !void {
    for (values) |value| {
        if (value.len == 0) return error.EmptyValue;
        if (require_identifier) try validateIdentifier(value) else try rejectSecret(value);
    }
}

fn rejectSecret(value: []const u8) !void {
    if (Secrets.containsSecret(value)) return error.SecretDetected;
}

pub const Builtin = struct {
    pub const fake_http_client = descriptor(
        "zigeffect-std.fake-http-client",
        .http_client,
        .fake,
        .none,
        &.{"returns a configured response without network IO"},
    );
    pub const local_http_client = descriptor(
        "zigeffect-std.local-http-client",
        .http_client,
        .local_development,
        .real,
        &.{"has no live release conformance receipt"},
    );
    pub const memory_http_server = descriptor(
        "zigeffect-std.memory-http",
        .http_server,
        .fake,
        .none,
        &.{"does not listen on an operating-system socket"},
    );
    pub const fake_sql_database = descriptor(
        "zigeffect-std.fake-sql-database",
        .sql_database,
        .fake,
        .none,
        &.{"stores configured rows and transaction state in memory"},
    );
    pub const fake_clock = descriptor(
        "zigeffect-std.fake-clock",
        .clock,
        .fake,
        .none,
        &.{"time advances only when directed by the caller"},
    );
    pub const fake_process_runner = descriptor(
        "zigeffect-std.fake-process-runner",
        .process_runner,
        .fake,
        .none,
        &.{"returns configured process output without starting a process"},
    );
    pub const local_process_runner = descriptor(
        "zigeffect-std.local-process-runner",
        .process_runner,
        .local_development,
        .local_process,
        &.{"starts host-local processes and has no production sandbox conformance"},
    );
    pub const memory_filesystem = descriptor(
        "zigeffect-std.memory-filesystem",
        .filesystem,
        .fake,
        .none,
        &.{"stores files only in process memory"},
    );
    pub const local_filesystem = descriptor(
        "zigeffect-std.local-filesystem",
        .filesystem,
        .local_development,
        .local_process,
        &.{"operates within a host-local directory without shared storage conformance"},
    );
    pub const memory_workflow_journal = descriptor(
        "zigeffect.memory-workflow-journal",
        .workflow_journal,
        .deterministic_model,
        .modeled,
        &.{"journal contents do not survive process termination"},
    );
    pub const file_workflow_journal = descriptor(
        "zigeffect.file-workflow-journal",
        .workflow_journal,
        .local_development,
        .local_process,
        &.{"single-host file storage is not shared durable service storage"},
    );
    pub const memory_message_storage = descriptor(
        "zigeffect.memory-message-storage",
        .message_storage,
        .deterministic_model,
        .modeled,
        &.{"messages do not survive process termination"},
    );
    pub const file_message_storage = descriptor(
        "zigeffect.file-message-storage",
        .message_storage,
        .local_development,
        .local_process,
        &.{"single-host file storage does not provide distributed claim fencing"},
    );
    pub const memory_lease_storage = descriptor(
        "zigeffect.memory-lease-storage",
        .lease_storage,
        .deterministic_model,
        .modeled,
        &.{"leases are authoritative only inside one process"},
    );
    pub const file_lease_storage = descriptor(
        "zigeffect.file-lease-storage",
        .lease_storage,
        .local_development,
        .local_process,
        &.{"single-host file leases are not a distributed consensus authority"},
    );
    pub const in_process_cluster_transport = descriptor(
        "zigeffect.in-process-cluster-transport",
        .cluster_transport,
        .deterministic_model,
        .modeled,
        &.{"delivery never crosses an operating-system process boundary"},
    );
    pub const encoded_in_process_http_transport = descriptor(
        "zigeffect.encoded-in-process-http-transport",
        .cluster_transport,
        .deterministic_model,
        .modeled,
        &.{"encodes HTTP-shaped bytes but invokes an in-process handler"},
    );
    pub const loopback_socket_transport = descriptor(
        "zigeffect.loopback-socket-cluster-transport",
        .cluster_transport,
        .local_development,
        .real,
        &.{"listens only on a host-local loopback socket"},
    );
    pub const remote_localhost_socket_transport = descriptor(
        "zigeffect.remote-localhost-socket-cluster-transport",
        .cluster_transport,
        .local_development,
        .real,
        &.{"rejects non-localhost endpoints and delegates storage in process"},
    );
    pub const encoded_in_process_socket_transport = descriptor(
        "zigeffect.encoded-in-process-socket-transport",
        .cluster_transport,
        .deterministic_model,
        .modeled,
        &.{"encodes socket-shaped frames but invokes an in-process handler"},
    );

    pub const all = &[_]Descriptor{
        fake_http_client,
        local_http_client,
        memory_http_server,
        fake_sql_database,
        fake_clock,
        fake_process_runner,
        local_process_runner,
        memory_filesystem,
        local_filesystem,
        memory_workflow_journal,
        file_workflow_journal,
        memory_message_storage,
        file_message_storage,
        memory_lease_storage,
        file_lease_storage,
        in_process_cluster_transport,
        encoded_in_process_http_transport,
        loopback_socket_transport,
        remote_localhost_socket_transport,
        encoded_in_process_socket_transport,
    };

    fn descriptor(
        id: []const u8,
        kind: Kind,
        maturity: Maturity,
        side_effects: SideEffects,
        limitations: []const []const u8,
    ) Descriptor {
        return .{
            .id = id,
            .kind = kind,
            .maturity = maturity,
            .package = if (std.mem.startsWith(u8, id, "zigeffect-std.")) "zigeffect-std" else "zigeffect",
            .version = "0.1.0",
            .side_effects = side_effects,
            .limitations = limitations,
        };
    }
};

test "capability maturity is ordered explicitly" {
    try std.testing.expect(Maturity.production_candidate.satisfies(.local_development));
    try std.testing.expect(Maturity.production_verified.satisfies(.production_candidate));
    try std.testing.expect(!Maturity.deterministic_model.satisfies(.production_candidate));
}

test "capability requirements match kind maturity features and target" {
    const descriptor = Descriptor{
        .id = "zigeffect-http.server",
        .kind = .http_server,
        .maturity = .production_candidate,
        .package = "zigeffect-http",
        .version = "0.1.0",
        .features = &.{ "http1", "streaming", "graceful-drain" },
        .targets = &.{ "x86_64-linux", "aarch64-macos" },
        .side_effects = .real,
        .conformance = .{
            .schema = "zigeffect.http-server-conformance",
            .version = 1,
            .receipt = "artifacts/http-live.json",
            .authority = .live_external,
            .observed_at_ms = 1_000,
            .valid_until_ms = 2_000,
            .content_sha256 = "sha256:0000000000000000000000000000000000000000000000000000000000000000",
        },
        .limitations = &.{"http2 is not yet supported"},
    };
    const requirement = Requirement{
        .kind = .http_server,
        .minimum_maturity = .production_candidate,
        .features = &.{ "http1", "graceful-drain" },
        .target = "x86_64-linux",
        .requires_live_conformance = true,
        .evidence_time_ms = 1_500,
    };

    try std.testing.expectEqual(Match.matched, match(descriptor, requirement));
    try std.testing.expectEqual(
        Match.insufficient_maturity,
        match(descriptor, .{ .kind = .http_server, .minimum_maturity = .production_verified }),
    );
    try std.testing.expectEqual(
        Match.wrong_kind,
        match(descriptor, .{ .kind = .sql_database, .minimum_maturity = .production_candidate }),
    );
    try std.testing.expectEqual(
        Match.missing_feature,
        match(descriptor, .{ .kind = .http_server, .features = &.{"http2"} }),
    );
    try std.testing.expectEqual(
        Match.unsupported_target,
        match(descriptor, .{ .kind = .http_server, .target = "wasm32-wasi" }),
    );
}

test "capability descriptor rejects secrets and malformed stable fields" {
    var descriptor = Descriptor{
        .id = "adapter.http",
        .kind = .http_server,
        .maturity = .fake,
        .package = "zigeffect-std",
        .version = "0.1.0",
        .limitations = &.{"token=sentinel-secret-for-tests"},
    };
    try std.testing.expectError(error.SecretDetected, descriptor.validate());

    descriptor.limitations = &.{};
    descriptor.id = "Adapter HTTP";
    try std.testing.expectError(error.InvalidIdentifier, descriptor.validate());
}

test "production maturity requires real effects and live conformance" {
    var descriptor = Descriptor{
        .id = "adapter.http",
        .kind = .http_server,
        .maturity = .production_candidate,
        .package = "zigeffect-http",
        .version = "0.1.0",
    };
    try std.testing.expectError(error.InvalidSideEffectPosture, descriptor.validate());

    descriptor.side_effects = .real;
    try std.testing.expectError(error.LiveConformanceRequired, descriptor.validate());

    descriptor.conformance = .{
        .schema = "zigeffect.http-server-conformance",
        .version = 1,
        .receipt = "artifacts/model.json",
        .authority = .deterministic_model,
        .observed_at_ms = 1_000,
        .valid_until_ms = 2_000,
    };
    try std.testing.expectError(error.LiveConformanceRequired, descriptor.validate());
}

test "production matching rejects stale live conformance" {
    const descriptor = Descriptor{
        .id = "adapter.http",
        .kind = .http_server,
        .maturity = .production_candidate,
        .package = "zigeffect-http",
        .version = "0.1.0",
        .side_effects = .real,
        .conformance = .{
            .schema = "zigeffect.http-server-conformance",
            .version = 1,
            .receipt = "artifacts/http-live.json",
            .authority = .live_external,
            .observed_at_ms = 1_000,
            .valid_until_ms = 2_000,
            .content_sha256 = "sha256:0000000000000000000000000000000000000000000000000000000000000000",
        },
    };
    try descriptor.validate();
    try std.testing.expectEqual(
        Match.stale_conformance,
        match(descriptor, .{
            .kind = .http_server,
            .minimum_maturity = .production_candidate,
            .requires_live_conformance = true,
            .evidence_time_ms = 2_001,
        }),
    );
}

test "capability receipt references cannot escape the project root" {
    const descriptor = Descriptor{
        .id = "adapter.http",
        .kind = .http_server,
        .maturity = .production_candidate,
        .package = "zigeffect-http",
        .version = "0.1.0",
        .side_effects = .real,
        .conformance = .{
            .schema = "zigeffect.http-server-conformance",
            .version = 1,
            .receipt = "../outside.json",
            .authority = .live_external,
            .observed_at_ms = 1_000,
            .valid_until_ms = 2_000,
            .content_sha256 = "sha256:0000000000000000000000000000000000000000000000000000000000000000",
        },
    };
    try std.testing.expectError(error.InvalidReceiptReference, descriptor.validate());
}

test "capability descriptors round trip through schema versioned JSON" {
    const descriptor = Descriptor{
        .id = "zigeffect-std.memory-http",
        .kind = .http_server,
        .maturity = .fake,
        .package = "zigeffect-std",
        .version = "0.1.0",
        .features = &.{"typed-router"},
        .targets = &.{"any"},
        .side_effects = .none,
        .limitations = &.{"does not listen on an operating-system socket"},
    };

    const json = try descriptor.jsonAlloc(std.testing.allocator);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, schema) != null);

    var parsed = try parseDescriptor(std.testing.allocator, json);
    defer parsed.deinit();
    try std.testing.expectEqualStrings(descriptor.id, parsed.value.id);
    try std.testing.expectEqual(descriptor.kind, parsed.value.kind);
    try std.testing.expectEqual(descriptor.maturity, parsed.value.maturity);
}

test "capability JSON is allocation failure safe" {
    const Harness = struct {
        fn run(allocator: std.mem.Allocator) !void {
            const descriptor = Descriptor{
                .id = "zigeffect-std.memory-http",
                .kind = .http_server,
                .maturity = .fake,
                .package = "zigeffect-std",
                .version = "0.1.0",
                .features = &.{"typed-router"},
            };
            const json = try descriptor.jsonAlloc(allocator);
            defer allocator.free(json);
            var parsed = try parseDescriptor(allocator, json);
            defer parsed.deinit();
            try std.testing.expectEqualStrings(descriptor.id, parsed.value.id);
        }
    };

    try std.testing.checkAllAllocationFailures(std.testing.allocator, Harness.run, .{});
}

test "capability resolution rejects duplicate ids and reports why no adapter matched" {
    const memory_http = Descriptor{
        .id = "zigeffect-std.memory-http",
        .kind = .http_server,
        .maturity = .fake,
        .package = "zigeffect-std",
        .version = "0.1.0",
    };
    const duplicate = [_]Descriptor{ memory_http, memory_http };
    try std.testing.expectError(
        error.DuplicateAdapterId,
        resolve(&duplicate, .{ .kind = .http_server }),
    );

    const available = [_]Descriptor{memory_http};
    const result = try resolve(&available, .{
        .kind = .http_server,
        .minimum_maturity = .production_candidate,
    });
    try std.testing.expect(result.descriptor == null);
    try std.testing.expectEqual(Match.insufficient_maturity, result.best_failure);

    const missing = try resolve(&.{}, .{ .kind = .http_server });
    try std.testing.expectEqual(Match.adapter_not_found, missing.best_failure);
}

test "builtin adapter catalog classifies every local compatibility boundary truthfully" {
    for (Builtin.all) |descriptor| try descriptor.validate();
    _ = try resolve(Builtin.all, .{ .kind = .cluster_transport });

    try std.testing.expectEqual(Maturity.deterministic_model, Builtin.encoded_in_process_http_transport.maturity);
    try std.testing.expectEqual(Maturity.deterministic_model, Builtin.encoded_in_process_socket_transport.maturity);
    try std.testing.expectEqual(Maturity.local_development, Builtin.remote_localhost_socket_transport.maturity);
    try std.testing.expectEqual(Maturity.local_development, Builtin.file_workflow_journal.maturity);
    try std.testing.expectEqual(Maturity.local_development, Builtin.file_message_storage.maturity);
    try std.testing.expectEqual(Maturity.local_development, Builtin.file_lease_storage.maturity);

    try std.testing.expectEqual(
        Match.insufficient_maturity,
        match(Builtin.encoded_in_process_http_transport, .{
            .kind = .cluster_transport,
            .minimum_maturity = .production_candidate,
            .requires_live_conformance = true,
        }),
    );
}

test "adapter evidence is bounded redacted execution identity" {
    const evidence = AdapterEvidence.fromDescriptor(
        "local",
        "public-http",
        "aarch64-macos",
        Builtin.memory_http_server,
        .insufficient_maturity,
    );
    try evidence.validate();
    try std.testing.expectEqualStrings(Builtin.memory_http_server.id, evidence.adapter_id);

    var secret = evidence;
    secret.profile_id = "token=sentinel-secret-for-tests";
    try std.testing.expectError(error.SecretDetected, secret.validate());
}
