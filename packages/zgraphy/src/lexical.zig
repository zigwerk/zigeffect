const std = @import("std");
const owned = @import("memory.zig");

pub const NodeKind = enum {
    repository,
    file,
    token,
};

pub const Node = struct {
    kind: NodeKind,
    label: []const u8,
    path: []const u8,
    line: u32,
};

pub const Options = struct {
    max_files: usize = 1024,
    max_file_bytes: usize = 1024 * 1024,
    max_source_bytes: usize = 8 * 1024 * 1024,
    max_nodes: usize = 4096,
    max_token_bytes: usize = 128,
};

pub const Graph = struct {
    allocator: std.mem.Allocator,
    nodes: std.ArrayList(Node) = .empty,
    files: usize = 0,
    source_bytes: usize = 0,

    pub fn init(allocator: std.mem.Allocator) Graph {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Graph) void {
        for (self.nodes.items) |node| {
            self.allocator.free(node.label);
            self.allocator.free(node.path);
        }
        self.nodes.deinit(self.allocator);
    }

    fn addNode(self: *Graph, options: Options, kind: NodeKind, label: []const u8, path: []const u8, line: u32) !void {
        if (self.nodes.items.len >= options.max_nodes) return error.LexicalNodeLimitExceeded;
        const owned_label = try owned.copy(u8, self.allocator, label);
        errdefer self.allocator.free(owned_label);
        const owned_path = try owned.copy(u8, self.allocator, path);
        errdefer self.allocator.free(owned_path);
        try self.nodes.append(self.allocator, .{
            .kind = kind,
            .label = owned_label,
            .path = owned_path,
            .line = line,
        });
    }

    fn hasToken(self: *const Graph, path: []const u8, token: []const u8) bool {
        for (self.nodes.items) |node| {
            if (node.kind == .token and std.mem.eql(u8, node.path, path) and std.mem.eql(u8, node.label, token)) return true;
        }
        return false;
    }
};

pub fn build(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    options: Options,
) !Graph {
    if (options.max_files == 0 or options.max_file_bytes == 0 or options.max_source_bytes == 0 or
        options.max_nodes == 0 or options.max_token_bytes == 0)
    {
        return error.InvalidLexicalLimit;
    }
    var graph = Graph.init(allocator);
    errdefer graph.deinit();
    try graph.addNode(options, .repository, ".", ".", 0);

    var paths: std.ArrayList([]const u8) = .empty;
    defer {
        for (paths.items) |path| allocator.free(path);
        paths.deinit(allocator);
    }
    var walker = try root.walk(allocator);
    defer walker.deinit();
    while (try walker.next(io)) |entry| {
        if (entry.kind != .file or excludedPath(entry.path) or !supportedPath(entry.path)) continue;
        if (paths.items.len >= options.max_files) return error.LexicalFileLimitExceeded;
        try paths.append(allocator, try owned.copy(u8, allocator, entry.path));
    }
    std.mem.sort([]const u8, paths.items, {}, struct {
        fn lessThan(_: void, left: []const u8, right: []const u8) bool {
            return std.mem.lessThan(u8, left, right);
        }
    }.lessThan);

    for (paths.items) |path| {
        const source = try root.readFileAlloc(io, path, allocator, .limited(options.max_file_bytes));
        defer allocator.free(source);
        graph.source_bytes = std.math.add(usize, graph.source_bytes, source.len) catch return error.LexicalSourceLimitExceeded;
        if (graph.source_bytes > options.max_source_bytes) return error.LexicalSourceLimitExceeded;
        try graph.addNode(options, .file, std.fs.path.basename(path), path, 1);
        graph.files += 1;
        try addTokens(&graph, options, path, source);
    }
    return graph;
}

fn addTokens(graph: *Graph, options: Options, path: []const u8, source: []const u8) !void {
    var cursor: usize = 0;
    var line: u32 = 1;
    while (cursor < source.len) {
        const byte = source[cursor];
        if (byte == '\n') {
            line += 1;
            cursor += 1;
            continue;
        }
        if (!identifierStart(byte)) {
            cursor += 1;
            continue;
        }
        const start = cursor;
        cursor += 1;
        while (cursor < source.len and identifierContinue(source[cursor])) : (cursor += 1) {}
        const token = source[start..cursor];
        if (token.len > options.max_token_bytes or graph.hasToken(path, token)) continue;
        try graph.addNode(options, .token, token, path, line);
    }
}

fn identifierStart(byte: u8) bool {
    return std.ascii.isAlphabetic(byte) or byte == '_';
}

fn identifierContinue(byte: u8) bool {
    return identifierStart(byte) or std.ascii.isDigit(byte);
}

fn supportedPath(path: []const u8) bool {
    for ([_][]const u8{ ".zig", ".ts", ".tsx", ".js", ".jsx", ".proto" }) |extension| {
        if (std.mem.endsWith(u8, path, extension)) return true;
    }
    return false;
}

fn excludedPath(path: []const u8) bool {
    var components = std.mem.splitScalar(u8, path, '/');
    while (components.next()) |component| {
        for ([_][]const u8{ ".git", ".zgraphy", ".zig-cache", "zig-out", "node_modules" }) |excluded| {
            if (std.mem.eql(u8, component, excluded)) return true;
        }
    }
    return false;
}
