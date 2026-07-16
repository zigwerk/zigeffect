const std = @import("std");
const service_mod = @import("service.zig");

pub const Allocator = std.mem.Allocator;

pub const LayerKind = enum {
    succeed,
    sync,
    effect,
    scoped,
};

pub const LayerStatus = enum {
    declared,
    building,
    ready,
    failed,
};

pub const LayerNode = struct {
    id: u64,
    kind: LayerKind,
    status: LayerStatus = .declared,
    name: []const u8,
    provided_service_key: []const u8,
    provided_api_type: []const u8,
    operations: []const []const u8 = &.{},
    memoized_reuses: usize = 0,
};

pub const ServiceRequirement = struct {
    consumer_layer_id: u64,
    service_key: []const u8,
};

pub const ServiceNode = struct {
    key: []const u8,
    api_type: []const u8,
    provider_layer_id: u64,
    exposed: bool,
    operations: []const []const u8 = &.{},
};

pub const DependencyEdge = struct {
    provider_layer_id: u64,
    consumer_layer_id: u64,
    service_key: []const u8,
};

pub const TopologySnapshot = struct {
    allocator: Allocator,
    layers: []LayerNode,
    services: []ServiceNode,
    edges: []DependencyEdge,

    pub fn deinit(self: *TopologySnapshot) void {
        self.allocator.free(self.layers);
        self.allocator.free(self.services);
        self.allocator.free(self.edges);
        self.* = undefined;
    }
};

pub const Topology = struct {
    allocator: Allocator,
    layers: std.ArrayList(LayerNode) = .empty,
    requirements: std.ArrayList(ServiceRequirement) = .empty,
    exposed_services: std.StringHashMap(void),

    pub fn init(allocator: Allocator) Topology {
        return .{
            .allocator = allocator,
            .exposed_services = std.StringHashMap(void).init(allocator),
        };
    }

    pub fn deinit(self: *Topology) void {
        self.layers.deinit(self.allocator);
        self.requirements.deinit(self.allocator);
        self.exposed_services.deinit();
    }

    pub fn declare(
        self: *Topology,
        id: u64,
        kind: LayerKind,
        comptime Tag: type,
        comptime Requirements: anytype,
    ) Allocator.Error!void {
        service_mod.assertServiceTag(Tag);
        if (self.findLayer(id) != null) return;

        try self.layers.append(self.allocator, .{
            .id = id,
            .kind = kind,
            .name = Tag.service_key,
            .provided_service_key = Tag.service_key,
            .provided_api_type = @typeName(Tag.API),
            .operations = if (@hasDecl(Tag, "operations")) Tag.operations else &.{},
        });
        errdefer _ = self.layers.pop();

        inline for (Requirements) |Required| {
            try self.requirements.append(self.allocator, .{
                .consumer_layer_id = id,
                .service_key = Required.service_key,
            });
        }
    }

    pub fn markBuilding(self: *Topology, id: u64) void {
        if (self.findLayer(id)) |node| node.status = .building;
    }

    pub fn markReady(self: *Topology, id: u64) void {
        if (self.findLayer(id)) |node| node.status = .ready;
    }

    pub fn markFailed(self: *Topology, id: u64) void {
        if (self.findLayer(id)) |node| node.status = .failed;
    }

    pub fn markMemoized(self: *Topology, id: u64) void {
        if (self.findLayer(id)) |node| node.memoized_reuses += 1;
    }

    pub fn markRootOutputs(self: *Topology, comptime Outputs: anytype) Allocator.Error!void {
        inline for (Outputs) |Tag| try self.exposed_services.put(Tag.service_key, {});
    }

    pub fn snapshot(self: *const Topology, allocator: Allocator) Allocator.Error!TopologySnapshot {
        const layers = try allocator.dupe(LayerNode, self.layers.items);
        errdefer allocator.free(layers);

        const services = try allocator.alloc(ServiceNode, self.layers.items.len);
        errdefer allocator.free(services);
        for (self.layers.items, 0..) |layer, index| {
            services[index] = .{
                .key = layer.provided_service_key,
                .api_type = layer.provided_api_type,
                .provider_layer_id = layer.id,
                .exposed = self.exposed_services.contains(layer.provided_service_key),
                .operations = layer.operations,
            };
        }

        var edges = std.ArrayList(DependencyEdge).empty;
        errdefer edges.deinit(allocator);
        for (self.requirements.items) |requirement| {
            for (self.layers.items) |provider| {
                if (!std.mem.eql(u8, provider.provided_service_key, requirement.service_key)) continue;
                try edges.append(allocator, .{
                    .provider_layer_id = provider.id,
                    .consumer_layer_id = requirement.consumer_layer_id,
                    .service_key = requirement.service_key,
                });
                break;
            }
        }

        return .{
            .allocator = allocator,
            .layers = layers,
            .services = services,
            .edges = try edges.toOwnedSlice(allocator),
        };
    }

    fn findLayer(self: *Topology, id: u64) ?*LayerNode {
        for (self.layers.items) |*layer| if (layer.id == id) return layer;
        return null;
    }
};
