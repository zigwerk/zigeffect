const std = @import("std");

pub const Studio = @import("studio.zig");
pub const Plan = @import("plan.zig");

test {
    _ = @import("studio_test.zig");
    _ = @import("plan_test.zig");
}

pub const catalog_schema = "zigeffect.statechart.catalog.v1";
pub const catalog_schema_version: u32 = 1;
pub const default_path = ".zigeffect/statecharts";
pub const catalog_file = "catalog.json";
pub const catalog_backup_file = "catalog.json.prev";
pub const catalog_temporary_file = "catalog.json.tmp";

pub const CatalogError = error{
    UnsupportedSchema,
    InvalidCatalog,
    DuplicateDefinition,
    DefinitionNotFound,
    InstanceNotFound,
    ArtifactNotFound,
    CatalogRecoveryFailed,
};

pub const Projection = struct {
    definition_id: []const u8,
    definition_version: ?u32 = null,
    xstate: ?std.json.Value = null,
    mermaid: ?[]const u8 = null,
    dot: ?[]const u8 = null,
};

pub const Catalog = struct {
    schema: []const u8,
    schema_version: u32,
    definitions: []const std.json.Value = &.{},
    snapshots: []const std.json.Value = &.{},
    executions: []const std.json.Value = &.{},
    coverage: []const std.json.Value = &.{},
    paths: []const std.json.Value = &.{},
    projections: []const Projection = &.{},
    proposals: []const std.json.Value = &.{},
    proofs: []const std.json.Value = &.{},
    reviews: []const std.json.Value = &.{},
    approvals: []const std.json.Value = &.{},
    applications: []const std.json.Value = &.{},
    fleet: ?std.json.Value = null,
    control_receipts: []const std.json.Value = &.{},

    pub fn validate(self: Catalog) CatalogError!void {
        if (!std.mem.eql(u8, self.schema, catalog_schema) or self.schema_version != catalog_schema_version) {
            return error.UnsupportedSchema;
        }
        for (self.definitions, 0..) |definition_value, index| {
            const id = valueStringField(definition_value, "id") orelse return error.InvalidCatalog;
            const fingerprint = valueU64Field(definition_value, "fingerprint") orelse return error.InvalidCatalog;
            const version = valueU64Field(definition_value, "version") orelse 1;
            if (version == 0 or version > std.math.maxInt(u32)) return error.InvalidCatalog;
            for (self.definitions[0..index]) |previous| {
                const previous_id = valueStringField(previous, "id") orelse return error.InvalidCatalog;
                const previous_fingerprint = valueU64Field(previous, "fingerprint") orelse return error.InvalidCatalog;
                const previous_version = valueU64Field(previous, "version") orelse 1;
                if (fingerprint == previous_fingerprint or (std.mem.eql(u8, id, previous_id) and version == previous_version)) return error.DuplicateDefinition;
            }
        }
    }

    pub fn definition(self: Catalog, id: []const u8) ?std.json.Value {
        var latest: ?std.json.Value = null;
        var latest_version: u64 = 0;
        for (self.definitions) |candidate| {
            const candidate_id = valueStringField(candidate, "id") orelse continue;
            if (!std.mem.eql(u8, candidate_id, id)) continue;
            const version = valueU64Field(candidate, "version") orelse 1;
            if (latest == null or version > latest_version) {
                latest = candidate;
                latest_version = version;
            }
        }
        return latest;
    }

    pub fn definitionFingerprint(self: Catalog, id: []const u8) ?u64 {
        return valueU64Field(self.definition(id) orelse return null, "fingerprint");
    }

    pub fn listJsonAlloc(self: Catalog, allocator: std.mem.Allocator) ![]u8 {
        return stringifyValuesAlloc(allocator, self.definitions, struct {
            fn accept(_: std.json.Value) bool {
                return true;
            }
        }.accept);
    }

    pub fn showJsonAlloc(self: Catalog, allocator: std.mem.Allocator, id: []const u8) ![]u8 {
        const found = self.definition(id) orelse return error.DefinitionNotFound;
        return std.json.Stringify.valueAlloc(allocator, found, .{});
    }

    pub fn versionsJsonAlloc(self: Catalog, allocator: std.mem.Allocator, id: []const u8) ![]u8 {
        if (self.definition(id) == null) return error.DefinitionNotFound;
        return stringifyMatchingStringAlloc(allocator, self.definitions, "id", id);
    }

    pub fn instancesJsonAlloc(self: Catalog, allocator: std.mem.Allocator, definition_id: []const u8) ![]u8 {
        const fingerprint = self.definitionFingerprint(definition_id) orelse return error.DefinitionNotFound;
        return stringifyMatchingU64Alloc(allocator, self.snapshots, "definition_fingerprint", fingerprint);
    }

    pub fn traceJsonAlloc(self: Catalog, allocator: std.mem.Allocator, instance_id: u64) ![]u8 {
        if (!self.hasInstance(instance_id)) return error.InstanceNotFound;
        return stringifyMatchingU64Alloc(allocator, self.executions, "instance_id", instance_id);
    }

    pub fn explainJsonAlloc(self: Catalog, allocator: std.mem.Allocator, instance_id: u64) ![]u8 {
        const snapshot = self.latestInstance(instance_id) orelse return error.InstanceNotFound;
        const execution = self.latestExecution(instance_id);
        var output = std.ArrayList(u8).empty;
        errdefer output.deinit(allocator);
        try output.appendSlice(allocator, "{\"snapshot\":");
        try appendJsonValue(&output, allocator, snapshot);
        try output.appendSlice(allocator, ",\"latest_execution\":");
        if (execution) |value| try appendJsonValue(&output, allocator, value) else try output.appendSlice(allocator, "null");
        try output.append(allocator, '}');
        return output.toOwnedSlice(allocator);
    }

    pub fn coverageJsonAlloc(self: Catalog, allocator: std.mem.Allocator, definition_id: []const u8) ![]u8 {
        const fingerprint = self.definitionFingerprint(definition_id) orelse return error.DefinitionNotFound;
        const matches = try stringifyMatchingU64Alloc(allocator, self.coverage, "definition_fingerprint", fingerprint);
        if (std.mem.eql(u8, matches, "[]")) {
            allocator.free(matches);
            return error.ArtifactNotFound;
        }
        return matches;
    }

    pub fn pathsJsonAlloc(self: Catalog, allocator: std.mem.Allocator, definition_id: []const u8) ![]u8 {
        if (self.definition(definition_id) == null) return error.DefinitionNotFound;
        return stringifyMatchingStringAlloc(allocator, self.paths, "definition_id", definition_id) catch |err| switch (err) {
            error.ArtifactNotFound => error.ArtifactNotFound,
            else => err,
        };
    }

    pub fn exportAlloc(self: Catalog, allocator: std.mem.Allocator, definition_id: []const u8, format: ExportFormat) ![]u8 {
        const latest = self.definition(definition_id) orelse return error.DefinitionNotFound;
        const latest_version: u32 = @intCast(valueU64Field(latest, "version") orelse 1);
        var legacy_projection: ?Projection = null;
        for (self.projections) |projection| {
            if (!std.mem.eql(u8, projection.definition_id, definition_id)) continue;
            if (projection.definition_version == null) {
                legacy_projection = projection;
                continue;
            }
            if (projection.definition_version.? != latest_version) continue;
            return switch (format) {
                .xstate => if (projection.xstate) |value| std.json.Stringify.valueAlloc(allocator, value, .{}) else error.ArtifactNotFound,
                .mermaid => if (projection.mermaid) |value| allocator.dupe(u8, value) else error.ArtifactNotFound,
                .dot => if (projection.dot) |value| allocator.dupe(u8, value) else error.ArtifactNotFound,
                .native => self.showJsonAlloc(allocator, definition_id),
            };
        }
        if (legacy_projection) |projection| return switch (format) {
            .xstate => if (projection.xstate) |value| std.json.Stringify.valueAlloc(allocator, value, .{}) else error.ArtifactNotFound,
            .mermaid => if (projection.mermaid) |value| allocator.dupe(u8, value) else error.ArtifactNotFound,
            .dot => if (projection.dot) |value| allocator.dupe(u8, value) else error.ArtifactNotFound,
            .native => self.showJsonAlloc(allocator, definition_id),
        };
        if (format == .native) return self.showJsonAlloc(allocator, definition_id);
        return error.ArtifactNotFound;
    }

    pub fn studioJsonAlloc(self: Catalog, allocator: std.mem.Allocator, definition_id: []const u8) ![]u8 {
        if (self.definition(definition_id) == null) return error.DefinitionNotFound;
        var output = std.ArrayList(u8).empty;
        errdefer output.deinit(allocator);
        try output.appendSlice(allocator, "{\"schema\":\"zigeffect.statechart.studio-bundle.v1\",\"machine_id\":");
        const encoded_id = try std.json.Stringify.valueAlloc(allocator, definition_id, .{});
        defer allocator.free(encoded_id);
        try output.appendSlice(allocator, encoded_id);
        try output.appendSlice(allocator, ",\"proposals\":");
        try appendMachineProposals(&output, allocator, self.proposals, definition_id);
        try output.appendSlice(allocator, ",\"proofs\":");
        try appendBoundArtifacts(&output, allocator, self.proofs, "proposal_digest", self.proposals, "digest", self.proposals, definition_id);
        try output.appendSlice(allocator, ",\"reviews\":");
        try appendBoundArtifacts(&output, allocator, self.reviews, "proposal_digest", self.proposals, "digest", self.proposals, definition_id);
        try output.appendSlice(allocator, ",\"approvals\":");
        try appendBoundArtifacts(&output, allocator, self.approvals, "proposal_digest", self.proposals, "digest", self.proposals, definition_id);
        try output.appendSlice(allocator, ",\"applications\":");
        try appendBoundArtifacts(&output, allocator, self.applications, "approval_digest", self.approvals, "digest", self.proposals, definition_id);
        try output.append(allocator, '}');
        return output.toOwnedSlice(allocator);
    }

    pub fn fleetJsonAlloc(self: Catalog, allocator: std.mem.Allocator) ![]u8 {
        const value = self.fleet orelse return error.ArtifactNotFound;
        return std.json.Stringify.valueAlloc(allocator, value, .{});
    }

    pub fn controlReceiptsJsonAlloc(self: Catalog, allocator: std.mem.Allocator) ![]u8 {
        return stringifyValuesAlloc(allocator, self.control_receipts, struct {
            fn accept(_: std.json.Value) bool {
                return true;
            }
        }.accept);
    }

    fn hasInstance(self: Catalog, instance_id: u64) bool {
        return self.latestInstance(instance_id) != null;
    }

    fn latestInstance(self: Catalog, instance_id: u64) ?std.json.Value {
        var latest: ?std.json.Value = null;
        var latest_revision: u64 = 0;
        var found = false;
        for (self.snapshots) |snapshot| {
            const candidate_id = valueU64Field(snapshot, "instance_id") orelse continue;
            if (candidate_id != instance_id) continue;
            const revision = valueU64Field(snapshot, "revision") orelse 0;
            if (!found or revision >= latest_revision) {
                latest = snapshot;
                latest_revision = revision;
                found = true;
            }
        }
        return latest;
    }

    fn latestExecution(self: Catalog, instance_id: u64) ?std.json.Value {
        var latest: ?std.json.Value = null;
        var latest_revision: u64 = 0;
        var found = false;
        for (self.executions) |execution| {
            const candidate_id = valueU64Field(execution, "instance_id") orelse continue;
            if (candidate_id != instance_id) continue;
            const revision = valueU64Field(execution, "revision") orelse 0;
            if (!found or revision >= latest_revision) {
                latest = execution;
                latest_revision = revision;
                found = true;
            }
        }
        return latest;
    }
};

fn appendMachineProposals(output: *std.ArrayList(u8), allocator: std.mem.Allocator, proposals: []const std.json.Value, machine_id: []const u8) !void {
    try output.append(allocator, '[');
    var count: usize = 0;
    for (proposals) |proposal| {
        const candidate = valueStringField(proposal, "machine_id") orelse continue;
        if (!std.mem.eql(u8, candidate, machine_id)) continue;
        if (count != 0) try output.append(allocator, ',');
        try appendJsonValue(output, allocator, proposal);
        count += 1;
    }
    try output.append(allocator, ']');
}

fn appendBoundArtifacts(
    output: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    values: []const std.json.Value,
    reference_field: []const u8,
    owners: []const std.json.Value,
    owner_digest_field: []const u8,
    proposals: []const std.json.Value,
    machine_id: []const u8,
) !void {
    try output.append(allocator, '[');
    var count: usize = 0;
    for (values) |value| {
        const reference = valueStringField(value, reference_field) orelse continue;
        var accepted = false;
        for (owners) |owner| {
            const digest = valueStringField(owner, owner_digest_field) orelse continue;
            if (!std.mem.eql(u8, digest, reference)) continue;
            if (std.mem.eql(u8, reference_field, "approval_digest")) {
                const proposal_digest = valueStringField(owner, "proposal_digest") orelse continue;
                accepted = proposalDigestBelongsToMachine(proposals, proposal_digest, machine_id);
            } else accepted = valueStringField(owner, "machine_id") != null and std.mem.eql(u8, valueStringField(owner, "machine_id").?, machine_id);
            if (accepted) break;
        }
        if (!accepted) continue;
        if (count != 0) try output.append(allocator, ',');
        try appendJsonValue(output, allocator, value);
        count += 1;
    }
    try output.append(allocator, ']');
}

fn proposalDigestBelongsToMachine(proposals: []const std.json.Value, digest: []const u8, machine_id: []const u8) bool {
    for (proposals) |proposal| {
        const candidate_digest = valueStringField(proposal, "digest") orelse continue;
        const candidate_machine = valueStringField(proposal, "machine_id") orelse continue;
        if (std.mem.eql(u8, candidate_digest, digest) and std.mem.eql(u8, candidate_machine, machine_id)) return true;
    }
    return false;
}

pub const ExportFormat = enum { native, xstate, mermaid, dot };
pub const ParsedCatalog = std.json.Parsed(Catalog);

pub fn parseCatalog(allocator: std.mem.Allocator, input: []const u8) !ParsedCatalog {
    var parsed = try std.json.parseFromSlice(Catalog, allocator, input, .{ .allocate = .alloc_always, .ignore_unknown_fields = false });
    errdefer parsed.deinit();
    try parsed.value.validate();
    return parsed;
}

pub fn writeCatalogAtomic(
    allocator: std.mem.Allocator,
    io: std.Io,
    dir: std.Io.Dir,
    catalog: Catalog,
) !void {
    try catalog.validate();
    const encoded = try std.json.Stringify.valueAlloc(allocator, catalog, .{ .emit_null_optional_fields = false });
    defer allocator.free(encoded);
    var verified = try parseCatalog(allocator, encoded);
    verified.deinit();

    dir.deleteFile(io, catalog_temporary_file) catch |err| switch (err) {
        error.FileNotFound => {},
        else => return err,
    };
    try dir.writeFile(io, .{ .sub_path = catalog_temporary_file, .data = encoded });
    dir.deleteFile(io, catalog_backup_file) catch |err| switch (err) {
        error.FileNotFound => {},
        else => return err,
    };
    var rotated = false;
    dir.rename(catalog_file, dir, catalog_backup_file, io) catch |err| switch (err) {
        error.FileNotFound => {},
        else => return err,
    };
    if (dir.access(io, catalog_backup_file, .{})) |_| rotated = true else |_| {}
    dir.rename(catalog_temporary_file, dir, catalog_file, io) catch |err| {
        if (rotated) dir.rename(catalog_backup_file, dir, catalog_file, io) catch {};
        return err;
    };
}

pub fn readCatalogRecovering(
    allocator: std.mem.Allocator,
    io: std.Io,
    dir: std.Io.Dir,
    max_bytes: usize,
) !ParsedCatalog {
    const current_text = dir.readFileAlloc(io, catalog_file, allocator, .limited(max_bytes)) catch null;
    if (current_text) |text| {
        defer allocator.free(text);
        if (parseCatalog(allocator, text)) |parsed| return parsed else |_| {}
    }
    const backup_text = dir.readFileAlloc(io, catalog_backup_file, allocator, .limited(max_bytes)) catch return error.CatalogRecoveryFailed;
    defer allocator.free(backup_text);
    const recovered = parseCatalog(allocator, backup_text) catch return error.CatalogRecoveryFailed;

    dir.deleteFile(io, catalog_file) catch {};
    dir.rename(catalog_backup_file, dir, catalog_file, io) catch {
        recovered.deinit();
        return error.CatalogRecoveryFailed;
    };
    return recovered;
}

fn stringifyMatchingU64Alloc(allocator: std.mem.Allocator, values: []const std.json.Value, field: []const u8, expected: u64) ![]u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);
    try output.append(allocator, '[');
    var count: usize = 0;
    for (values) |value| {
        if (valueU64Field(value, field) != expected) continue;
        if (count != 0) try output.append(allocator, ',');
        try appendJsonValue(&output, allocator, value);
        count += 1;
    }
    try output.append(allocator, ']');
    return output.toOwnedSlice(allocator);
}

fn stringifyMatchingStringAlloc(allocator: std.mem.Allocator, values: []const std.json.Value, field: []const u8, expected: []const u8) ![]u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);
    try output.append(allocator, '[');
    var count: usize = 0;
    for (values) |value| {
        const actual = valueStringField(value, field) orelse continue;
        if (!std.mem.eql(u8, actual, expected)) continue;
        if (count != 0) try output.append(allocator, ',');
        try appendJsonValue(&output, allocator, value);
        count += 1;
    }
    try output.append(allocator, ']');
    if (count == 0) {
        output.deinit(allocator);
        return error.ArtifactNotFound;
    }
    return output.toOwnedSlice(allocator);
}

fn stringifyValuesAlloc(
    allocator: std.mem.Allocator,
    values: []const std.json.Value,
    accept: *const fn (std.json.Value) bool,
) ![]u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);
    try output.append(allocator, '[');
    var count: usize = 0;
    for (values) |value| {
        if (!accept(value)) continue;
        if (count != 0) try output.append(allocator, ',');
        try appendJsonValue(&output, allocator, value);
        count += 1;
    }
    try output.append(allocator, ']');
    return output.toOwnedSlice(allocator);
}

fn appendJsonValue(output: *std.ArrayList(u8), allocator: std.mem.Allocator, value: std.json.Value) !void {
    const encoded = try std.json.Stringify.valueAlloc(allocator, value, .{});
    defer allocator.free(encoded);
    try output.appendSlice(allocator, encoded);
}

fn valueStringField(value: std.json.Value, field: []const u8) ?[]const u8 {
    if (value != .object) return null;
    const item = value.object.get(field) orelse return null;
    if (item != .string) return null;
    return item.string;
}

fn valueU64Field(value: std.json.Value, field: []const u8) ?u64 {
    if (value != .object) return null;
    const item = value.object.get(field) orelse return null;
    return switch (item) {
        .integer => |integer| if (integer < 0) null else @intCast(integer),
        .string => |text| std.fmt.parseInt(u64, text, 10) catch null,
        else => null,
    };
}

test "catalog validates and queries definitions instances traces and projections" {
    const json =
        \\{"schema":"zigeffect.statechart.catalog.v1","schema_version":1,
        \\ "definitions":[{"schema":"zigeffect.statechart.definition.v1","id":"agent.review","fingerprint":44}],
        \\ "snapshots":[{"instance_id":7,"definition_fingerprint":44,"revision":2}],
        \\ "executions":[{"instance_id":7,"revision":2,"transition_id":"approve"}],
        \\ "coverage":[{"definition_fingerprint":44,"visited":3}],
        \\ "paths":[{"definition_id":"agent.review","transitions":["approve"]}],
        \\ "projections":[{"definition_id":"agent.review","xstate":{"id":"agent.review"},"mermaid":"stateDiagram-v2","dot":"digraph statechart {}"}],
        \\ "fleet":{"schema":"zigeffect.statechart.fleet-snapshot.v1","instances":[]},
        \\ "control_receipts":[{"schema":"zigeffect.statechart.control-receipt.v1","request_id":"r-1"}]}
    ;
    var parsed = try parseCatalog(std.testing.allocator, json);
    defer parsed.deinit();

    const show = try parsed.value.showJsonAlloc(std.testing.allocator, "agent.review");
    defer std.testing.allocator.free(show);
    try std.testing.expect(std.mem.indexOf(u8, show, "agent.review") != null);
    const instances = try parsed.value.instancesJsonAlloc(std.testing.allocator, "agent.review");
    defer std.testing.allocator.free(instances);
    try std.testing.expect(std.mem.indexOf(u8, instances, "\"instance_id\":7") != null);
    const trace = try parsed.value.traceJsonAlloc(std.testing.allocator, 7);
    defer std.testing.allocator.free(trace);
    try std.testing.expect(std.mem.indexOf(u8, trace, "approve") != null);
    const exported = try parsed.value.exportAlloc(std.testing.allocator, "agent.review", .mermaid);
    defer std.testing.allocator.free(exported);
    try std.testing.expectEqualStrings("stateDiagram-v2", exported);
    const fleet = try parsed.value.fleetJsonAlloc(std.testing.allocator);
    defer std.testing.allocator.free(fleet);
    try std.testing.expect(std.mem.indexOf(u8, fleet, "fleet-snapshot") != null);
    const controls = try parsed.value.controlReceiptsJsonAlloc(std.testing.allocator);
    defer std.testing.allocator.free(controls);
    try std.testing.expect(std.mem.indexOf(u8, controls, "r-1") != null);
}

test "catalog queries v2 decimal-string u64 identities without precision loss" {
    const json =
        \\{"schema":"zigeffect.statechart.catalog.v1","schema_version":1,
        \\ "definitions":[{"schema":"zigeffect.statechart.definition.v2","id":"agent.large","fingerprint":"18446744073709551614"}],
        \\ "snapshots":[{"schema":"zigeffect.statechart.snapshot.v2","instance_id":"18446744073709551615","definition_fingerprint":"18446744073709551614","revision":"9007199254740993"}],
        \\ "executions":[{"schema":"zigeffect.statechart.execution.v2","instance_id":"18446744073709551615","revision":"9007199254740993"}]}
    ;
    var parsed = try parseCatalog(std.testing.allocator, json);
    defer parsed.deinit();
    const instances = try parsed.value.instancesJsonAlloc(std.testing.allocator, "agent.large");
    defer std.testing.allocator.free(instances);
    try std.testing.expect(std.mem.indexOf(u8, instances, "18446744073709551615") != null);
    const trace = try parsed.value.traceJsonAlloc(std.testing.allocator, std.math.maxInt(u64));
    defer std.testing.allocator.free(trace);
    try std.testing.expect(std.mem.indexOf(u8, trace, "9007199254740993") != null);
}

test "catalog retains immutable machine version history and resolves the latest" {
    const json =
        \\{"schema":"zigeffect.statechart.catalog.v1","schema_version":1,
        \\ "definitions":[
        \\   {"id":"agent.review","version":1,"fingerprint":"41"},
        \\   {"id":"agent.review","version":2,"fingerprint":"42"}]}
    ;
    var parsed = try parseCatalog(std.testing.allocator, json);
    defer parsed.deinit();
    try std.testing.expectEqual(@as(?u64, 42), parsed.value.definitionFingerprint("agent.review"));
    const versions = try parsed.value.versionsJsonAlloc(std.testing.allocator, "agent.review");
    defer std.testing.allocator.free(versions);
    try std.testing.expect(std.mem.indexOf(u8, versions, "\"version\":1") != null);
    try std.testing.expect(std.mem.indexOf(u8, versions, "\"version\":2") != null);

    const duplicate =
        \\{"schema":"zigeffect.statechart.catalog.v1","schema_version":1,
        \\ "definitions":[{"id":"agent.review","version":2,"fingerprint":"42"},{"id":"agent.review","version":2,"fingerprint":"43"}]}
    ;
    try std.testing.expectError(error.DuplicateDefinition, parseCatalog(std.testing.allocator, duplicate));
}

test "catalog returns machine scoped studio governance evidence" {
    const json =
        \\{"schema":"zigeffect.statechart.catalog.v1","schema_version":1,
        \\ "definitions":[{"id":"agent.review","fingerprint":"42"},{"id":"agent.other","fingerprint":"99"}],
        \\ "proposals":[{"machine_id":"agent.review","digest":"review-proposal"},{"machine_id":"agent.other","digest":"other-proposal"}],
        \\ "proofs":[{"proposal_digest":"review-proposal","digest":"review-proof"},{"proposal_digest":"other-proposal","digest":"other-proof"}],
        \\ "reviews":[{"proposal_digest":"review-proposal","digest":"review-review"}],
        \\ "approvals":[{"proposal_digest":"review-proposal","digest":"review-approval"},{"proposal_digest":"other-proposal","digest":"other-approval"}],
        \\ "applications":[{"approval_digest":"review-approval"},{"approval_digest":"other-approval"}]}
    ;
    var parsed = try parseCatalog(std.testing.allocator, json);
    defer parsed.deinit();
    const bundle = try parsed.value.studioJsonAlloc(std.testing.allocator, "agent.review");
    defer std.testing.allocator.free(bundle);
    try std.testing.expect(std.mem.indexOf(u8, bundle, "review-proof") != null);
    try std.testing.expect(std.mem.indexOf(u8, bundle, "review-approval") != null);
    try std.testing.expect(std.mem.indexOf(u8, bundle, "other-proof") == null);
    try std.testing.expect(std.mem.indexOf(u8, bundle, "other-approval") == null);
}

test "catalog production rotates atomically and recovers a partial current write" {
    const json =
        \\{"schema":"zigeffect.statechart.catalog.v1","schema_version":1,
        \\ "definitions":[{"schema":"zigeffect.statechart.definition.v2","id":"agent.atomic","fingerprint":"99"}]}
    ;
    var parsed = try parseCatalog(std.testing.allocator, json);
    defer parsed.deinit();
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try writeCatalogAtomic(std.testing.allocator, std.testing.io, tmp.dir, parsed.value);
    try writeCatalogAtomic(std.testing.allocator, std.testing.io, tmp.dir, parsed.value);
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = catalog_file, .data = "{\"schema\":" });

    var recovered = try readCatalogRecovering(std.testing.allocator, std.testing.io, tmp.dir, 1024 * 1024);
    defer recovered.deinit();
    try std.testing.expect(recovered.value.definition("agent.atomic") != null);
    const restored = try tmp.dir.readFileAlloc(std.testing.io, catalog_file, std.testing.allocator, .limited(1024 * 1024));
    defer std.testing.allocator.free(restored);
    try std.testing.expect(std.mem.indexOf(u8, restored, "agent.atomic") != null);
}
