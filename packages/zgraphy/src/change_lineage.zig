const std = @import("std");
const discovery = @import("discovery.zig");
const memory = @import("memory.zig");
const model = @import("model.zig");

pub const schema = "zgraphy.change-lineage.v1";
pub const schema_version: u32 = 1;
pub const max_artifact_bytes: usize = 256 * 1024 * 1024;

pub const Relation = enum {
    renamed_from,
    moved_from,
};

pub const Evidence = enum {
    exact_content_unique,
};

pub const Provenance = enum {
    inferred,
};

pub const Record = struct {
    id: []const u8,
    relation: Relation,
    evidence: Evidence = .exact_content_unique,
    provenance: Provenance = .inferred,
    predecessor_generation: []const u8,
    successor_generation: []const u8,
    predecessor_path: []const u8,
    successor_path: []const u8,
    predecessor_node_id: u64,
    successor_node_id: u64,
    content_digest: []const u8,
    classification: discovery.Classification,
};

pub const Ambiguity = struct {
    id: []const u8,
    evidence: Evidence = .exact_content_unique,
    predecessor_generation: []const u8,
    successor_generation: []const u8,
    content_digest: []const u8,
    classification: discovery.Classification,
    predecessor_paths: []const []const u8,
    successor_paths: []const []const u8,
};

pub const Summary = struct {
    records: usize = 0,
    renamed: usize = 0,
    moved: usize = 0,
    ambiguous_groups: usize = 0,
    ambiguous_predecessors: usize = 0,
    ambiguous_successors: usize = 0,
};

pub const Artifact = struct {
    schema: []const u8 = schema,
    schema_version: u32 = schema_version,
    repository_id: []const u8,
    parent_generation: []const u8,
    target_generation: []const u8,
    input_fingerprint: []const u8,
    fingerprint: []const u8,
    summary: Summary,
    records: []Record,
    ambiguities: []Ambiguity,
    complete: bool = true,
};

pub const Owned = struct {
    allocator: std.mem.Allocator,
    value: Artifact,

    pub fn deinit(self: *Owned) void {
        self.allocator.free(self.value.repository_id);
        self.allocator.free(self.value.parent_generation);
        self.allocator.free(self.value.target_generation);
        self.allocator.free(self.value.input_fingerprint);
        self.allocator.free(self.value.fingerprint);
        for (self.value.records) |record| freeRecord(self.allocator, record);
        self.allocator.free(self.value.records);
        for (self.value.ambiguities) |ambiguity| freeAmbiguity(self.allocator, ambiguity);
        self.allocator.free(self.value.ambiguities);
        self.value.repository_id = &.{};
        self.value.parent_generation = &.{};
        self.value.target_generation = &.{};
        self.value.input_fingerprint = &.{};
        self.value.fingerprint = &.{};
        self.value.records = &.{};
        self.value.ambiguities = &.{};
    }

    pub fn bindTargetGeneration(self: *Owned, target_generation: []const u8) !void {
        if (target_generation.len == 0 or self.value.target_generation.len != 0) return error.InvalidLineageTarget;
        const target = try memory.copy(u8, self.allocator, target_generation);
        errdefer {
            for (self.value.records) |*record| if (std.mem.eql(u8, record.successor_generation, target_generation)) {
                self.allocator.free(record.successor_generation);
                record.successor_generation = &.{};
            };
            for (self.value.ambiguities) |*ambiguity| if (std.mem.eql(u8, ambiguity.successor_generation, target_generation)) {
                self.allocator.free(ambiguity.successor_generation);
                ambiguity.successor_generation = &.{};
            };
            self.value.target_generation = &.{};
            self.allocator.free(target);
        }
        for (self.value.records) |*record| if (record.successor_generation.len == 0) {
            record.successor_generation = try memory.copy(u8, self.allocator, target_generation);
        };
        for (self.value.ambiguities) |*ambiguity| if (ambiguity.successor_generation.len == 0) {
            ambiguity.successor_generation = try memory.copy(u8, self.allocator, target_generation);
        };
        self.value.target_generation = target;
        const fingerprint = try artifactFingerprintAlloc(self.allocator, self.value);
        errdefer self.allocator.free(fingerprint);
        var candidate = self.value;
        candidate.fingerprint = fingerprint;
        try validate(self.allocator, candidate);
        self.allocator.free(self.value.fingerprint);
        self.value.fingerprint = fingerprint;
    }
};

const Candidate = struct {
    record: *const discovery.Record,
};

const InputRecord = struct {
    id: []const u8,
    relation: Relation,
    evidence: Evidence,
    provenance: Provenance,
    predecessor_generation: []const u8,
    predecessor_path: []const u8,
    successor_path: []const u8,
    predecessor_node_id: u64,
    successor_node_id: u64,
    content_digest: []const u8,
    classification: discovery.Classification,
};

const InputAmbiguity = struct {
    id: []const u8,
    evidence: Evidence,
    predecessor_generation: []const u8,
    content_digest: []const u8,
    classification: discovery.Classification,
    predecessor_paths: []const []const u8,
    successor_paths: []const []const u8,
};

const InputFingerprintPayload = struct {
    schema: []const u8 = schema,
    schema_version: u32 = schema_version,
    repository_id: []const u8,
    records: []const InputRecord,
    ambiguities: []const InputAmbiguity,
};

const ArtifactFingerprintPayload = struct {
    schema: []const u8 = schema,
    schema_version: u32 = schema_version,
    repository_id: []const u8,
    parent_generation: []const u8,
    target_generation: []const u8,
    input_fingerprint: []const u8,
    summary: Summary,
    records: []const Record,
    ambiguities: []const Ambiguity,
    complete: bool = true,
};

pub fn reconcile(
    allocator: std.mem.Allocator,
    repository_id: []const u8,
    parent_generation: []const u8,
    previous: ?Artifact,
    previous_records: []const discovery.Record,
    current: *const discovery.Result,
    max_history_records: usize,
) !Owned {
    if (max_history_records == 0) return error.InvalidLineageBound;
    var records: std.ArrayList(Record) = .empty;
    errdefer {
        for (records.items) |record| freeRecord(allocator, record);
        records.deinit(allocator);
    }
    var ambiguities: std.ArrayList(Ambiguity) = .empty;
    errdefer {
        for (ambiguities.items) |ambiguity| freeAmbiguity(allocator, ambiguity);
        ambiguities.deinit(allocator);
    }
    if (previous) |artifact| {
        for (artifact.records) |record| try records.append(allocator, try cloneRecord(allocator, record));
        for (artifact.ambiguities) |ambiguity| try ambiguities.append(allocator, try cloneAmbiguity(allocator, ambiguity));
    }

    var removed: std.ArrayList(Candidate) = .empty;
    defer removed.deinit(allocator);
    for (previous_records) |*record| {
        if (!graphBearing(record.disposition) or record.content_digest == null or record.relative_path.len == 0) continue;
        if (current.findByPath(record.relative_path) == null) try removed.append(allocator, .{ .record = record });
    }
    var added: std.ArrayList(Candidate) = .empty;
    defer added.deinit(allocator);
    for (current.records) |*record| {
        if (!graphBearing(record.disposition) or record.content_digest == null or record.relative_path.len == 0) continue;
        if (findRecord(previous_records, record.relative_path) == null) try added.append(allocator, .{ .record = record });
    }
    std.mem.sort(Candidate, removed.items, {}, candidateLessThan);
    std.mem.sort(Candidate, added.items, {}, candidateLessThan);

    var removed_index: usize = 0;
    var added_index: usize = 0;
    while (removed_index < removed.items.len and added_index < added.items.len) {
        const ordering = compareCandidateKey(removed.items[removed_index], added.items[added_index]);
        if (ordering == .lt) {
            removed_index = groupEnd(removed.items, removed_index);
            continue;
        }
        if (ordering == .gt) {
            added_index = groupEnd(added.items, added_index);
            continue;
        }
        const removed_end = groupEnd(removed.items, removed_index);
        const added_end = groupEnd(added.items, added_index);
        const old_group = removed.items[removed_index..removed_end];
        const new_group = added.items[added_index..added_end];
        if (old_group.len == 1 and new_group.len == 1) {
            if (records.items.len >= max_history_records) return error.LineageHistoryLimitExceeded;
            try records.append(allocator, try makeRecord(allocator, parent_generation, old_group[0].record, new_group[0].record));
        } else {
            if (ambiguities.items.len >= max_history_records) return error.LineageHistoryLimitExceeded;
            try ambiguities.append(allocator, try makeAmbiguity(allocator, parent_generation, old_group, new_group));
        }
        removed_index = removed_end;
        added_index = added_end;
    }
    std.mem.sort(Record, records.items, {}, recordLessThan);
    std.mem.sort(Ambiguity, ambiguities.items, {}, ambiguityLessThan);
    try rejectDuplicateIds(records.items, ambiguities.items);
    if (records.items.len + ambiguities.items.len > max_history_records) return error.LineageHistoryLimitExceeded;

    const owned_repository_id = try memory.copy(u8, allocator, repository_id);
    errdefer allocator.free(owned_repository_id);
    const owned_parent = try memory.copy(u8, allocator, parent_generation);
    errdefer allocator.free(owned_parent);
    const empty_target = try memory.copy(u8, allocator, "");
    errdefer allocator.free(empty_target);
    const empty_fingerprint = try memory.copy(u8, allocator, "");
    errdefer allocator.free(empty_fingerprint);
    const record_slice = try records.toOwnedSlice(allocator);
    errdefer {
        for (record_slice) |record| freeRecord(allocator, record);
        allocator.free(record_slice);
    }
    const ambiguity_slice = try ambiguities.toOwnedSlice(allocator);
    errdefer {
        for (ambiguity_slice) |ambiguity| freeAmbiguity(allocator, ambiguity);
        allocator.free(ambiguity_slice);
    }
    var result = Owned{
        .allocator = allocator,
        .value = .{
            .repository_id = owned_repository_id,
            .parent_generation = owned_parent,
            .target_generation = empty_target,
            .input_fingerprint = empty_fingerprint,
            .fingerprint = try memory.copy(u8, allocator, ""),
            .summary = summarize(record_slice, ambiguity_slice),
            .records = record_slice,
            .ambiguities = ambiguity_slice,
        },
    };
    errdefer result.deinit();
    const input_fingerprint = try inputFingerprintAlloc(allocator, result.value);
    allocator.free(result.value.input_fingerprint);
    result.value.input_fingerprint = input_fingerprint;
    return result;
}

pub fn encodeAlloc(allocator: std.mem.Allocator, artifact: Artifact) ![]u8 {
    try validate(allocator, artifact);
    const bytes = try std.json.Stringify.valueAlloc(allocator, artifact, .{ .whitespace = .indent_2 });
    if (bytes.len > max_artifact_bytes) {
        allocator.free(bytes);
        return error.ChangeLineageTooLarge;
    }
    return bytes;
}

pub fn read(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    path: []const u8,
) !std.json.Parsed(Artifact) {
    const bytes = try root.readFileAlloc(io, path, allocator, .limited(max_artifact_bytes));
    defer allocator.free(bytes);
    var parsed = std.json.parseFromSlice(Artifact, allocator, bytes, .{ .allocate = .alloc_always }) catch return error.CorruptChangeLineage;
    errdefer parsed.deinit();
    try validate(allocator, parsed.value);
    return parsed;
}

pub fn validate(allocator: std.mem.Allocator, artifact: Artifact) !void {
    if (!artifact.complete or !std.mem.eql(u8, artifact.schema, schema) or artifact.schema_version != schema_version or
        artifact.repository_id.len == 0 or artifact.target_generation.len == 0 or artifact.input_fingerprint.len != 71 or
        artifact.fingerprint.len != 71)
    {
        return error.IncompatibleChangeLineage;
    }
    if (!std.meta.eql(artifact.summary, summarize(artifact.records, artifact.ambiguities))) return error.ChangeLineageSummaryMismatch;
    var previous_id: []const u8 = "";
    for (artifact.records) |record| {
        try validateRecord(allocator, record);
        if (previous_id.len > 0 and std.mem.order(u8, previous_id, record.id) != .lt) return error.ChangeLineageOrderMismatch;
        previous_id = record.id;
    }
    previous_id = "";
    for (artifact.ambiguities) |ambiguity| {
        try validateAmbiguity(allocator, ambiguity);
        if (previous_id.len > 0 and std.mem.order(u8, previous_id, ambiguity.id) != .lt) return error.ChangeLineageOrderMismatch;
        previous_id = ambiguity.id;
    }
    try rejectDuplicateIds(artifact.records, artifact.ambiguities);
    const expected_input = try inputFingerprintAlloc(allocator, artifact);
    defer allocator.free(expected_input);
    if (!std.mem.eql(u8, expected_input, artifact.input_fingerprint)) return error.ChangeLineageInputFingerprintMismatch;
    const expected = try artifactFingerprintAlloc(allocator, artifact);
    defer allocator.free(expected);
    if (!std.mem.eql(u8, expected, artifact.fingerprint)) return error.ChangeLineageFingerprintMismatch;
}

fn graphBearing(disposition: discovery.Disposition) bool {
    return disposition == .deeply_indexed or disposition == .placed_unsupported or disposition == .placed_asset;
}

fn findRecord(records: []const discovery.Record, path: []const u8) ?*const discovery.Record {
    for (records) |*record| if (std.mem.eql(u8, record.relative_path, path)) return record;
    return null;
}

fn candidateLessThan(_: void, left: Candidate, right: Candidate) bool {
    return compareCandidate(left, right) == .lt;
}

fn compareCandidate(left: Candidate, right: Candidate) std.math.Order {
    const key_order = compareCandidateKey(left, right);
    if (key_order != .eq) return key_order;
    return std.mem.order(u8, left.record.relative_path, right.record.relative_path);
}

fn compareCandidateKey(left: Candidate, right: Candidate) std.math.Order {
    const digest_order = std.mem.order(u8, &left.record.content_digest.?, &right.record.content_digest.?);
    if (digest_order != .eq) return digest_order;
    return compareClassification(left.record.classification, right.record.classification);
}

fn compareClassification(left: discovery.Classification, right: discovery.Classification) std.math.Order {
    const left_language = @intFromEnum(left.language);
    const right_language = @intFromEnum(right.language);
    if (left_language < right_language) return .lt;
    if (left_language > right_language) return .gt;

    const left_artifact = @intFromEnum(left.artifact);
    const right_artifact = @intFromEnum(right.artifact);
    if (left_artifact < right_artifact) return .lt;
    if (left_artifact > right_artifact) return .gt;

    inline for (.{ "is_test", "is_fixture", "is_generated", "is_vendored", "is_archived" }) |field| {
        const left_value = @field(left, field);
        const right_value = @field(right, field);
        const left_int = @intFromBool(left_value);
        const right_int = @intFromBool(right_value);
        if (left_int < right_int) return .lt;
        if (left_int > right_int) return .gt;
    }
    return .eq;
}

fn groupEnd(items: []const Candidate, start: usize) usize {
    var end = start + 1;
    while (end < items.len and compareCandidateKey(items[start], items[end]) == .eq) : (end += 1) {}
    return end;
}

fn makeRecord(
    allocator: std.mem.Allocator,
    parent_generation: []const u8,
    predecessor: *const discovery.Record,
    successor: *const discovery.Record,
) !Record {
    const predecessor_parent = std.fs.path.dirname(predecessor.relative_path) orelse "";
    const successor_parent = std.fs.path.dirname(successor.relative_path) orelse "";
    const relation: Relation = if (std.mem.eql(u8, predecessor_parent, successor_parent)) .renamed_from else .moved_from;
    const digest_hex = std.fmt.bytesToHex(predecessor.content_digest.?, .lower);
    const predecessor_path = try memory.copy(u8, allocator, predecessor.relative_path);
    errdefer allocator.free(predecessor_path);
    const successor_path = try memory.copy(u8, allocator, successor.relative_path);
    errdefer allocator.free(successor_path);
    const predecessor_generation = try memory.copy(u8, allocator, parent_generation);
    errdefer allocator.free(predecessor_generation);
    const successor_generation = try memory.copy(u8, allocator, "");
    errdefer allocator.free(successor_generation);
    const content_digest = try memory.copy(u8, allocator, &digest_hex);
    errdefer allocator.free(content_digest);
    const id = try recordIdAlloc(allocator, relation, parent_generation, predecessor.relative_path, successor.relative_path, &digest_hex);
    errdefer allocator.free(id);
    return .{
        .id = id,
        .relation = relation,
        .predecessor_generation = predecessor_generation,
        .successor_generation = successor_generation,
        .predecessor_path = predecessor_path,
        .successor_path = successor_path,
        .predecessor_node_id = model.stableId(.file, predecessor.relative_path, std.fs.path.basename(predecessor.relative_path)),
        .successor_node_id = model.stableId(.file, successor.relative_path, std.fs.path.basename(successor.relative_path)),
        .content_digest = content_digest,
        .classification = predecessor.classification,
    };
}

fn makeAmbiguity(
    allocator: std.mem.Allocator,
    parent_generation: []const u8,
    predecessors: []const Candidate,
    successors: []const Candidate,
) !Ambiguity {
    const digest_hex = std.fmt.bytesToHex(predecessors[0].record.content_digest.?, .lower);
    const predecessor_paths = try cloneCandidatePaths(allocator, predecessors);
    errdefer freePaths(allocator, predecessor_paths);
    const successor_paths = try cloneCandidatePaths(allocator, successors);
    errdefer freePaths(allocator, successor_paths);
    const predecessor_generation = try memory.copy(u8, allocator, parent_generation);
    errdefer allocator.free(predecessor_generation);
    const successor_generation = try memory.copy(u8, allocator, "");
    errdefer allocator.free(successor_generation);
    const content_digest = try memory.copy(u8, allocator, &digest_hex);
    errdefer allocator.free(content_digest);
    const id = try ambiguityIdAlloc(allocator, parent_generation, &digest_hex, predecessor_paths, successor_paths);
    errdefer allocator.free(id);
    return .{
        .id = id,
        .predecessor_generation = predecessor_generation,
        .successor_generation = successor_generation,
        .content_digest = content_digest,
        .classification = predecessors[0].record.classification,
        .predecessor_paths = predecessor_paths,
        .successor_paths = successor_paths,
    };
}

fn cloneCandidatePaths(allocator: std.mem.Allocator, candidates: []const Candidate) ![][]const u8 {
    const paths = try memory.slice([]const u8, allocator, candidates.len);
    errdefer allocator.free(paths);
    var initialized: usize = 0;
    errdefer for (paths[0..initialized]) |path| allocator.free(path);
    for (candidates, 0..) |candidate, index| {
        paths[index] = try memory.copy(u8, allocator, candidate.record.relative_path);
        initialized += 1;
    }
    return paths;
}

fn cloneRecord(allocator: std.mem.Allocator, source: Record) !Record {
    var result = source;
    result.id = try memory.copy(u8, allocator, source.id);
    errdefer allocator.free(result.id);
    result.predecessor_generation = try memory.copy(u8, allocator, source.predecessor_generation);
    errdefer allocator.free(result.predecessor_generation);
    result.successor_generation = try memory.copy(u8, allocator, source.successor_generation);
    errdefer allocator.free(result.successor_generation);
    result.predecessor_path = try memory.copy(u8, allocator, source.predecessor_path);
    errdefer allocator.free(result.predecessor_path);
    result.successor_path = try memory.copy(u8, allocator, source.successor_path);
    errdefer allocator.free(result.successor_path);
    result.content_digest = try memory.copy(u8, allocator, source.content_digest);
    return result;
}

fn cloneAmbiguity(allocator: std.mem.Allocator, source: Ambiguity) !Ambiguity {
    var result = source;
    result.id = try memory.copy(u8, allocator, source.id);
    errdefer allocator.free(result.id);
    result.predecessor_generation = try memory.copy(u8, allocator, source.predecessor_generation);
    errdefer allocator.free(result.predecessor_generation);
    result.successor_generation = try memory.copy(u8, allocator, source.successor_generation);
    errdefer allocator.free(result.successor_generation);
    result.content_digest = try memory.copy(u8, allocator, source.content_digest);
    errdefer allocator.free(result.content_digest);
    result.predecessor_paths = try clonePaths(allocator, source.predecessor_paths);
    errdefer freePaths(allocator, result.predecessor_paths);
    result.successor_paths = try clonePaths(allocator, source.successor_paths);
    return result;
}

fn clonePaths(allocator: std.mem.Allocator, source: []const []const u8) ![][]const u8 {
    const paths = try memory.slice([]const u8, allocator, source.len);
    errdefer allocator.free(paths);
    var initialized: usize = 0;
    errdefer for (paths[0..initialized]) |path| allocator.free(path);
    for (source, 0..) |path, index| {
        paths[index] = try memory.copy(u8, allocator, path);
        initialized += 1;
    }
    return paths;
}

fn freeRecord(allocator: std.mem.Allocator, record: Record) void {
    allocator.free(record.id);
    allocator.free(record.predecessor_generation);
    allocator.free(record.successor_generation);
    allocator.free(record.predecessor_path);
    allocator.free(record.successor_path);
    allocator.free(record.content_digest);
}

fn freeAmbiguity(allocator: std.mem.Allocator, ambiguity: Ambiguity) void {
    allocator.free(ambiguity.id);
    allocator.free(ambiguity.predecessor_generation);
    allocator.free(ambiguity.successor_generation);
    allocator.free(ambiguity.content_digest);
    freePaths(allocator, ambiguity.predecessor_paths);
    freePaths(allocator, ambiguity.successor_paths);
}

fn freePaths(allocator: std.mem.Allocator, paths: []const []const u8) void {
    for (paths) |path| allocator.free(path);
    allocator.free(paths);
}

fn recordLessThan(_: void, left: Record, right: Record) bool {
    return std.mem.order(u8, left.id, right.id) == .lt;
}

fn ambiguityLessThan(_: void, left: Ambiguity, right: Ambiguity) bool {
    return std.mem.order(u8, left.id, right.id) == .lt;
}

fn rejectDuplicateIds(records: []const Record, ambiguities: []const Ambiguity) !void {
    for (records, 0..) |record, index| {
        if (index > 0 and std.mem.eql(u8, records[index - 1].id, record.id)) return error.DuplicateLineageRecord;
    }
    for (ambiguities, 0..) |ambiguity, index| {
        if (index > 0 and std.mem.eql(u8, ambiguities[index - 1].id, ambiguity.id)) return error.DuplicateLineageAmbiguity;
    }
}

fn summarize(records: []const Record, ambiguities: []const Ambiguity) Summary {
    var summary = Summary{ .records = records.len, .ambiguous_groups = ambiguities.len };
    for (records) |record| switch (record.relation) {
        .renamed_from => summary.renamed += 1,
        .moved_from => summary.moved += 1,
    };
    for (ambiguities) |ambiguity| {
        summary.ambiguous_predecessors += ambiguity.predecessor_paths.len;
        summary.ambiguous_successors += ambiguity.successor_paths.len;
    }
    return summary;
}

fn validateRecord(allocator: std.mem.Allocator, record: Record) !void {
    if (record.id.len != 71 or record.predecessor_generation.len == 0 or record.successor_generation.len == 0 or
        record.predecessor_path.len == 0 or record.successor_path.len == 0 or record.content_digest.len != 64 or
        std.mem.eql(u8, record.predecessor_path, record.successor_path))
    {
        return error.InvalidLineageRecord;
    }
    const expected_predecessor = model.stableId(.file, record.predecessor_path, std.fs.path.basename(record.predecessor_path));
    const expected_successor = model.stableId(.file, record.successor_path, std.fs.path.basename(record.successor_path));
    if (record.predecessor_node_id != expected_predecessor or record.successor_node_id != expected_successor) return error.InvalidLineageNodeIdentity;
    const predecessor_parent = std.fs.path.dirname(record.predecessor_path) orelse "";
    const successor_parent = std.fs.path.dirname(record.successor_path) orelse "";
    const expected_relation: Relation = if (std.mem.eql(u8, predecessor_parent, successor_parent)) .renamed_from else .moved_from;
    if (record.relation != expected_relation or !validRelativePath(record.predecessor_path) or !validRelativePath(record.successor_path) or
        !validHexDigest(record.content_digest)) return error.InvalidLineageRecord;
    const expected = try recordIdAlloc(allocator, record.relation, record.predecessor_generation, record.predecessor_path, record.successor_path, record.content_digest);
    defer allocator.free(expected);
    if (!std.mem.eql(u8, expected, record.id)) return error.InvalidLineageRecordIdentity;
}

fn validateAmbiguity(allocator: std.mem.Allocator, ambiguity: Ambiguity) !void {
    if (ambiguity.id.len != 71 or ambiguity.predecessor_generation.len == 0 or ambiguity.successor_generation.len == 0 or
        ambiguity.content_digest.len != 64 or ambiguity.predecessor_paths.len == 0 or ambiguity.successor_paths.len == 0 or
        (ambiguity.predecessor_paths.len == 1 and ambiguity.successor_paths.len == 1))
    {
        return error.InvalidLineageAmbiguity;
    }
    if (!validHexDigest(ambiguity.content_digest) or !sortedUniquePaths(ambiguity.predecessor_paths) or
        !sortedUniquePaths(ambiguity.successor_paths)) return error.InvalidLineageAmbiguityPaths;
    const expected = try ambiguityIdAlloc(allocator, ambiguity.predecessor_generation, ambiguity.content_digest, ambiguity.predecessor_paths, ambiguity.successor_paths);
    defer allocator.free(expected);
    if (!std.mem.eql(u8, expected, ambiguity.id)) return error.InvalidLineageAmbiguityIdentity;
}

fn sortedUniquePaths(paths: []const []const u8) bool {
    for (paths, 0..) |path, index| {
        if (!validRelativePath(path)) return false;
        if (index > 0 and std.mem.order(u8, paths[index - 1], path) != .lt) return false;
    }
    return true;
}

fn validRelativePath(path: []const u8) bool {
    return path.len > 0 and path.len <= std.fs.max_path_bytes and !std.fs.path.isAbsolute(path) and
        std.mem.indexOfScalar(u8, path, '\\') == null and std.mem.indexOfScalar(u8, path, 0) == null and
        !std.mem.eql(u8, path, "..") and !std.mem.startsWith(u8, path, "../") and
        std.mem.indexOf(u8, path, "/../") == null and !std.mem.endsWith(u8, path, "/..");
}

fn validHexDigest(value: []const u8) bool {
    if (value.len != 64) return false;
    for (value) |byte| if (!std.ascii.isDigit(byte) and !(byte >= 'a' and byte <= 'f')) return false;
    return true;
}

fn recordIdAlloc(
    allocator: std.mem.Allocator,
    relation: Relation,
    predecessor_generation: []const u8,
    predecessor_path: []const u8,
    successor_path: []const u8,
    content_digest: []const u8,
) ![]u8 {
    const payload = .{
        .domain = "zgraphy-lineage-record-v1",
        .relation = relation,
        .predecessor_generation = predecessor_generation,
        .predecessor_path = predecessor_path,
        .successor_path = successor_path,
        .content_digest = content_digest,
    };
    const bytes = try std.json.Stringify.valueAlloc(allocator, payload, .{});
    defer allocator.free(bytes);
    return sha256IdentityAlloc(allocator, bytes);
}

fn ambiguityIdAlloc(
    allocator: std.mem.Allocator,
    predecessor_generation: []const u8,
    content_digest: []const u8,
    predecessor_paths: []const []const u8,
    successor_paths: []const []const u8,
) ![]u8 {
    const payload = .{
        .domain = "zgraphy-lineage-ambiguity-v1",
        .predecessor_generation = predecessor_generation,
        .content_digest = content_digest,
        .predecessor_paths = predecessor_paths,
        .successor_paths = successor_paths,
    };
    const bytes = try std.json.Stringify.valueAlloc(allocator, payload, .{});
    defer allocator.free(bytes);
    return sha256IdentityAlloc(allocator, bytes);
}

fn inputFingerprintAlloc(allocator: std.mem.Allocator, artifact: Artifact) ![]u8 {
    const input_records = try memory.slice(InputRecord, allocator, artifact.records.len);
    defer allocator.free(input_records);
    for (artifact.records, 0..) |record, index| input_records[index] = .{
        .id = record.id,
        .relation = record.relation,
        .evidence = record.evidence,
        .provenance = record.provenance,
        .predecessor_generation = record.predecessor_generation,
        .predecessor_path = record.predecessor_path,
        .successor_path = record.successor_path,
        .predecessor_node_id = record.predecessor_node_id,
        .successor_node_id = record.successor_node_id,
        .content_digest = record.content_digest,
        .classification = record.classification,
    };
    const input_ambiguities = try memory.slice(InputAmbiguity, allocator, artifact.ambiguities.len);
    defer allocator.free(input_ambiguities);
    for (artifact.ambiguities, 0..) |ambiguity, index| input_ambiguities[index] = .{
        .id = ambiguity.id,
        .evidence = ambiguity.evidence,
        .predecessor_generation = ambiguity.predecessor_generation,
        .content_digest = ambiguity.content_digest,
        .classification = ambiguity.classification,
        .predecessor_paths = ambiguity.predecessor_paths,
        .successor_paths = ambiguity.successor_paths,
    };
    const payload = InputFingerprintPayload{
        .repository_id = artifact.repository_id,
        .records = input_records,
        .ambiguities = input_ambiguities,
    };
    const bytes = try std.json.Stringify.valueAlloc(allocator, payload, .{});
    defer allocator.free(bytes);
    return sha256IdentityAlloc(allocator, bytes);
}

fn artifactFingerprintAlloc(allocator: std.mem.Allocator, artifact: Artifact) ![]u8 {
    const payload = ArtifactFingerprintPayload{
        .repository_id = artifact.repository_id,
        .parent_generation = artifact.parent_generation,
        .target_generation = artifact.target_generation,
        .input_fingerprint = artifact.input_fingerprint,
        .summary = artifact.summary,
        .records = artifact.records,
        .ambiguities = artifact.ambiguities,
    };
    const bytes = try std.json.Stringify.valueAlloc(allocator, payload, .{});
    defer allocator.free(bytes);
    return sha256IdentityAlloc(allocator, bytes);
}

fn sha256IdentityAlloc(allocator: std.mem.Allocator, bytes: []const u8) ![]u8 {
    var digest = [_]u8{0} ** 32;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    const hex = std.fmt.bytesToHex(digest, .lower);
    return std.fmt.allocPrint(allocator, "sha256:{s}", .{hex});
}
