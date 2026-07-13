const std = @import("std");
const zstd = @import("zigeffect_std");
const Typed = @import("typed.zig");
const Incremental = @import("incremental.zig");
const health_proto = @import("generated/grpc/health/v1.pb.zig");
const reflection_proto = @import("generated/grpc/reflection/v1.pb.zig");

pub const Grpc = zstd.Grpc;
pub const embedded_descriptor_set = @embedFile("generated/schema.binpb");

pub const Services = struct {
    health: *Grpc.HealthRegistry,
    descriptor_set: []const u8 = embedded_descriptor_set,
    service_names: []const []const u8,

    pub fn install(self: *Services, unary: *Grpc.Registry, streaming: *Grpc.StreamingRegistry) !void {
        try unary.register(.{
            .service = "grpc.health.v1.Health",
            .method = "Check",
            .handler = Grpc.UnaryHandler.from(Services, self),
        });
        try streaming.register("grpc.health.v1.Health", "Watch", .server_streaming, Grpc.StreamingHandler.from(Services, self));
        try streaming.register("grpc.reflection.v1.ServerReflection", "ServerReflectionInfo", .bidirectional_streaming, Grpc.StreamingHandler.from(Services, self));
        try streaming.register("grpc.reflection.v1alpha.ServerReflection", "ServerReflectionInfo", .bidirectional_streaming, Grpc.StreamingHandler.from(Services, self));
    }

    /// Installs the live Health Watch implementation. The incremental route
    /// takes precedence over the buffered compatibility route on the host.
    pub fn installIncremental(self: *Services, incremental: *Incremental.Registry) !void {
        try incremental.register(
            "grpc.health.v1.Health",
            "Watch",
            .server_streaming,
            Incremental.Handler.from(Services, self),
        );
    }

    pub fn runIncremental(self: *Services, call: *Incremental.Call) anyerror!Grpc.Status {
        if (!std.mem.eql(u8, call.context.service, "grpc.health.v1.Health") or
            !std.mem.eql(u8, call.context.method, "Watch")) return .{ .code = .unimplemented };
        const first = (try call.receive()) orelse return .{ .code = .invalid_argument, .message = "health request required" };
        var request_message = first;
        defer request_message.deinit();
        var request = try Typed.decodeAlloc(health_proto.HealthCheckRequest, self.health.allocator, request_message.bytes);
        defer request.deinit(self.health.allocator);

        var subscription = try self.health.subscribe(call.inbound.io, request.service);
        defer subscription.deinit();
        var last_status = self.health.check(request.service);
        try self.sendHealth(call, last_status);
        const deadline = std.Io.Clock.Timestamp.fromNow(call.inbound.io, .{
            .raw = .fromMilliseconds(@intCast(call.context.timeout_millis)),
            .clock = .awake,
        });
        while (true) {
            const Event = union(enum) {
                revision: anyerror!u64,
                deadline: std.Io.Cancelable!void,
                cancellation: std.Io.Cancelable!void,
            };
            var results: [3]Event = undefined;
            var select = std.Io.Select(Event).init(call.inbound.io, &results);
            select.async(.revision, healthRevisionTask, .{subscription});
            select.async(.deadline, healthDeadlineTask, .{ call.inbound.io, deadline });
            select.async(.cancellation, healthCancellationTask, .{call});
            const first_event = select.await() catch |err| {
                select.cancelDiscard();
                return err;
            };
            select.cancelDiscard();
            switch (first_event) {
                .revision => |result| _ = try result,
                .deadline => |result| {
                    try result;
                    return .{ .code = .deadline_exceeded };
                },
                .cancellation => |result| {
                    try result;
                    return .{ .code = .cancelled };
                },
            }
            const next_status = self.health.check(request.service);
            if (next_status == last_status) continue;
            last_status = next_status;
            self.sendHealth(call, next_status) catch |err| return switch (err) {
                error.Closed, error.Canceled => .{ .code = .cancelled },
                else => err,
            };
        }
    }

    fn sendHealth(self: *Services, call: *Incremental.Call, status: Grpc.HealthStatus) !void {
        const response = health_proto.HealthCheckResponse{ .status = healthStatus(status) };
        const encoded = try Typed.encodeAlloc(self.health.allocator, response);
        defer self.health.allocator.free(encoded);
        try call.sendAlloc(self.health.allocator, encoded);
    }

    pub fn invoke(self: *Services, allocator: std.mem.Allocator, request: Grpc.UnaryRequest) anyerror!Grpc.UnaryResponse {
        if (!std.mem.eql(u8, request.service, "grpc.health.v1.Health") or !std.mem.eql(u8, request.method, "Check")) return error.MethodNotFound;
        var decoded = try Typed.decodeAlloc(health_proto.HealthCheckRequest, allocator, request.payload);
        defer decoded.deinit(allocator);
        const response = health_proto.HealthCheckResponse{ .status = healthStatus(self.health.check(decoded.service)) };
        const encoded = try Typed.encodeAlloc(allocator, response);
        defer allocator.free(encoded);
        return Grpc.UnaryResponse.initAlloc(allocator, encoded, .ok());
    }

    pub fn invokeStreaming(self: *Services, allocator: std.mem.Allocator, request: Grpc.StreamingRequest) anyerror!Grpc.StreamingResponse {
        if (std.mem.eql(u8, request.service, "grpc.health.v1.Health") and std.mem.eql(u8, request.method, "Watch")) {
            if (request.messages.len != 1) return error.InvalidMessageCount;
            var decoded = try Typed.decodeAlloc(health_proto.HealthCheckRequest, allocator, request.messages[0]);
            defer decoded.deinit(allocator);
            const response = health_proto.HealthCheckResponse{ .status = healthStatus(self.health.check(decoded.service)) };
            const encoded = try Typed.encodeAlloc(allocator, response);
            defer allocator.free(encoded);
            return Grpc.StreamingResponse.initAlloc(allocator, &.{encoded}, .ok());
        }
        if ((std.mem.eql(u8, request.service, "grpc.reflection.v1.ServerReflection") or
            std.mem.eql(u8, request.service, "grpc.reflection.v1alpha.ServerReflection")) and
            std.mem.eql(u8, request.method, "ServerReflectionInfo"))
        {
            return self.reflectAlloc(allocator, request.messages);
        }
        return error.MethodNotFound;
    }

    fn reflectAlloc(self: *Services, allocator: std.mem.Allocator, requests: []const []const u8) !Grpc.StreamingResponse {
        var encoded_responses: std.ArrayList([]u8) = .empty;
        defer {
            for (encoded_responses.items) |response| allocator.free(response);
            encoded_responses.deinit(allocator);
        }
        for (requests) |bytes| {
            var request = try Typed.decodeAlloc(reflection_proto.ServerReflectionRequest, allocator, bytes);
            defer request.deinit(allocator);
            var response = try self.reflectionResponse(allocator, request);
            defer deinitReflectionContainer(allocator, &response);
            const encoded = try Typed.encodeAlloc(allocator, response);
            try encoded_responses.append(allocator, encoded);
        }
        return Grpc.StreamingResponse.initAlloc(allocator, encoded_responses.items, .ok());
    }

    fn reflectionResponse(self: *Services, allocator: std.mem.Allocator, request: reflection_proto.ServerReflectionRequest) !reflection_proto.ServerReflectionResponse {
        const message_request = request.message_request orelse return reflectionError(.invalid_argument, "reflection request is empty");
        return switch (message_request) {
            .list_services => blk: {
                var services: std.ArrayList(reflection_proto.ServiceResponse) = .empty;
                for (self.service_names) |name| try services.append(allocator, .{ .name = name });
                break :blk .{ .valid_host = request.host, .message_response = .{ .list_services_response = .{ .service = services } } };
            },
            .file_by_filename => |filename| blk: {
                var files: std.ArrayList([]const u8) = .empty;
                if (!try appendFileClosure(&files, allocator, self.descriptor_set, filename)) break :blk reflectionError(.not_found, "descriptor file not found");
                break :blk .{ .valid_host = request.host, .message_response = .{ .file_descriptor_response = .{ .file_descriptor_proto = files } } };
            },
            .file_containing_symbol => |symbol| blk: {
                const filename = (try fileContainingSymbolAlloc(allocator, self.descriptor_set, symbol)) orelse break :blk reflectionError(.not_found, "descriptor symbol not found");
                defer allocator.free(filename);
                var files: std.ArrayList([]const u8) = .empty;
                _ = try appendFileClosure(&files, allocator, self.descriptor_set, filename);
                break :blk .{ .valid_host = request.host, .message_response = .{ .file_descriptor_response = .{ .file_descriptor_proto = files } } };
            },
            .file_containing_extension => |extension| blk: {
                const filename = (try fileContainingExtensionAlloc(allocator, self.descriptor_set, extension.containing_type, extension.extension_number)) orelse break :blk reflectionError(.not_found, "descriptor extension not found");
                defer allocator.free(filename);
                var files: std.ArrayList([]const u8) = .empty;
                _ = try appendFileClosure(&files, allocator, self.descriptor_set, filename);
                break :blk .{ .valid_host = request.host, .message_response = .{ .file_descriptor_response = .{ .file_descriptor_proto = files } } };
            },
            .all_extension_numbers_of_type => |type_name| blk: {
                var numbers: std.ArrayList(i32) = .empty;
                try appendExtensionNumbers(&numbers, allocator, self.descriptor_set, type_name);
                break :blk .{ .valid_host = request.host, .message_response = .{ .all_extension_numbers_response = .{
                    .base_type_name = type_name,
                    .extension_number = numbers,
                } } };
            },
        };
    }
};

fn healthRevisionTask(subscription: *Grpc.HealthSubscription) anyerror!u64 {
    return subscription.receive();
}

fn healthDeadlineTask(io: std.Io, deadline: std.Io.Clock.Timestamp) std.Io.Cancelable!void {
    return deadline.wait(io);
}

fn healthCancellationTask(call: *Incremental.Call) std.Io.Cancelable!void {
    while (!call.isCancelled()) call.sleep(1) catch return error.Canceled;
}

fn deinitReflectionContainer(allocator: std.mem.Allocator, response: *reflection_proto.ServerReflectionResponse) void {
    const message = &(response.message_response orelse return);
    switch (message.*) {
        .list_services_response => |*list| list.service.deinit(allocator),
        .file_descriptor_response => |*files| files.file_descriptor_proto.deinit(allocator),
        .all_extension_numbers_response => |*extensions| extensions.extension_number.deinit(allocator),
        else => {},
    }
}

fn healthStatus(status: Grpc.HealthStatus) health_proto.HealthCheckResponse.ServingStatus {
    return switch (status) {
        .unknown => .UNKNOWN,
        .serving => .SERVING,
        .not_serving => .NOT_SERVING,
        .service_unknown => .SERVICE_UNKNOWN,
    };
}

fn reflectionError(code: Grpc.Code, message: []const u8) reflection_proto.ServerReflectionResponse {
    return .{ .message_response = .{ .error_response = .{ .error_code = @intFromEnum(code), .error_message = message } } };
}

fn readVarint(bytes: []const u8, offset: *usize) !u64 {
    var value: u64 = 0;
    var shift: u6 = 0;
    while (offset.* < bytes.len and shift < 64) : (shift += 7) {
        const byte = bytes[offset.*];
        offset.* += 1;
        value |= @as(u64, byte & 0x7f) << shift;
        if ((byte & 0x80) == 0) return value;
    }
    return error.InvalidDescriptorSet;
}

fn appendDescriptorFiles(files: *std.ArrayList([]const u8), allocator: std.mem.Allocator, descriptor_set: []const u8) !void {
    var offset: usize = 0;
    while (offset < descriptor_set.len) {
        const tag = try readVarint(descriptor_set, &offset);
        if (tag != 10) return error.InvalidDescriptorSet;
        const length = try readVarint(descriptor_set, &offset);
        if (length > descriptor_set.len - offset) return error.InvalidDescriptorSet;
        try files.append(allocator, descriptor_set[offset .. offset + @as(usize, @intCast(length))]);
        offset += @intCast(length);
    }
}

const DescriptorField = struct {
    number: u64,
    wire_type: u3,
    bytes: []const u8 = &.{},
    integer: u64 = 0,
};

fn nextDescriptorField(bytes: []const u8, offset: *usize) !?DescriptorField {
    if (offset.* == bytes.len) return null;
    const tag = try readVarint(bytes, offset);
    const number = tag >> 3;
    const wire_type: u3 = @intCast(tag & 7);
    if (number == 0) return error.InvalidDescriptorSet;
    return switch (wire_type) {
        0 => .{ .number = number, .wire_type = wire_type, .integer = try readVarint(bytes, offset) },
        1 => blk: {
            if (bytes.len - offset.* < 8) return error.InvalidDescriptorSet;
            const payload = bytes[offset.* .. offset.* + 8];
            offset.* += 8;
            break :blk .{ .number = number, .wire_type = wire_type, .bytes = payload };
        },
        2 => blk: {
            const length = try readVarint(bytes, offset);
            if (length > bytes.len - offset.*) return error.InvalidDescriptorSet;
            const payload = bytes[offset.* .. offset.* + @as(usize, @intCast(length))];
            offset.* += @intCast(length);
            break :blk .{ .number = number, .wire_type = wire_type, .bytes = payload };
        },
        5 => blk: {
            if (bytes.len - offset.* < 4) return error.InvalidDescriptorSet;
            const payload = bytes[offset.* .. offset.* + 4];
            offset.* += 4;
            break :blk .{ .number = number, .wire_type = wire_type, .bytes = payload };
        },
        else => error.InvalidDescriptorSet,
    };
}

fn descriptorString(bytes: []const u8, field_number: u64) !?[]const u8 {
    var offset: usize = 0;
    while (try nextDescriptorField(bytes, &offset)) |field| {
        if (field.number == field_number and field.wire_type == 2) return field.bytes;
    }
    return null;
}

fn findDescriptorFile(descriptor_set: []const u8, filename: []const u8) !?[]const u8 {
    var offset: usize = 0;
    while (try nextDescriptorField(descriptor_set, &offset)) |field| {
        if (field.number != 1 or field.wire_type != 2) continue;
        const name = (try descriptorString(field.bytes, 1)) orelse continue;
        if (std.mem.eql(u8, name, filename)) return field.bytes;
    }
    return null;
}

fn appendFileClosure(files: *std.ArrayList([]const u8), allocator: std.mem.Allocator, descriptor_set: []const u8, filename: []const u8) !bool {
    const file = (try findDescriptorFile(descriptor_set, filename)) orelse return false;
    for (files.items) |existing| if (existing.ptr == file.ptr) return true;
    try files.append(allocator, file);
    var offset: usize = 0;
    while (try nextDescriptorField(file, &offset)) |field| {
        if (field.number == 3 and field.wire_type == 2) {
            if (!try appendFileClosure(files, allocator, descriptor_set, field.bytes)) return error.InvalidDescriptorDependency;
        }
    }
    return true;
}

fn qualifiedNameAlloc(allocator: std.mem.Allocator, parts: []const []const u8) ![]u8 {
    var output: std.Io.Writer.Allocating = .init(allocator);
    errdefer output.deinit();
    var written = false;
    for (parts) |part| {
        if (part.len == 0) continue;
        if (written) try output.writer.writeByte('.');
        try output.writer.writeAll(part);
        written = true;
    }
    return output.toOwnedSlice();
}

fn namedDescriptorMatches(allocator: std.mem.Allocator, descriptor: []const u8, parent_parts: []const []const u8, symbol: []const u8, child_field: ?u64) !bool {
    const name = (try descriptorString(descriptor, 1)) orelse return false;
    const parts = try allocator.alloc([]const u8, parent_parts.len + 1);
    defer allocator.free(parts);
    @memcpy(parts[0..parent_parts.len], parent_parts);
    parts[parent_parts.len] = name;
    const qualified = try qualifiedNameAlloc(allocator, parts);
    defer allocator.free(qualified);
    if (std.mem.eql(u8, qualified, symbol)) return true;
    if (child_field) |number| {
        var offset: usize = 0;
        while (try nextDescriptorField(descriptor, &offset)) |field| {
            if (field.number != number or field.wire_type != 2) continue;
            const child = (try descriptorString(field.bytes, 1)) orelse continue;
            const child_name = try qualifiedNameAlloc(allocator, &.{ qualified, child });
            defer allocator.free(child_name);
            if (std.mem.eql(u8, child_name, symbol)) return true;
        }
    }
    return false;
}

fn messageMatchesSymbol(allocator: std.mem.Allocator, descriptor: []const u8, parent_parts: []const []const u8, symbol: []const u8) !bool {
    const name = (try descriptorString(descriptor, 1)) orelse return false;
    const parts = try allocator.alloc([]const u8, parent_parts.len + 1);
    defer allocator.free(parts);
    @memcpy(parts[0..parent_parts.len], parent_parts);
    parts[parent_parts.len] = name;
    const qualified = try qualifiedNameAlloc(allocator, parts);
    defer allocator.free(qualified);
    if (std.mem.eql(u8, qualified, symbol)) return true;
    var offset: usize = 0;
    while (try nextDescriptorField(descriptor, &offset)) |field| {
        if (field.wire_type != 2) continue;
        if (field.number == 2 or field.number == 6 or field.number == 8) {
            const child = (try descriptorString(field.bytes, 1)) orelse continue;
            const child_name = try qualifiedNameAlloc(allocator, &.{ qualified, child });
            defer allocator.free(child_name);
            if (std.mem.eql(u8, child_name, symbol)) return true;
        } else if (field.number == 3) {
            if (try messageMatchesSymbol(allocator, field.bytes, parts, symbol)) return true;
        } else if (field.number == 4) {
            if (try namedDescriptorMatches(allocator, field.bytes, parts, symbol, 2)) return true;
        }
    }
    return false;
}

fn fileMatchesSymbol(allocator: std.mem.Allocator, file: []const u8, symbol: []const u8) !bool {
    const package = (try descriptorString(file, 2)) orelse "";
    const parents = [_][]const u8{package};
    var offset: usize = 0;
    while (try nextDescriptorField(file, &offset)) |field| {
        if (field.wire_type != 2) continue;
        if (field.number == 4) {
            if (try messageMatchesSymbol(allocator, field.bytes, &parents, symbol)) return true;
        } else if (field.number == 5 or field.number == 6) {
            if (try namedDescriptorMatches(allocator, field.bytes, &parents, symbol, 2)) return true;
        } else if (field.number == 7) {
            const name = (try descriptorString(field.bytes, 1)) orelse continue;
            const qualified = try qualifiedNameAlloc(allocator, &.{ package, name });
            defer allocator.free(qualified);
            if (std.mem.eql(u8, qualified, symbol)) return true;
        }
    }
    return false;
}

fn fileContainingSymbolAlloc(allocator: std.mem.Allocator, descriptor_set: []const u8, symbol: []const u8) !?[]u8 {
    if (symbol.len == 0 or symbol.len > 2048) return null;
    var files: std.ArrayList([]const u8) = .empty;
    defer files.deinit(allocator);
    try appendDescriptorFiles(&files, allocator, descriptor_set);
    for (files.items) |file| if (try fileMatchesSymbol(allocator, file, symbol)) {
        const name = try allocator.dupe(u8, (try descriptorString(file, 1)).?);
        return name;
    };
    return null;
}

fn extensionMatches(field: []const u8, type_name: []const u8, extension_number: ?i32) !bool {
    const extendee = (try descriptorString(field, 2)) orelse return false;
    const normalized = if (extendee.len != 0 and extendee[0] == '.') extendee[1..] else extendee;
    const requested = if (type_name.len != 0 and type_name[0] == '.') type_name[1..] else type_name;
    if (!std.mem.eql(u8, normalized, requested)) return false;
    if (extension_number) |expected| {
        var offset: usize = 0;
        while (try nextDescriptorField(field, &offset)) |descriptor_field| {
            if (descriptor_field.number == 3 and descriptor_field.wire_type == 0) return descriptor_field.integer == @as(u64, @intCast(expected));
        }
        return false;
    }
    return true;
}

fn visitMessageExtensions(field: []const u8, type_name: []const u8, extension_number: ?i32, numbers: ?*std.ArrayList(i32), allocator: std.mem.Allocator) !bool {
    var found = false;
    var offset: usize = 0;
    while (try nextDescriptorField(field, &offset)) |descriptor_field| {
        if (descriptor_field.wire_type != 2) continue;
        if (descriptor_field.number == 6 and try extensionMatches(descriptor_field.bytes, type_name, extension_number)) {
            if (numbers) |list| {
                var field_offset: usize = 0;
                while (try nextDescriptorField(descriptor_field.bytes, &field_offset)) |extension_field| {
                    if (extension_field.number == 3 and extension_field.wire_type == 0) try list.append(allocator, @intCast(extension_field.integer));
                }
            }
            found = true;
            if (numbers == null) return true;
        }
        if (descriptor_field.number == 3 and try visitMessageExtensions(descriptor_field.bytes, type_name, extension_number, numbers, allocator)) {
            found = true;
            if (numbers == null) return true;
        }
    }
    return found;
}

fn fileHasExtension(file: []const u8, type_name: []const u8, extension_number: ?i32, numbers: ?*std.ArrayList(i32), allocator: std.mem.Allocator) !bool {
    var found = false;
    var offset: usize = 0;
    while (try nextDescriptorField(file, &offset)) |field| {
        if (field.wire_type != 2) continue;
        if (field.number == 7 and try extensionMatches(field.bytes, type_name, extension_number)) {
            found = true;
            if (numbers) |list| {
                var field_offset: usize = 0;
                while (try nextDescriptorField(field.bytes, &field_offset)) |extension_field| {
                    if (extension_field.number == 3 and extension_field.wire_type == 0) try list.append(allocator, @intCast(extension_field.integer));
                }
            }
        } else if (field.number == 4 and try visitMessageExtensions(field.bytes, type_name, extension_number, numbers, allocator)) found = true;
    }
    return found;
}

fn fileContainingExtensionAlloc(allocator: std.mem.Allocator, descriptor_set: []const u8, type_name: []const u8, extension_number: i32) !?[]u8 {
    if (extension_number <= 0) return null;
    var files: std.ArrayList([]const u8) = .empty;
    defer files.deinit(allocator);
    try appendDescriptorFiles(&files, allocator, descriptor_set);
    for (files.items) |file| if (try fileHasExtension(file, type_name, extension_number, null, allocator)) {
        const name = try allocator.dupe(u8, (try descriptorString(file, 1)).?);
        return name;
    };
    return null;
}

fn appendExtensionNumbers(numbers: *std.ArrayList(i32), allocator: std.mem.Allocator, descriptor_set: []const u8, type_name: []const u8) !void {
    var files: std.ArrayList([]const u8) = .empty;
    defer files.deinit(allocator);
    try appendDescriptorFiles(&files, allocator, descriptor_set);
    for (files.items) |file| _ = try fileHasExtension(file, type_name, null, numbers, allocator);
    std.mem.sort(i32, numbers.items, {}, std.sort.asc(i32));
}

test "health and reflection services use generated standard contracts" {
    var health = Grpc.HealthRegistry.init(std.testing.allocator);
    defer health.deinit();
    try health.set("orders.v1.Orders", .serving);
    const names = [_][]const u8{ "orders.v1.Orders", "grpc.health.v1.Health", "grpc.reflection.v1.ServerReflection", "grpc.reflection.v1alpha.ServerReflection" };
    var services = Services{ .health = &health, .service_names = &names };
    var unary = Grpc.Registry.init(std.testing.allocator);
    defer unary.deinit();
    var streaming = Grpc.StreamingRegistry.init(std.testing.allocator);
    defer streaming.deinit();
    try services.install(&unary, &streaming);

    const health_request = try Typed.encodeAlloc(std.testing.allocator, health_proto.HealthCheckRequest{ .service = "orders.v1.Orders" });
    defer std.testing.allocator.free(health_request);
    var health_response = try unary.invokeAlloc(std.testing.allocator, .{
        .authority = "local",
        .service = "grpc.health.v1.Health",
        .method = "Check",
        .payload = health_request,
        .timeout_millis = 1_000,
    }, .{});
    defer health_response.deinit();
    var decoded_health = try Typed.decodeAlloc(health_proto.HealthCheckResponse, std.testing.allocator, health_response.payload);
    defer decoded_health.deinit(std.testing.allocator);
    try std.testing.expectEqual(health_proto.HealthCheckResponse.ServingStatus.SERVING, decoded_health.status);

    const reflection_request = try Typed.encodeAlloc(std.testing.allocator, reflection_proto.ServerReflectionRequest{ .message_request = .{ .list_services = "" } });
    defer std.testing.allocator.free(reflection_request);
    var reflection_response = try streaming.invokeAlloc(std.testing.allocator, .{
        .authority = "local",
        .service = "grpc.reflection.v1.ServerReflection",
        .method = "ServerReflectionInfo",
        .messages = &.{reflection_request},
        .timeout_millis = 1_000,
        .shape = .bidirectional_streaming,
    }, .{});
    defer reflection_response.deinit();
    var decoded_reflection = try Typed.decodeAlloc(reflection_proto.ServerReflectionResponse, std.testing.allocator, reflection_response.messages[0]);
    defer decoded_reflection.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 4), decoded_reflection.message_response.?.list_services_response.service.items.len);

    var alpha_response = try streaming.invokeAlloc(std.testing.allocator, .{
        .authority = "local",
        .service = "grpc.reflection.v1alpha.ServerReflection",
        .method = "ServerReflectionInfo",
        .messages = &.{reflection_request},
        .timeout_millis = 1_000,
        .shape = .bidirectional_streaming,
    }, .{});
    defer alpha_response.deinit();
    var decoded_alpha = try Typed.decodeAlloc(reflection_proto.ServerReflectionResponse, std.testing.allocator, alpha_response.messages[0]);
    defer decoded_alpha.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 4), decoded_alpha.message_response.?.list_services_response.service.items.len);

    const file_request = try Typed.encodeAlloc(std.testing.allocator, reflection_proto.ServerReflectionRequest{ .message_request = .{ .file_by_filename = "grpc/health/v1/health.proto" } });
    defer std.testing.allocator.free(file_request);
    var file_response = try streaming.invokeAlloc(std.testing.allocator, .{
        .authority = "local",
        .service = "grpc.reflection.v1.ServerReflection",
        .method = "ServerReflectionInfo",
        .messages = &.{file_request},
        .timeout_millis = 1_000,
        .shape = .bidirectional_streaming,
    }, .{});
    defer file_response.deinit();
    var decoded_file = try Typed.decodeAlloc(reflection_proto.ServerReflectionResponse, std.testing.allocator, file_response.messages[0]);
    defer decoded_file.deinit(std.testing.allocator);
    const descriptors = decoded_file.message_response.?.file_descriptor_response.file_descriptor_proto.items;
    try std.testing.expectEqual(@as(usize, 1), descriptors.len);
    try std.testing.expectEqualStrings("grpc/health/v1/health.proto", (try descriptorString(descriptors[0], 1)).?);

    const symbol_request = try Typed.encodeAlloc(std.testing.allocator, reflection_proto.ServerReflectionRequest{ .message_request = .{ .file_containing_symbol = "grpc.health.v1.Health.Watch" } });
    defer std.testing.allocator.free(symbol_request);
    var symbol_response = try streaming.invokeAlloc(std.testing.allocator, .{
        .authority = "local",
        .service = "grpc.reflection.v1.ServerReflection",
        .method = "ServerReflectionInfo",
        .messages = &.{symbol_request},
        .timeout_millis = 1_000,
        .shape = .bidirectional_streaming,
    }, .{});
    defer symbol_response.deinit();
    var decoded_symbol = try Typed.decodeAlloc(reflection_proto.ServerReflectionResponse, std.testing.allocator, symbol_response.messages[0]);
    defer decoded_symbol.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), decoded_symbol.message_response.?.file_descriptor_response.file_descriptor_proto.items.len);
}

test "health Watch publishes live status changes until cancellation" {
    var health = Grpc.HealthRegistry.init(std.testing.allocator);
    defer health.deinit();
    try health.set("orders.v1.Orders", .serving);
    const names = [_][]const u8{"grpc.health.v1.Health"};
    var services = Services{ .health = &health, .service_names = &names };
    var inbound = try Incremental.Pipe.init(std.testing.allocator, std.testing.io, 2);
    defer inbound.deinit();
    var outbound = try Incremental.Pipe.init(std.testing.allocator, std.testing.io, 2);
    defer outbound.deinit();
    const request = try Typed.encodeAlloc(std.testing.allocator, health_proto.HealthCheckRequest{ .service = "orders.v1.Orders" });
    defer std.testing.allocator.free(request);
    try inbound.sendAlloc(std.testing.allocator, request);
    // Server-streaming clients normally half-close the request immediately;
    // Watch must remain subscribed on the response side after this point.
    inbound.close();
    const Notify = struct {
        fn call(_: *anyopaque) void {}
    };
    var marker: u8 = 0;
    var call = Incremental.Call{
        .context = .{
            .authority = "localhost",
            .service = "grpc.health.v1.Health",
            .method = "Watch",
            .shape = .server_streaming,
            .timeout_millis = 1_000,
        },
        .inbound = &inbound,
        .outbound = &outbound,
        .notify_pointer = &marker,
        .notify_fn = Notify.call,
    };
    const Context = struct {
        services: *Services,
        call: *Incremental.Call,
        status: ?Grpc.Status = null,
        failure: ?anyerror = null,
        fn run(self: *@This()) void {
            self.status = self.services.runIncremental(self.call) catch |err| {
                self.failure = err;
                return;
            };
        }
    };
    var context = Context{ .services = &services, .call = &call };
    const thread = try std.Thread.spawn(.{}, Context.run, .{&context});

    var first = (try outbound.receive()).?;
    defer first.deinit();
    var first_status = try Typed.decodeAlloc(health_proto.HealthCheckResponse, std.testing.allocator, first.bytes);
    defer first_status.deinit(std.testing.allocator);
    try std.testing.expectEqual(health_proto.HealthCheckResponse.ServingStatus.SERVING, first_status.status);

    try health.set("orders.v1.Orders", .not_serving);
    var second = (try outbound.receive()).?;
    defer second.deinit();
    var second_status = try Typed.decodeAlloc(health_proto.HealthCheckResponse, std.testing.allocator, second.bytes);
    defer second_status.deinit(std.testing.allocator);
    try std.testing.expectEqual(health_proto.HealthCheckResponse.ServingStatus.NOT_SERVING, second_status.status);

    outbound.close();
    thread.join();
    if (context.failure) |err| return err;
    try std.testing.expectEqual(Grpc.Code.cancelled, context.status.?.code);
}
