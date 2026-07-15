const std = @import("std");
const zstd = @import("zigeffect_std");
const Typed = @import("typed.zig");
const proto = @import("generated/grpc/channelz/v1.pb.zig");

pub const Grpc = zstd.Grpc;
pub const Proto = proto;

pub const State = enum { unknown, idle, connecting, ready, transient_failure, shutdown };

pub const Ref = struct {
    id: i64,
    name: []const u8 = "",
};

pub const ChannelSnapshot = struct {
    ref: Ref,
    state: State,
    target: []const u8 = "",
    calls_started: i64 = 0,
    calls_succeeded: i64 = 0,
    calls_failed: i64 = 0,
    channel_refs: []const Ref = &.{},
    subchannel_refs: []const Ref = &.{},
    socket_refs: []const Ref = &.{},
};

pub const SubchannelSnapshot = ChannelSnapshot;

pub const ServerSnapshot = struct {
    ref: Ref,
    calls_started: i64 = 0,
    calls_succeeded: i64 = 0,
    calls_failed: i64 = 0,
    listen_socket_refs: []const Ref = &.{},
};

pub const SocketSnapshot = struct {
    ref: Ref,
    /// Owning server for accepted/listening sockets. Null denotes a client
    /// channel socket and excludes it from GetServerSockets pagination.
    server_id: ?i64 = null,
    streams_started: i64 = 0,
    streams_succeeded: i64 = 0,
    streams_failed: i64 = 0,
    messages_sent: i64 = 0,
    messages_received: i64 = 0,
    keepalives_sent: i64 = 0,
    peer_max_concurrent_streams: u32 = 0,
    remote_name: []const u8 = "",
};

fn SnapshotSource(comptime Snapshot: type) type {
    return struct {
        pointer: *anyopaque,
        snapshot_fn: *const fn (*anyopaque) Snapshot,

        pub fn from(comptime Provider: type, provider: *Provider) @This() {
            return .{
                .pointer = provider,
                .snapshot_fn = struct {
                    fn snapshot(pointer: *anyopaque) Snapshot {
                        return (@as(*Provider, @ptrCast(@alignCast(pointer)))).channelzSnapshot();
                    }
                }.snapshot,
            };
        }

        pub fn snapshot(self: @This()) Snapshot {
            return self.snapshot_fn(self.pointer);
        }
    };
}

pub const ChannelSource = SnapshotSource(ChannelSnapshot);
pub const SubchannelSource = SnapshotSource(SubchannelSnapshot);
pub const ServerSource = SnapshotSource(ServerSnapshot);
pub const SocketSource = SnapshotSource(SocketSnapshot);

pub const Registry = struct {
    allocator: std.mem.Allocator,
    channels: std.ArrayList(ChannelSource) = .empty,
    subchannels: std.ArrayList(SubchannelSource) = .empty,
    servers: std.ArrayList(ServerSource) = .empty,
    sockets: std.ArrayList(SocketSource) = .empty,
    mutex: std.atomic.Mutex = .unlocked,

    pub fn init(allocator: std.mem.Allocator) Registry {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Registry) void {
        self.channels.deinit(self.allocator);
        self.subchannels.deinit(self.allocator);
        self.servers.deinit(self.allocator);
        self.sockets.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn registerChannel(self: *Registry, source: ChannelSource) !void {
        try validateRef(source.snapshot().ref);
        self.lock();
        defer self.mutex.unlock();
        if (findSource(ChannelSnapshot, self.channels.items, source.snapshot().ref.id) != null) return error.DuplicateChannelzId;
        try self.channels.append(self.allocator, source);
    }

    pub fn registerSubchannel(self: *Registry, source: SubchannelSource) !void {
        try validateRef(source.snapshot().ref);
        self.lock();
        defer self.mutex.unlock();
        if (findSource(SubchannelSnapshot, self.subchannels.items, source.snapshot().ref.id) != null) return error.DuplicateChannelzId;
        try self.subchannels.append(self.allocator, source);
    }

    pub fn registerServer(self: *Registry, source: ServerSource) !void {
        try validateRef(source.snapshot().ref);
        self.lock();
        defer self.mutex.unlock();
        if (findSource(ServerSnapshot, self.servers.items, source.snapshot().ref.id) != null) return error.DuplicateChannelzId;
        try self.servers.append(self.allocator, source);
    }

    pub fn registerSocket(self: *Registry, source: SocketSource) !void {
        try validateRef(source.snapshot().ref);
        self.lock();
        defer self.mutex.unlock();
        if (findSource(SocketSnapshot, self.sockets.items, source.snapshot().ref.id) != null) return error.DuplicateChannelzId;
        try self.sockets.append(self.allocator, source);
    }

    fn lock(self: *Registry) void {
        while (!self.mutex.tryLock()) std.Thread.yield() catch {};
    }
};

fn validateRef(ref: Ref) !void {
    if (ref.id <= 0 or ref.name.len > 512) return error.InvalidChannelzReference;
}

fn findSource(comptime Snapshot: type, sources: []const SnapshotSource(Snapshot), id: i64) ?SnapshotSource(Snapshot) {
    for (sources) |source| if (source.snapshot().ref.id == id) return source;
    return null;
}

pub const Service = struct {
    registry: *Registry,

    pub fn install(self: *Service, unary: *Grpc.Registry) !void {
        inline for (.{
            "GetTopChannels",
            "GetServers",
            "GetServer",
            "GetServerSockets",
            "GetChannel",
            "GetSubchannel",
            "GetSocket",
        }) |method| try unary.register(.{
            .service = "grpc.channelz.v1.Channelz",
            .method = method,
            .handler = Grpc.UnaryHandler.from(Service, self),
        });
    }

    pub fn invoke(self: *Service, allocator: std.mem.Allocator, request: Grpc.UnaryRequest) !Grpc.UnaryResponse {
        self.registry.lock();
        defer self.registry.mutex.unlock();
        if (std.mem.eql(u8, request.method, "GetTopChannels")) return self.getTopChannels(allocator, request.payload);
        if (std.mem.eql(u8, request.method, "GetServers")) return self.getServers(allocator, request.payload);
        if (std.mem.eql(u8, request.method, "GetServer")) return self.getServer(allocator, request.payload);
        if (std.mem.eql(u8, request.method, "GetServerSockets")) return self.getServerSockets(allocator, request.payload);
        if (std.mem.eql(u8, request.method, "GetChannel")) return self.getChannel(allocator, request.payload);
        if (std.mem.eql(u8, request.method, "GetSubchannel")) return self.getSubchannel(allocator, request.payload);
        if (std.mem.eql(u8, request.method, "GetSocket")) return self.getSocket(allocator, request.payload);
        return Grpc.UnaryResponse.initAlloc(allocator, "", .{ .code = .unimplemented, .message = "Channelz method is not implemented" });
    }

    fn getTopChannels(self: *Service, allocator: std.mem.Allocator, payload: []const u8) !Grpc.UnaryResponse {
        var request = try Typed.decodeAlloc(proto.GetTopChannelsRequest, allocator, payload);
        defer request.deinit(allocator);
        const page = pageBounds(request.start_channel_id, request.max_results) catch return statusResponse(allocator, .invalid_argument, "invalid Channelz page");
        var response = proto.GetTopChannelsResponse{ .end = true };
        defer deinitChannels(allocator, &response.channel);
        for (self.registry.channels.items) |source| {
            const snapshot = source.snapshot();
            if (snapshot.ref.id < page.start) continue;
            if (response.channel.items.len == page.maximum) {
                response.end = false;
                break;
            }
            try response.channel.append(allocator, try channelMessage(allocator, snapshot));
        }
        return encodedResponse(allocator, response);
    }

    fn getServers(self: *Service, allocator: std.mem.Allocator, payload: []const u8) !Grpc.UnaryResponse {
        var request = try Typed.decodeAlloc(proto.GetServersRequest, allocator, payload);
        defer request.deinit(allocator);
        const page = pageBounds(request.start_server_id, request.max_results) catch return statusResponse(allocator, .invalid_argument, "invalid Channelz page");
        var response = proto.GetServersResponse{ .end = true };
        defer deinitServers(allocator, &response.server);
        for (self.registry.servers.items) |source| {
            const snapshot = source.snapshot();
            if (snapshot.ref.id < page.start) continue;
            if (response.server.items.len == page.maximum) {
                response.end = false;
                break;
            }
            try response.server.append(allocator, try serverMessage(allocator, snapshot));
        }
        return encodedResponse(allocator, response);
    }

    fn getServer(self: *Service, allocator: std.mem.Allocator, payload: []const u8) !Grpc.UnaryResponse {
        var request = try Typed.decodeAlloc(proto.GetServerRequest, allocator, payload);
        defer request.deinit(allocator);
        const source = findSource(ServerSnapshot, self.registry.servers.items, request.server_id) orelse return statusResponse(allocator, .not_found, "Channelz server not found");
        var server = try serverMessage(allocator, source.snapshot());
        defer deinitServer(allocator, &server);
        return encodedResponse(allocator, proto.GetServerResponse{ .server = server });
    }

    fn getServerSockets(self: *Service, allocator: std.mem.Allocator, payload: []const u8) !Grpc.UnaryResponse {
        var request = try Typed.decodeAlloc(proto.GetServerSocketsRequest, allocator, payload);
        defer request.deinit(allocator);
        if (findSource(ServerSnapshot, self.registry.servers.items, request.server_id) == null) return statusResponse(allocator, .not_found, "Channelz server not found");
        const page = pageBounds(request.start_socket_id, request.max_results) catch return statusResponse(allocator, .invalid_argument, "invalid Channelz page");
        var response = proto.GetServerSocketsResponse{ .end = true };
        defer response.socket_ref.deinit(allocator);
        for (self.registry.sockets.items) |source| {
            const snapshot = source.snapshot();
            if (snapshot.server_id == null or snapshot.server_id.? != request.server_id) continue;
            if (snapshot.ref.id < page.start) continue;
            if (response.socket_ref.items.len == page.maximum) {
                response.end = false;
                break;
            }
            try response.socket_ref.append(allocator, socketRef(snapshot.ref));
        }
        return encodedResponse(allocator, response);
    }

    fn getChannel(self: *Service, allocator: std.mem.Allocator, payload: []const u8) !Grpc.UnaryResponse {
        var request = try Typed.decodeAlloc(proto.GetChannelRequest, allocator, payload);
        defer request.deinit(allocator);
        const source = findSource(ChannelSnapshot, self.registry.channels.items, request.channel_id) orelse return statusResponse(allocator, .not_found, "Channelz channel not found");
        var channel = try channelMessage(allocator, source.snapshot());
        defer deinitChannel(allocator, &channel);
        return encodedResponse(allocator, proto.GetChannelResponse{ .channel = channel });
    }

    fn getSubchannel(self: *Service, allocator: std.mem.Allocator, payload: []const u8) !Grpc.UnaryResponse {
        var request = try Typed.decodeAlloc(proto.GetSubchannelRequest, allocator, payload);
        defer request.deinit(allocator);
        const source = findSource(SubchannelSnapshot, self.registry.subchannels.items, request.subchannel_id) orelse return statusResponse(allocator, .not_found, "Channelz subchannel not found");
        var subchannel = try subchannelMessage(allocator, source.snapshot());
        defer deinitSubchannel(allocator, &subchannel);
        return encodedResponse(allocator, proto.GetSubchannelResponse{ .subchannel = subchannel });
    }

    fn getSocket(self: *Service, allocator: std.mem.Allocator, payload: []const u8) !Grpc.UnaryResponse {
        var request = try Typed.decodeAlloc(proto.GetSocketRequest, allocator, payload);
        defer request.deinit(allocator);
        const source = findSource(SocketSnapshot, self.registry.sockets.items, request.socket_id) orelse return statusResponse(allocator, .not_found, "Channelz socket not found");
        return encodedResponse(allocator, proto.GetSocketResponse{ .socket = socketMessage(source.snapshot()) });
    }
};

fn pageBounds(start: i64, maximum: i64) !struct { start: i64, maximum: usize } {
    if (start < 0 or maximum < 0) return error.InvalidPage;
    return .{ .start = start, .maximum = if (maximum == 0) 100 else @intCast(@min(maximum, 100)) };
}

fn stateMessage(state: State) proto.ChannelConnectivityState {
    return .{ .state = switch (state) {
        .unknown => .UNKNOWN,
        .idle => .IDLE,
        .connecting => .CONNECTING,
        .ready => .READY,
        .transient_failure => .TRANSIENT_FAILURE,
        .shutdown => .SHUTDOWN,
    } };
}

fn channelRef(ref: Ref) proto.ChannelRef {
    return .{ .channel_id = ref.id, .name = ref.name };
}
fn subchannelRef(ref: Ref) proto.SubchannelRef {
    return .{ .subchannel_id = ref.id, .name = ref.name };
}
fn socketRef(ref: Ref) proto.SocketRef {
    return .{ .socket_id = ref.id, .name = ref.name };
}

fn channelMessage(allocator: std.mem.Allocator, snapshot: ChannelSnapshot) !proto.Channel {
    var result = proto.Channel{
        .ref = channelRef(snapshot.ref),
        .data = .{
            .state = stateMessage(snapshot.state),
            .target = snapshot.target,
            .calls_started = snapshot.calls_started,
            .calls_succeeded = snapshot.calls_succeeded,
            .calls_failed = snapshot.calls_failed,
        },
    };
    for (snapshot.channel_refs) |ref| try result.channel_ref.append(allocator, channelRef(ref));
    for (snapshot.subchannel_refs) |ref| try result.subchannel_ref.append(allocator, subchannelRef(ref));
    for (snapshot.socket_refs) |ref| try result.socket_ref.append(allocator, socketRef(ref));
    return result;
}

fn subchannelMessage(allocator: std.mem.Allocator, snapshot: SubchannelSnapshot) !proto.Subchannel {
    var result = proto.Subchannel{
        .ref = subchannelRef(snapshot.ref),
        .data = .{
            .state = stateMessage(snapshot.state),
            .target = snapshot.target,
            .calls_started = snapshot.calls_started,
            .calls_succeeded = snapshot.calls_succeeded,
            .calls_failed = snapshot.calls_failed,
        },
    };
    for (snapshot.channel_refs) |ref| try result.channel_ref.append(allocator, channelRef(ref));
    for (snapshot.subchannel_refs) |ref| try result.subchannel_ref.append(allocator, subchannelRef(ref));
    for (snapshot.socket_refs) |ref| try result.socket_ref.append(allocator, socketRef(ref));
    return result;
}

fn serverMessage(allocator: std.mem.Allocator, snapshot: ServerSnapshot) !proto.Server {
    var result = proto.Server{
        .ref = .{ .server_id = snapshot.ref.id, .name = snapshot.ref.name },
        .data = .{
            .calls_started = snapshot.calls_started,
            .calls_succeeded = snapshot.calls_succeeded,
            .calls_failed = snapshot.calls_failed,
        },
    };
    for (snapshot.listen_socket_refs) |ref| try result.listen_socket.append(allocator, socketRef(ref));
    return result;
}

fn socketMessage(snapshot: SocketSnapshot) proto.Socket {
    return .{
        .ref = socketRef(snapshot.ref),
        .data = .{
            .streams_started = snapshot.streams_started,
            .streams_succeeded = snapshot.streams_succeeded,
            .streams_failed = snapshot.streams_failed,
            .messages_sent = snapshot.messages_sent,
            .messages_received = snapshot.messages_received,
            .keep_alives_sent = snapshot.keepalives_sent,
            .peer_max_concurrent_streams = snapshot.peer_max_concurrent_streams,
        },
        .remote_name = snapshot.remote_name,
    };
}

fn deinitChannel(allocator: std.mem.Allocator, channel: *proto.Channel) void {
    channel.channel_ref.deinit(allocator);
    channel.subchannel_ref.deinit(allocator);
    channel.socket_ref.deinit(allocator);
}
fn deinitChannels(allocator: std.mem.Allocator, channels: *std.ArrayList(proto.Channel)) void {
    for (channels.items) |*channel| deinitChannel(allocator, channel);
    channels.deinit(allocator);
}
fn deinitSubchannel(allocator: std.mem.Allocator, subchannel: *proto.Subchannel) void {
    subchannel.channel_ref.deinit(allocator);
    subchannel.subchannel_ref.deinit(allocator);
    subchannel.socket_ref.deinit(allocator);
}
fn deinitServer(allocator: std.mem.Allocator, server: *proto.Server) void {
    server.listen_socket.deinit(allocator);
}
fn deinitServers(allocator: std.mem.Allocator, servers: *std.ArrayList(proto.Server)) void {
    for (servers.items) |*server| deinitServer(allocator, server);
    servers.deinit(allocator);
}

fn encodedResponse(allocator: std.mem.Allocator, response: anytype) !Grpc.UnaryResponse {
    const bytes = try Typed.encodeAlloc(allocator, response);
    defer allocator.free(bytes);
    return Grpc.UnaryResponse.initAlloc(allocator, bytes, .ok());
}

fn statusResponse(allocator: std.mem.Allocator, code: Grpc.Code, message: []const u8) !Grpc.UnaryResponse {
    return Grpc.UnaryResponse.initAlloc(allocator, "", .{ .code = code, .message = message });
}

test "official Channelz service binds paginated channel server subchannel and socket snapshots" {
    const ChannelProvider = struct {
        pub fn channelzSnapshot(_: *@This()) ChannelSnapshot {
            return .{ .ref = .{ .id = 1, .name = "orders" }, .state = .ready, .target = "dns:///orders:443", .calls_started = 3, .calls_succeeded = 2, .calls_failed = 1 };
        }
    };
    const SubchannelProvider = struct {
        pub fn channelzSnapshot(_: *@This()) SubchannelSnapshot {
            return .{ .ref = .{ .id = 7, .name = "orders-0" }, .state = .ready };
        }
    };
    const ServerProvider = struct {
        pub fn channelzSnapshot(_: *@This()) ServerSnapshot {
            return .{ .ref = .{ .id = 5, .name = "api" }, .calls_started = 4, .calls_succeeded = 4 };
        }
    };
    const SocketProvider = struct {
        pub fn channelzSnapshot(_: *@This()) SocketSnapshot {
            return .{ .ref = .{ .id = 3, .name = "h2" }, .server_id = 5, .streams_started = 9, .streams_succeeded = 8, .streams_failed = 1 };
        }
    };
    const OtherSocketProvider = struct {
        pub fn channelzSnapshot(_: *@This()) SocketSnapshot {
            return .{ .ref = .{ .id = 4, .name = "other" }, .server_id = 6 };
        }
    };
    var channel_provider = ChannelProvider{};
    var subchannel_provider = SubchannelProvider{};
    var server_provider = ServerProvider{};
    var socket_provider = SocketProvider{};
    var other_socket_provider = OtherSocketProvider{};
    var snapshots = Registry.init(std.testing.allocator);
    defer snapshots.deinit();
    try snapshots.registerChannel(ChannelSource.from(ChannelProvider, &channel_provider));
    try snapshots.registerSubchannel(SubchannelSource.from(SubchannelProvider, &subchannel_provider));
    try snapshots.registerServer(ServerSource.from(ServerProvider, &server_provider));
    try snapshots.registerSocket(SocketSource.from(SocketProvider, &socket_provider));
    try snapshots.registerSocket(SocketSource.from(OtherSocketProvider, &other_socket_provider));
    var service = Service{ .registry = &snapshots };
    var unary = Grpc.Registry.init(std.testing.allocator);
    defer unary.deinit();
    try service.install(&unary);
    const request_bytes = try Typed.encodeAlloc(std.testing.allocator, proto.GetTopChannelsRequest{});
    defer std.testing.allocator.free(request_bytes);
    var response = try unary.invokeAlloc(std.testing.allocator, .{ .authority = "local", .service = "grpc.channelz.v1.Channelz", .method = "GetTopChannels", .payload = request_bytes, .timeout_millis = 1_000 }, .{});
    defer response.deinit();
    var decoded = try Typed.decodeAlloc(proto.GetTopChannelsResponse, std.testing.allocator, response.payload);
    defer decoded.deinit(std.testing.allocator);
    try std.testing.expect(response.status.isOk());
    try std.testing.expectEqual(@as(usize, 1), decoded.channel.items.len);
    try std.testing.expectEqual(@as(i64, 1), decoded.channel.items[0].ref.?.channel_id);
    try std.testing.expectEqual(proto.ChannelConnectivityState.State.READY, decoded.channel.items[0].data.?.state.?.state);

    const sockets_request = try Typed.encodeAlloc(std.testing.allocator, proto.GetServerSocketsRequest{ .server_id = 5 });
    defer std.testing.allocator.free(sockets_request);
    var sockets_response = try unary.invokeAlloc(std.testing.allocator, .{ .authority = "local", .service = "grpc.channelz.v1.Channelz", .method = "GetServerSockets", .payload = sockets_request, .timeout_millis = 1_000 }, .{});
    defer sockets_response.deinit();
    var sockets = try Typed.decodeAlloc(proto.GetServerSocketsResponse, std.testing.allocator, sockets_response.payload);
    defer sockets.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), sockets.socket_ref.items.len);
    try std.testing.expectEqual(@as(i64, 3), sockets.socket_ref.items[0].socket_id);
}
