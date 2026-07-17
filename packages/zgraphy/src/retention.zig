const std = @import("std");
const extraction_cache = @import("extraction_cache.zig");
const owned = @import("memory.zig");

pub const schema = "zgraphy.retention-report.v1";
pub const pins_schema = "zgraphy.retention-pins.v1";
pub const schema_version: u32 = 1;
pub const pins_path = ".zgraphy/retention-pins.json";
pub const latest_path = ".zgraphy/runtime/gc/latest.json";
pub const generation_root = ".zgraphy/generations";
pub const max_pins: usize = 128;
pub const max_pins_bytes: usize = 64 * 1024;
pub const max_report_bytes: usize = 8 * 1024 * 1024;
pub const max_generation_metadata_bytes: usize = 1024 * 1024;
pub const max_generation_entries: usize = 4096;
pub const max_cache_entries: usize = 1_000_000;
pub const max_actions: usize = max_generation_entries + max_cache_entries + 256;

pub const Mode = enum {
    dry_run,
    apply,
};

pub const Status = enum {
    never_run,
    planned,
    applied,
    deferred_readers,
    disabled,
    failed,
};

pub const ActionKind = enum {
    generation,
    cache_entry,
    cache_namespace,
};

pub const Reason = enum {
    unretained_generation,
    abandoned_generation,
    unreferenced_cache,
    obsolete_structural_recipe,
};

pub const Policy = struct {
    automatic_gc: bool = true,
    retention_generations: usize = 8,
    retention_grace_ms: u64 = 5 * 60 * 1000,
    max_generation_entries: usize = max_generation_entries,
    max_cache_entries: usize = max_cache_entries,
    max_pins: usize = max_pins,

    pub fn validate(self: Policy) !void {
        if (self.retention_generations < 2 or self.retention_generations > 128 or
            self.retention_grace_ms > 30 * 24 * 60 * 60 * 1000 or
            self.max_generation_entries == 0 or self.max_generation_entries > max_generation_entries or
            self.max_cache_entries == 0 or self.max_cache_entries > max_cache_entries or
            self.max_pins == 0 or self.max_pins > max_pins)
        {
            return error.InvalidRetentionPolicy;
        }
    }
};

pub const Input = struct {
    repository_id: []const u8,
    active_generation: []const u8,
    active_semantic: []const u8,
    active_parent: []const u8,
    active_replaces: []const u8,
    generation_schema: []const u8,
    generation_schema_version: u32,
    policy: Policy,
    now_ms: u64,
};

pub const Action = struct {
    kind: ActionKind,
    identity: []const u8,
    reason: Reason,
    eligible: bool,
    tombstones: usize = 0,
    applied: bool = false,
};

pub const Summary = struct {
    status: Status = .never_run,
    scanned_generation_entries: usize = 0,
    valid_generations: usize = 0,
    retained_generations: usize = 0,
    pinned_generations: usize = 0,
    generation_candidates: usize = 0,
    cache_entries_scanned: usize = 0,
    cache_candidates: usize = 0,
    obsolete_namespaces: usize = 0,
    grace_deferred: usize = 0,
    reader_deferred: usize = 0,
    generations_deleted: usize = 0,
    journals_compacted: usize = 0,
    tombstones_compacted: usize = 0,
    cache_entries_deleted: usize = 0,
    namespaces_deleted: usize = 0,
    already_absent: usize = 0,
    failed_actions: usize = 0,
    preserved_unknown: usize = 0,
    preserved_symlinks: usize = 0,
    migration_references: usize = 0,
    resumable_job_references: usize = 0,
};

pub const Report = struct {
    allocator: std.mem.Allocator,
    repository_id: []const u8,
    active_generation: []const u8,
    policy: Policy,
    observed_at_ms: u64,
    plan_fingerprint: [32]u8,
    actions: []Action,
    summary: Summary,

    pub fn deinit(self: *Report) void {
        self.allocator.free(self.repository_id);
        self.allocator.free(self.active_generation);
        for (self.actions) |action| self.allocator.free(action.identity);
        self.allocator.free(self.actions);
        self.repository_id = &.{};
        self.active_generation = &.{};
        self.actions = &.{};
    }
};

const PinsData = struct {
    schema: []const u8,
    schema_version: u32,
    repository_id: []const u8,
    generations: []const []const u8,
    fingerprint: []const u8,
    complete: bool,
};

const Pins = struct {
    allocator: std.mem.Allocator,
    generations: []const []const u8,

    fn deinit(self: *Pins) void {
        for (self.generations) |generation| self.allocator.free(generation);
        self.allocator.free(self.generations);
        self.generations = &.{};
    }
};

const DeltaSummary = struct {
    tombstones: usize = 0,
};

const GenerationHeader = struct {
    schema: []const u8,
    schema_version: u32,
    repository_id: []const u8,
    generation: []const u8,
    semantic_generation: []const u8,
    parent_generation: []const u8,
    replaces_generation: []const u8,
    extraction_manifest_digest: []const u8,
    delta_summary: DeltaSummary = .{},
    complete: bool,
};

const Generation = struct {
    allocator: std.mem.Allocator,
    id: []const u8,
    semantic: []const u8,
    parent: []const u8,
    replaces: []const u8,
    modified_ms: u64,
    tombstones: usize,
    valid: bool,
    keep: bool = false,

    fn deinit(self: *Generation) void {
        self.allocator.free(self.id);
        if (self.semantic.len > 0) self.allocator.free(self.semantic);
        if (self.parent.len > 0) self.allocator.free(self.parent);
        if (self.replaces.len > 0) self.allocator.free(self.replaces);
        self.id = &.{};
        self.semantic = &.{};
        self.parent = &.{};
        self.replaces = &.{};
    }
};

const LatestData = struct {
    schema: []const u8,
    schema_version: u32,
    repository_id: []const u8,
    active_generation: []const u8,
    plan_fingerprint: []const u8,
    receipt_fingerprint: []const u8,
    summary: Summary,
    complete: bool,
};

pub fn plan(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    input: Input,
) !Report {
    try input.policy.validate();
    if (!validRepositoryId(input.repository_id) or !validGenerationId(input.active_generation) or !validGenerationId(input.active_semantic) or
        (input.active_parent.len > 0 and !validGenerationId(input.active_parent)) or
        (input.active_replaces.len > 0 and !validGenerationId(input.active_replaces)) or
        input.generation_schema.len == 0 or input.generation_schema_version == 0)
    {
        return error.InvalidRetentionInput;
    }

    var generations: std.ArrayList(Generation) = .empty;
    defer {
        for (generations.items) |*generation| generation.deinit();
        generations.deinit(allocator);
    }
    var summary = Summary{ .status = .planned };
    try scanGenerations(allocator, io, root, input, &generations, &summary);
    std.mem.sort(Generation, generations.items, {}, generationLessThan);

    const active_index = findGeneration(generations.items, input.active_generation) orelse return error.ActiveGenerationMissingFromRetentionInventory;
    if (!generations.items[active_index].valid) return error.InvalidActiveRetentionGeneration;
    if (!std.mem.eql(u8, generations.items[active_index].semantic, input.active_semantic) or
        !std.mem.eql(u8, generations.items[active_index].parent, input.active_parent) or
        !std.mem.eql(u8, generations.items[active_index].replaces, input.active_replaces))
    {
        return error.ActiveRetentionBindingMismatch;
    }
    var history_index: ?usize = active_index;
    var recent: usize = 0;
    while (history_index != null and recent < input.policy.retention_generations) : (recent += 1) {
        const index = history_index.?;
        generations.items[index].keep = true;
        const parent = generations.items[index].parent;
        history_index = if (parent.len == 0) null else findGeneration(generations.items, parent);
    }

    var pins = try readPins(allocator, io, root, input.repository_id, input.policy.max_pins);
    defer pins.deinit();
    summary.pinned_generations = pins.generations.len;
    for (pins.generations) |pin| {
        const index = findGeneration(generations.items, pin) orelse return error.PinnedGenerationMissing;
        if (!generations.items[index].valid) return error.InvalidPinnedGeneration;
        generations.items[index].keep = true;
        markDependency(generations.items, generations.items[index].parent);
        markDependency(generations.items, generations.items[index].replaces);
    }

    if (input.active_parent.len > 0) {
        const index = findGeneration(generations.items, input.active_parent) orelse return error.ActiveFallbackGenerationMissing;
        if (!generations.items[index].valid) return error.InvalidActiveFallbackGeneration;
        generations.items[index].keep = true;
    }
    if (input.active_replaces.len > 0) {
        const index = findGeneration(generations.items, input.active_replaces) orelse return error.ActiveReplacementGenerationMissing;
        generations.items[index].keep = true;
    }
    for (generations.items) |generation| {
        if (!generation.keep or std.mem.eql(u8, generation.semantic, generation.id)) continue;
        const index = findGeneration(generations.items, generation.semantic) orelse return error.SemanticGenerationMissing;
        if (!generations.items[index].valid) return error.InvalidSemanticGeneration;
        generations.items[index].keep = true;
    }
    var live_keys: std.ArrayList([]const u8) = .empty;
    defer deinitStrings(allocator, &live_keys);
    for (generations.items) |generation| {
        if (!generation.keep) continue;
        summary.retained_generations += 1;
        const manifest_path = try std.fmt.allocPrint(allocator, "{s}/{s}/extraction-manifest.json", .{ generation_root, generation.id });
        defer allocator.free(manifest_path);
        var manifest = extraction_cache.readManifest(allocator, io, root, manifest_path) catch return error.RetainedExtractionManifestUnavailable;
        defer manifest.deinit();
        for (manifest.units) |unit| try appendUniqueString(allocator, &live_keys, unit.cache_key);
    }
    std.mem.sort([]const u8, live_keys.items, {}, stringLessThan);

    var actions: std.ArrayList(Action) = .empty;
    errdefer deinitActions(allocator, &actions);
    for (generations.items) |generation| {
        if (generation.keep) continue;
        const eligible = graceElapsed(input.now_ms, generation.modified_ms, input.policy.retention_grace_ms);
        try appendAction(allocator, &actions, .{
            .kind = .generation,
            .identity = generation.id,
            .reason = if (generation.valid) .unretained_generation else .abandoned_generation,
            .eligible = eligible,
            .tombstones = generation.tombstones,
        });
        summary.generation_candidates += @intFromBool(eligible);
        summary.grace_deferred += @intFromBool(!eligible);
    }
    try scanCache(allocator, io, root, input, live_keys.items, &actions, &summary);
    std.mem.sort(Action, actions.items, {}, actionLessThan);

    const repository_id = try owned.copy(u8, allocator, input.repository_id);
    errdefer allocator.free(repository_id);
    const active_generation = try owned.copy(u8, allocator, input.active_generation);
    errdefer allocator.free(active_generation);
    const action_slice = try actions.toOwnedSlice(allocator);
    errdefer {
        for (action_slice) |action| allocator.free(action.identity);
        allocator.free(action_slice);
    }
    const fingerprint = planFingerprint(input, action_slice);
    return .{
        .allocator = allocator,
        .repository_id = repository_id,
        .active_generation = active_generation,
        .policy = input.policy,
        .observed_at_ms = input.now_ms,
        .plan_fingerprint = fingerprint,
        .actions = action_slice,
        .summary = summary,
    };
}

pub fn apply(io: std.Io, root: std.Io.Dir, report: *Report) void {
    for (report.actions) |*action| {
        if (!action.eligible) continue;
        switch (action.kind) {
            .generation => {
                if (!validGenerationId(action.identity)) {
                    report.summary.failed_actions += 1;
                    continue;
                }
                const path = std.fmt.allocPrint(report.allocator, "{s}/{s}", .{ generation_root, action.identity }) catch {
                    report.summary.failed_actions += 1;
                    continue;
                };
                defer report.allocator.free(path);
                root.deleteTree(io, path) catch {
                    report.summary.failed_actions += 1;
                    continue;
                };
                action.applied = true;
                report.summary.generations_deleted += 1;
                report.summary.journals_compacted += 1;
                report.summary.tombstones_compacted = std.math.add(usize, report.summary.tombstones_compacted, action.tombstones) catch std.math.maxInt(usize);
            },
            .cache_entry => {
                const path = extraction_cache.entryPathAlloc(report.allocator, action.identity) catch {
                    report.summary.failed_actions += 1;
                    continue;
                };
                defer report.allocator.free(path);
                root.deleteFile(io, path) catch |failure| switch (failure) {
                    error.FileNotFound => {
                        report.summary.already_absent += 1;
                        action.applied = true;
                        continue;
                    },
                    else => {
                        report.summary.failed_actions += 1;
                        continue;
                    },
                };
                action.applied = true;
                report.summary.cache_entries_deleted += 1;
            },
            .cache_namespace => {
                if (!validRecipeName(action.identity) or std.mem.eql(u8, action.identity, extraction_cache.recipe)) {
                    report.summary.failed_actions += 1;
                    continue;
                }
                const path = std.fmt.allocPrint(report.allocator, "{s}/{s}", .{ extraction_cache.cache_root, action.identity }) catch {
                    report.summary.failed_actions += 1;
                    continue;
                };
                defer report.allocator.free(path);
                root.deleteTree(io, path) catch {
                    report.summary.failed_actions += 1;
                    continue;
                };
                action.applied = true;
                report.summary.namespaces_deleted += 1;
            },
        }
    }
    report.summary.status = if (report.summary.failed_actions == 0) .applied else .failed;
}

pub fn writeLatest(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir, report: *const Report) !void {
    const fingerprint = std.fmt.bytesToHex(report.plan_fingerprint, .lower);
    const receipt_digest = receiptFingerprint(report.repository_id, report.active_generation, report.plan_fingerprint, report.summary);
    const receipt_fingerprint = std.fmt.bytesToHex(receipt_digest, .lower);
    const bytes = try std.json.Stringify.valueAlloc(allocator, .{
        .schema = schema,
        .schema_version = schema_version,
        .repository_id = report.repository_id,
        .active_generation = report.active_generation,
        .policy = report.policy,
        .observed_at_ms = report.observed_at_ms,
        .plan_fingerprint = fingerprint[0..],
        .receipt_fingerprint = receipt_fingerprint[0..],
        .summary = report.summary,
        .actions = report.actions,
        .complete = true,
    }, .{ .whitespace = .indent_2 });
    defer allocator.free(bytes);
    if (bytes.len > max_report_bytes) return error.RetentionReportTooLarge;
    try atomicWrite(allocator, io, root, latest_path, bytes);
}

pub fn readLatestSummary(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir, repository_id: []const u8) !Summary {
    const bytes = try root.readFileAlloc(io, latest_path, allocator, .limited(max_report_bytes));
    defer allocator.free(bytes);
    var parsed = std.json.parseFromSlice(LatestData, allocator, bytes, .{ .ignore_unknown_fields = true }) catch return error.CorruptRetentionReport;
    defer parsed.deinit();
    if (!parsed.value.complete or !std.mem.eql(u8, parsed.value.schema, schema) or parsed.value.schema_version != schema_version or
        !std.mem.eql(u8, parsed.value.repository_id, repository_id) or !validGenerationId(parsed.value.active_generation) or
        !validHex(parsed.value.plan_fingerprint) or !validHex(parsed.value.receipt_fingerprint)) return error.CorruptRetentionReport;
    var plan_digest: [32]u8 = @splat(0);
    _ = std.fmt.hexToBytes(&plan_digest, parsed.value.plan_fingerprint) catch return error.CorruptRetentionReport;
    const expected = receiptFingerprint(parsed.value.repository_id, parsed.value.active_generation, plan_digest, parsed.value.summary);
    const expected_hex = std.fmt.bytesToHex(expected, .lower);
    if (!std.mem.eql(u8, &expected_hex, parsed.value.receipt_fingerprint)) return error.CorruptRetentionReport;
    return parsed.value.summary;
}

pub fn setPin(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    repository_id: []const u8,
    generation: []const u8,
    expected_generation_schema: []const u8,
    expected_generation_schema_version: u32,
    present: bool,
) !void {
    if (!validGenerationId(generation)) return error.InvalidGenerationId;
    if (present) {
        var target = try readGeneration(allocator, io, root, generation, expected_generation_schema, expected_generation_schema_version, repository_id);
        defer target.deinit();
        if (!target.valid) return error.InvalidPinnedGeneration;
    }

    var pins = try readPins(allocator, io, root, repository_id, max_pins);
    defer pins.deinit();
    var values: std.ArrayList([]const u8) = .empty;
    defer deinitStrings(allocator, &values);
    for (pins.generations) |value| {
        if (!present and std.mem.eql(u8, value, generation)) continue;
        try appendUniqueString(allocator, &values, value);
    }
    if (present) try appendUniqueString(allocator, &values, generation);
    if (values.items.len > max_pins) return error.RetentionPinLimitExceeded;
    std.mem.sort([]const u8, values.items, {}, stringLessThan);
    const digest = pinsFingerprint(repository_id, values.items);
    const digest_hex = std.fmt.bytesToHex(digest, .lower);
    const bytes = try std.json.Stringify.valueAlloc(allocator, .{
        .schema = pins_schema,
        .schema_version = schema_version,
        .repository_id = repository_id,
        .generations = values.items,
        .fingerprint = digest_hex[0..],
        .complete = true,
    }, .{ .whitespace = .indent_2 });
    defer allocator.free(bytes);
    if (bytes.len > max_pins_bytes) return error.RetentionPinsTooLarge;
    try atomicWrite(allocator, io, root, pins_path, bytes);
}

fn scanGenerations(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    input: Input,
    generations: *std.ArrayList(Generation),
    summary: *Summary,
) !void {
    var directory = root.openDir(io, generation_root, .{ .iterate = true, .follow_symlinks = false }) catch |failure| switch (failure) {
        error.FileNotFound => return error.MissingGenerationRoot,
        else => return failure,
    };
    defer directory.close(io);
    var iterator = directory.iterate();
    while (try iterator.next(io)) |entry| {
        summary.scanned_generation_entries = std.math.add(usize, summary.scanned_generation_entries, 1) catch return error.RetentionGenerationScanLimitExceeded;
        if (summary.scanned_generation_entries > input.policy.max_generation_entries) return error.RetentionGenerationScanLimitExceeded;
        if (entry.kind == .sym_link) {
            summary.preserved_symlinks += 1;
            continue;
        }
        if (entry.kind != .directory or !validGenerationId(entry.name)) {
            summary.preserved_unknown += 1;
            continue;
        }
        var generation = try readGeneration(allocator, io, root, entry.name, input.generation_schema, input.generation_schema_version, input.repository_id);
        errdefer generation.deinit();
        if (generation.valid) summary.valid_generations += 1;
        try generations.append(allocator, generation);
    }
}

fn readGeneration(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    generation: []const u8,
    expected_schema: []const u8,
    expected_schema_version: u32,
    repository_id: []const u8,
) !Generation {
    if (!validGenerationId(generation)) return error.InvalidGenerationId;
    const metadata_path = try std.fmt.allocPrint(allocator, "{s}/{s}/generation.json", .{ generation_root, generation });
    defer allocator.free(metadata_path);
    const stat = root.statFile(io, metadata_path, .{ .follow_symlinks = false }) catch null;
    const modified_ms = if (stat) |value| timestampMillis(value.mtime.nanoseconds) else 0;
    const id = try owned.copy(u8, allocator, generation);
    errdefer allocator.free(id);
    const bytes = root.readFileAlloc(io, metadata_path, allocator, .limited(max_generation_metadata_bytes)) catch |failure| switch (failure) {
        error.FileNotFound, error.StreamTooLong => return .{
            .allocator = allocator,
            .id = id,
            .semantic = "",
            .parent = "",
            .replaces = "",
            .modified_ms = modified_ms,
            .tombstones = 0,
            .valid = false,
        },
        else => return failure,
    };
    defer allocator.free(bytes);
    var parsed = std.json.parseFromSlice(GenerationHeader, allocator, bytes, .{ .allocate = .alloc_always, .ignore_unknown_fields = true }) catch return .{
        .allocator = allocator,
        .id = id,
        .semantic = "",
        .parent = "",
        .replaces = "",
        .modified_ms = modified_ms,
        .tombstones = 0,
        .valid = false,
    };
    defer parsed.deinit();
    const value = parsed.value;
    const valid = value.complete and std.mem.eql(u8, value.schema, expected_schema) and value.schema_version == expected_schema_version and
        std.mem.eql(u8, value.repository_id, repository_id) and std.mem.eql(u8, value.generation, generation) and
        validGenerationId(value.semantic_generation) and (value.parent_generation.len == 0 or validGenerationId(value.parent_generation)) and
        (value.replaces_generation.len == 0 or validGenerationId(value.replaces_generation)) and validHex(value.extraction_manifest_digest);
    const semantic = if (valid) try owned.copy(u8, allocator, value.semantic_generation) else "";
    errdefer if (semantic.len > 0) allocator.free(semantic);
    const parent = if (valid and value.parent_generation.len > 0) try owned.copy(u8, allocator, value.parent_generation) else "";
    errdefer if (parent.len > 0) allocator.free(parent);
    const replaces = if (valid and value.replaces_generation.len > 0) try owned.copy(u8, allocator, value.replaces_generation) else "";
    errdefer if (replaces.len > 0) allocator.free(replaces);
    return .{
        .allocator = allocator,
        .id = id,
        .semantic = semantic,
        .parent = parent,
        .replaces = replaces,
        .modified_ms = modified_ms,
        .tombstones = if (valid) value.delta_summary.tombstones else 0,
        .valid = valid,
    };
}

fn scanCache(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    input: Input,
    live_keys: []const []const u8,
    actions: *std.ArrayList(Action),
    summary: *Summary,
) !void {
    var cache_base = root.openDir(io, extraction_cache.cache_root, .{ .iterate = true, .follow_symlinks = false }) catch |failure| switch (failure) {
        error.FileNotFound => return,
        else => return failure,
    };
    defer cache_base.close(io);
    var namespace_iterator = cache_base.iterate();
    while (try namespace_iterator.next(io)) |namespace| {
        summary.cache_entries_scanned = std.math.add(usize, summary.cache_entries_scanned, 1) catch return error.RetentionCacheScanLimitExceeded;
        if (summary.cache_entries_scanned > input.policy.max_cache_entries) return error.RetentionCacheScanLimitExceeded;
        if (namespace.kind == .sym_link) {
            summary.preserved_symlinks += 1;
            continue;
        }
        if (namespace.kind != .directory) {
            summary.preserved_unknown += 1;
            continue;
        }
        if (std.mem.eql(u8, namespace.name, extraction_cache.recipe)) continue;
        if (!validRecipeName(namespace.name)) {
            summary.preserved_unknown += 1;
            continue;
        }
        const namespace_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ extraction_cache.cache_root, namespace.name });
        defer allocator.free(namespace_path);
        const stat = root.statFile(io, namespace_path, .{ .follow_symlinks = false }) catch null;
        const modified_ms = if (stat) |value| timestampMillis(value.mtime.nanoseconds) else 0;
        const eligible = graceElapsed(input.now_ms, modified_ms, input.policy.retention_grace_ms);
        try appendAction(allocator, actions, .{
            .kind = .cache_namespace,
            .identity = namespace.name,
            .reason = .obsolete_structural_recipe,
            .eligible = eligible,
        });
        summary.obsolete_namespaces += @intFromBool(eligible);
        summary.grace_deferred += @intFromBool(!eligible);
    }

    const recipe_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ extraction_cache.cache_root, extraction_cache.recipe });
    defer allocator.free(recipe_path);
    var recipe_dir = root.openDir(io, recipe_path, .{ .iterate = true, .follow_symlinks = false }) catch |failure| switch (failure) {
        error.FileNotFound => return,
        else => return failure,
    };
    defer recipe_dir.close(io);
    var shard_iterator = recipe_dir.iterate();
    while (try shard_iterator.next(io)) |shard| {
        summary.cache_entries_scanned = std.math.add(usize, summary.cache_entries_scanned, 1) catch return error.RetentionCacheScanLimitExceeded;
        if (summary.cache_entries_scanned > input.policy.max_cache_entries) return error.RetentionCacheScanLimitExceeded;
        if (shard.kind == .sym_link) {
            summary.preserved_symlinks += 1;
            continue;
        }
        if (shard.kind != .directory or !validShard(shard.name)) {
            summary.preserved_unknown += 1;
            continue;
        }
        const shard_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ recipe_path, shard.name });
        defer allocator.free(shard_path);
        var shard_dir = root.openDir(io, shard_path, .{ .iterate = true, .follow_symlinks = false }) catch continue;
        defer shard_dir.close(io);
        var entry_iterator = shard_dir.iterate();
        while (try entry_iterator.next(io)) |entry| {
            summary.cache_entries_scanned = std.math.add(usize, summary.cache_entries_scanned, 1) catch return error.RetentionCacheScanLimitExceeded;
            if (summary.cache_entries_scanned > input.policy.max_cache_entries) return error.RetentionCacheScanLimitExceeded;
            if (entry.kind == .sym_link) {
                summary.preserved_symlinks += 1;
                continue;
            }
            const key = cacheKeyFromName(entry.name) orelse {
                summary.preserved_unknown += 1;
                continue;
            };
            if (entry.kind != .file or !std.mem.eql(u8, key[0..2], shard.name)) {
                summary.preserved_unknown += 1;
                continue;
            }
            if (containsString(live_keys, key)) continue;
            const entry_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ shard_path, entry.name });
            defer allocator.free(entry_path);
            const stat = root.statFile(io, entry_path, .{ .follow_symlinks = false }) catch null;
            const modified_ms = if (stat) |value| timestampMillis(value.mtime.nanoseconds) else 0;
            const eligible = graceElapsed(input.now_ms, modified_ms, input.policy.retention_grace_ms);
            try appendAction(allocator, actions, .{
                .kind = .cache_entry,
                .identity = key,
                .reason = .unreferenced_cache,
                .eligible = eligible,
            });
            summary.cache_candidates += @intFromBool(eligible);
            summary.grace_deferred += @intFromBool(!eligible);
        }
    }
}

fn readPins(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir, repository_id: []const u8, limit: usize) !Pins {
    const bytes = root.readFileAlloc(io, pins_path, allocator, .limited(max_pins_bytes)) catch |failure| switch (failure) {
        error.FileNotFound => return .{ .allocator = allocator, .generations = try owned.slice([]const u8, allocator, 0) },
        error.StreamTooLong => return error.CorruptRetentionPins,
        else => return failure,
    };
    defer allocator.free(bytes);
    var parsed = std.json.parseFromSlice(PinsData, allocator, bytes, .{ .allocate = .alloc_always }) catch return error.CorruptRetentionPins;
    defer parsed.deinit();
    if (!parsed.value.complete or !std.mem.eql(u8, parsed.value.schema, pins_schema) or parsed.value.schema_version != schema_version or
        !std.mem.eql(u8, parsed.value.repository_id, repository_id) or !validHex(parsed.value.fingerprint) or parsed.value.generations.len > limit)
    {
        return error.CorruptRetentionPins;
    }
    var previous: []const u8 = "";
    for (parsed.value.generations) |generation| {
        if (!validGenerationId(generation) or (previous.len > 0 and !std.mem.lessThan(u8, previous, generation))) return error.CorruptRetentionPins;
        previous = generation;
    }
    const expected = pinsFingerprint(repository_id, parsed.value.generations);
    const expected_hex = std.fmt.bytesToHex(expected, .lower);
    if (!std.mem.eql(u8, &expected_hex, parsed.value.fingerprint)) return error.CorruptRetentionPins;
    const generations = try owned.slice([]const u8, allocator, parsed.value.generations.len);
    errdefer allocator.free(generations);
    var initialized: usize = 0;
    errdefer for (generations[0..initialized]) |generation| allocator.free(generation);
    for (parsed.value.generations, 0..) |generation, index| {
        generations[index] = try owned.copy(u8, allocator, generation);
        initialized += 1;
    }
    return .{ .allocator = allocator, .generations = generations };
}

fn appendAction(allocator: std.mem.Allocator, actions: *std.ArrayList(Action), action: Action) !void {
    if (actions.items.len >= max_actions) return error.RetentionPlanActionLimitExceeded;
    const identity = try owned.copy(u8, allocator, action.identity);
    errdefer allocator.free(identity);
    try actions.append(allocator, .{
        .kind = action.kind,
        .identity = identity,
        .reason = action.reason,
        .eligible = action.eligible,
        .tombstones = action.tombstones,
        .applied = action.applied,
    });
}

fn deinitActions(allocator: std.mem.Allocator, actions: *std.ArrayList(Action)) void {
    for (actions.items) |action| allocator.free(action.identity);
    actions.deinit(allocator);
}

fn appendUniqueString(allocator: std.mem.Allocator, values: *std.ArrayList([]const u8), value: []const u8) !void {
    if (containsString(values.items, value)) return;
    const copy = try owned.copy(u8, allocator, value);
    errdefer allocator.free(copy);
    try values.append(allocator, copy);
}

fn deinitStrings(allocator: std.mem.Allocator, values: *std.ArrayList([]const u8)) void {
    for (values.items) |value| allocator.free(value);
    values.deinit(allocator);
}

fn markDependency(generations: []Generation, identity: []const u8) void {
    if (identity.len == 0) return;
    if (findGeneration(generations, identity)) |index| generations[index].keep = true;
}

fn findGeneration(generations: []const Generation, identity: []const u8) ?usize {
    for (generations, 0..) |generation, index| if (std.mem.eql(u8, generation.id, identity)) return index;
    return null;
}

fn generationLessThan(_: void, left: Generation, right: Generation) bool {
    if (left.valid != right.valid) return left.valid;
    if (left.modified_ms != right.modified_ms) return left.modified_ms > right.modified_ms;
    return std.mem.lessThan(u8, left.id, right.id);
}

fn actionLessThan(_: void, left: Action, right: Action) bool {
    if (left.kind != right.kind) return @intFromEnum(left.kind) < @intFromEnum(right.kind);
    return std.mem.lessThan(u8, left.identity, right.identity);
}

fn stringLessThan(_: void, left: []const u8, right: []const u8) bool {
    return std.mem.lessThan(u8, left, right);
}

fn containsString(values: []const []const u8, target: []const u8) bool {
    for (values) |value| if (std.mem.eql(u8, value, target)) return true;
    return false;
}

fn planFingerprint(input: Input, actions: []const Action) [32]u8 {
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    updateDigest(&hasher, schema);
    updateDigest(&hasher, input.repository_id);
    updateDigest(&hasher, input.active_generation);
    updateInteger(&hasher, input.policy.retention_generations);
    updateInteger(&hasher, input.policy.retention_grace_ms);
    updateInteger(&hasher, actions.len);
    for (actions) |action| {
        updateInteger(&hasher, @intFromEnum(action.kind));
        updateDigest(&hasher, action.identity);
        updateInteger(&hasher, @intFromEnum(action.reason));
        updateInteger(&hasher, @intFromBool(action.eligible));
        updateInteger(&hasher, action.tombstones);
    }
    var output: [32]u8 = @splat(0);
    hasher.final(&output);
    return output;
}

fn pinsFingerprint(repository_id: []const u8, generations: []const []const u8) [32]u8 {
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    updateDigest(&hasher, pins_schema);
    updateDigest(&hasher, repository_id);
    updateInteger(&hasher, generations.len);
    for (generations) |generation| updateDigest(&hasher, generation);
    var output: [32]u8 = @splat(0);
    hasher.final(&output);
    return output;
}

fn receiptFingerprint(repository_id: []const u8, active_generation: []const u8, plan_fingerprint: [32]u8, summary: Summary) [32]u8 {
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    updateDigest(&hasher, schema);
    updateDigest(&hasher, repository_id);
    updateDigest(&hasher, active_generation);
    hasher.update(&plan_fingerprint);
    updateInteger(&hasher, @intFromEnum(summary.status));
    updateInteger(&hasher, summary.scanned_generation_entries);
    updateInteger(&hasher, summary.valid_generations);
    updateInteger(&hasher, summary.retained_generations);
    updateInteger(&hasher, summary.pinned_generations);
    updateInteger(&hasher, summary.generation_candidates);
    updateInteger(&hasher, summary.cache_entries_scanned);
    updateInteger(&hasher, summary.cache_candidates);
    updateInteger(&hasher, summary.obsolete_namespaces);
    updateInteger(&hasher, summary.grace_deferred);
    updateInteger(&hasher, summary.reader_deferred);
    updateInteger(&hasher, summary.generations_deleted);
    updateInteger(&hasher, summary.journals_compacted);
    updateInteger(&hasher, summary.tombstones_compacted);
    updateInteger(&hasher, summary.cache_entries_deleted);
    updateInteger(&hasher, summary.namespaces_deleted);
    updateInteger(&hasher, summary.already_absent);
    updateInteger(&hasher, summary.failed_actions);
    updateInteger(&hasher, summary.preserved_unknown);
    updateInteger(&hasher, summary.preserved_symlinks);
    updateInteger(&hasher, summary.migration_references);
    updateInteger(&hasher, summary.resumable_job_references);
    var output: [32]u8 = @splat(0);
    hasher.final(&output);
    return output;
}

fn updateDigest(hasher: *std.crypto.hash.sha2.Sha256, value: []const u8) void {
    updateInteger(hasher, value.len);
    hasher.update(value);
}

fn updateInteger(hasher: *std.crypto.hash.sha2.Sha256, value: anytype) void {
    var bytes: [8]u8 = @splat(0);
    std.mem.writeInt(u64, &bytes, @intCast(value), .little);
    hasher.update(&bytes);
}

fn graceElapsed(now_ms: u64, modified_ms: u64, grace_ms: u64) bool {
    if (grace_ms == 0) return true;
    if (modified_ms == 0 or modified_ms > now_ms) return false;
    return now_ms - modified_ms >= grace_ms;
}

fn timestampMillis(nanoseconds: i128) u64 {
    if (nanoseconds <= 0) return 0;
    return @intCast(@min(@as(i128, std.math.maxInt(u64)), @divFloor(nanoseconds, std.time.ns_per_ms)));
}

fn cacheKeyFromName(name: []const u8) ?[]const u8 {
    if (name.len != 69 or !std.mem.endsWith(u8, name, ".json")) return null;
    const key = name[0..64];
    if (!validHex(key)) return null;
    return key;
}

fn validShard(value: []const u8) bool {
    return value.len == 2 and lowerHex(value[0]) and lowerHex(value[1]);
}

fn validRecipeName(value: []const u8) bool {
    if (!std.mem.startsWith(u8, value, "structural-facts-v") or value.len <= "structural-facts-v".len) return false;
    for (value["structural-facts-v".len..]) |byte| if (!std.ascii.isDigit(byte)) return false;
    return true;
}

pub fn validGenerationId(value: []const u8) bool {
    if (value.len != 66 or !std.mem.startsWith(u8, value, "g-")) return false;
    return validHex(value[2..]);
}

fn validRepositoryId(value: []const u8) bool {
    if (value.len != 37 or !std.mem.startsWith(u8, value, "repo-")) return false;
    for (value[5..]) |byte| if (!lowerHex(byte)) return false;
    return true;
}

fn validHex(value: []const u8) bool {
    if (value.len != 64) return false;
    for (value) |byte| if (!lowerHex(byte)) return false;
    return true;
}

fn lowerHex(byte: u8) bool {
    return std.ascii.isDigit(byte) or (byte >= 'a' and byte <= 'f');
}

fn atomicWrite(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir, path: []const u8, bytes: []const u8) !void {
    if (!validOwnedPath(path)) return error.InvalidRetentionPath;
    if (std.mem.lastIndexOfScalar(u8, path, '/')) |slash| try root.createDirPath(io, path[0..slash]);
    for (0..1024) |slot| {
        const temporary = try std.fmt.allocPrint(allocator, "{s}.tmp.{d}", .{ path, slot });
        defer allocator.free(temporary);
        const file = root.createFile(io, temporary, .{ .exclusive = true }) catch |failure| switch (failure) {
            error.PathAlreadyExists => continue,
            else => return failure,
        };
        defer file.close(io);
        errdefer root.deleteFile(io, temporary) catch {};
        try file.writeStreamingAll(io, bytes);
        root.rename(temporary, root, path, io) catch |failure| {
            root.deleteFile(io, temporary) catch {};
            return failure;
        };
        return;
    }
    return error.AtomicTemporaryPathExhausted;
}

fn validOwnedPath(path: []const u8) bool {
    if (path.len == 0 or std.fs.path.isAbsolute(path) or std.mem.indexOfScalar(u8, path, '\\') != null) return false;
    var parts = std.mem.splitScalar(u8, path, '/');
    while (parts.next()) |part| if (part.len == 0 or std.mem.eql(u8, part, ".") or std.mem.eql(u8, part, "..")) return false;
    return true;
}
