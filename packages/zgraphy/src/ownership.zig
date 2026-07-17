const std = @import("std");
const discovery = @import("discovery.zig");
const model = @import("model.zig");
const owned = @import("memory.zig");

pub const schema = "zgraphy.ownership-manifest.v1";
pub const schema_version: u32 = 1;

pub const Provider = enum(u8) {
    repository,
    nested_git,
    zigeffect,
    zig_zon,
    package_json,
    pyproject,
    cargo,
    go_module,
    buf,
};

pub const UnitKind = enum(u8) {
    repository,
    nested_repository,
    workspace,
    application,
    package,
    library,
};

pub const Options = struct {
    max_units: usize = 4096,
    max_manifest_bytes: usize = 1024 * 1024,
    discovery_validated: bool = false,
};

pub const Unit = struct {
    kind: UnitKind,
    label: []const u8,
    root: []const u8,
    manifest_path: []const u8,
    provider: Provider,
};

pub const Assignment = struct {
    file_path: []const u8,
    owner_kind: UnitKind,
    owner_label: []const u8,
    owner_root: []const u8,
    provider: Provider,
};

pub const Summary = struct {
    units: usize = 0,
    assignments: usize = 0,
    adapters_succeeded: usize = 0,
    adapters_failed: usize = 0,
    nested_repositories: usize = 0,
    repository_owned: usize = 0,
    explicit_unit_owned: usize = 0,
};

pub const Result = struct {
    allocator: std.mem.Allocator,
    units: []Unit,
    assignments: []Assignment,
    summary: Summary,
    manifest_digest: [32]u8,

    pub fn deinit(self: *Result) void {
        for (self.units) |unit| {
            self.allocator.free(unit.label);
            if (unit.root.len > 0) self.allocator.free(unit.root);
            if (unit.manifest_path.len > 0) self.allocator.free(unit.manifest_path);
        }
        self.allocator.free(self.units);
        self.allocator.free(self.assignments);
        self.units = &.{};
        self.assignments = &.{};
    }

    pub fn findAssignment(self: *const Result, path: []const u8) ?*const Assignment {
        for (self.assignments, 0..) |assignment, index| {
            if (std.mem.eql(u8, assignment.file_path, path)) return &self.assignments[index];
        }
        return null;
    }

    pub fn reconciles(self: *const Result, discovered: *const discovery.Result) bool {
        const placed = discovered.summary.deeply_indexed + discovered.summary.placed_unsupported + discovered.summary.placed_asset;
        if (self.assignments.len != placed or self.summary.assignments != placed) return false;
        for (discovered.records) |record| {
            if (!isPlaced(record.disposition)) continue;
            var matches: usize = 0;
            for (self.assignments) |assignment| if (std.mem.eql(u8, assignment.file_path, record.relative_path)) {
                matches += 1;
            };
            if (matches != 1) return false;
        }
        return true;
    }
};

pub fn analyze(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    discovered: *const discovery.Result,
    options: Options,
) !Result {
    if (!options.discovery_validated) try discovery.validate(discovered);
    if (options.max_units == 0 or options.max_manifest_bytes == 0) return error.InvalidOwnershipOptions;
    var units: std.ArrayList(Unit) = .empty;
    errdefer deinitUnits(allocator, &units);
    try appendUnit(allocator, &units, options.max_units, .repository, discovered.repository_id, "", "", .repository);

    var summary = Summary{};
    for (discovered.records) |record| {
        if (record.disposition == .excluded_mandatory and std.mem.eql(u8, std.fs.path.basename(record.relative_path), ".git")) {
            const repository_root = std.fs.path.dirname(record.relative_path) orelse continue;
            if (repository_root.len == 0) continue;
            try appendUnit(allocator, &units, options.max_units, .nested_repository, std.fs.path.basename(repository_root), repository_root, record.relative_path, .nested_git);
            summary.nested_repositories += 1;
            continue;
        }
        if (!isPlaced(record.disposition)) continue;
        const provider = providerFor(record.relative_path) orelse continue;
        const bytes = try readVerifiedManifest(allocator, io, root, &record, options.max_manifest_bytes);
        defer allocator.free(bytes);
        const before = units.items.len;
        try appendProviderUnits(allocator, &units, options.max_units, provider, record.relative_path, bytes);
        if (units.items.len > before) {
            summary.adapters_succeeded += 1;
        } else {
            summary.adapters_failed += 1;
        }
    }

    std.mem.sort(Unit, units.items, {}, lessThanUnit);
    const unit_slice = try units.toOwnedSlice(allocator);
    errdefer {
        var owned_units = std.ArrayList(Unit).fromOwnedSlice(unit_slice);
        deinitUnits(allocator, &owned_units);
    }
    var assignments: std.ArrayList(Assignment) = .empty;
    errdefer assignments.deinit(allocator);
    for (discovered.records) |record| {
        if (!isPlaced(record.disposition)) continue;
        const owner = deepestOwner(unit_slice, record.relative_path) orelse return error.MissingOwnershipContext;
        try assignments.append(allocator, .{
            .file_path = record.relative_path,
            .owner_kind = owner.kind,
            .owner_label = owner.label,
            .owner_root = owner.root,
            .provider = owner.provider,
        });
        if (owner.kind == .repository) summary.repository_owned += 1 else summary.explicit_unit_owned += 1;
    }
    std.mem.sort(Assignment, assignments.items, {}, lessThanAssignment);
    const assignment_slice = try assignments.toOwnedSlice(allocator);
    summary.units = unit_slice.len;
    summary.assignments = assignment_slice.len;
    var result = Result{
        .allocator = allocator,
        .units = unit_slice,
        .assignments = assignment_slice,
        .summary = summary,
        .manifest_digest = ownershipDigest(discovered.repository_id, unit_slice, assignment_slice),
    };
    errdefer result.deinit();
    try validate(discovered, &result);
    return result;
}

pub fn validate(discovered: *const discovery.Result, result: *const Result) !void {
    if (result.units.len == 0 or result.summary.units != result.units.len or
        result.summary.assignments != result.assignments.len or !result.reconciles(discovered))
    {
        return error.InvalidOwnershipResult;
    }
    var previous_unit: ?Unit = null;
    for (result.units) |unit| {
        if (unit.label.len == 0 or (unit.root.len > 0 and !validRelativePath(unit.root))) return error.InvalidOwnershipUnit;
        if (previous_unit) |prior| if (!lessThanUnit({}, prior, unit)) return error.DuplicateOwnershipUnit;
        previous_unit = unit;
    }
    var previous_path: ?[]const u8 = null;
    for (result.assignments) |assignment| {
        if (!validRelativePath(assignment.file_path)) return error.InvalidOwnershipAssignment;
        if (previous_path) |prior| if (!std.mem.lessThan(u8, prior, assignment.file_path)) return error.DuplicateOwnershipAssignment;
        previous_path = assignment.file_path;
        var owner_exists = false;
        for (result.units) |unit| {
            if (unit.kind == assignment.owner_kind and std.mem.eql(u8, unit.label, assignment.owner_label) and
                std.mem.eql(u8, unit.root, assignment.owner_root) and unit.provider == assignment.provider)
            {
                owner_exists = true;
                break;
            }
        }
        if (!owner_exists) return error.MissingOwnershipUnit;
    }
    const expected = ownershipDigest(discovered.repository_id, result.units, result.assignments);
    if (!std.mem.eql(u8, &expected, &result.manifest_digest)) return error.InvalidOwnershipDigest;
}

pub fn materialize(graph: *model.RepositoryGraph, discovered: *const discovery.Result, result: *const Result) !void {
    try validate(discovered, result);
    const repository_id = model.stableId(.repository, "", discovered.repository_id);
    if (graph.findNode(repository_id) == null) return error.MissingRepositoryPlacement;
    for (result.units) |unit| {
        if (unit.kind == .repository) continue;
        const unit_id = try addUnitNode(graph, unit);
        const parent_id = parentNodeId(result.units, discovered.repository_id, unit) orelse repository_id;
        try graph.addEdge(.{ .from = parent_id, .to = unit_id, .relation = .contains, .provenance = .extracted, .source_path = unit.manifest_path });
        if (unit.manifest_path.len > 0) {
            const manifest_file = model.stableId(.file, unit.manifest_path, std.fs.path.basename(unit.manifest_path));
            if (graph.findNode(manifest_file) != null) {
                try graph.addEdge(.{ .from = manifest_file, .to = unit_id, .relation = .defines, .provenance = .extracted, .source_path = unit.manifest_path });
            }
        }
    }
    for (result.assignments) |assignment| {
        const owner_id = assignmentNodeId(discovered.repository_id, assignment);
        const file_id = model.stableId(.file, assignment.file_path, std.fs.path.basename(assignment.file_path));
        if (graph.findNode(owner_id) == null or graph.findNode(file_id) == null) return error.MissingOwnershipPlacement;
        try graph.addEdge(.{ .from = file_id, .to = owner_id, .relation = .owned_by, .provenance = .extracted });
    }
}

fn appendProviderUnits(
    allocator: std.mem.Allocator,
    units: *std.ArrayList(Unit),
    max_units: usize,
    provider: Provider,
    manifest_path: []const u8,
    bytes: []const u8,
) !void {
    const unit_root = std.fs.path.dirname(manifest_path) orelse "";
    switch (provider) {
        .zigeffect => {
            var parsed = std.json.parseFromSlice(std.json.Value, allocator, bytes, .{}) catch return;
            defer parsed.deinit();
            const object = switch (parsed.value) {
                .object => |value| value,
                else => return,
            };
            const name = jsonString(object.get("name")) orelse if (unit_root.len > 0) std.fs.path.basename(unit_root) else "application";
            try appendUnit(allocator, units, max_units, .application, name, unit_root, manifest_path, provider);
        },
        .package_json => {
            var parsed = std.json.parseFromSlice(std.json.Value, allocator, bytes, .{}) catch return;
            defer parsed.deinit();
            const object = switch (parsed.value) {
                .object => |value| value,
                else => return,
            };
            const name = jsonString(object.get("name")) orelse return;
            if (object.get("workspaces") != null) try appendUnit(allocator, units, max_units, .workspace, name, unit_root, manifest_path, provider);
            const kind: UnitKind = if (hasApplicationScript(object)) .application else .package;
            try appendUnit(allocator, units, max_units, kind, name, unit_root, manifest_path, provider);
        },
        .pyproject => {
            const name = sectionName(bytes, "[project]") orelse return;
            try appendUnit(allocator, units, max_units, .package, name, unit_root, manifest_path, provider);
        },
        .cargo => {
            if (std.mem.indexOf(u8, bytes, "[workspace]") != null) {
                const workspace_name = if (unit_root.len > 0) std.fs.path.basename(unit_root) else "cargo-workspace";
                try appendUnit(allocator, units, max_units, .workspace, workspace_name, unit_root, manifest_path, provider);
            }
            if (sectionName(bytes, "[package]")) |name| try appendUnit(allocator, units, max_units, .library, name, unit_root, manifest_path, provider);
        },
        .go_module => {
            const name = goModuleName(bytes) orelse return;
            try appendUnit(allocator, units, max_units, .library, name, unit_root, manifest_path, provider);
        },
        .zig_zon => {
            const name = zigZonName(bytes) orelse return;
            try appendUnit(allocator, units, max_units, .package, name, unit_root, manifest_path, provider);
        },
        .buf => {
            const name = if (unit_root.len > 0) std.fs.path.basename(unit_root) else "proto";
            try appendUnit(allocator, units, max_units, .package, name, unit_root, manifest_path, provider);
        },
        .repository, .nested_git => return error.InvalidOwnershipProvider,
    }
}

fn appendUnit(
    allocator: std.mem.Allocator,
    units: *std.ArrayList(Unit),
    max_units: usize,
    kind: UnitKind,
    label: []const u8,
    root: []const u8,
    manifest_path: []const u8,
    provider: Provider,
) !void {
    if (label.len == 0 or label.len > 512 or root.len > std.fs.max_path_bytes or manifest_path.len > std.fs.max_path_bytes) return error.InvalidOwnershipUnit;
    for (units.items) |unit| {
        if (unit.kind == kind and std.mem.eql(u8, unit.label, label) and std.mem.eql(u8, unit.root, root)) return;
    }
    if (units.items.len >= max_units) return error.OwnershipUnitLimitExceeded;
    const copied_label = try owned.copy(u8, allocator, label);
    errdefer allocator.free(copied_label);
    const copied_root = if (root.len > 0) try owned.copy(u8, allocator, root) else "";
    errdefer if (copied_root.len > 0) allocator.free(copied_root);
    const copied_manifest = if (manifest_path.len > 0) try owned.copy(u8, allocator, manifest_path) else "";
    errdefer if (copied_manifest.len > 0) allocator.free(copied_manifest);
    try units.append(allocator, .{
        .kind = kind,
        .label = copied_label,
        .root = copied_root,
        .manifest_path = copied_manifest,
        .provider = provider,
    });
}

fn deinitUnits(allocator: std.mem.Allocator, units: *std.ArrayList(Unit)) void {
    for (units.items) |unit| {
        allocator.free(unit.label);
        if (unit.root.len > 0) allocator.free(unit.root);
        if (unit.manifest_path.len > 0) allocator.free(unit.manifest_path);
    }
    units.deinit(allocator);
}

fn deepestOwner(units: []const Unit, path: []const u8) ?Unit {
    var best: ?Unit = null;
    for (units) |unit| {
        if (!ownsFiles(unit.kind) or !pathWithin(path, unit.root)) continue;
        if (best == null or unit.root.len > best.?.root.len or
            (unit.root.len == best.?.root.len and ownerPriority(unit.kind) > ownerPriority(best.?.kind)))
        {
            best = unit;
        }
    }
    return best;
}

fn parentNodeId(units: []const Unit, repository_identity: []const u8, child: Unit) ?u64 {
    var parent: ?Unit = null;
    for (units) |candidate| {
        if (candidate.kind == .workspace and std.mem.eql(u8, candidate.root, child.root)) {
            parent = candidate;
            break;
        }
        if (!ownsFiles(candidate.kind) or candidate.root.len >= child.root.len or !pathWithin(child.root, candidate.root)) continue;
        if (parent == null or candidate.root.len > parent.?.root.len) parent = candidate;
    }
    const found = parent orelse return model.stableId(.repository, "", repository_identity);
    return unitNodeId(repository_identity, found);
}

fn assignmentNodeId(repository_identity: []const u8, assignment: Assignment) u64 {
    if (assignment.owner_kind == .repository) return model.stableId(.repository, "", repository_identity);
    return model.stableId(nodeKind(assignment.owner_kind), assignment.owner_root, assignment.owner_label);
}

fn unitNodeId(repository_identity: []const u8, unit: Unit) u64 {
    if (unit.kind == .repository) return model.stableId(.repository, "", repository_identity);
    return model.stableId(nodeKind(unit.kind), unit.root, unit.label);
}

fn addUnitNode(graph: *model.RepositoryGraph, unit: Unit) !u64 {
    return graph.addNode(.{
        .kind = nodeKind(unit.kind),
        .label = unit.label,
        .path = unit.root,
        .search_text = tryUnitSearchText(graph, unit),
    });
}

fn tryUnitSearchText(graph: *model.RepositoryGraph, unit: Unit) []const u8 {
    _ = graph;
    return unit.manifest_path;
}

fn nodeKind(kind: UnitKind) model.NodeKind {
    return switch (kind) {
        .repository, .nested_repository => .repository,
        .workspace => .workspace,
        .application => .application,
        .package => .package,
        .library => .library,
    };
}

fn ownsFiles(kind: UnitKind) bool {
    return kind != .workspace;
}

fn ownerPriority(kind: UnitKind) u8 {
    return switch (kind) {
        .application => 6,
        .package => 5,
        .library => 4,
        .nested_repository => 3,
        .repository => 2,
        .workspace => 1,
    };
}

fn providerFor(path: []const u8) ?Provider {
    const basename = std.fs.path.basename(path);
    if (std.mem.eql(u8, basename, "zigeffect.project.json")) return .zigeffect;
    if (std.mem.eql(u8, basename, "build.zig.zon")) return .zig_zon;
    if (std.mem.eql(u8, basename, "package.json")) return .package_json;
    if (std.mem.eql(u8, basename, "pyproject.toml")) return .pyproject;
    if (std.mem.eql(u8, basename, "Cargo.toml")) return .cargo;
    if (std.mem.eql(u8, basename, "go.mod")) return .go_module;
    if (std.mem.eql(u8, basename, "buf.yaml")) return .buf;
    return null;
}

fn readVerifiedManifest(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    record: *const discovery.Record,
    max_bytes: usize,
) ![]u8 {
    const expected = record.content_digest orelse return error.MissingManifestFingerprint;
    if (record.size > max_bytes) return error.OwnershipManifestTooLarge;
    const bytes = root.readFileAlloc(io, record.relative_path, allocator, .limited(max_bytes)) catch return error.OwnershipManifestUnavailable;
    errdefer allocator.free(bytes);
    var actual: [32]u8 = @splat(0);
    std.crypto.hash.sha2.Sha256.hash(bytes, &actual, .{});
    if (!std.mem.eql(u8, &expected, &actual)) return error.OwnershipManifestChanged;
    return bytes;
}

fn jsonString(value: ?std.json.Value) ?[]const u8 {
    const present = value orelse return null;
    return switch (present) {
        .string => |text| text,
        else => null,
    };
}

fn hasApplicationScript(object: std.json.ObjectMap) bool {
    const scripts = object.get("scripts") orelse return false;
    const map = switch (scripts) {
        .object => |value| value,
        else => return false,
    };
    return map.contains("dev") or map.contains("start") or map.contains("serve");
}

fn sectionName(bytes: []const u8, section: []const u8) ?[]const u8 {
    var in_section = false;
    var lines = std.mem.splitScalar(u8, bytes, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r");
        if (line.len == 0 or line[0] == '#') continue;
        if (line[0] == '[') {
            in_section = std.mem.eql(u8, line, section);
            continue;
        }
        if (!in_section or !std.mem.startsWith(u8, line, "name")) continue;
        const equals = std.mem.indexOfScalar(u8, line, '=') orelse continue;
        const value = std.mem.trim(u8, line[equals + 1 ..], " \t\r\"");
        if (value.len > 0) return value;
    }
    return null;
}

fn goModuleName(bytes: []const u8) ?[]const u8 {
    var lines = std.mem.splitScalar(u8, bytes, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r");
        if (!std.mem.startsWith(u8, line, "module ")) continue;
        const value = std.mem.trim(u8, line["module ".len..], " \t\r");
        if (value.len > 0) return value;
    }
    return null;
}

fn zigZonName(bytes: []const u8) ?[]const u8 {
    const key = ".name";
    const start = std.mem.indexOf(u8, bytes, key) orelse return null;
    const equals_relative = std.mem.indexOfScalar(u8, bytes[start + key.len ..], '=') orelse return null;
    var value = std.mem.trimStart(u8, bytes[start + key.len + equals_relative + 1 ..], " \t\r\n");
    if (value.len > 0 and value[0] == '.') value = value[1..];
    if (value.len > 0 and value[0] == '"') value = value[1..];
    var end: usize = 0;
    while (end < value.len and (std.ascii.isAlphanumeric(value[end]) or value[end] == '_' or value[end] == '-')) end += 1;
    if (end == 0) return null;
    return value[0..end];
}

fn pathWithin(path: []const u8, root: []const u8) bool {
    if (root.len == 0) return true;
    return std.mem.eql(u8, path, root) or (std.mem.startsWith(u8, path, root) and path.len > root.len and path[root.len] == '/');
}

fn validRelativePath(path: []const u8) bool {
    if (path.len == 0 or std.fs.path.isAbsolute(path) or std.mem.indexOfScalar(u8, path, '\\') != null) return false;
    var components = std.mem.splitScalar(u8, path, '/');
    while (components.next()) |component| if (component.len == 0 or std.mem.eql(u8, component, ".") or std.mem.eql(u8, component, "..")) return false;
    return true;
}

fn isPlaced(disposition: discovery.Disposition) bool {
    return disposition == .deeply_indexed or disposition == .placed_unsupported or disposition == .placed_asset;
}

fn lessThanUnit(_: void, left: Unit, right: Unit) bool {
    if (!std.mem.eql(u8, left.root, right.root)) return std.mem.lessThan(u8, left.root, right.root);
    if (left.kind != right.kind) return @intFromEnum(left.kind) < @intFromEnum(right.kind);
    return std.mem.lessThan(u8, left.label, right.label);
}

fn lessThanAssignment(_: void, left: Assignment, right: Assignment) bool {
    return std.mem.lessThan(u8, left.file_path, right.file_path);
}

fn ownershipDigest(repository_id: []const u8, units: []const Unit, assignments: []const Assignment) [32]u8 {
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    updateBytes(&hasher, schema);
    updateBytes(&hasher, repository_id);
    for (units) |unit| {
        updateU64(&hasher, @intCast(@intFromEnum(unit.kind)));
        updateBytes(&hasher, unit.label);
        updateBytes(&hasher, unit.root);
        updateBytes(&hasher, unit.manifest_path);
        updateU64(&hasher, @intCast(@intFromEnum(unit.provider)));
    }
    for (assignments) |assignment| {
        updateBytes(&hasher, assignment.file_path);
        updateU64(&hasher, @intCast(@intFromEnum(assignment.owner_kind)));
        updateBytes(&hasher, assignment.owner_label);
        updateBytes(&hasher, assignment.owner_root);
        updateU64(&hasher, @intCast(@intFromEnum(assignment.provider)));
    }
    var digest: [32]u8 = @splat(0);
    hasher.final(&digest);
    return digest;
}

fn updateBytes(hasher: *std.crypto.hash.sha2.Sha256, value: []const u8) void {
    updateU64(hasher, @intCast(value.len));
    hasher.update(value);
}

fn updateU64(hasher: *std.crypto.hash.sha2.Sha256, value: u64) void {
    var bytes: [8]u8 = @splat(0);
    std.mem.writeInt(u64, &bytes, value, .little);
    hasher.update(&bytes);
}
