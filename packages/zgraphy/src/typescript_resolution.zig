const std = @import("std");
const typescript_parser = @import("typescript_parser.zig");
const owned = @import("memory.zig");

pub const schema = "zgraphy.typescript-module-resolution.v1";
pub const schema_version: u32 = 1;
pub const resolver_version = "inventory-tsconfig-workspace-v1";

pub const Status = enum(u8) {
    resolved,
    external,
    unresolved,
    ambiguous,
    invalid,
    exhausted,
};

pub const Rule = enum(u8) {
    exact,
    esm_source_substitution,
    source_extension,
    directory_index,
    tsconfig_exact,
    tsconfig_wildcard,
    tsconfig_directory_prefix,
    tsconfig_base_url,
    workspace_export,
    workspace_entry_fallback,
};

pub const DiagnosticKind = enum(u8) {
    config_invalid,
    config_cycle,
    config_limit,
    workspace_invalid,
    package_invalid,
    package_escape,
    package_limit,
    duplicate_package,
    candidate_limit,
    result_limit,
};

pub const Resolution = struct {
    source_path: []const u8,
    specifier: []const u8,
    import_kind: typescript_parser.ImportKind,
    type_only: bool,
    span: typescript_parser.Span,
    status: Status,
    candidate_start: usize,
    candidate_count: usize,
};

pub const Candidate = struct {
    resolution_index: usize,
    target_path: []const u8,
    rule: Rule,
    authority_path: []const u8,
    rank: usize,
};

pub const Diagnostic = struct {
    kind: DiagnosticKind,
    source_path: []const u8,
    detail: []const u8,
};

pub const Summary = struct {
    imports: usize = 0,
    resolved: usize = 0,
    external: usize = 0,
    unresolved: usize = 0,
    ambiguous: usize = 0,
    invalid: usize = 0,
    exhausted: usize = 0,
    candidates: usize = 0,
    diagnostics: usize = 0,
};

pub const Result = struct {
    allocator: std.mem.Allocator,
    resolutions: []Resolution,
    candidates: []Candidate,
    diagnostics: []Diagnostic,
    summary: Summary,
    fingerprint: [32]u8,

    pub fn deinit(self: *Result) void {
        for (self.resolutions) |resolution| {
            self.allocator.free(resolution.source_path);
            self.allocator.free(resolution.specifier);
        }
        self.allocator.free(self.resolutions);
        for (self.candidates) |candidate| {
            self.allocator.free(candidate.target_path);
            if (candidate.authority_path.len > 0) self.allocator.free(candidate.authority_path);
        }
        self.allocator.free(self.candidates);
        for (self.diagnostics) |diagnostic| {
            self.allocator.free(diagnostic.source_path);
            if (diagnostic.detail.len > 0) self.allocator.free(diagnostic.detail);
        }
        self.allocator.free(self.diagnostics);
        self.resolutions = &.{};
        self.candidates = &.{};
        self.diagnostics = &.{};
    }

    pub fn findResolution(
        self: *const Result,
        source_path: []const u8,
        specifier: []const u8,
        import_kind: typescript_parser.ImportKind,
    ) ?*const Resolution {
        for (self.resolutions, 0..) |resolution, index| {
            if (std.mem.eql(u8, resolution.source_path, source_path) and
                std.mem.eql(u8, resolution.specifier, specifier) and
                resolution.import_kind == import_kind)
            {
                return &self.resolutions[index];
            }
        }
        return null;
    }

    pub fn candidatesFor(self: *const Result, resolution: *const Resolution) []const Candidate {
        return self.candidates[resolution.candidate_start..][0..resolution.candidate_count];
    }

    pub fn hasDiagnostic(self: *const Result, kind: DiagnosticKind, source_path: []const u8) bool {
        for (self.diagnostics) |diagnostic| {
            if (diagnostic.kind == kind and std.mem.eql(u8, diagnostic.source_path, source_path)) return true;
        }
        return false;
    }
};

pub const Options = struct {
    max_files: usize = 100_000,
    max_imports: usize = 1_000_000,
    max_documents: usize = 100_000,
    max_document_bytes: usize = 4 * 1024 * 1024,
    max_total_document_bytes: usize = 256 * 1024 * 1024,
    max_configs: usize = 10_000,
    max_packages: usize = 100_000,
    max_workspace_patterns: usize = 100_000,
    max_aliases: usize = 100_000,
    max_alias_targets: usize = 64,
    max_config_depth: usize = 64,
    max_export_depth: usize = 64,
    max_export_alternatives: usize = 4096,
    max_candidates_per_import: usize = 64,
    max_candidates: usize = 4_000_000,
    max_diagnostics: usize = 100_000,
    max_path_bytes: usize = std.fs.max_path_bytes,
    max_result_bytes: usize = 512 * 1024 * 1024,
};

const Document = struct {
    path: []const u8,
    bytes: []const u8,
};

const ImportFact = struct {
    source_path: []const u8,
    specifier: []const u8,
    kind: typescript_parser.ImportKind,
    type_only: bool,
    span: typescript_parser.Span,
};

pub const Corpus = struct {
    allocator: std.mem.Allocator,
    options: Options,
    file_paths: std.ArrayList([]const u8) = .empty,
    documents: std.ArrayList(Document) = .empty,
    parsed_paths: std.ArrayList([]const u8) = .empty,
    imports: std.ArrayList(ImportFact) = .empty,
    total_document_bytes: usize = 0,

    pub fn init(allocator: std.mem.Allocator, options: Options) !Corpus {
        try validateOptions(options);
        return .{ .allocator = allocator, .options = options };
    }

    pub fn deinit(self: *Corpus) void {
        for (self.file_paths.items) |path| self.allocator.free(path);
        self.file_paths.deinit(self.allocator);
        for (self.documents.items) |document| {
            self.allocator.free(document.path);
            self.allocator.free(document.bytes);
        }
        self.documents.deinit(self.allocator);
        for (self.parsed_paths.items) |path| self.allocator.free(path);
        self.parsed_paths.deinit(self.allocator);
        for (self.imports.items) |fact| {
            self.allocator.free(fact.source_path);
            self.allocator.free(fact.specifier);
        }
        self.imports.deinit(self.allocator);
    }

    pub fn addFile(self: *Corpus, path: []const u8) !void {
        if (path.len > self.options.max_path_bytes) return error.TypeScriptResolutionPathLimitExceeded;
        if (!validRelativePath(path)) return error.InvalidTypeScriptResolutionPath;
        for (self.file_paths.items) |existing| {
            if (std.mem.eql(u8, existing, path)) return error.DuplicateTypeScriptResolutionFile;
        }
        if (self.file_paths.items.len >= self.options.max_files) return error.TypeScriptResolutionFileLimitExceeded;
        const copied = try owned.copy(u8, self.allocator, path);
        errdefer self.allocator.free(copied);
        try self.file_paths.append(self.allocator, copied);
    }

    pub fn addDocument(self: *Corpus, path: []const u8, bytes: []const u8) !void {
        if (!self.hasFile(path)) return error.TypeScriptResolutionDocumentOutsideInventory;
        for (self.documents.items) |document| {
            if (std.mem.eql(u8, document.path, path)) return error.DuplicateTypeScriptResolutionDocument;
        }
        if (self.documents.items.len >= self.options.max_documents) return error.TypeScriptResolutionDocumentLimitExceeded;
        if (bytes.len > self.options.max_document_bytes) return error.TypeScriptResolutionDocumentByteLimitExceeded;
        const total = std.math.add(usize, self.total_document_bytes, bytes.len) catch return error.TypeScriptResolutionDocumentByteLimitExceeded;
        if (total > self.options.max_total_document_bytes) return error.TypeScriptResolutionDocumentByteLimitExceeded;
        const copied_path = try owned.copy(u8, self.allocator, path);
        errdefer self.allocator.free(copied_path);
        const copied_bytes = try owned.copy(u8, self.allocator, bytes);
        errdefer self.allocator.free(copied_bytes);
        try self.documents.append(self.allocator, .{ .path = copied_path, .bytes = copied_bytes });
        self.total_document_bytes = total;
    }

    pub fn addParsed(self: *Corpus, parsed: *const typescript_parser.Result) !void {
        try typescript_parser.validate(parsed);
        if (!self.hasFile(parsed.path)) return error.TypeScriptResolutionSourceOutsideInventory;
        for (self.parsed_paths.items) |path| {
            if (std.mem.eql(u8, path, parsed.path)) return error.DuplicateTypeScriptResolutionSource;
        }
        const import_end = std.math.add(usize, self.imports.items.len, parsed.imports.len) catch return error.TypeScriptResolutionImportLimitExceeded;
        if (import_end > self.options.max_imports) return error.TypeScriptResolutionImportLimitExceeded;
        const original_import_count = self.imports.items.len;
        errdefer {
            while (self.imports.items.len > original_import_count) {
                const fact = self.imports.pop().?;
                self.allocator.free(fact.source_path);
                self.allocator.free(fact.specifier);
            }
        }
        const parsed_path = try owned.copy(u8, self.allocator, parsed.path);
        errdefer self.allocator.free(parsed_path);
        for (parsed.imports) |import| {
            const source_path = try owned.copy(u8, self.allocator, parsed.path);
            errdefer self.allocator.free(source_path);
            const specifier = try owned.copy(u8, self.allocator, import.target);
            errdefer self.allocator.free(specifier);
            try self.imports.append(self.allocator, .{
                .source_path = source_path,
                .specifier = specifier,
                .kind = import.kind,
                .type_only = import.type_only,
                .span = import.span,
            });
        }
        try self.parsed_paths.append(self.allocator, parsed_path);
    }

    pub fn resolve(self: *const Corpus) !Result {
        var engine = Engine.init(self);
        defer engine.deinit();
        return engine.run();
    }

    fn hasFile(self: *const Corpus, path: []const u8) bool {
        for (self.file_paths.items) |existing| if (std.mem.eql(u8, existing, path)) return true;
        return false;
    }
};

pub fn validate(result: *const Result) !void {
    var expected = Summary{};
    var candidate_cursor: usize = 0;
    var previous_resolution: ?Resolution = null;
    for (result.resolutions, 0..) |resolution, resolution_index| {
        const end = std.math.add(usize, resolution.candidate_start, resolution.candidate_count) catch return error.InvalidTypeScriptResolutionCandidateRange;
        if (resolution.candidate_start != candidate_cursor or end > result.candidates.len or
            !validRelativePath(resolution.source_path) or resolution.specifier.len == 0)
        {
            return error.InvalidTypeScriptResolutionCandidateRange;
        }
        if (previous_resolution) |previous| {
            if (!lessThanOrEqualResolution(previous, resolution)) return error.UnsortedTypeScriptResolutions;
        }
        previous_resolution = resolution;
        expected.imports += 1;
        switch (resolution.status) {
            .resolved => expected.resolved += 1,
            .external => expected.external += 1,
            .unresolved => expected.unresolved += 1,
            .ambiguous => expected.ambiguous += 1,
            .invalid => expected.invalid += 1,
            .exhausted => expected.exhausted += 1,
        }
        if ((resolution.status == .resolved and resolution.candidate_count != 1) or
            (resolution.status == .ambiguous and resolution.candidate_count < 2) or
            ((resolution.status == .external or resolution.status == .unresolved or resolution.status == .invalid or resolution.status == .exhausted) and resolution.candidate_count != 0))
        {
            return error.InvalidTypeScriptResolutionStatus;
        }
        for (result.candidates[resolution.candidate_start..end], 0..) |candidate, rank| {
            if (candidate.resolution_index != resolution_index or candidate.rank != rank or !validRelativePath(candidate.target_path)) {
                return error.InvalidTypeScriptResolutionCandidate;
            }
        }
        candidate_cursor = end;
    }
    expected.candidates = result.candidates.len;
    expected.diagnostics = result.diagnostics.len;
    if (!std.meta.eql(expected, result.summary) or candidate_cursor != result.candidates.len) {
        return error.InvalidTypeScriptResolutionSummary;
    }
    var previous_diagnostic: ?Diagnostic = null;
    for (result.diagnostics) |diagnostic| {
        if (diagnostic.source_path.len == 0 or !validRelativePath(diagnostic.source_path)) return error.InvalidTypeScriptResolutionDiagnostic;
        if (previous_diagnostic) |previous| {
            if (!lessThanOrEqualDiagnostic(previous, diagnostic)) return error.UnsortedTypeScriptResolutionDiagnostics;
        }
        previous_diagnostic = diagnostic;
    }
    const expected_fingerprint = resolutionFingerprint(result.resolutions, result.candidates, result.diagnostics, result.summary);
    if (!std.mem.eql(u8, &expected_fingerprint, &result.fingerprint)) return error.InvalidTypeScriptResolutionFingerprint;
}

const Alias = struct {
    pattern: []const u8,
    targets: []const []const u8,
    base_root: []const u8,
    authority_path: []const u8,
};

const Config = struct {
    path: []const u8,
    directory: []const u8,
    base_root: []const u8,
    extends: []const []const u8,
    aliases: []const Alias,
    selectable: bool,
};

const WorkspacePattern = struct {
    value: []const u8,
    negated: bool,
};

const Workspace = struct {
    root: []const u8,
    authority_path: []const u8,
    patterns: []const WorkspacePattern,
};

const Package = struct {
    name: []const u8,
    root: []const u8,
    manifest_path: []const u8,
    workspace_root: []const u8,
    exports: ?std.json.Value,
    source: ?[]const u8,
    types: ?[]const u8,
    svelte: ?[]const u8,
    module: ?[]const u8,
    browser: ?[]const u8,
    main: ?[]const u8,
};

const TempDiagnostic = struct {
    kind: DiagnosticKind,
    source_path: []const u8,
    detail: []const u8,
};

const TempCandidate = struct {
    target_path: []const u8,
    rule: Rule,
    authority_path: []const u8,
};

const PathMatch = struct {
    path: []const u8,
    rule: Rule,
};

const ResolutionDisposition = enum {
    local,
    external,
    unresolved,
    invalid,
};

const MatchState = enum {
    no_match,
    matched,
};

const Engine = struct {
    corpus: *const Corpus,
    arena: std.heap.ArenaAllocator,
    configs: std.ArrayList(Config) = .empty,
    workspaces: std.ArrayList(Workspace) = .empty,
    packages: std.ArrayList(Package) = .empty,
    diagnostics: std.ArrayList(TempDiagnostic) = .empty,
    alias_count: usize = 0,
    workspace_pattern_count: usize = 0,

    fn init(corpus: *const Corpus) Engine {
        return .{
            .corpus = corpus,
            .arena = std.heap.ArenaAllocator.init(corpus.allocator),
        };
    }

    fn deinit(self: *Engine) void {
        self.configs.deinit(self.arena.allocator());
        self.workspaces.deinit(self.arena.allocator());
        self.packages.deinit(self.arena.allocator());
        self.diagnostics.deinit(self.arena.allocator());
        self.arena.deinit();
    }

    fn run(self: *Engine) !Result {
        try self.buildConfigs();
        try self.buildWorkspaces();
        try self.buildPackages();
        return self.buildResult();
    }

    fn buildConfigs(self: *Engine) !void {
        for (self.corpus.documents.items) |document| {
            if (!isConfigDocument(document.path)) continue;
            if (self.configs.items.len >= self.corpus.options.max_configs) return error.TypeScriptResolutionConfigLimitExceeded;
            const value = try self.parseJsonc(document.path, document.bytes, .config_invalid) orelse continue;
            const object = switch (value) {
                .object => |object| object,
                else => {
                    try self.appendDiagnostic(.config_invalid, document.path, "configuration root is not an object");
                    continue;
                },
            };
            if (!isSelectableConfig(document.path) and object.get("extends") == null and object.get("compilerOptions") == null) continue;
            const directory = std.fs.path.dirname(document.path) orelse "";
            var base_root = directory;
            var aliases: std.ArrayList(Alias) = .empty;
            var extends: std.ArrayList([]const u8) = .empty;
            if (object.get("extends")) |extends_value| {
                try self.appendExtends(directory, extends_value, &extends, document.path);
            }
            if (object.get("compilerOptions")) |compiler_value| switch (compiler_value) {
                .object => |compiler| {
                    if (jsonString(compiler.get("baseUrl"))) |base_url| {
                        if (try normalizeRepositoryPath(self.arena.allocator(), directory, base_url, true)) |normalized| {
                            base_root = normalized;
                        } else {
                            try self.appendDiagnostic(.config_invalid, document.path, "baseUrl escapes the repository");
                        }
                    }
                    if (compiler.get("paths")) |paths_value| switch (paths_value) {
                        .object => |paths_object| {
                            var iterator = paths_object.iterator();
                            while (iterator.next()) |entry| {
                                if (!validAliasPattern(entry.key_ptr.*)) {
                                    try self.appendDiagnostic(.config_invalid, document.path, "paths contains an invalid alias pattern");
                                    continue;
                                }
                                if (self.alias_count >= self.corpus.options.max_aliases) return error.TypeScriptResolutionAliasLimitExceeded;
                                const targets = try self.aliasTargets(entry.value_ptr.*, document.path);
                                if (targets.len == 0) continue;
                                try aliases.append(self.arena.allocator(), .{
                                    .pattern = entry.key_ptr.*,
                                    .targets = targets,
                                    .base_root = base_root,
                                    .authority_path = document.path,
                                });
                                self.alias_count += 1;
                            }
                        },
                        else => try self.appendDiagnostic(.config_invalid, document.path, "compilerOptions.paths is not an object"),
                    };
                },
                else => try self.appendDiagnostic(.config_invalid, document.path, "compilerOptions is not an object"),
            };
            try self.configs.append(self.arena.allocator(), .{
                .path = document.path,
                .directory = directory,
                .base_root = base_root,
                .extends = try extends.toOwnedSlice(self.arena.allocator()),
                .aliases = try aliases.toOwnedSlice(self.arena.allocator()),
                .selectable = isSelectableConfig(document.path),
            });
        }
        std.mem.sort(Config, self.configs.items, {}, lessThanConfig);
    }

    fn appendExtends(
        self: *Engine,
        directory: []const u8,
        value: std.json.Value,
        output: *std.ArrayList([]const u8),
        source_path: []const u8,
    ) !void {
        switch (value) {
            .string => |target| try self.appendExtendTarget(directory, target, output, source_path),
            .array => |array| {
                for (array.items) |item| switch (item) {
                    .string => |target| try self.appendExtendTarget(directory, target, output, source_path),
                    else => try self.appendDiagnostic(.config_invalid, source_path, "extends array contains a non-string target"),
                };
            },
            else => try self.appendDiagnostic(.config_invalid, source_path, "extends is not a string or array"),
        }
    }

    fn appendExtendTarget(
        self: *Engine,
        directory: []const u8,
        target: []const u8,
        output: *std.ArrayList([]const u8),
        source_path: []const u8,
    ) !void {
        const normalized = try normalizeRepositoryPath(self.arena.allocator(), directory, target, false) orelse {
            try self.appendDiagnostic(.config_invalid, source_path, "extends target escapes the repository");
            return;
        };
        if (self.hasDocument(normalized)) {
            try output.append(self.arena.allocator(), normalized);
            return;
        }
        const with_json = try std.fmt.allocPrint(self.arena.allocator(), "{s}.json", .{normalized});
        try output.append(self.arena.allocator(), with_json);
    }

    fn aliasTargets(self: *Engine, value: std.json.Value, source_path: []const u8) ![]const []const u8 {
        var targets: std.ArrayList([]const u8) = .empty;
        switch (value) {
            .string => |target| try targets.append(self.arena.allocator(), target),
            .array => |array| {
                for (array.items) |item| switch (item) {
                    .string => |target| {
                        if (targets.items.len >= self.corpus.options.max_alias_targets) return error.TypeScriptResolutionAliasTargetLimitExceeded;
                        try targets.append(self.arena.allocator(), target);
                    },
                    else => try self.appendDiagnostic(.config_invalid, source_path, "paths target contains a non-string value"),
                };
            },
            else => try self.appendDiagnostic(.config_invalid, source_path, "paths target is not a string or array"),
        }
        return targets.toOwnedSlice(self.arena.allocator());
    }

    fn parseJsonc(
        self: *Engine,
        source_path: []const u8,
        bytes: []const u8,
        diagnostic_kind: DiagnosticKind,
    ) !?std.json.Value {
        const normalized = stripJsoncAlloc(self.arena.allocator(), bytes) catch {
            try self.appendDiagnostic(diagnostic_kind, source_path, "document could not be normalized");
            return null;
        };
        return std.json.parseFromSliceLeaky(std.json.Value, self.arena.allocator(), normalized, .{ .allocate = .alloc_always }) catch {
            try self.appendDiagnostic(diagnostic_kind, source_path, "document is not valid JSONC");
            return null;
        };
    }

    fn hasDocument(self: *const Engine, path: []const u8) bool {
        for (self.corpus.documents.items) |document| if (std.mem.eql(u8, document.path, path)) return true;
        return false;
    }

    fn buildWorkspaces(self: *Engine) !void {
        for (self.corpus.documents.items) |document| {
            if (!std.mem.eql(u8, std.fs.path.basename(document.path), "pnpm-workspace.yaml")) continue;
            var patterns: std.ArrayList(WorkspacePattern) = .empty;
            var in_packages = false;
            var lines = std.mem.splitScalar(u8, document.bytes, '\n');
            while (lines.next()) |raw_line| {
                const line = std.mem.trim(u8, raw_line, " \t\r");
                if (line.len == 0 or line[0] == '#') continue;
                if (std.mem.eql(u8, line, "packages:")) {
                    in_packages = true;
                    continue;
                }
                if (!in_packages) continue;
                if (!std.mem.startsWith(u8, line, "-")) {
                    if (raw_line.len > 0 and raw_line[0] != ' ' and raw_line[0] != '\t') break;
                    continue;
                }
                var pattern = std.mem.trim(u8, line[1..], " \t\r");
                pattern = unquote(pattern);
                if (pattern.len == 0) continue;
                const negated = pattern[0] == '!';
                if (negated) pattern = pattern[1..];
                if (!validWorkspacePattern(pattern)) {
                    try self.appendDiagnostic(.workspace_invalid, document.path, "pnpm workspace contains an unsafe pattern");
                    continue;
                }
                if (self.workspace_pattern_count >= self.corpus.options.max_workspace_patterns) return error.TypeScriptResolutionWorkspacePatternLimitExceeded;
                try patterns.append(self.arena.allocator(), .{ .value = pattern, .negated = negated });
                self.workspace_pattern_count += 1;
            }
            if (patterns.items.len == 0) {
                try self.appendDiagnostic(.workspace_invalid, document.path, "pnpm workspace has no package patterns");
                continue;
            }
            try self.workspaces.append(self.arena.allocator(), .{
                .root = std.fs.path.dirname(document.path) orelse "",
                .authority_path = document.path,
                .patterns = try patterns.toOwnedSlice(self.arena.allocator()),
            });
        }

        for (self.corpus.documents.items) |document| {
            if (!std.mem.eql(u8, std.fs.path.basename(document.path), "package.json")) continue;
            const root = std.fs.path.dirname(document.path) orelse "";
            if (self.hasPnpmWorkspace(root)) continue;
            const value = try self.parseJsonc(document.path, document.bytes, .workspace_invalid) orelse continue;
            const object = switch (value) {
                .object => |object| object,
                else => continue,
            };
            const workspaces_value = object.get("workspaces") orelse continue;
            var patterns: std.ArrayList(WorkspacePattern) = .empty;
            try self.appendWorkspacePatterns(workspaces_value, &patterns, document.path);
            if (patterns.items.len == 0) continue;
            try self.workspaces.append(self.arena.allocator(), .{
                .root = root,
                .authority_path = document.path,
                .patterns = try patterns.toOwnedSlice(self.arena.allocator()),
            });
        }
        std.mem.sort(Workspace, self.workspaces.items, {}, lessThanWorkspace);
    }

    fn appendWorkspacePatterns(
        self: *Engine,
        value: std.json.Value,
        patterns: *std.ArrayList(WorkspacePattern),
        source_path: []const u8,
    ) !void {
        const selected = switch (value) {
            .array => value,
            .object => |object| if (object.get("packages")) |packages| packages else {
                try self.appendDiagnostic(.workspace_invalid, source_path, "workspace object has no packages array");
                return;
            },
            else => {
                try self.appendDiagnostic(.workspace_invalid, source_path, "workspaces is not an array or packages object");
                return;
            },
        };
        switch (selected) {
            .array => |array| for (array.items) |item| switch (item) {
                .string => |raw_pattern| {
                    var pattern = raw_pattern;
                    const negated = pattern.len > 0 and pattern[0] == '!';
                    if (negated) pattern = pattern[1..];
                    if (!validWorkspacePattern(pattern)) {
                        try self.appendDiagnostic(.workspace_invalid, source_path, "workspace contains an unsafe pattern");
                        continue;
                    }
                    if (self.workspace_pattern_count >= self.corpus.options.max_workspace_patterns) return error.TypeScriptResolutionWorkspacePatternLimitExceeded;
                    try patterns.append(self.arena.allocator(), .{ .value = pattern, .negated = negated });
                    self.workspace_pattern_count += 1;
                },
                else => try self.appendDiagnostic(.workspace_invalid, source_path, "workspace array contains a non-string pattern"),
            },
            else => try self.appendDiagnostic(.workspace_invalid, source_path, "workspace packages value is not an array"),
        }
    }

    fn hasPnpmWorkspace(self: *const Engine, root: []const u8) bool {
        for (self.workspaces.items) |workspace| {
            if (std.mem.eql(u8, workspace.root, root) and std.mem.eql(u8, std.fs.path.basename(workspace.authority_path), "pnpm-workspace.yaml")) return true;
        }
        return false;
    }

    fn buildPackages(self: *Engine) !void {
        for (self.corpus.documents.items) |document| {
            if (!std.mem.eql(u8, std.fs.path.basename(document.path), "package.json")) continue;
            const package_root = std.fs.path.dirname(document.path) orelse "";
            const workspace = self.workspaceForPackage(package_root) orelse continue;
            if (self.packages.items.len >= self.corpus.options.max_packages) return error.TypeScriptResolutionPackageLimitExceeded;
            const value = try self.parseJsonc(document.path, document.bytes, .package_invalid) orelse continue;
            const object = switch (value) {
                .object => |object| object,
                else => {
                    try self.appendDiagnostic(.package_invalid, document.path, "package manifest root is not an object");
                    continue;
                },
            };
            const name = jsonString(object.get("name")) orelse {
                try self.appendDiagnostic(.package_invalid, document.path, "workspace package has no name");
                continue;
            };
            if (!validPackageName(name)) {
                try self.appendDiagnostic(.package_invalid, document.path, "workspace package has an invalid name");
                continue;
            }
            try self.packages.append(self.arena.allocator(), .{
                .name = name,
                .root = package_root,
                .manifest_path = document.path,
                .workspace_root = workspace.root,
                .exports = object.get("exports"),
                .source = jsonString(object.get("source")),
                .types = jsonString(object.get("types")),
                .svelte = jsonString(object.get("svelte")),
                .module = jsonString(object.get("module")),
                .browser = jsonString(object.get("browser")),
                .main = jsonString(object.get("main")),
            });
        }
        std.mem.sort(Package, self.packages.items, {}, lessThanPackage);
        var index: usize = 0;
        while (index < self.packages.items.len) {
            var end = index + 1;
            while (end < self.packages.items.len and
                std.mem.eql(u8, self.packages.items[index].workspace_root, self.packages.items[end].workspace_root) and
                std.mem.eql(u8, self.packages.items[index].name, self.packages.items[end].name)) : (end += 1)
            {}
            if (end - index > 1) {
                for (self.packages.items[index..end]) |package| {
                    try self.appendDiagnostic(.duplicate_package, package.manifest_path, "workspace package name is duplicated");
                }
            }
            index = end;
        }
    }

    fn workspaceForPackage(self: *const Engine, package_root: []const u8) ?*const Workspace {
        var best: ?*const Workspace = null;
        for (self.workspaces.items, 0..) |workspace, index| {
            if (!pathWithinRoot(package_root, workspace.root) or std.mem.eql(u8, package_root, workspace.root)) continue;
            const relative = relativeToRoot(package_root, workspace.root) orelse continue;
            var included = false;
            for (workspace.patterns) |pattern| {
                if (workspaceGlobMatches(pattern.value, relative)) included = !pattern.negated;
            }
            if (!included) continue;
            if (best == null or workspace.root.len > best.?.root.len) best = &self.workspaces.items[index];
        }
        return best;
    }

    fn workspaceForSource(self: *const Engine, source_path: []const u8) ?*const Workspace {
        var best: ?*const Workspace = null;
        for (self.workspaces.items, 0..) |workspace, index| {
            if (!pathWithinRoot(source_path, workspace.root)) continue;
            if (best == null or workspace.root.len > best.?.root.len) best = &self.workspaces.items[index];
        }
        return best;
    }

    fn buildResult(self: *Engine) !Result {
        var resolutions: std.ArrayList(Resolution) = .empty;
        errdefer deinitResolutionList(self.corpus.allocator, &resolutions);
        var candidates: std.ArrayList(Candidate) = .empty;
        errdefer deinitCandidateList(self.corpus.allocator, &candidates);
        var diagnostics: std.ArrayList(Diagnostic) = .empty;
        errdefer deinitDiagnosticList(self.corpus.allocator, &diagnostics);
        var summary = Summary{};
        var result_bytes: usize = 0;

        const order = try self.arena.allocator().alloc(usize, self.corpus.imports.items.len);
        for (order, 0..) |*item, index| item.* = index;
        std.mem.sort(usize, order, self.corpus, lessThanImportIndex);
        for (order) |fact_index| {
            const fact = &self.corpus.imports.items[fact_index];
            var temporary: std.ArrayList(TempCandidate) = .empty;
            defer temporary.deinit(self.arena.allocator());
            const disposition = try self.resolveFact(fact, &temporary);
            std.mem.sort(TempCandidate, temporary.items, {}, lessThanTempCandidate);
            deduplicateTempCandidates(&temporary);

            var status: Status = switch (disposition) {
                .local => switch (temporary.items.len) {
                    0 => .unresolved,
                    1 => .resolved,
                    else => .ambiguous,
                },
                .external => .external,
                .unresolved => .unresolved,
                .invalid => .invalid,
            };
            const candidate_end = std.math.add(usize, candidates.items.len, temporary.items.len) catch return error.TypeScriptResolutionCandidateLimitExceeded;
            if (temporary.items.len > self.corpus.options.max_candidates_per_import or candidate_end > self.corpus.options.max_candidates) {
                status = .exhausted;
                temporary.items.len = 0;
                try self.appendDiagnostic(.candidate_limit, fact.source_path, "module candidate limit was exhausted");
            }

            const resolution_index = resolutions.items.len;
            const candidate_start = candidates.items.len;
            for (temporary.items, 0..) |candidate, rank| {
                result_bytes = try consumeResultBytes(result_bytes, @sizeOf(Candidate) + candidate.target_path.len + candidate.authority_path.len, self.corpus.options.max_result_bytes);
                const target_path = try owned.copy(u8, self.corpus.allocator, candidate.target_path);
                errdefer self.corpus.allocator.free(target_path);
                const authority_path = if (candidate.authority_path.len > 0) try owned.copy(u8, self.corpus.allocator, candidate.authority_path) else "";
                errdefer if (authority_path.len > 0) self.corpus.allocator.free(authority_path);
                try candidates.append(self.corpus.allocator, .{
                    .resolution_index = resolution_index,
                    .target_path = target_path,
                    .rule = candidate.rule,
                    .authority_path = authority_path,
                    .rank = rank,
                });
            }
            result_bytes = try consumeResultBytes(result_bytes, @sizeOf(Resolution) + fact.source_path.len + fact.specifier.len, self.corpus.options.max_result_bytes);
            const source_path = try owned.copy(u8, self.corpus.allocator, fact.source_path);
            errdefer self.corpus.allocator.free(source_path);
            const specifier = try owned.copy(u8, self.corpus.allocator, fact.specifier);
            errdefer self.corpus.allocator.free(specifier);
            try resolutions.append(self.corpus.allocator, .{
                .source_path = source_path,
                .specifier = specifier,
                .import_kind = fact.kind,
                .type_only = fact.type_only,
                .span = fact.span,
                .status = status,
                .candidate_start = candidate_start,
                .candidate_count = temporary.items.len,
            });
            summary.imports += 1;
            switch (status) {
                .resolved => summary.resolved += 1,
                .external => summary.external += 1,
                .unresolved => summary.unresolved += 1,
                .ambiguous => summary.ambiguous += 1,
                .invalid => summary.invalid += 1,
                .exhausted => summary.exhausted += 1,
            }
        }
        summary.candidates = candidates.items.len;

        std.mem.sort(TempDiagnostic, self.diagnostics.items, {}, lessThanTempDiagnostic);
        for (self.diagnostics.items) |diagnostic| {
            result_bytes = try consumeResultBytes(result_bytes, @sizeOf(Diagnostic) + diagnostic.source_path.len + diagnostic.detail.len, self.corpus.options.max_result_bytes);
            const source_path = try owned.copy(u8, self.corpus.allocator, diagnostic.source_path);
            errdefer self.corpus.allocator.free(source_path);
            const detail = if (diagnostic.detail.len > 0) try owned.copy(u8, self.corpus.allocator, diagnostic.detail) else "";
            errdefer if (detail.len > 0) self.corpus.allocator.free(detail);
            try diagnostics.append(self.corpus.allocator, .{
                .kind = diagnostic.kind,
                .source_path = source_path,
                .detail = detail,
            });
        }
        summary.diagnostics = diagnostics.items.len;

        const resolution_slice = try resolutions.toOwnedSlice(self.corpus.allocator);
        const candidate_slice = candidates.toOwnedSlice(self.corpus.allocator) catch |failure| {
            var values = std.ArrayList(Resolution).fromOwnedSlice(resolution_slice);
            deinitResolutionList(self.corpus.allocator, &values);
            return failure;
        };
        const diagnostic_slice = diagnostics.toOwnedSlice(self.corpus.allocator) catch |failure| {
            var resolution_values = std.ArrayList(Resolution).fromOwnedSlice(resolution_slice);
            deinitResolutionList(self.corpus.allocator, &resolution_values);
            var values = std.ArrayList(Candidate).fromOwnedSlice(candidate_slice);
            deinitCandidateList(self.corpus.allocator, &values);
            return failure;
        };
        var result = Result{
            .allocator = self.corpus.allocator,
            .resolutions = resolution_slice,
            .candidates = candidate_slice,
            .diagnostics = diagnostic_slice,
            .summary = summary,
            .fingerprint = resolutionFingerprint(resolution_slice, candidate_slice, diagnostic_slice, summary),
        };
        errdefer result.deinit();
        try validate(&result);
        return result;
    }

    fn resolveFact(self: *Engine, fact: *const ImportFact, candidates: *std.ArrayList(TempCandidate)) !ResolutionDisposition {
        if (fact.specifier.len == 0 or std.fs.path.isAbsolute(fact.specifier) or std.mem.indexOfScalar(u8, fact.specifier, '\\') != null) return .invalid;
        if (isRelativeSpecifier(fact.specifier)) {
            const parent = std.fs.path.dirname(fact.source_path) orelse "";
            const normalized = try normalizeRepositoryPath(self.arena.allocator(), parent, fact.specifier, false) orelse return .invalid;
            if (try self.resolveInventoryPath(normalized)) |matched| {
                try candidates.append(self.arena.allocator(), .{
                    .target_path = matched.path,
                    .rule = matched.rule,
                    .authority_path = "",
                });
                return .local;
            }
            return .unresolved;
        }

        const config_index = self.nearestConfigIndex(fact.source_path);
        if (config_index) |index| {
            var aliases: std.ArrayList(Alias) = .empty;
            defer aliases.deinit(self.arena.allocator());
            var stack: std.ArrayList(usize) = .empty;
            defer stack.deinit(self.arena.allocator());
            try self.collectEffectiveAliases(index, &stack, &aliases);
            if (try self.resolveAlias(fact.specifier, aliases.items, candidates) == .matched) {
                return if (candidates.items.len > 0) .local else .unresolved;
            }
            const config = self.configs.items[index];
            if (try normalizeRepositoryPath(self.arena.allocator(), config.base_root, fact.specifier, false)) |base_candidate| {
                if (try self.resolveInventoryPath(base_candidate)) |matched| {
                    try candidates.append(self.arena.allocator(), .{
                        .target_path = matched.path,
                        .rule = .tsconfig_base_url,
                        .authority_path = config.path,
                    });
                    return .local;
                }
            }
        }

        if (try self.resolveWorkspace(fact.source_path, fact.specifier, candidates) == .matched) {
            return if (candidates.items.len > 0) .local else .unresolved;
        }
        return if (validBareSpecifier(fact.specifier)) .external else .invalid;
    }

    fn nearestConfigIndex(self: *const Engine, source_path: []const u8) ?usize {
        var best: ?usize = null;
        for (self.configs.items, 0..) |config, index| {
            if (!config.selectable or !pathWithinRoot(source_path, config.directory)) continue;
            if (best == null or config.directory.len > self.configs.items[best.?].directory.len or
                (config.directory.len == self.configs.items[best.?].directory.len and std.mem.lessThan(u8, config.path, self.configs.items[best.?].path)))
            {
                best = index;
            }
        }
        return best;
    }

    fn collectEffectiveAliases(
        self: *Engine,
        config_index: usize,
        stack: *std.ArrayList(usize),
        aliases: *std.ArrayList(Alias),
    ) !void {
        for (stack.items) |ancestor| {
            if (ancestor == config_index) {
                try self.appendDiagnostic(.config_cycle, self.configs.items[config_index].path, "configuration inheritance cycle was truncated");
                return;
            }
        }
        if (stack.items.len >= self.corpus.options.max_config_depth) {
            try self.appendDiagnostic(.config_limit, self.configs.items[config_index].path, "configuration inheritance depth was exhausted");
            return;
        }
        try stack.append(self.arena.allocator(), config_index);
        defer _ = stack.pop();
        const config = self.configs.items[config_index];
        for (config.extends) |parent_path| {
            const parent_index = self.findConfigIndex(parent_path) orelse {
                try self.appendDiagnostic(.config_invalid, config.path, "extended configuration is absent from the repository inventory");
                continue;
            };
            try self.collectEffectiveAliases(parent_index, stack, aliases);
        }
        for (config.aliases) |alias| {
            var replaced = false;
            for (aliases.items) |*existing| {
                if (!std.mem.eql(u8, existing.pattern, alias.pattern)) continue;
                existing.* = alias;
                replaced = true;
                break;
            }
            if (!replaced) try aliases.append(self.arena.allocator(), alias);
        }
    }

    fn findConfigIndex(self: *const Engine, path: []const u8) ?usize {
        for (self.configs.items, 0..) |config, index| if (std.mem.eql(u8, config.path, path)) return index;
        return null;
    }

    fn resolveAlias(
        self: *Engine,
        specifier: []const u8,
        aliases: []const Alias,
        candidates: *std.ArrayList(TempCandidate),
    ) !MatchState {
        const matched = bestAliasMatch(specifier, aliases) orelse return .no_match;
        const rule: Rule = switch (matched.kind) {
            .exact => .tsconfig_exact,
            .wildcard => .tsconfig_wildcard,
            .directory_prefix => .tsconfig_directory_prefix,
        };
        for (matched.alias.targets) |target| {
            const substituted = switch (matched.kind) {
                .exact => target,
                .wildcard => try replaceSingleStar(self.arena.allocator(), target, matched.capture),
                .directory_prefix => try std.fmt.allocPrint(self.arena.allocator(), "{s}{s}", .{ target, matched.capture }),
            };
            const normalized = try normalizeRepositoryPath(self.arena.allocator(), matched.alias.base_root, substituted, false) orelse continue;
            if (try self.resolveInventoryPath(normalized)) |path_match| {
                try candidates.append(self.arena.allocator(), .{
                    .target_path = path_match.path,
                    .rule = rule,
                    .authority_path = matched.alias.authority_path,
                });
                break;
            }
        }
        return .matched;
    }

    fn resolveInventoryPath(self: *Engine, base_path: []const u8) !?PathMatch {
        if (self.corpus.hasFile(base_path)) return .{ .path = base_path, .rule = .exact };
        const substitutions = [_][2][]const u8{
            .{ ".jsx", ".tsx" },
            .{ ".mjs", ".mts" },
            .{ ".cjs", ".cts" },
            .{ ".js", ".ts" },
            .{ ".js", ".tsx" },
        };
        for (substitutions) |substitution| {
            if (!std.mem.endsWith(u8, base_path, substitution[0])) continue;
            const stem = base_path[0 .. base_path.len - substitution[0].len];
            const candidate = try std.fmt.allocPrint(self.arena.allocator(), "{s}{s}", .{ stem, substitution[1] });
            if (self.corpus.hasFile(candidate)) return .{ .path = candidate, .rule = .esm_source_substitution };
        }
        for (source_extensions) |extension| {
            const candidate = try std.fmt.allocPrint(self.arena.allocator(), "{s}{s}", .{ base_path, extension });
            if (self.corpus.hasFile(candidate)) return .{ .path = candidate, .rule = .source_extension };
        }
        for (source_extensions) |extension| {
            const candidate = try std.fmt.allocPrint(self.arena.allocator(), "{s}/index{s}", .{ base_path, extension });
            if (self.corpus.hasFile(candidate)) return .{ .path = candidate, .rule = .directory_index };
        }
        return null;
    }

    fn resolveWorkspace(
        self: *Engine,
        source_path: []const u8,
        specifier: []const u8,
        candidates: *std.ArrayList(TempCandidate),
    ) !MatchState {
        const workspace = self.workspaceForSource(source_path) orelse return .no_match;
        const package_specifier = splitPackageSpecifier(specifier) orelse return .no_match;
        var matched = false;
        for (self.packages.items) |package| {
            if (!std.mem.eql(u8, package.workspace_root, workspace.root) or !std.mem.eql(u8, package.name, package_specifier.name)) continue;
            matched = true;
            _ = try self.resolvePackage(&package, package_specifier.subpath, candidates);
        }
        return if (matched) .matched else .no_match;
    }

    fn resolvePackage(
        self: *Engine,
        package: *const Package,
        subpath: []const u8,
        candidates: *std.ArrayList(TempCandidate),
    ) !bool {
        if (package.exports) |exports| {
            return self.resolvePackageExports(package, exports, subpath, candidates) catch |failure| switch (failure) {
                error.TypeScriptResolutionPackageExportDepthLimitExceeded,
                error.TypeScriptResolutionPackageExportAlternativeLimitExceeded,
                => {
                    try self.appendDiagnostic(.package_limit, package.manifest_path, "package export traversal limit was exhausted");
                    return false;
                },
                else => return failure,
            };
        }
        if (subpath.len != 0) return false;
        const fields = [_]?[]const u8{
            package.source,
            package.types,
            package.svelte,
            package.module,
            package.browser,
            package.main,
        };
        for (fields) |field| if (field) |target| {
            if (try self.resolvePackageTarget(package, target, "", .workspace_entry_fallback, candidates)) return true;
        };
        const fallbacks = [_][]const u8{ "./src/index", "./index" };
        for (fallbacks) |target| {
            if (try self.resolvePackageTarget(package, target, "", .workspace_entry_fallback, candidates)) return true;
        }
        return false;
    }

    fn resolvePackageExports(
        self: *Engine,
        package: *const Package,
        exports: std.json.Value,
        subpath: []const u8,
        candidates: *std.ArrayList(TempCandidate),
    ) !bool {
        const requested_key = if (subpath.len == 0) "." else try std.fmt.allocPrint(self.arena.allocator(), "./{s}", .{subpath});
        var alternatives: usize = 0;
        switch (exports) {
            .object => |object| {
                if (objectUsesSubpathKeys(object)) {
                    if (object.get(requested_key)) |exact| {
                        return self.resolveExportValue(package, exact, "", candidates, 0, &alternatives);
                    }
                    const wildcard = bestExportWildcard(object, requested_key) orelse return false;
                    return self.resolveExportValue(package, wildcard.value, wildcard.capture, candidates, 0, &alternatives);
                }
                if (subpath.len != 0) return false;
                return self.resolveExportValue(package, exports, "", candidates, 0, &alternatives);
            },
            else => {
                if (subpath.len != 0) return false;
                return self.resolveExportValue(package, exports, "", candidates, 0, &alternatives);
            },
        }
    }

    fn resolveExportValue(
        self: *Engine,
        package: *const Package,
        value: std.json.Value,
        capture: []const u8,
        candidates: *std.ArrayList(TempCandidate),
        depth: usize,
        alternatives: *usize,
    ) !bool {
        if (depth >= self.corpus.options.max_export_depth) return error.TypeScriptResolutionPackageExportDepthLimitExceeded;
        alternatives.* = std.math.add(usize, alternatives.*, 1) catch return error.TypeScriptResolutionPackageExportAlternativeLimitExceeded;
        if (alternatives.* > self.corpus.options.max_export_alternatives) return error.TypeScriptResolutionPackageExportAlternativeLimitExceeded;
        switch (value) {
            .string => |target| return self.resolvePackageTarget(package, target, capture, .workspace_export, candidates),
            .array => |array| {
                for (array.items) |item| {
                    if (try self.resolveExportValue(package, item, capture, candidates, depth + 1, alternatives)) return true;
                }
                return false;
            },
            .object => |object| {
                const conditions = [_][]const u8{ "types", "import", "require", "browser", "node", "default" };
                for (conditions) |condition| if (object.get(condition)) |selected| {
                    if (try self.resolveExportValue(package, selected, capture, candidates, depth + 1, alternatives)) return true;
                };
                return false;
            },
            .null => return false,
            else => {
                try self.appendDiagnostic(.package_invalid, package.manifest_path, "package exports contains an unsupported value");
                return false;
            },
        }
    }

    fn resolvePackageTarget(
        self: *Engine,
        package: *const Package,
        raw_target: []const u8,
        capture: []const u8,
        rule: Rule,
        candidates: *std.ArrayList(TempCandidate),
    ) !bool {
        if (!std.mem.startsWith(u8, raw_target, "./")) {
            try self.appendDiagnostic(.package_escape, package.manifest_path, "package target is not package-relative");
            return false;
        }
        const target = if (std.mem.indexOfScalar(u8, raw_target, '*') != null)
            try replaceSingleStar(self.arena.allocator(), raw_target, capture)
        else
            raw_target;
        const normalized = try normalizeRepositoryPath(self.arena.allocator(), package.root, target, false) orelse {
            try self.appendDiagnostic(.package_escape, package.manifest_path, "package target escapes the repository");
            return false;
        };
        if (!pathWithinRoot(normalized, package.root) or std.mem.eql(u8, normalized, package.root)) {
            try self.appendDiagnostic(.package_escape, package.manifest_path, "package target escapes its package root");
            return false;
        }
        const matched = try self.resolveInventoryPath(normalized) orelse return false;
        try candidates.append(self.arena.allocator(), .{
            .target_path = matched.path,
            .rule = rule,
            .authority_path = package.manifest_path,
        });
        return true;
    }

    fn appendDiagnostic(self: *Engine, kind: DiagnosticKind, source_path: []const u8, detail: []const u8) !void {
        for (self.diagnostics.items) |diagnostic| {
            if (diagnostic.kind == kind and std.mem.eql(u8, diagnostic.source_path, source_path) and std.mem.eql(u8, diagnostic.detail, detail)) return;
        }
        if (self.diagnostics.items.len >= self.corpus.options.max_diagnostics) return error.TypeScriptResolutionDiagnosticLimitExceeded;
        try self.diagnostics.append(self.arena.allocator(), .{
            .kind = kind,
            .source_path = try owned.copy(u8, self.arena.allocator(), source_path),
            .detail = try owned.copy(u8, self.arena.allocator(), detail),
        });
    }
};

const source_extensions = [_][]const u8{
    ".ts",
    ".tsx",
    ".mts",
    ".cts",
    ".svelte",
    ".js",
    ".jsx",
    ".mjs",
    ".cjs",
};

fn stripJsoncAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    try output.ensureTotalCapacity(allocator, input.len);
    var index: usize = 0;
    var in_string = false;
    var escaped = false;
    var line_comment = false;
    var block_comment = false;
    while (index < input.len) : (index += 1) {
        const byte = input[index];
        const next = if (index + 1 < input.len) input[index + 1] else 0;
        if (line_comment) {
            if (byte == '\n') {
                line_comment = false;
                try output.append(allocator, '\n');
            } else {
                try output.append(allocator, ' ');
            }
            continue;
        }
        if (block_comment) {
            if (byte == '*' and next == '/') {
                try output.append(allocator, ' ');
                try output.append(allocator, ' ');
                index += 1;
                block_comment = false;
            } else {
                try output.append(allocator, if (byte == '\n') '\n' else ' ');
            }
            continue;
        }
        if (in_string) {
            try output.append(allocator, byte);
            if (escaped) {
                escaped = false;
            } else if (byte == '\\') {
                escaped = true;
            } else if (byte == '"') {
                in_string = false;
            }
            continue;
        }
        if (byte == '"') {
            in_string = true;
            try output.append(allocator, byte);
        } else if (byte == '/' and next == '/') {
            try output.append(allocator, ' ');
            try output.append(allocator, ' ');
            index += 1;
            line_comment = true;
        } else if (byte == '/' and next == '*') {
            try output.append(allocator, ' ');
            try output.append(allocator, ' ');
            index += 1;
            block_comment = true;
        } else {
            try output.append(allocator, byte);
        }
    }
    if (block_comment) return error.UnterminatedJsoncComment;
    var string_state = false;
    escaped = false;
    for (output.items, 0..) |byte, comma_index| {
        if (string_state) {
            if (escaped) {
                escaped = false;
            } else if (byte == '\\') {
                escaped = true;
            } else if (byte == '"') {
                string_state = false;
            }
            continue;
        }
        if (byte == '"') {
            string_state = true;
            continue;
        }
        if (byte != ',') continue;
        var lookahead = comma_index + 1;
        while (lookahead < output.items.len and std.ascii.isWhitespace(output.items[lookahead])) : (lookahead += 1) {}
        if (lookahead < output.items.len and (output.items[lookahead] == '}' or output.items[lookahead] == ']')) output.items[comma_index] = ' ';
    }
    return output.toOwnedSlice(allocator);
}

fn jsonString(value: ?std.json.Value) ?[]const u8 {
    const present = value orelse return null;
    return switch (present) {
        .string => |text| text,
        else => null,
    };
}

fn isConfigDocument(path: []const u8) bool {
    const basename = std.fs.path.basename(path);
    return !std.mem.eql(u8, basename, "package.json") and std.mem.eql(u8, std.fs.path.extension(path), ".json");
}

fn isSelectableConfig(path: []const u8) bool {
    const basename = std.fs.path.basename(path);
    return std.mem.eql(u8, basename, "tsconfig.json") or std.mem.eql(u8, basename, "jsconfig.json");
}

fn lessThanConfig(_: void, left: Config, right: Config) bool {
    return std.mem.lessThan(u8, left.path, right.path);
}

fn lessThanWorkspace(_: void, left: Workspace, right: Workspace) bool {
    const root_order = std.mem.order(u8, left.root, right.root);
    if (root_order != .eq) return root_order == .lt;
    return std.mem.lessThan(u8, left.authority_path, right.authority_path);
}

fn lessThanPackage(_: void, left: Package, right: Package) bool {
    const workspace_order = std.mem.order(u8, left.workspace_root, right.workspace_root);
    if (workspace_order != .eq) return workspace_order == .lt;
    const name_order = std.mem.order(u8, left.name, right.name);
    if (name_order != .eq) return name_order == .lt;
    return std.mem.lessThan(u8, left.root, right.root);
}

fn normalizeRepositoryPath(
    allocator: std.mem.Allocator,
    base: []const u8,
    target: []const u8,
    allow_root: bool,
) !?[]const u8 {
    if (target.len == 0 or std.fs.path.isAbsolute(target) or std.mem.indexOfScalar(u8, target, '\\') != null) return null;
    const normalized = try std.fs.path.resolvePosix(allocator, &.{ base, target });
    if (std.fs.path.isAbsolutePosix(normalized) or std.mem.eql(u8, normalized, "..") or std.mem.startsWith(u8, normalized, "../")) return null;
    if (std.mem.eql(u8, normalized, ".")) {
        if (!allow_root) return null;
        return try owned.copy(u8, allocator, "");
    }
    if (!validRelativePath(normalized)) return null;
    return normalized;
}

fn pathWithinRoot(path: []const u8, root: []const u8) bool {
    if (root.len == 0) return path.len > 0;
    return std.mem.eql(u8, path, root) or (path.len > root.len and std.mem.startsWith(u8, path, root) and path[root.len] == '/');
}

fn relativeToRoot(path: []const u8, root: []const u8) ?[]const u8 {
    if (!pathWithinRoot(path, root)) return null;
    if (root.len == 0) return path;
    if (std.mem.eql(u8, path, root)) return "";
    return path[root.len + 1 ..];
}

fn unquote(value: []const u8) []const u8 {
    if (value.len >= 2 and ((value[0] == '"' and value[value.len - 1] == '"') or (value[0] == '\'' and value[value.len - 1] == '\''))) {
        return value[1 .. value.len - 1];
    }
    return value;
}

fn validWorkspacePattern(pattern: []const u8) bool {
    if (pattern.len == 0 or pattern[0] == '/' or std.mem.indexOfScalar(u8, pattern, '\\') != null) return false;
    var parts = std.mem.splitScalar(u8, pattern, '/');
    while (parts.next()) |part| if (part.len == 0 or std.mem.eql(u8, part, ".") or std.mem.eql(u8, part, "..")) return false;
    return true;
}

fn workspaceGlobMatches(pattern: []const u8, path: []const u8) bool {
    var pattern_segments: [128][]const u8 = @splat("");
    var path_segments: [128][]const u8 = @splat("");
    const pattern_count = splitSegments(pattern, &pattern_segments) orelse return false;
    const path_count = splitSegments(path, &path_segments) orelse return false;
    return globSegments(pattern_segments[0..pattern_count], path_segments[0..path_count]);
}

fn splitSegments(path: []const u8, output: *[128][]const u8) ?usize {
    var iterator = std.mem.splitScalar(u8, path, '/');
    var count: usize = 0;
    while (iterator.next()) |segment| {
        if (count >= output.len) return null;
        output[count] = segment;
        count += 1;
    }
    return count;
}

fn globSegments(pattern: []const []const u8, path: []const []const u8) bool {
    if (pattern.len == 0) return path.len == 0;
    if (std.mem.eql(u8, pattern[0], "**")) {
        if (globSegments(pattern[1..], path)) return true;
        return path.len > 0 and globSegments(pattern, path[1..]);
    }
    return path.len > 0 and wildcardSegmentMatches(pattern[0], path[0]) and globSegments(pattern[1..], path[1..]);
}

fn wildcardSegmentMatches(pattern: []const u8, value: []const u8) bool {
    var pattern_index: usize = 0;
    var value_index: usize = 0;
    var star_index: ?usize = null;
    var star_value_index: usize = 0;
    while (value_index < value.len) {
        if (pattern_index < pattern.len and (pattern[pattern_index] == '?' or pattern[pattern_index] == value[value_index])) {
            pattern_index += 1;
            value_index += 1;
        } else if (pattern_index < pattern.len and pattern[pattern_index] == '*') {
            star_index = pattern_index;
            pattern_index += 1;
            star_value_index = value_index;
        } else if (star_index) |star| {
            pattern_index = star + 1;
            star_value_index += 1;
            value_index = star_value_index;
        } else {
            return false;
        }
    }
    while (pattern_index < pattern.len and pattern[pattern_index] == '*') pattern_index += 1;
    return pattern_index == pattern.len;
}

fn validPackageName(name: []const u8) bool {
    if (name.len == 0 or name[0] == '/' or std.mem.indexOfScalar(u8, name, '\\') != null or std.mem.indexOf(u8, name, "..") != null) return false;
    if (name[0] == '@') {
        const slash = std.mem.indexOfScalar(u8, name, '/') orelse return false;
        return slash > 1 and slash + 1 < name.len and std.mem.indexOfScalarPos(u8, name, slash + 1, '/') == null;
    }
    return std.mem.indexOfScalar(u8, name, '/') == null;
}

const AliasKind = enum {
    exact,
    wildcard,
    directory_prefix,
};

fn validAliasPattern(pattern: []const u8) bool {
    if (pattern.len == 0 or pattern[0] == '/' or std.mem.indexOfScalar(u8, pattern, '\\') != null) return false;
    const star = std.mem.indexOfScalar(u8, pattern, '*') orelse return true;
    return std.mem.indexOfScalarPos(u8, pattern, star + 1, '*') == null;
}

const AliasMatch = struct {
    alias: *const Alias,
    kind: AliasKind,
    capture: []const u8,
    prefix_len: usize,
    suffix_len: usize,
};

fn bestAliasMatch(specifier: []const u8, aliases: []const Alias) ?AliasMatch {
    var best: ?AliasMatch = null;
    for (aliases, 0..) |alias, index| {
        const star = std.mem.indexOfScalar(u8, alias.pattern, '*');
        var candidate: ?AliasMatch = null;
        if (star) |star_index| {
            if (std.mem.indexOfScalarPos(u8, alias.pattern, star_index + 1, '*') != null) continue;
            const prefix = alias.pattern[0..star_index];
            const suffix = alias.pattern[star_index + 1 ..];
            if (specifier.len >= prefix.len + suffix.len and std.mem.startsWith(u8, specifier, prefix) and std.mem.endsWith(u8, specifier, suffix)) {
                candidate = .{
                    .alias = &aliases[index],
                    .kind = .wildcard,
                    .capture = specifier[prefix.len .. specifier.len - suffix.len],
                    .prefix_len = prefix.len,
                    .suffix_len = suffix.len,
                };
            }
        } else if (std.mem.endsWith(u8, alias.pattern, "/") and std.mem.startsWith(u8, specifier, alias.pattern) and specifier.len > alias.pattern.len) {
            candidate = .{
                .alias = &aliases[index],
                .kind = .directory_prefix,
                .capture = specifier[alias.pattern.len..],
                .prefix_len = alias.pattern.len,
                .suffix_len = 0,
            };
        } else if (std.mem.eql(u8, alias.pattern, specifier)) {
            return .{
                .alias = &aliases[index],
                .kind = .exact,
                .capture = "",
                .prefix_len = alias.pattern.len,
                .suffix_len = 0,
            };
        }
        const present = candidate orelse continue;
        if (best == null or aliasMatchBetter(present, best.?)) best = present;
    }
    return best;
}

fn aliasMatchBetter(left: AliasMatch, right: AliasMatch) bool {
    if (left.kind != right.kind) return @intFromEnum(left.kind) < @intFromEnum(right.kind);
    if (left.prefix_len != right.prefix_len) return left.prefix_len > right.prefix_len;
    if (left.suffix_len != right.suffix_len) return left.suffix_len > right.suffix_len;
    return std.mem.lessThan(u8, left.alias.pattern, right.alias.pattern);
}

fn replaceSingleStar(allocator: std.mem.Allocator, pattern: []const u8, capture: []const u8) ![]const u8 {
    const star = std.mem.indexOfScalar(u8, pattern, '*') orelse return pattern;
    if (std.mem.indexOfScalarPos(u8, pattern, star + 1, '*') != null) return error.InvalidTypeScriptResolutionWildcard;
    return std.fmt.allocPrint(allocator, "{s}{s}{s}", .{ pattern[0..star], capture, pattern[star + 1 ..] });
}

const PackageSpecifier = struct {
    name: []const u8,
    subpath: []const u8,
};

fn splitPackageSpecifier(specifier: []const u8) ?PackageSpecifier {
    if (!validBareSpecifier(specifier)) return null;
    if (specifier[0] == '@') {
        const first = std.mem.indexOfScalar(u8, specifier, '/') orelse return null;
        const second = std.mem.indexOfScalarPos(u8, specifier, first + 1, '/');
        return if (second) |slash|
            .{ .name = specifier[0..slash], .subpath = specifier[slash + 1 ..] }
        else
            .{ .name = specifier, .subpath = "" };
    }
    if (std.mem.indexOfScalar(u8, specifier, '/')) |slash| {
        return .{ .name = specifier[0..slash], .subpath = specifier[slash + 1 ..] };
    }
    return .{ .name = specifier, .subpath = "" };
}

fn validBareSpecifier(specifier: []const u8) bool {
    if (specifier.len == 0 or specifier[0] == '.' or specifier[0] == '/' or std.mem.indexOfScalar(u8, specifier, '\\') != null) return false;
    var segments = std.mem.splitScalar(u8, specifier, '/');
    while (segments.next()) |segment| if (segment.len == 0 or std.mem.eql(u8, segment, ".") or std.mem.eql(u8, segment, "..")) return false;
    return true;
}

fn isRelativeSpecifier(specifier: []const u8) bool {
    return std.mem.eql(u8, specifier, ".") or std.mem.eql(u8, specifier, "..") or std.mem.startsWith(u8, specifier, "./") or std.mem.startsWith(u8, specifier, "../");
}

fn objectUsesSubpathKeys(object: std.json.ObjectMap) bool {
    var iterator = object.iterator();
    while (iterator.next()) |entry| if (std.mem.startsWith(u8, entry.key_ptr.*, ".")) return true;
    return false;
}

const ExportWildcard = struct {
    value: std.json.Value,
    capture: []const u8,
    prefix_len: usize,
    suffix_len: usize,
};

fn bestExportWildcard(object: std.json.ObjectMap, requested_key: []const u8) ?ExportWildcard {
    var best: ?ExportWildcard = null;
    var iterator = object.iterator();
    while (iterator.next()) |entry| {
        const key = entry.key_ptr.*;
        const star = std.mem.indexOfScalar(u8, key, '*') orelse continue;
        if (std.mem.indexOfScalarPos(u8, key, star + 1, '*') != null) continue;
        const prefix = key[0..star];
        const suffix = key[star + 1 ..];
        if (requested_key.len < prefix.len + suffix.len or !std.mem.startsWith(u8, requested_key, prefix) or !std.mem.endsWith(u8, requested_key, suffix)) continue;
        const candidate = ExportWildcard{
            .value = entry.value_ptr.*,
            .capture = requested_key[prefix.len .. requested_key.len - suffix.len],
            .prefix_len = prefix.len,
            .suffix_len = suffix.len,
        };
        if (best == null or candidate.prefix_len > best.?.prefix_len or
            (candidate.prefix_len == best.?.prefix_len and candidate.suffix_len > best.?.suffix_len))
        {
            best = candidate;
        }
    }
    return best;
}

fn lessThanImportIndex(corpus: *const Corpus, left_index: usize, right_index: usize) bool {
    const left = corpus.imports.items[left_index];
    const right = corpus.imports.items[right_index];
    const path_order = std.mem.order(u8, left.source_path, right.source_path);
    if (path_order != .eq) return path_order == .lt;
    if (left.span.start_byte != right.span.start_byte) return left.span.start_byte < right.span.start_byte;
    const specifier_order = std.mem.order(u8, left.specifier, right.specifier);
    if (specifier_order != .eq) return specifier_order == .lt;
    return @intFromEnum(left.kind) < @intFromEnum(right.kind);
}

fn lessThanTempCandidate(_: void, left: TempCandidate, right: TempCandidate) bool {
    const path_order = std.mem.order(u8, left.target_path, right.target_path);
    if (path_order != .eq) return path_order == .lt;
    if (left.rule != right.rule) return @intFromEnum(left.rule) < @intFromEnum(right.rule);
    return std.mem.lessThan(u8, left.authority_path, right.authority_path);
}

fn deduplicateTempCandidates(values: *std.ArrayList(TempCandidate)) void {
    if (values.items.len < 2) return;
    var write_index: usize = 1;
    for (values.items[1..]) |candidate| {
        const previous = values.items[write_index - 1];
        if (std.mem.eql(u8, previous.target_path, candidate.target_path) and previous.rule == candidate.rule and
            std.mem.eql(u8, previous.authority_path, candidate.authority_path))
        {
            continue;
        }
        values.items[write_index] = candidate;
        write_index += 1;
    }
    values.items.len = write_index;
}

fn lessThanTempDiagnostic(_: void, left: TempDiagnostic, right: TempDiagnostic) bool {
    const path_order = std.mem.order(u8, left.source_path, right.source_path);
    if (path_order != .eq) return path_order == .lt;
    if (left.kind != right.kind) return @intFromEnum(left.kind) < @intFromEnum(right.kind);
    return std.mem.lessThan(u8, left.detail, right.detail);
}

fn lessThanOrEqualResolution(left: Resolution, right: Resolution) bool {
    const path_order = std.mem.order(u8, left.source_path, right.source_path);
    if (path_order != .eq) return path_order == .lt;
    if (left.span.start_byte != right.span.start_byte) return left.span.start_byte < right.span.start_byte;
    const specifier_order = std.mem.order(u8, left.specifier, right.specifier);
    if (specifier_order != .eq) return specifier_order == .lt;
    return @intFromEnum(left.import_kind) <= @intFromEnum(right.import_kind);
}

fn lessThanOrEqualDiagnostic(left: Diagnostic, right: Diagnostic) bool {
    const path_order = std.mem.order(u8, left.source_path, right.source_path);
    if (path_order != .eq) return path_order == .lt;
    if (left.kind != right.kind) return @intFromEnum(left.kind) < @intFromEnum(right.kind);
    return std.mem.order(u8, left.detail, right.detail) != .gt;
}

fn consumeResultBytes(current: usize, amount: usize, limit: usize) !usize {
    const next = std.math.add(usize, current, amount) catch return error.TypeScriptResolutionResultLimitExceeded;
    if (next > limit) return error.TypeScriptResolutionResultLimitExceeded;
    return next;
}

fn deinitResolutionList(allocator: std.mem.Allocator, values: *std.ArrayList(Resolution)) void {
    for (values.items) |value| {
        allocator.free(value.source_path);
        allocator.free(value.specifier);
    }
    values.deinit(allocator);
}

fn deinitCandidateList(allocator: std.mem.Allocator, values: *std.ArrayList(Candidate)) void {
    for (values.items) |value| {
        allocator.free(value.target_path);
        if (value.authority_path.len > 0) allocator.free(value.authority_path);
    }
    values.deinit(allocator);
}

fn deinitDiagnosticList(allocator: std.mem.Allocator, values: *std.ArrayList(Diagnostic)) void {
    for (values.items) |value| {
        allocator.free(value.source_path);
        if (value.detail.len > 0) allocator.free(value.detail);
    }
    values.deinit(allocator);
}

fn resolutionFingerprint(
    resolutions: []const Resolution,
    candidates: []const Candidate,
    diagnostics: []const Diagnostic,
    summary: Summary,
) [32]u8 {
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    updateBytes(&hasher, schema);
    updateBytes(&hasher, resolver_version);
    updateU64(&hasher, summary.imports);
    updateU64(&hasher, summary.resolved);
    updateU64(&hasher, summary.external);
    updateU64(&hasher, summary.unresolved);
    updateU64(&hasher, summary.ambiguous);
    updateU64(&hasher, summary.invalid);
    updateU64(&hasher, summary.exhausted);
    updateU64(&hasher, summary.candidates);
    updateU64(&hasher, summary.diagnostics);
    for (resolutions) |resolution| {
        updateBytes(&hasher, resolution.source_path);
        updateBytes(&hasher, resolution.specifier);
        updateU64(&hasher, @intFromEnum(resolution.import_kind));
        updateU64(&hasher, @intFromBool(resolution.type_only));
        updateSpan(&hasher, resolution.span);
        updateU64(&hasher, @intFromEnum(resolution.status));
        updateU64(&hasher, resolution.candidate_start);
        updateU64(&hasher, resolution.candidate_count);
    }
    for (candidates) |candidate| {
        updateU64(&hasher, candidate.resolution_index);
        updateBytes(&hasher, candidate.target_path);
        updateU64(&hasher, @intFromEnum(candidate.rule));
        updateBytes(&hasher, candidate.authority_path);
        updateU64(&hasher, candidate.rank);
    }
    for (diagnostics) |diagnostic| {
        updateU64(&hasher, @intFromEnum(diagnostic.kind));
        updateBytes(&hasher, diagnostic.source_path);
        updateBytes(&hasher, diagnostic.detail);
    }
    var digest: [32]u8 = @splat(0);
    hasher.final(&digest);
    return digest;
}

fn updateSpan(hasher: *std.crypto.hash.sha2.Sha256, span: typescript_parser.Span) void {
    updateU64(hasher, span.start_byte);
    updateU64(hasher, span.end_byte);
    updateU64(hasher, span.start_line);
    updateU64(hasher, span.start_column);
    updateU64(hasher, span.end_line);
    updateU64(hasher, span.end_column);
}

fn updateBytes(hasher: *std.crypto.hash.sha2.Sha256, bytes: []const u8) void {
    updateU64(hasher, bytes.len);
    hasher.update(bytes);
}

fn updateU64(hasher: *std.crypto.hash.sha2.Sha256, value: u64) void {
    var bytes: [8]u8 = @splat(0);
    std.mem.writeInt(u64, &bytes, value, .little);
    hasher.update(&bytes);
}

fn validateOptions(options: Options) !void {
    if (options.max_files == 0 or options.max_imports == 0 or options.max_documents == 0 or
        options.max_document_bytes == 0 or options.max_total_document_bytes == 0 or
        options.max_configs == 0 or options.max_packages == 0 or options.max_workspace_patterns == 0 or options.max_aliases == 0 or
        options.max_alias_targets == 0 or options.max_config_depth == 0 or options.max_config_depth > 1024 or
        options.max_export_depth == 0 or options.max_export_depth > 1024 or options.max_export_alternatives == 0 or
        options.max_candidates_per_import == 0 or options.max_candidates == 0 or
        options.max_diagnostics == 0 or options.max_path_bytes == 0 or options.max_result_bytes == 0)
    {
        return error.InvalidTypeScriptResolutionOptions;
    }
}

fn validRelativePath(path: []const u8) bool {
    if (path.len == 0 or path[0] == '/' or path[path.len - 1] == '/' or std.mem.indexOfScalar(u8, path, '\\') != null) return false;
    var parts = std.mem.splitScalar(u8, path, '/');
    while (parts.next()) |part| {
        if (part.len == 0 or std.mem.eql(u8, part, ".") or std.mem.eql(u8, part, "..")) return false;
    }
    return true;
}
