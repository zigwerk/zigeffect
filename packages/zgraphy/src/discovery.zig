const std = @import("std");
const model = @import("model.zig");
const owned = @import("memory.zig");

pub const schema = "zgraphy.discovery-manifest.v1";
pub const schema_version: u32 = 1;
pub const classifier_version = "universal-classifier-v1";
pub const policy_version = "local-safe-policy-v1";

pub const Language = enum(u8) {
    zig,
    typescript,
    javascript,
    python,
    rust,
    go,
    c,
    cpp,
    java,
    proto,
    json,
    yaml,
    toml,
    markdown,
    shell,
    sql,
    html,
    css,
    media,
    unknown,
};

pub const Artifact = enum(u8) {
    source,
    package_manifest,
    build_definition,
    lockfile,
    protocol,
    config,
    schema,
    migration,
    ci,
    deployment,
    documentation,
    asset,
    data,
    unknown,
};

pub const Disposition = enum(u8) {
    deeply_indexed,
    placed_unsupported,
    placed_asset,
    ignored_rule,
    excluded_mandatory,
    excluded_sensitive,
    excluded_binary,
    excluded_oversized,
    unreadable,
    symlink_not_followed,
    unsupported_special,
    invalid_path,
    limit_exhausted,
};

pub const Classification = struct {
    language: Language = .unknown,
    artifact: Artifact = .unknown,
    is_test: bool = false,
    is_fixture: bool = false,
    is_generated: bool = false,
    is_vendored: bool = false,
    is_archived: bool = false,
};

pub const Record = struct {
    relative_path: []const u8,
    path_digest: [32]u8,
    classification: Classification,
    disposition: Disposition,
    responsible: []const u8,
    size: u64 = 0,
    content_digest: ?[32]u8 = null,
};

pub const Summary = struct {
    total: usize = 0,
    deeply_indexed: usize = 0,
    placed_unsupported: usize = 0,
    placed_asset: usize = 0,
    ignored_rule: usize = 0,
    excluded_mandatory: usize = 0,
    excluded_sensitive: usize = 0,
    excluded_binary: usize = 0,
    excluded_oversized: usize = 0,
    unreadable: usize = 0,
    symlink_not_followed: usize = 0,
    unsupported_special: usize = 0,
    invalid_path: usize = 0,
    limit_exhausted: usize = 0,

    fn include(self: *Summary, disposition: Disposition) void {
        self.total += 1;
        switch (disposition) {
            .deeply_indexed => self.deeply_indexed += 1,
            .placed_unsupported => self.placed_unsupported += 1,
            .placed_asset => self.placed_asset += 1,
            .ignored_rule => self.ignored_rule += 1,
            .excluded_mandatory => self.excluded_mandatory += 1,
            .excluded_sensitive => self.excluded_sensitive += 1,
            .excluded_binary => self.excluded_binary += 1,
            .excluded_oversized => self.excluded_oversized += 1,
            .unreadable => self.unreadable += 1,
            .symlink_not_followed => self.symlink_not_followed += 1,
            .unsupported_special => self.unsupported_special += 1,
            .invalid_path => self.invalid_path += 1,
            .limit_exhausted => self.limit_exhausted += 1,
        }
    }
};

pub const Options = struct {
    repository_id: []const u8 = "repo-00000000000000000000000000000000",
    max_entries: usize = 200_000,
    max_files: usize = 100_000,
    max_file_bytes: usize = 4 * 1024 * 1024,
    max_total_bytes: usize = 512 * 1024 * 1024,
    max_depth: usize = 128,
    max_path_bytes: usize = std.fs.max_path_bytes,
};

pub const Result = struct {
    allocator: std.mem.Allocator,
    repository_id: []const u8,
    records: []Record,
    summary: Summary,
    manifest_digest: [32]u8,
    observed_entries: usize,
    hashed_bytes: usize,

    pub fn deinit(self: *Result) void {
        for (self.records) |record| {
            if (record.relative_path.len > 0) self.allocator.free(record.relative_path);
            if (record.responsible.len > 0) self.allocator.free(record.responsible);
        }
        self.allocator.free(self.records);
        self.allocator.free(self.repository_id);
        self.records = &.{};
        self.repository_id = "";
    }

    pub fn reconciles(self: *const Result) bool {
        var summary = Summary{};
        for (self.records) |record| summary.include(record.disposition);
        return std.meta.eql(summary, self.summary);
    }

    pub fn findByPath(self: *const Result, path: []const u8) ?*const Record {
        for (self.records, 0..) |record, index| {
            if (std.mem.eql(u8, record.relative_path, path)) return &self.records[index];
        }
        return null;
    }
};

const IgnoreRule = struct {
    pattern: []const u8,
    base_path: []const u8,
    responsible: []const u8,
    negated: bool,
    anchored: bool,
    directory_only: bool,
};

const IgnoreRules = struct {
    allocator: std.mem.Allocator,
    rules: std.ArrayList(IgnoreRule) = .empty,

    fn deinit(self: *IgnoreRules) void {
        for (self.rules.items) |rule| {
            self.allocator.free(rule.pattern);
            if (rule.base_path.len > 0) self.allocator.free(rule.base_path);
            self.allocator.free(rule.responsible);
        }
        self.rules.deinit(self.allocator);
    }

    fn match(self: *const IgnoreRules, path: []const u8, is_directory: bool) ?*const IgnoreRule {
        var ignored = false;
        var responsible: ?*const IgnoreRule = null;
        for (self.rules.items, 0..) |rule, index| {
            if (!ruleMatches(rule, path, is_directory)) continue;
            ignored = !rule.negated;
            responsible = &self.rules.items[index];
        }
        return if (ignored) responsible else null;
    }
};

pub fn scan(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    options: Options,
) !Result {
    try validateOptions(options);
    var rules = try loadIgnoreRules(allocator, io, root);
    defer rules.deinit();

    var records: std.ArrayList(Record) = .empty;
    errdefer {
        for (records.items) |record| {
            if (record.relative_path.len > 0) allocator.free(record.relative_path);
            if (record.responsible.len > 0) allocator.free(record.responsible);
        }
        records.deinit(allocator);
    }
    var observed_entries: usize = 0;
    var files: usize = 0;
    var hashed_bytes: usize = 0;
    var walker = try root.walk(allocator);
    defer walker.deinit();
    while (try walker.next(io)) |entry| {
        observed_entries = std.math.add(usize, observed_entries, 1) catch return error.DiscoveryEntryLimitExceeded;
        if (observed_entries > options.max_entries) return error.DiscoveryEntryLimitExceeded;
        if (entry.depth() > options.max_depth) return error.DiscoveryDepthLimitExceeded;
        if (entry.path.len == 0 or entry.path.len > options.max_path_bytes or !validRelativePath(entry.path)) {
            return error.InvalidDiscoveryPath;
        }

        if (entry.kind == .directory) {
            if (mandatoryExcluded(entry.path)) {
                try appendRecord(allocator, &records, entry.path, .{}, .excluded_mandatory, "mandatory-policy", 0, null, false);
                walker.leave(io);
            } else if (rules.match(entry.path, true)) |rule| {
                try appendRecord(allocator, &records, entry.path, .{}, .ignored_rule, rule.responsible, 0, null, false);
                walker.leave(io);
            } else {
                try loadDirectoryIgnoreRules(allocator, io, root, entry.path, &rules);
            }
            continue;
        }
        if (entry.kind == .sym_link) {
            try appendRecord(allocator, &records, entry.path, classify(entry.path), .symlink_not_followed, "no-follow-policy", 0, null, false);
            continue;
        }
        if (entry.kind != .file) {
            try appendRecord(allocator, &records, entry.path, classify(entry.path), .unsupported_special, "file-kind-policy", 0, null, false);
            continue;
        }
        files = std.math.add(usize, files, 1) catch return error.DiscoveryFileLimitExceeded;
        if (files > options.max_files) return error.DiscoveryFileLimitExceeded;
        if (mandatoryExcluded(entry.path)) {
            try appendRecord(allocator, &records, entry.path, classify(entry.path), .excluded_mandatory, "mandatory-policy", 0, null, false);
            continue;
        }
        if (rules.match(entry.path, false)) |rule| {
            try appendRecord(allocator, &records, entry.path, classify(entry.path), .ignored_rule, rule.responsible, 0, null, false);
            continue;
        }
        if (isSensitivePath(entry.path)) {
            const stat = root.statFile(io, entry.path, .{ .follow_symlinks = false }) catch null;
            try appendRecord(allocator, &records, entry.path, classify(entry.path), .excluded_sensitive, "sensitive-name-policy", if (stat) |value| value.size else 0, null, true);
            continue;
        }
        const stat = root.statFile(io, entry.path, .{ .follow_symlinks = false }) catch {
            try appendRecord(allocator, &records, entry.path, classify(entry.path), .unreadable, "filesystem", 0, null, false);
            continue;
        };
        if (stat.size > options.max_file_bytes) {
            try appendRecord(allocator, &records, entry.path, classify(entry.path), .excluded_oversized, "file-byte-limit", stat.size, null, false);
            continue;
        }
        const bytes = root.readFileAlloc(io, entry.path, allocator, .limited(options.max_file_bytes)) catch {
            try appendRecord(allocator, &records, entry.path, classify(entry.path), .unreadable, "filesystem", stat.size, null, false);
            continue;
        };
        defer allocator.free(bytes);
        if (looksBinary(bytes)) {
            try appendRecord(allocator, &records, entry.path, classify(entry.path), .excluded_binary, "binary-prefix-policy", stat.size, null, false);
            continue;
        }
        hashed_bytes = std.math.add(usize, hashed_bytes, bytes.len) catch return error.DiscoveryByteLimitExceeded;
        if (hashed_bytes > options.max_total_bytes) return error.DiscoveryByteLimitExceeded;
        var digest: [32]u8 = @splat(0);
        std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
        const classification = classify(entry.path);
        const disposition: Disposition = if (classification.language == .zig or classification.language == .typescript or classification.language == .javascript or classification.language == .proto)
            .deeply_indexed
        else if (classification.artifact == .asset)
            .placed_asset
        else
            .placed_unsupported;
        try appendRecord(allocator, &records, entry.path, classification, disposition, "universal-classifier-v1", stat.size, digest, false);
    }

    std.mem.sort(Record, records.items, {}, lessThanRecord);
    const repository_id = try owned.copy(u8, allocator, options.repository_id);
    errdefer allocator.free(repository_id);
    const record_slice = try records.toOwnedSlice(allocator);
    var result = Result{
        .allocator = allocator,
        .repository_id = repository_id,
        .records = record_slice,
        .summary = summarize(record_slice),
        .manifest_digest = manifestDigest(repository_id, record_slice),
        .observed_entries = observed_entries,
        .hashed_bytes = hashed_bytes,
    };
    errdefer result.deinit();
    try validate(&result);
    return result;
}

pub fn validate(result: *const Result) !void {
    if (!isValidRepositoryId(result.repository_id) or result.records.len == 0 or !result.reconciles()) return error.InvalidDiscoveryResult;
    var previous: ?*const Record = null;
    for (result.records, 0..) |record, index| {
        if (record.relative_path.len > 0 and !validRelativePath(record.relative_path)) return error.InvalidDiscoveryPath;
        if (record.disposition == .excluded_sensitive) {
            if (record.relative_path.len != 0 or record.content_digest != null) return error.SensitiveDiscoveryLeak;
        } else if (record.relative_path.len == 0) return error.MissingDiscoveryPath;
        if ((record.disposition == .deeply_indexed or record.disposition == .placed_unsupported or record.disposition == .placed_asset) and record.content_digest == null) {
            return error.IncompleteDiscoveryFingerprint;
        }
        if (previous) |prior| {
            if (!lessThanRecord({}, prior.*, record)) return error.UnsortedDiscoveryManifest;
        }
        previous = &result.records[index];
    }
    const expected_digest = manifestDigest(result.repository_id, result.records);
    if (!std.mem.eql(u8, &expected_digest, &result.manifest_digest)) return error.InvalidDiscoveryManifestDigest;
}

pub fn materialize(graph: *model.RepositoryGraph, result: *const Result) !void {
    try validate(result);
    const repository_id = try graph.addNode(.{
        .id = model.stableId(.repository, "", result.repository_id),
        .kind = .repository,
        .label = result.repository_id,
        .path = ".",
        .search_text = "repository root",
    });
    for (result.records) |record| {
        if (record.disposition != .deeply_indexed and record.disposition != .placed_unsupported and record.disposition != .placed_asset) continue;
        const path = record.relative_path;
        var parent_id = repository_id;
        var offset: usize = 0;
        while (std.mem.indexOfScalarPos(u8, path, offset, '/')) |slash| {
            const directory_path = path[0..slash];
            const label = std.fs.path.basename(directory_path);
            const directory_id = try graph.addNode(.{
                .kind = .directory,
                .label = label,
                .path = directory_path,
                .search_text = directory_path,
            });
            try graph.addEdge(.{ .from = parent_id, .to = directory_id, .relation = .contains, .provenance = .extracted });
            parent_id = directory_id;
            offset = slash + 1;
        }
        const basename = std.fs.path.basename(path);
        const search_text = try std.fmt.allocPrint(graph.allocator, "{s} {s} {s}", .{ path, @tagName(record.classification.language), @tagName(record.classification.artifact) });
        defer graph.allocator.free(search_text);
        const file_id = try graph.addNode(.{
            .kind = .file,
            .label = basename,
            .path = path,
            .line = 1,
            .search_text = search_text,
        });
        try graph.addEdge(.{ .from = parent_id, .to = file_id, .relation = .contains, .provenance = .extracted });
    }
}

pub fn classify(path: []const u8) Classification {
    const basename = std.fs.path.basename(path);
    var result = Classification{
        .language = languageFor(path),
        .artifact = artifactFor(path, basename),
        .is_test = isTestPath(path, basename),
        .is_fixture = hasComponent(path, "fixture") or hasComponent(path, "fixtures"),
        .is_generated = hasComponent(path, "generated") or hasComponent(path, "gen") or
            std.mem.indexOf(u8, basename, ".generated.") != null or std.mem.endsWith(u8, basename, ".pb.zig") or std.mem.endsWith(u8, basename, ".pb.ts"),
        .is_vendored = hasComponent(path, "vendor") or hasComponent(path, "vendored") or hasComponent(path, "third_party"),
        .is_archived = hasComponent(path, "archive") or hasComponent(path, "legacy"),
    };
    if (result.is_test and result.artifact == .source) result.artifact = .source;
    return result;
}

fn validateOptions(options: Options) !void {
    if (!isValidRepositoryId(options.repository_id) or options.max_entries == 0 or options.max_files == 0 or
        options.max_file_bytes == 0 or options.max_total_bytes == 0 or options.max_depth == 0 or
        options.max_path_bytes == 0 or options.max_path_bytes > std.fs.max_path_bytes)
    {
        return error.InvalidDiscoveryOptions;
    }
}

pub fn isValidRepositoryId(value: []const u8) bool {
    if (value.len != 37 or !std.mem.startsWith(u8, value, "repo-")) return false;
    for (value[5..]) |byte| if (!std.ascii.isHex(byte)) return false;
    return true;
}

fn validRelativePath(path: []const u8) bool {
    if (path.len == 0 or std.fs.path.isAbsolute(path) or std.mem.indexOfScalar(u8, path, '\\') != null) return false;
    var components = std.mem.splitScalar(u8, path, '/');
    while (components.next()) |component| {
        if (component.len == 0 or std.mem.eql(u8, component, ".") or std.mem.eql(u8, component, "..")) return false;
    }
    return true;
}

fn appendRecord(
    allocator: std.mem.Allocator,
    records: *std.ArrayList(Record),
    path: []const u8,
    classification: Classification,
    disposition: Disposition,
    responsible: []const u8,
    size: u64,
    content_digest: ?[32]u8,
    conceal_path: bool,
) !void {
    const relative_path = if (conceal_path) "" else try owned.copy(u8, allocator, path);
    errdefer if (relative_path.len > 0) allocator.free(relative_path);
    const responsible_copy = try owned.copy(u8, allocator, responsible);
    errdefer allocator.free(responsible_copy);
    var path_digest: [32]u8 = @splat(0);
    std.crypto.hash.sha2.Sha256.hash(path, &path_digest, .{});
    try records.append(allocator, .{
        .relative_path = relative_path,
        .path_digest = path_digest,
        .classification = classification,
        .disposition = disposition,
        .responsible = responsible_copy,
        .size = size,
        .content_digest = content_digest,
    });
}

fn lessThanRecord(_: void, left: Record, right: Record) bool {
    if (left.relative_path.len == 0 and right.relative_path.len == 0) return std.mem.lessThan(u8, &left.path_digest, &right.path_digest);
    if (left.relative_path.len == 0) return true;
    if (right.relative_path.len == 0) return false;
    return std.mem.lessThan(u8, left.relative_path, right.relative_path);
}

fn summarize(records: []const Record) Summary {
    var summary = Summary{};
    for (records) |record| summary.include(record.disposition);
    return summary;
}

fn manifestDigest(repository_id: []const u8, records: []const Record) [32]u8 {
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    updateBytes(&hasher, schema);
    updateBytes(&hasher, repository_id);
    updateBytes(&hasher, classifier_version);
    updateBytes(&hasher, policy_version);
    for (records) |record| {
        updateBytes(&hasher, record.relative_path);
        hasher.update(&record.path_digest);
        updateU64(&hasher, @intCast(@intFromEnum(record.classification.language)));
        updateU64(&hasher, @intCast(@intFromEnum(record.classification.artifact)));
        updateU64(&hasher, @intCast(@intFromBool(record.classification.is_test)));
        updateU64(&hasher, @intCast(@intFromBool(record.classification.is_fixture)));
        updateU64(&hasher, @intCast(@intFromBool(record.classification.is_generated)));
        updateU64(&hasher, @intCast(@intFromBool(record.classification.is_vendored)));
        updateU64(&hasher, @intCast(@intFromBool(record.classification.is_archived)));
        updateU64(&hasher, @intCast(@intFromEnum(record.disposition)));
        updateBytes(&hasher, record.responsible);
        updateU64(&hasher, record.size);
        if (record.content_digest) |digest| hasher.update(&digest);
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

fn loadIgnoreRules(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir) !IgnoreRules {
    var rules = IgnoreRules{ .allocator = allocator };
    errdefer rules.deinit();
    try loadDirectoryIgnoreRules(allocator, io, root, "", &rules);
    return rules;
}

const ParsedIgnoreLine = struct {
    pattern: []const u8,
    negated: bool,
    anchored: bool,
    directory_only: bool,
};

fn loadDirectoryIgnoreRules(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    base_path: []const u8,
    rules: *IgnoreRules,
) !void {
    for ([_][]const u8{ ".gitignore", ".zgraphyignore" }) |basename| {
        const ignore_path = if (base_path.len == 0)
            try owned.copy(u8, allocator, basename)
        else
            try std.fmt.allocPrint(allocator, "{s}/{s}", .{ base_path, basename });
        defer allocator.free(ignore_path);
        const contents = root.readFileAlloc(io, ignore_path, allocator, .limited(512 * 1024)) catch |failure| switch (failure) {
            error.FileNotFound => continue,
            else => return failure,
        };
        defer allocator.free(contents);
        var lines = std.mem.splitScalar(u8, contents, '\n');
        var line_number: usize = 0;
        while (lines.next()) |raw_line| {
            line_number += 1;
            const parsed = parseIgnoreLine(raw_line) orelse continue;
            if (parsed.pattern.len > 1024 or rules.rules.items.len >= 4096 or !validIgnorePattern(parsed.pattern)) return error.InvalidDiscoveryIgnoreRule;
            const pattern = try owned.copy(u8, allocator, parsed.pattern);
            errdefer allocator.free(pattern);
            const copied_base = if (base_path.len > 0) try owned.copy(u8, allocator, base_path) else "";
            errdefer if (copied_base.len > 0) allocator.free(copied_base);
            const responsible = try std.fmt.allocPrint(allocator, "ignore:{s}:{d}", .{ ignore_path, line_number });
            errdefer allocator.free(responsible);
            try rules.rules.append(allocator, .{
                .pattern = pattern,
                .base_path = copied_base,
                .responsible = responsible,
                .negated = parsed.negated,
                .anchored = parsed.anchored,
                .directory_only = parsed.directory_only,
            });
        }
    }
}

fn parseIgnoreLine(raw: []const u8) ?ParsedIgnoreLine {
    var line = std.mem.trimEnd(u8, raw, "\r");
    line = std.mem.trimStart(u8, line, " \t");
    if (line.len == 0 or line[0] == '#') return null;
    var escaped = false;
    var comment_at: ?usize = null;
    for (line, 0..) |byte, index| {
        if (escaped) {
            escaped = false;
            continue;
        }
        if (byte == '\\') {
            escaped = true;
            continue;
        }
        if (byte == '#' and index > 0 and std.ascii.isWhitespace(line[index - 1])) {
            comment_at = index;
            break;
        }
    }
    if (comment_at) |index| line = line[0..index];
    var end = line.len;
    while (end > 0 and line[end - 1] == ' ') {
        var slash_count: usize = 0;
        var cursor = end - 1;
        while (cursor > 0 and line[cursor - 1] == '\\') : (cursor -= 1) slash_count += 1;
        if (slash_count % 2 == 1) break;
        end -= 1;
    }
    line = line[0..end];
    if (line.len == 0) return null;
    const negated = line[0] == '!';
    if (negated) line = line[1..];
    const anchored = line.len > 0 and line[0] == '/';
    if (anchored) line = line[1..];
    const directory_only = line.len > 0 and line[line.len - 1] == '/';
    if (directory_only) line = line[0 .. line.len - 1];
    if (line.len == 0) return null;
    return .{ .pattern = line, .negated = negated, .anchored = anchored, .directory_only = directory_only };
}

fn validIgnorePattern(pattern: []const u8) bool {
    if (pattern.len == 0 or std.mem.indexOfScalar(u8, pattern, 0) != null) return false;
    var wildcards: usize = 0;
    for (pattern) |byte| if (byte == '*' or byte == '?' or byte == '[') {
        wildcards += 1;
    };
    if (wildcards > 64) return false;
    var components = std.mem.splitScalar(u8, pattern, '/');
    while (components.next()) |component| if (std.mem.eql(u8, component, "..")) return false;
    return true;
}

fn ruleMatches(rule: IgnoreRule, path: []const u8, is_directory: bool) bool {
    const relative = relativeToBase(path, rule.base_path) orelse return false;
    if (rule.directory_only and !is_directory) return false;
    if (rule.anchored or std.mem.indexOfScalar(u8, rule.pattern, '/') != null) return globMatches(rule.pattern, relative);
    var components = std.mem.splitScalar(u8, relative, '/');
    while (components.next()) |component| {
        if (globMatches(rule.pattern, component)) return true;
    }
    return false;
}

fn relativeToBase(path: []const u8, base_path: []const u8) ?[]const u8 {
    if (base_path.len == 0) return path;
    if (!std.mem.startsWith(u8, path, base_path) or path.len <= base_path.len or path[base_path.len] != '/') return null;
    return path[base_path.len + 1 ..];
}

fn globMatches(pattern: []const u8, value: []const u8) bool {
    var budget: usize = 8192;
    return globMatchesAt(pattern, 0, value, 0, &budget);
}

fn globMatchesAt(pattern: []const u8, pattern_index: usize, value: []const u8, value_index: usize, budget: *usize) bool {
    if (budget.* == 0) return false;
    budget.* -= 1;
    var pi = pattern_index;
    var vi = value_index;
    while (pi < pattern.len) {
        const token = pattern[pi];
        if (token == '*') {
            var after = pi + 1;
            while (after < pattern.len and pattern[after] == '*') after += 1;
            const double_star = after - pi >= 2;
            if (double_star) {
                if (after < pattern.len and pattern[after] == '/' and globMatchesAt(pattern, after + 1, value, vi, budget)) return true;
                var cursor = vi;
                while (true) {
                    if (globMatchesAt(pattern, after, value, cursor, budget)) return true;
                    if (cursor >= value.len) break;
                    cursor += 1;
                }
                return false;
            }
            var cursor = vi;
            while (true) {
                if (globMatchesAt(pattern, after, value, cursor, budget)) return true;
                if (cursor >= value.len or value[cursor] == '/') break;
                cursor += 1;
            }
            return false;
        }
        if (vi >= value.len) return false;
        if (token == '?') {
            if (value[vi] == '/') return false;
            pi += 1;
            vi += 1;
            continue;
        }
        if (token == '[') {
            const class = matchCharacterClass(pattern, pi, value[vi]) orelse return false;
            if (!class.matched or value[vi] == '/') return false;
            pi = class.next_index;
            vi += 1;
            continue;
        }
        if (token == '\\' and pi + 1 < pattern.len) pi += 1;
        if (pattern[pi] != value[vi]) return false;
        pi += 1;
        vi += 1;
    }
    return vi == value.len;
}

const CharacterClassMatch = struct { matched: bool, next_index: usize };

fn matchCharacterClass(pattern: []const u8, start: usize, value: u8) ?CharacterClassMatch {
    var cursor = start + 1;
    if (cursor >= pattern.len) return null;
    const negated = pattern[cursor] == '!' or pattern[cursor] == '^';
    if (negated) cursor += 1;
    var matched = false;
    var saw_item = false;
    while (cursor < pattern.len and pattern[cursor] != ']') {
        saw_item = true;
        var first = pattern[cursor];
        if (first == '\\' and cursor + 1 < pattern.len) {
            cursor += 1;
            first = pattern[cursor];
        }
        if (cursor + 2 < pattern.len and pattern[cursor + 1] == '-' and pattern[cursor + 2] != ']') {
            const last = pattern[cursor + 2];
            if (value >= first and value <= last) matched = true;
            cursor += 3;
        } else {
            if (value == first) matched = true;
            cursor += 1;
        }
    }
    if (!saw_item or cursor >= pattern.len or pattern[cursor] != ']') return null;
    return .{ .matched = if (negated) !matched else matched, .next_index = cursor + 1 };
}

fn mandatoryExcluded(path: []const u8) bool {
    var components = std.mem.splitScalar(u8, path, '/');
    while (components.next()) |component| {
        for ([_][]const u8{ ".git", ".zgraphy", ".zigeffect", ".zig-cache", "zig-out", "node_modules", "zig-pkg", "__pycache__", ".next", ".nuxt", ".turbo", ".terraform" }) |excluded| {
            if (std.mem.eql(u8, component, excluded)) return true;
        }
    }
    return false;
}

fn isSensitivePath(path: []const u8) bool {
    const basename = std.fs.path.basename(path);
    if (std.mem.eql(u8, basename, ".env") or std.mem.startsWith(u8, basename, ".env.") or
        std.mem.eql(u8, basename, ".npmrc") or std.mem.eql(u8, basename, ".pypirc") or
        std.mem.eql(u8, basename, "credentials.json") or std.mem.eql(u8, basename, "id_rsa") or
        std.mem.eql(u8, basename, "id_ed25519"))
    {
        return true;
    }
    return std.mem.endsWith(u8, basename, ".pem") or std.mem.endsWith(u8, basename, ".key") or
        std.mem.indexOf(u8, basename, "private-key") != null;
}

fn looksBinary(bytes: []const u8) bool {
    const sample = bytes[0..@min(bytes.len, 8192)];
    return std.mem.indexOfScalar(u8, sample, 0) != null;
}

fn languageFor(path: []const u8) Language {
    const basename = std.fs.path.basename(path);
    if (std.mem.eql(u8, basename, "go.mod")) return .go;
    const extension = std.fs.path.extension(basename);
    if (std.mem.eql(u8, extension, ".zig")) return .zig;
    if (std.mem.eql(u8, extension, ".ts") or std.mem.eql(u8, extension, ".tsx") or std.mem.eql(u8, extension, ".mts") or std.mem.eql(u8, extension, ".cts")) return .typescript;
    if (std.mem.eql(u8, extension, ".js") or std.mem.eql(u8, extension, ".jsx") or std.mem.eql(u8, extension, ".mjs") or std.mem.eql(u8, extension, ".cjs")) return .javascript;
    if (std.mem.eql(u8, extension, ".py")) return .python;
    if (std.mem.eql(u8, extension, ".rs")) return .rust;
    if (std.mem.eql(u8, extension, ".go")) return .go;
    if (std.mem.eql(u8, extension, ".c") or std.mem.eql(u8, extension, ".h")) return .c;
    if (std.mem.eql(u8, extension, ".cpp") or std.mem.eql(u8, extension, ".cc") or std.mem.eql(u8, extension, ".hpp")) return .cpp;
    if (std.mem.eql(u8, extension, ".java")) return .java;
    if (std.mem.eql(u8, extension, ".proto")) return .proto;
    if (std.mem.eql(u8, extension, ".json")) return .json;
    if (std.mem.eql(u8, extension, ".yaml") or std.mem.eql(u8, extension, ".yml")) return .yaml;
    if (std.mem.eql(u8, extension, ".toml")) return .toml;
    if (std.mem.eql(u8, extension, ".md") or std.mem.eql(u8, extension, ".mdx")) return .markdown;
    if (std.mem.eql(u8, extension, ".sh") or std.mem.eql(u8, extension, ".bash") or std.mem.eql(u8, extension, ".zsh")) return .shell;
    if (std.mem.eql(u8, extension, ".sql")) return .sql;
    if (std.mem.eql(u8, extension, ".html") or std.mem.eql(u8, extension, ".htm")) return .html;
    if (std.mem.eql(u8, extension, ".css") or std.mem.eql(u8, extension, ".scss")) return .css;
    if (isAssetExtension(extension)) return .media;
    return .unknown;
}

fn artifactFor(path: []const u8, basename: []const u8) Artifact {
    if (std.mem.eql(u8, basename, "package.json") or std.mem.eql(u8, basename, "pyproject.toml") or
        std.mem.eql(u8, basename, "Cargo.toml") or std.mem.eql(u8, basename, "go.mod") or
        std.mem.eql(u8, basename, "build.zig.zon") or std.mem.eql(u8, basename, "zigeffect.project.json"))
    {
        return .package_manifest;
    }
    if (std.mem.eql(u8, basename, "build.zig") or std.mem.eql(u8, basename, "Makefile") or
        std.mem.eql(u8, basename, "Dockerfile"))
    {
        return .build_definition;
    }
    if (std.mem.endsWith(u8, basename, ".lock") or std.mem.eql(u8, basename, "bun.lock") or std.mem.eql(u8, basename, "go.sum")) return .lockfile;
    if (std.mem.endsWith(u8, basename, ".proto") or std.mem.eql(u8, basename, "buf.yaml") or std.mem.eql(u8, basename, "openapi.yaml")) return .protocol;
    if (std.mem.endsWith(u8, basename, ".md") or std.mem.endsWith(u8, basename, ".mdx")) return .documentation;
    if (isAssetExtension(std.fs.path.extension(basename))) return .asset;
    if (hasComponent(path, "migrations") or hasComponent(path, "migration")) return .migration;
    if (hasComponent(path, ".github") or std.mem.eql(u8, basename, "gitlab-ci.yml")) return .ci;
    if (std.mem.indexOf(u8, basename, "deploy") != null or std.mem.eql(u8, basename, "cloudbuild.yaml")) return .deployment;
    const language = languageFor(path);
    if (language == .json or language == .yaml or language == .toml) return .config;
    if (language == .proto or language == .sql) return .schema;
    if (language != .unknown and language != .media and language != .markdown) return .source;
    return .unknown;
}

fn isAssetExtension(extension: []const u8) bool {
    for ([_][]const u8{ ".png", ".jpg", ".jpeg", ".gif", ".svg", ".webp", ".ico", ".mp4", ".mov", ".webm", ".pdf", ".woff", ".woff2" }) |asset| {
        if (std.mem.eql(u8, extension, asset)) return true;
    }
    return false;
}

fn isTestPath(path: []const u8, basename: []const u8) bool {
    for ([_][]const u8{ "test", "tests", "__tests__", "spec", "specs", "__specs__" }) |component| {
        if (hasComponent(path, component)) return true;
    }
    return std.mem.endsWith(u8, basename, "_test.zig") or std.mem.startsWith(u8, basename, "test_") or
        std.mem.indexOf(u8, basename, ".test.") != null or std.mem.indexOf(u8, basename, ".spec.") != null;
}

fn hasComponent(path: []const u8, wanted: []const u8) bool {
    var components = std.mem.splitScalar(u8, path, '/');
    while (components.next()) |component| if (std.mem.eql(u8, component, wanted)) return true;
    return false;
}
