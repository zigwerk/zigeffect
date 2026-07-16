const std = @import("std");
const model = @import("model.zig");
const owned = @import("memory.zig");

pub const max_manifest_bytes: usize = 4 * 1024 * 1024;
pub const max_causal_bytes: usize = 64 * 1024 * 1024;
pub const causal_wal_path = ".zigeffect/graph/causal-graph.jsonl";

pub const BuildOptions = struct {
    max_files: usize = 100_000,
    max_file_bytes: usize = 4 * 1024 * 1024,
    max_source_bytes: usize = 512 * 1024 * 1024,
    max_nodes: usize = 100_000,
    max_edges: usize = 500_000,
};

pub const BuildSummary = struct {
    files_discovered: usize = 0,
    files_indexed: usize = 0,
    files_skipped: usize = 0,
    source_bytes: usize = 0,
    causal_records: usize = 0,
    nodes: usize = 0,
    edges: usize = 0,
    vectors: usize = 0,
};

pub const BuildResult = struct {
    graph: model.RepositoryGraph,
    summary: BuildSummary,

    pub fn deinit(self: *BuildResult) void {
        self.graph.deinit();
    }
};

const Symbol = struct {
    id: u64,
    name: []const u8,
    line: u32,
};

pub fn buildRepository(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    options: BuildOptions,
) !BuildResult {
    if (options.max_files == 0 or options.max_file_bytes == 0 or options.max_source_bytes == 0) return error.InvalidLimit;
    var graph = try model.RepositoryGraph.init(allocator, .{
        .max_nodes = options.max_nodes,
        .max_edges = options.max_edges,
    });
    errdefer graph.deinit();
    const repository_id = try graph.addNode(.{
        .kind = .repository,
        .label = ".",
        .path = ".",
        .search_text = "repository root",
    });
    var ignore_rules = try loadIgnoreRules(allocator, io, root);
    defer ignore_rules.deinit();

    var paths: std.ArrayList([]const u8) = .empty;
    defer {
        for (paths.items) |path| allocator.free(path);
        paths.deinit(allocator);
    }
    var walker = try root.walk(allocator);
    defer walker.deinit();
    while (try walker.next(io)) |entry| {
        if (entry.kind != .file or mandatoryExcluded(entry.path) or ignore_rules.matches(entry.path) or !supportedPath(entry.path)) continue;
        if (paths.items.len >= options.max_files) return error.FileLimitExceeded;
        try paths.append(allocator, try owned.copy(u8, allocator, entry.path));
    }
    std.mem.sort([]const u8, paths.items, {}, struct {
        fn lessThan(_: void, left: []const u8, right: []const u8) bool {
            return std.mem.lessThan(u8, left, right);
        }
    }.lessThan);

    var summary = BuildSummary{ .files_discovered = paths.items.len };
    for (paths.items) |path| {
        if (std.mem.eql(u8, path, "zigeffect.project.json")) continue;
        const source = root.readFileAlloc(io, path, allocator, .limited(options.max_file_bytes)) catch {
            summary.files_skipped += 1;
            continue;
        };
        defer allocator.free(source);
        summary.source_bytes = std.math.add(usize, summary.source_bytes, source.len) catch return error.SourceLimitExceeded;
        if (summary.source_bytes > options.max_source_bytes) return error.SourceLimitExceeded;
        if (looksBinary(source)) {
            summary.files_skipped += 1;
            continue;
        }
        try indexZigSource(&graph, path, source);
        try linkFileHierarchy(&graph, repository_id, path);
        summary.files_indexed += 1;
    }
    for (paths.items) |path| {
        if (!std.mem.eql(u8, path, "zigeffect.project.json")) continue;
        const manifest = root.readFileAlloc(io, path, allocator, .limited(@min(options.max_file_bytes, max_manifest_bytes))) catch {
            summary.files_skipped += 1;
            continue;
        };
        defer allocator.free(manifest);
        summary.source_bytes = std.math.add(usize, summary.source_bytes, manifest.len) catch return error.SourceLimitExceeded;
        if (summary.source_bytes > options.max_source_bytes) return error.SourceLimitExceeded;
        try indexZigEffectManifest(&graph, manifest);
        summary.files_indexed += 1;
    }
    try resolveFileImports(&graph);
    try resolveSymbolCalls(&graph);
    const causal_records = root.readFileAlloc(io, causal_wal_path, allocator, .limited(max_causal_bytes)) catch |failure| switch (failure) {
        error.FileNotFound => null,
        else => return failure,
    };
    if (causal_records) |records| {
        defer allocator.free(records);
        summary.causal_records = try indexCausalRecords(&graph, causal_wal_path, records);
    }
    summary.nodes = graph.nodeCount();
    summary.edges = graph.edgeCount();
    summary.vectors = graph.vectorCount();
    return .{ .graph = graph, .summary = summary };
}

pub fn indexZigSource(graph: *model.RepositoryGraph, path: []const u8, source: []const u8) !void {
    try validateSourcePath(path);
    const file_label = std.fs.path.basename(path);
    const file_id = try graph.addNode(.{
        .kind = .file,
        .label = file_label,
        .path = path,
        .line = 1,
        .search_text = path,
    });

    var symbols: std.ArrayList(Symbol) = .empty;
    defer symbols.deinit(graph.allocator);
    var line_iterator = std.mem.splitScalar(u8, source, '\n');
    var line_number: u32 = 1;
    var in_block_comment = false;
    while (line_iterator.next()) |raw_line| : (line_number += 1) {
        const line = stripComments(raw_line, &in_block_comment);
        if (importTarget(line)) |target| {
            const external_id = try graph.addNode(.{
                .kind = .external_module,
                .label = target,
                .path = target,
                .line = line_number,
                .search_text = target,
            });
            try graph.addEdge(.{
                .from = file_id,
                .to = external_id,
                .relation = .imports,
                .provenance = .extracted,
                .source_path = path,
                .line = line_number,
            });
        }
        if (declaration(line)) |decl| {
            const symbol_id = try graph.addNode(.{
                .kind = .symbol,
                .label = decl.name,
                .path = path,
                .line = line_number,
                .search_text = line,
            });
            try graph.addEdge(.{
                .from = file_id,
                .to = symbol_id,
                .relation = .declares,
                .provenance = .extracted,
                .source_path = path,
                .line = line_number,
            });
            try symbols.append(graph.allocator, .{ .id = symbol_id, .name = graph.findNode(symbol_id).?.label, .line = line_number });
        }
    }

    line_iterator = std.mem.splitScalar(u8, source, '\n');
    line_number = 1;
    in_block_comment = false;
    var current_function: ?u64 = null;
    var brace_depth: isize = 0;
    while (line_iterator.next()) |raw_line| : (line_number += 1) {
        const line = stripComments(raw_line, &in_block_comment);
        var call_region = line;
        if (functionName(line)) |name| {
            brace_depth = 0;
            if (std.mem.indexOfScalar(u8, line, '{')) |open| {
                current_function = findUniqueSymbol(symbols.items, name);
                call_region = line[open + 1 ..];
            } else {
                current_function = null;
            }
        }
        if (current_function) |caller| {
            var calls = CallIterator.init(call_region);
            while (calls.next()) |callee| {
                if (isControlWord(callee)) continue;
                const target = findUniqueSymbol(symbols.items, callee) orelse try graph.addNode(.{
                    .kind = .concept,
                    .label = callee,
                    .path = path,
                    .line = line_number,
                    .search_text = callee,
                });
                if (target == caller) continue;
                try graph.addEdge(.{
                    .from = caller,
                    .to = target,
                    .relation = .calls,
                    .provenance = if (graph.findNode(target).?.kind == .concept) .ambiguous else .inferred,
                    .source_path = path,
                    .line = line_number,
                });
            }
        }
        brace_depth += braceDelta(line);
        if (current_function != null and brace_depth <= 0 and std.mem.indexOfScalar(u8, line, '}') != null) {
            current_function = null;
            brace_depth = 0;
        }
    }
}

pub fn indexZigEffectManifest(graph: *model.RepositoryGraph, json: []const u8) !void {
    if (json.len == 0 or json.len > max_manifest_bytes) return error.InvalidManifest;
    var parsed = std.json.parseFromSlice(std.json.Value, graph.allocator, json, .{}) catch return error.InvalidManifest;
    defer parsed.deinit();
    const root = switch (parsed.value) {
        .object => |object| object,
        else => return error.InvalidManifest,
    };
    const schema = valueString(root.get("schema")) orelse return error.InvalidManifest;
    if (!std.mem.eql(u8, schema, "zigeffect.project.v1")) return error.UnsupportedManifest;

    if (root.get("components")) |value| if (value == .array) {
        for (value.array.items) |item| {
            const object = valueObject(item) orelse continue;
            const id = valueString(object.get("id")) orelse continue;
            const path = valueString(object.get("path")) orelse "";
            _ = try graph.addNode(.{ .kind = .component, .label = id, .path = path, .search_text = id });
        }
        for (value.array.items) |item| {
            const object = valueObject(item) orelse continue;
            const id = valueString(object.get("id")) orelse continue;
            const component = findByKindAndLabel(graph, .component, id) orelse continue;
            const component_id = component.id;
            const component_path = component.path;
            if (findSourceByPath(graph, component_path)) |source| {
                try graph.addEdge(.{ .from = component_id, .to = source.id, .relation = .source_root, .provenance = .extracted, .source_path = "zigeffect.project.json" });
            }
            if (object.get("depends_on")) |dependencies| if (dependencies == .array) {
                for (dependencies.array.items) |dependency_value| {
                    const dependency_label = valueString(dependency_value) orelse continue;
                    const dependency = findByKindAndLabel(graph, .component, dependency_label) orelse continue;
                    try graph.addEdge(.{ .from = component_id, .to = dependency.id, .relation = .depends_on, .provenance = .extracted, .source_path = "zigeffect.project.json" });
                }
            };
        }
    };
    if (root.get("commands")) |value| if (value == .array) {
        for (value.array.items) |item| {
            const object = valueObject(item) orelse continue;
            const id = valueString(object.get("id")) orelse continue;
            _ = try graph.addNode(.{ .kind = .command, .label = id, .path = "zigeffect.project.json", .search_text = id });
        }
    };
    if (root.get("requirements")) |value| if (value == .array) {
        for (value.array.items) |item| {
            const object = valueObject(item) orelse continue;
            const id = valueString(object.get("id")) orelse continue;
            const summary = valueString(object.get("summary")) orelse id;
            const requirement_id = try graph.addNode(.{ .kind = .requirement, .label = id, .path = "zigeffect.project.json", .search_text = summary });
            if (valueString(object.get("component"))) |component_label| {
                if (findByKindAndLabel(graph, .component, component_label)) |component| {
                    try graph.addEdge(.{ .from = requirement_id, .to = component.id, .relation = .satisfies, .provenance = .extracted, .source_path = "zigeffect.project.json" });
                }
            }
        }
    };
    if (root.get("acceptance_checks")) |value| if (value == .array) {
        for (value.array.items) |item| {
            const object = valueObject(item) orelse continue;
            const id = valueString(object.get("id")) orelse continue;
            const expectation = valueString(object.get("expectation")) orelse id;
            const check_id = try graph.addNode(.{ .kind = .acceptance_check, .label = id, .path = "zigeffect.project.json", .search_text = expectation });
            if (valueString(object.get("requirement"))) |requirement_label| {
                if (findByKindAndLabel(graph, .requirement, requirement_label)) |requirement| {
                    try graph.addEdge(.{ .from = requirement.id, .to = check_id, .relation = .verified_by, .provenance = .extracted, .source_path = "zigeffect.project.json" });
                }
            }
            if (valueString(object.get("command"))) |command_label| {
                if (findByKindAndLabel(graph, .command, command_label)) |command| {
                    try graph.addEdge(.{ .from = check_id, .to = command.id, .relation = .executes, .provenance = .extracted, .source_path = "zigeffect.project.json" });
                }
            }
        }
    };
    if (root.get("test_scenarios")) |value| if (value == .array) {
        for (value.array.items) |item| {
            const object = valueObject(item) orelse continue;
            const id = valueString(object.get("id")) orelse continue;
            const label = valueString(object.get("label")) orelse id;
            const scenario_id = try graph.addNode(.{ .kind = .test_scenario, .label = id, .path = "zigeffect.project.json", .search_text = label });
            if (valueString(object.get("requirement"))) |requirement_label| {
                if (findByKindAndLabel(graph, .requirement, requirement_label)) |requirement| {
                    try graph.addEdge(.{ .from = scenario_id, .to = requirement.id, .relation = .covers, .provenance = .extracted, .source_path = "zigeffect.project.json" });
                }
            }
            if (valueString(object.get("command"))) |command_label| {
                if (findByKindAndLabel(graph, .command, command_label)) |command| {
                    try graph.addEdge(.{ .from = scenario_id, .to = command.id, .relation = .executes, .provenance = .extracted, .source_path = "zigeffect.project.json" });
                }
            }
            if (object.get("source_roots")) |roots| if (roots == .array) {
                for (roots.array.items) |source_value| {
                    const source_path = valueString(source_value) orelse continue;
                    if (findSourceByPath(graph, source_path)) |source| {
                        try graph.addEdge(.{ .from = scenario_id, .to = source.id, .relation = .source_root, .provenance = .extracted, .source_path = "zigeffect.project.json" });
                    }
                }
            };
        }
    };
}

pub fn indexCausalRecords(graph: *model.RepositoryGraph, wal_path: []const u8, jsonl: []const u8) !usize {
    if (jsonl.len > max_causal_bytes) return error.CausalGraphTooLarge;
    const PersistedNode = struct { properties: []const u8 };
    const PersistedRecord = struct { session_id: u64, node: PersistedNode };
    const Properties = struct {
        event_id: u64,
        kind: []const u8,
        parent_id: ?u64 = null,
        label: []const u8 = "",
        status: []const u8 = "",
        domain_entity_ref: []const u8 = "",
    };
    const Parent = struct { session_id: u64, child: u64, parent_event_id: u64 };
    var parents: std.ArrayList(Parent) = .empty;
    defer parents.deinit(graph.allocator);
    var imported: usize = 0;
    var lines = std.mem.splitScalar(u8, jsonl, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var persisted = std.json.parseFromSlice(PersistedRecord, graph.allocator, line, .{ .ignore_unknown_fields = true }) catch return error.InvalidCausalRecord;
        defer persisted.deinit();
        var properties = std.json.parseFromSlice(Properties, graph.allocator, persisted.value.node.properties, .{ .ignore_unknown_fields = true }) catch return error.InvalidCausalRecord;
        defer properties.deinit();
        const event = properties.value;
        var id_buffer = [_]u8{0} ** 32;
        const event_identity = std.fmt.bufPrint(&id_buffer, "{d}:{d}", .{ persisted.value.session_id, event.event_id }) catch return error.InvalidCausalRecord;
        const search_text = try std.fmt.allocPrint(graph.allocator, "{s} {s} {s}", .{ event.kind, event.label, event.status });
        defer graph.allocator.free(search_text);
        const node_id = try graph.addNode(.{
            .kind = .causal_event,
            .label = if (event.label.len > 0) event.label else event.kind,
            .path = wal_path,
            .search_text = search_text,
            .id = model.stableId(.causal_event, wal_path, event_identity),
        });
        if (event.parent_id) |parent_event_id| try parents.append(graph.allocator, .{
            .session_id = persisted.value.session_id,
            .child = node_id,
            .parent_event_id = parent_event_id,
        });
        if (sourceRefTarget(graph, event.domain_entity_ref)) |source| {
            try graph.addEdge(.{
                .from = node_id,
                .to = source.id,
                .relation = .observed_at,
                .provenance = .extracted,
                .source_path = wal_path,
            });
        }
        imported += 1;
    }
    for (parents.items) |parent| {
        var id_buffer = [_]u8{0} ** 32;
        const parent_identity = std.fmt.bufPrint(&id_buffer, "{d}:{d}", .{ parent.session_id, parent.parent_event_id }) catch continue;
        const parent_id = model.stableId(.causal_event, wal_path, parent_identity);
        if (graph.findNode(parent_id) == null) continue;
        try graph.addEdge(.{
            .from = parent_id,
            .to = parent.child,
            .relation = .causal_parent,
            .provenance = .extracted,
            .source_path = wal_path,
        });
    }
    return imported;
}

const Declaration = struct { name: []const u8 };

fn declaration(line: []const u8) ?Declaration {
    if (functionName(line)) |name| return .{ .name = name };
    const const_at = std.mem.indexOf(u8, line, "const ") orelse return null;
    const tail = line[const_at + "const ".len ..];
    const equals = std.mem.indexOfScalar(u8, tail, '=') orelse return null;
    const name = std.mem.trim(u8, tail[0..equals], " \t");
    if (name.len == 0) return null;
    const value = tail[equals + 1 ..];
    if (std.mem.indexOf(u8, value, "struct") == null and
        std.mem.indexOf(u8, value, "enum") == null and
        std.mem.indexOf(u8, value, "union") == null and
        std.mem.indexOf(u8, value, "error{") == null) return null;
    return .{ .name = name };
}

fn functionName(line: []const u8) ?[]const u8 {
    const fn_at = std.mem.indexOf(u8, line, "fn ") orelse return null;
    const start = fn_at + 3;
    var end = start;
    while (end < line.len and isIdentifierByte(line[end])) end += 1;
    if (end == start or end >= line.len or line[end] != '(') return null;
    return line[start..end];
}

fn importTarget(line: []const u8) ?[]const u8 {
    const marker = "@import(\"";
    const start_at = std.mem.indexOf(u8, line, marker) orelse return null;
    const start = start_at + marker.len;
    const end_offset = std.mem.indexOfScalar(u8, line[start..], '"') orelse return null;
    return line[start .. start + end_offset];
}

fn stripLineComment(line: []const u8) []const u8 {
    var in_string = false;
    var escaped = false;
    var index: usize = 0;
    while (index + 1 < line.len) : (index += 1) {
        const char = line[index];
        if (escaped) {
            escaped = false;
            continue;
        }
        if (char == '\\' and in_string) {
            escaped = true;
            continue;
        }
        if (char == '"') in_string = !in_string;
        if (!in_string and char == '/' and line[index + 1] == '/') return line[0..index];
    }
    return line;
}

fn stripComments(line: []const u8, in_block_comment: *bool) []const u8 {
    var visible = line;
    if (in_block_comment.*) {
        const end = std.mem.indexOf(u8, visible, "*/") orelse return "";
        visible = visible[end + 2 ..];
        in_block_comment.* = false;
    }
    const without_line_comment = stripLineComment(visible);
    if (blockCommentStart(without_line_comment)) |start| {
        if (std.mem.indexOf(u8, without_line_comment[start + 2 ..], "*/") == null) in_block_comment.* = true;
        return without_line_comment[0..start];
    }
    return without_line_comment;
}

fn blockCommentStart(line: []const u8) ?usize {
    var in_string = false;
    var escaped = false;
    var index: usize = 0;
    while (index + 1 < line.len) : (index += 1) {
        const char = line[index];
        if (escaped) {
            escaped = false;
            continue;
        }
        if (char == '\\' and in_string) {
            escaped = true;
            continue;
        }
        if (char == '"') in_string = !in_string;
        if (!in_string and char == '/' and line[index + 1] == '*') return index;
    }
    return null;
}

fn braceDelta(line: []const u8) isize {
    var delta: isize = 0;
    var in_string = false;
    for (line) |char| {
        if (char == '"') in_string = !in_string;
        if (in_string) continue;
        if (char == '{') delta += 1;
        if (char == '}') delta -= 1;
    }
    return delta;
}

fn findUniqueSymbol(symbols: []const Symbol, name: []const u8) ?u64 {
    var found: ?u64 = null;
    for (symbols) |symbol| {
        if (!std.mem.eql(u8, symbol.name, name)) continue;
        if (found != null) return null;
        found = symbol.id;
    }
    return found;
}

const CallIterator = struct {
    line: []const u8,
    cursor: usize = 0,

    fn init(line: []const u8) CallIterator {
        return .{ .line = line };
    }

    fn next(self: *CallIterator) ?[]const u8 {
        while (self.cursor < self.line.len) {
            const open_offset = std.mem.indexOfScalar(u8, self.line[self.cursor..], '(') orelse return null;
            const open = self.cursor + open_offset;
            var start = open;
            while (start > 0 and isIdentifierByte(self.line[start - 1])) start -= 1;
            self.cursor = open + 1;
            if (start == open) continue;
            return self.line[start..open];
        }
        return null;
    }
};

fn isIdentifierByte(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_';
}

fn isControlWord(value: []const u8) bool {
    for ([_][]const u8{ "if", "for", "while", "switch", "catch", "return", "defer", "errdefer" }) |word| {
        if (std.mem.eql(u8, word, value)) return true;
    }
    return false;
}

fn validateSourcePath(path: []const u8) !void {
    if (path.len == 0 or path[0] == '/' or std.mem.indexOf(u8, path, "..") != null or std.mem.indexOfScalar(u8, path, '\\') != null) {
        return error.InvalidSourcePath;
    }
}

fn valueString(value: ?std.json.Value) ?[]const u8 {
    const present = value orelse return null;
    return switch (present) {
        .string => |text| text,
        else => null,
    };
}

fn valueObject(value: std.json.Value) ?std.json.ObjectMap {
    return switch (value) {
        .object => |object| object,
        else => null,
    };
}

fn findByKindAndLabel(graph: *const model.RepositoryGraph, kind: model.NodeKind, label: []const u8) ?*const model.Node {
    for (graph.nodes.items) |*node| if (node.kind == kind and std.mem.eql(u8, node.label, label)) return node;
    return null;
}

fn findFileByPath(graph: *const model.RepositoryGraph, path: []const u8) ?*const model.Node {
    for (graph.nodes.items) |*node| if (node.kind == .file and std.mem.eql(u8, node.path, path)) return node;
    return null;
}

fn findSourceByPath(graph: *const model.RepositoryGraph, path: []const u8) ?*const model.Node {
    for (graph.nodes.items) |*node| {
        if ((node.kind == .file or node.kind == .directory) and std.mem.eql(u8, node.path, path)) return node;
    }
    return null;
}

fn sourceRefTarget(graph: *const model.RepositoryGraph, source_ref: []const u8) ?*const model.Node {
    const prefix = "zgraphy://source/";
    if (!std.mem.startsWith(u8, source_ref, prefix)) return null;
    const identity = source_ref[prefix.len..];
    const fragment = std.mem.lastIndexOfScalar(u8, identity, '#') orelse return null;
    const path = identity[0..fragment];
    const symbol = identity[fragment + 1 ..];
    if (path.len == 0 or symbol.len == 0 or path[0] == '/' or std.mem.indexOf(u8, path, "..") != null) return null;
    for (graph.nodes.items) |*node| {
        if (node.kind == .symbol and std.mem.eql(u8, node.path, path) and std.mem.eql(u8, node.label, symbol)) return node;
    }
    return null;
}

fn supportedPath(path: []const u8) bool {
    return std.mem.endsWith(u8, path, ".zig") or std.mem.eql(u8, path, "zigeffect.project.json");
}

const IgnoreRules = struct {
    allocator: std.mem.Allocator,
    patterns: std.ArrayList([]const u8) = .empty,

    fn deinit(self: *IgnoreRules) void {
        for (self.patterns.items) |pattern| self.allocator.free(pattern);
        self.patterns.deinit(self.allocator);
    }

    fn matches(self: *const IgnoreRules, path: []const u8) bool {
        for (self.patterns.items) |pattern| if (ignorePatternMatches(pattern, path)) return true;
        return false;
    }
};

fn loadIgnoreRules(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir) !IgnoreRules {
    var rules = IgnoreRules{ .allocator = allocator };
    errdefer rules.deinit();
    for ([_][]const u8{ ".gitignore", ".zgraphyignore" }) |ignore_path| {
        const contents = root.readFileAlloc(io, ignore_path, allocator, .limited(512 * 1024)) catch |failure| switch (failure) {
            error.FileNotFound => continue,
            else => return failure,
        };
        defer allocator.free(contents);
        var lines = std.mem.splitScalar(u8, contents, '\n');
        while (lines.next()) |raw_line| {
            var line = std.mem.trim(u8, raw_line, " \t\r");
            if (line.len == 0 or line[0] == '#') continue;
            if (line[0] == '!') continue;
            if (line[0] == '/') line = line[1..];
            if (line.len == 0 or line.len > 1024 or rules.patterns.items.len >= 4096) return error.InvalidIgnoreRule;
            try rules.patterns.append(allocator, try owned.copy(u8, allocator, line));
        }
    }
    return rules;
}

fn ignorePatternMatches(pattern: []const u8, path: []const u8) bool {
    if (std.mem.endsWith(u8, pattern, "/**")) {
        const prefix = pattern[0 .. pattern.len - 3];
        return std.mem.eql(u8, path, prefix) or (std.mem.startsWith(u8, path, prefix) and path.len > prefix.len and path[prefix.len] == '/');
    }
    if (std.mem.endsWith(u8, pattern, "/")) {
        const directory = pattern[0 .. pattern.len - 1];
        return std.mem.eql(u8, path, directory) or (std.mem.startsWith(u8, path, directory) and path.len > directory.len and path[directory.len] == '/');
    }
    if (std.mem.startsWith(u8, pattern, "*")) return std.mem.endsWith(u8, path, pattern[1..]);
    if (std.mem.indexOfScalar(u8, pattern, '/') == null) {
        var components = std.mem.splitScalar(u8, path, '/');
        while (components.next()) |component| if (std.mem.eql(u8, component, pattern)) return true;
    }
    return std.mem.eql(u8, path, pattern);
}

fn mandatoryExcluded(path: []const u8) bool {
    var components = std.mem.splitScalar(u8, path, '/');
    while (components.next()) |component| {
        for ([_][]const u8{ ".git", ".zgraphy", ".zig-cache", "zig-out", "node_modules", "zig-pkg" }) |excluded| {
            if (std.mem.eql(u8, component, excluded)) return true;
        }
    }
    return false;
}

fn looksBinary(source: []const u8) bool {
    const sample = source[0..@min(source.len, 8192)];
    return std.mem.indexOfScalar(u8, sample, 0) != null;
}

fn linkFileHierarchy(graph: *model.RepositoryGraph, repository_id: u64, path: []const u8) !void {
    const file = findFileByPath(graph, path) orelse return error.MissingIndexedFile;
    const file_id = file.id;
    const parent_path = std.fs.path.dirname(path) orelse {
        try graph.addEdge(.{ .from = repository_id, .to = file_id, .relation = .contains, .provenance = .extracted });
        return;
    };
    const directory_id = try graph.addNode(.{
        .kind = .directory,
        .label = std.fs.path.basename(parent_path),
        .path = parent_path,
        .search_text = parent_path,
    });
    try graph.addEdge(.{ .from = repository_id, .to = directory_id, .relation = .contains, .provenance = .extracted });
    try graph.addEdge(.{ .from = directory_id, .to = file_id, .relation = .contains, .provenance = .extracted });
}

fn resolveFileImports(graph: *model.RepositoryGraph) !void {
    const edges = try owned.copy(model.Edge, graph.allocator, graph.edges.items);
    defer graph.allocator.free(edges);
    for (edges) |edge| {
        if (edge.relation != .imports) continue;
        const importer = graph.findNode(edge.from) orelse continue;
        const external = graph.findNode(edge.to) orelse continue;
        if (importer.kind != .file or external.kind != .external_module) continue;
        var resolved_path_buffer = [_]u8{0} ** std.fs.max_path_bytes;
        const parent = std.fs.path.dirname(importer.path) orelse "";
        const candidate = if (parent.len == 0)
            std.fmt.bufPrint(&resolved_path_buffer, "{s}", .{external.path}) catch continue
        else
            std.fmt.bufPrint(&resolved_path_buffer, "{s}/{s}", .{ parent, external.path }) catch continue;
        const target = findFileByPath(graph, candidate) orelse continue;
        try graph.addEdge(.{
            .from = importer.id,
            .to = target.id,
            .relation = .imports,
            .provenance = .inferred,
            .source_path = importer.path,
            .line = edge.line,
        });
    }
}

fn resolveSymbolCalls(graph: *model.RepositoryGraph) !void {
    const edges = try owned.copy(model.Edge, graph.allocator, graph.edges.items);
    defer graph.allocator.free(edges);
    for (edges) |edge| {
        if (edge.relation != .calls) continue;
        const unresolved = graph.findNode(edge.to) orelse continue;
        if (unresolved.kind != .concept) continue;
        var resolved: ?u64 = null;
        for (graph.nodes.items) |candidate| {
            if (candidate.kind != .symbol or !std.mem.eql(u8, candidate.label, unresolved.label)) continue;
            if (resolved != null) {
                resolved = null;
                break;
            }
            resolved = candidate.id;
        }
        const target = resolved orelse continue;
        try graph.addEdge(.{
            .from = edge.from,
            .to = target,
            .relation = .calls,
            .provenance = .inferred,
            .source_path = edge.source_path,
            .line = edge.line,
        });
    }
}
