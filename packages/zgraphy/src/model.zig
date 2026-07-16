const std = @import("std");
const nendb = @import("nendb.zig");
const owned = @import("memory.zig");

pub const NodeKind = enum(u8) {
    repository,
    directory,
    file,
    symbol,
    external_module,
    component,
    requirement,
    acceptance_check,
    command,
    test_scenario,
    causal_event,
    concept,
    workspace,
    package,
    application,
    library,
    build_target,
    api_surface,
    module_reference,
    type,
    service,
    operation,
    message,
    field,
};

pub const Relation = enum(u16) {
    contains,
    declares,
    imports,
    calls,
    depends_on,
    satisfies,
    verified_by,
    executes,
    covers,
    source_root,
    causal_parent,
    observed_at,
    references,
    owned_by,
    member_of,
    part_of_target,
    defines,
    dispatches_to,
    deferred_imports,
    resolves_to,
    imports_from,
    re_exports,
    aliases,
    instantiates,
    has_field,
    uses_request,
    uses_response,
    references_type,
    generated_from,
    generated_client_for,
    generated_server_for,
};

pub const Provenance = enum(u8) {
    extracted,
    inferred,
    ambiguous,
};

pub const Options = struct {
    max_nodes: usize = 100_000,
    max_edges: usize = 500_000,
};

pub const Node = struct {
    id: u64,
    kind: NodeKind,
    label: []const u8,
    path: []const u8,
    line: u32,
    search_text: []const u8,
};

pub const Edge = struct {
    from: u64,
    to: u64,
    relation: Relation,
    provenance: Provenance = .extracted,
    source_path: []const u8 = "",
    line: u32 = 0,
};

pub const NodeInput = struct {
    id: ?u64 = null,
    kind: NodeKind,
    label: []const u8,
    path: []const u8 = "",
    line: u32 = 0,
    search_text: []const u8 = "",
};

pub const Path = struct {
    allocator: std.mem.Allocator,
    node_ids: []u64,
    complete: bool,
    exhausted: bool,

    pub fn deinit(self: *Path) void {
        self.allocator.free(self.node_ids);
    }
};

pub const RepositoryGraph = struct {
    allocator: std.mem.Allocator,
    topology: nendb.GraphData,
    nodes: std.ArrayList(Node) = .empty,
    edges: std.ArrayList(Edge) = .empty,

    pub fn init(allocator: std.mem.Allocator, options: Options) !RepositoryGraph {
        return .{
            .allocator = allocator,
            .topology = try nendb.GraphData.init(allocator, .{
                .max_nodes = options.max_nodes,
                .max_edges = options.max_edges,
            }),
        };
    }

    pub fn deinit(self: *RepositoryGraph) void {
        for (self.edges.items) |edge| if (edge.source_path.len > 0) self.allocator.free(edge.source_path);
        self.edges.deinit(self.allocator);
        for (self.nodes.items) |node| {
            self.allocator.free(node.label);
            if (node.path.len > 0) self.allocator.free(node.path);
            if (node.search_text.len > 0) self.allocator.free(node.search_text);
        }
        self.nodes.deinit(self.allocator);
        self.topology.deinit();
    }

    pub fn addNode(self: *RepositoryGraph, input: NodeInput) !u64 {
        const id = input.id orelse stableId(input.kind, input.path, input.label);
        if (self.topology.findNodeIndex(id)) |index| {
            const existing = self.nodes.items[index];
            if (existing.kind != input.kind or !std.mem.eql(u8, existing.label, input.label) or !std.mem.eql(u8, existing.path, input.path)) {
                return error.NodeIdCollision;
            }
            return id;
        }
        const label = try owned.copy(u8, self.allocator, input.label);
        errdefer self.allocator.free(label);
        const path = if (input.path.len == 0) "" else try owned.copy(u8, self.allocator, input.path);
        errdefer if (path.len > 0) self.allocator.free(path);
        const search_text = if (input.search_text.len == 0) "" else try owned.copy(u8, self.allocator, input.search_text);
        errdefer if (search_text.len > 0) self.allocator.free(search_text);

        const embedding = nendb.embedPair(input.label, input.search_text);
        const index = try self.topology.addNode(id, @intFromEnum(input.kind), &embedding);
        errdefer self.rollbackNode(index);
        try self.nodes.append(self.allocator, .{
            .id = id,
            .kind = input.kind,
            .label = label,
            .path = path,
            .line = input.line,
            .search_text = search_text,
        });
        return id;
    }

    pub fn addSearchableNode(
        self: *RepositoryGraph,
        kind: NodeKind,
        label: []const u8,
        path: []const u8,
        line: u32,
        search_text: []const u8,
    ) !u64 {
        return self.addNode(.{
            .kind = kind,
            .label = label,
            .path = path,
            .line = line,
            .search_text = search_text,
        });
    }

    pub fn addEdge(self: *RepositoryGraph, input: Edge) !void {
        if (self.hasEdge(input.from, input.to, input.relation)) return;
        const source_path = if (input.source_path.len == 0) "" else try owned.copy(u8, self.allocator, input.source_path);
        errdefer if (source_path.len > 0) self.allocator.free(source_path);
        _ = try self.topology.addEdge(input.from, input.to, @intFromEnum(input.relation));
        errdefer self.topology.edge_count -= 1;
        try self.edges.append(self.allocator, .{
            .from = input.from,
            .to = input.to,
            .relation = input.relation,
            .provenance = input.provenance,
            .source_path = source_path,
            .line = input.line,
        });
    }

    pub fn nodeCount(self: *const RepositoryGraph) usize {
        return self.nodes.items.len;
    }

    pub fn edgeCount(self: *const RepositoryGraph) usize {
        return self.edges.items.len;
    }

    pub fn vectorCount(self: *const RepositoryGraph) usize {
        return self.topology.vector_count;
    }

    pub fn nodeAt(self: *const RepositoryGraph, index: usize) *const Node {
        return &self.nodes.items[index];
    }

    pub fn vectorAt(self: *const RepositoryGraph, index: usize) []const f32 {
        return self.topology.vectorAt(@intCast(index));
    }

    pub fn findNode(self: *const RepositoryGraph, id: u64) ?*const Node {
        const index = self.topology.findNodeIndex(id) orelse return null;
        return &self.nodes.items[index];
    }

    pub fn findNodeByLabel(self: *const RepositoryGraph, label: []const u8) ?*const Node {
        for (self.nodes.items) |*node| if (std.ascii.eqlIgnoreCase(node.label, label)) return node;
        return null;
    }

    pub fn hasEdge(self: *const RepositoryGraph, from: u64, to: u64, relation: Relation) bool {
        for (self.edges.items) |edge| {
            if (edge.from == from and edge.to == to and edge.relation == relation) return true;
        }
        return false;
    }

    pub fn hasOutgoingRelation(self: *const RepositoryGraph, from: u64, relation: Relation) bool {
        for (self.edges.items) |edge| if (edge.from == from and edge.relation == relation) return true;
        return false;
    }

    pub fn shortestPathAlloc(
        self: *const RepositoryGraph,
        allocator: std.mem.Allocator,
        from: u64,
        to: u64,
        max_hops: usize,
    ) !Path {
        if (self.findNode(from) == null or self.findNode(to) == null) return error.NodeNotFound;
        if (max_hops == 0) return error.InvalidHopLimit;
        if (from == to) return .{
            .allocator = allocator,
            .node_ids = try owned.copy(u64, allocator, &.{from}),
            .complete = true,
            .exhausted = false,
        };

        const Parent = struct { parent: u64, depth: usize };
        var parents = std.AutoHashMap(u64, Parent).init(allocator);
        defer parents.deinit();
        var queue: std.ArrayList(u64) = .empty;
        defer queue.deinit(allocator);
        try queue.append(allocator, from);
        try parents.put(from, .{ .parent = from, .depth = 0 });
        var cursor: usize = 0;
        var found = false;
        var exhausted = false;
        while (cursor < queue.items.len and !found) : (cursor += 1) {
            const current = queue.items[cursor];
            const depth = parents.get(current).?.depth;
            if (depth >= max_hops) {
                exhausted = true;
                continue;
            }
            for (self.edges.items) |edge| {
                const neighbor = if (edge.from == current) edge.to else if (edge.to == current) edge.from else continue;
                if (parents.contains(neighbor)) continue;
                try parents.put(neighbor, .{ .parent = current, .depth = depth + 1 });
                try queue.append(allocator, neighbor);
                if (neighbor == to) {
                    found = true;
                    break;
                }
            }
        }
        if (!found) return .{
            .allocator = allocator,
            .node_ids = try owned.slice(u64, allocator, 0),
            .complete = false,
            .exhausted = exhausted,
        };
        const depth = parents.get(to).?.depth;
        const ids = try owned.slice(u64, allocator, depth + 1);
        var current = to;
        var index = depth + 1;
        while (index > 0) {
            index -= 1;
            ids[index] = current;
            current = parents.get(current).?.parent;
        }
        return .{ .allocator = allocator, .node_ids = ids, .complete = true, .exhausted = false };
    }

    fn rollbackNode(self: *RepositoryGraph, index: u32) void {
        const id = self.topology.node_ids[index];
        _ = self.topology.id_index.remove(id);
        self.topology.node_active[index] = false;
        self.topology.node_count -= 1;
        self.topology.vector_count -= 1;
    }
};

pub fn stableId(kind: NodeKind, scope: []const u8, name: []const u8) u64 {
    var hash = std.hash.Wyhash.hash(0x7a67726170687931, @tagName(kind));
    hash = std.hash.Wyhash.hash(hash, scope);
    hash = std.hash.Wyhash.hash(hash, name);
    return if (hash == 0) 1 else hash;
}
