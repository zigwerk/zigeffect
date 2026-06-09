const std = @import("std");
const identity = @import("identity.zig");
const mailbox_mod = @import("mailbox.zig");
const result_mod = @import("../core/result.zig");
const scope_mod = @import("../core/scope.zig");
const supervisor_mod = @import("../runtime/supervisor.zig");

pub const Allocator = std.mem.Allocator;
pub const EntityAddress = identity.EntityAddress;
pub const EntityEnvelope = mailbox_mod.EntityEnvelope;
pub const EntityAsk = mailbox_mod.EntityAsk;
pub const EntityCorrelationId = mailbox_mod.EntityCorrelationId;
pub const EntityMailboxError = mailbox_mod.EntityMailboxError;
pub const LocalMailboxStore = mailbox_mod.LocalMailboxStore;
pub const FinalizerExit = result_mod.FinalizerExit;
pub const Scope = scope_mod.Scope;
pub const Supervisor = supervisor_mod.Supervisor;
pub const SupervisorDecision = supervisor_mod.SupervisorDecision;
pub const SupervisorError = supervisor_mod.SupervisorError;
pub const SupervisorId = supervisor_mod.SupervisorId;
pub const SupervisorRestartMode = supervisor_mod.SupervisorRestartMode;
pub const SupervisorStrategy = supervisor_mod.SupervisorStrategy;
pub const RestartIntensity = supervisor_mod.RestartIntensity;

pub const EntityStatus = enum { idle, running, stopping, stopped, interrupted, failed, escalated };

pub const EntityRuntimeError = error{
    EntityNotFound,
    DuplicateEntity,
    EntityNotRunning,
    EntityServiceNotFound,
    DuplicateEntityService,
};

pub const EntityRegistration = struct {
    address: EntityAddress,
    name: []const u8,
    restart_mode: SupervisorRestartMode = .permanent,
    shutdown_order: u32 = 0,
    idle_timeout_ms: ?u64 = null,
};

pub const EntityHandlerResult = union(enum) {
    noreply,
    reply: []const u8,
    stop,
};

pub const EntityProcessResult = struct {
    address: EntityAddress,
    envelope: EntityEnvelope,
    status: EntityStatus,
    replied: bool = false,
    supervisor_decision: ?SupervisorDecision = null,

    pub fn deinit(self: *EntityProcessResult, allocator: Allocator) void {
        mailbox_mod.deinitEntityEnvelope(allocator, self.envelope);
    }
};

const ServiceEntry = struct {
    name: []const u8,
    value: ?*anyopaque,
};

pub const EntityScope = struct {
    allocator: Allocator,
    scope: Scope,
    services: std.ArrayList(ServiceEntry) = .empty,

    pub fn init(allocator: Allocator) EntityScope {
        return .{ .allocator = allocator, .scope = Scope.init(allocator) };
    }

    pub fn deinit(self: *EntityScope) void {
        self.scope.deinit();
        for (self.services.items) |entry| {
            self.allocator.free(entry.name);
        }
        self.services.deinit(self.allocator);
    }

    pub fn close(self: *EntityScope, exit: FinalizerExit) void {
        self.scope.closeWithExit(exit);
    }

    pub fn addFinalizerFor(
        self: *EntityScope,
        comptime Resource: type,
        resource: *Resource,
        comptime release: *const fn (*Resource) void,
    ) Allocator.Error!void {
        try self.scope.addFinalizerFor(Resource, resource, release);
    }

    pub fn provideService(self: *EntityScope, name: []const u8, value: ?*anyopaque) (Allocator.Error || EntityRuntimeError)!void {
        if (self.findService(name) != null) return error.DuplicateEntityService;
        const owned_name = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(owned_name);
        try self.services.append(self.allocator, .{ .name = owned_name, .value = value });
    }

    pub fn service(self: *const EntityScope, name: []const u8) EntityRuntimeError!?*anyopaque {
        const index = self.findService(name) orelse return error.EntityServiceNotFound;
        return self.services.items[index].value;
    }

    fn findService(self: *const EntityScope, name: []const u8) ?usize {
        for (self.services.items, 0..) |entry, index| {
            if (std.mem.eql(u8, entry.name, name)) return index;
        }
        return null;
    }
};

const EntityInstance = struct {
    address: EntityAddress,
    name: []const u8,
    status: EntityStatus = .running,
    scope: EntityScope,
    idle_timeout_ms: ?u64 = null,
    last_active_ms: u64 = 0,
    supervisor_child_id: supervisor_mod.SupervisorChildId,

    fn deinit(self: *EntityInstance, allocator: Allocator) void {
        mailbox_mod.deinitEntityAddress(allocator, self.address);
        if (self.name.len > 0) allocator.free(self.name);
        self.scope.deinit();
    }
};

pub const LocalEntityRuntimeOptions = struct {
    supervisor_id: SupervisorId = 1,
    supervisor_name: []const u8 = "local-entities",
    supervisor_strategy: SupervisorStrategy = .one_for_one,
    restart_intensity: RestartIntensity = .{},
};

pub const EntityRef = struct {
    address: EntityAddress,
    runtime: *LocalEntityRuntime,

    pub fn tell(self: EntityRef, payload_type_name: []const u8, payload: []const u8, redacted_detail: []const u8) Allocator.Error!EntityEnvelope {
        return self.runtime.mailbox.offer(.{
            .kind = .tell,
            .address = self.address,
            .payload_type_name = payload_type_name,
            .payload = payload,
            .redacted_detail = redacted_detail,
        });
    }

    pub fn ask(self: EntityRef, payload_type_name: []const u8, payload: []const u8, redacted_detail: []const u8) Allocator.Error!EntityAsk {
        const envelope = try self.runtime.mailbox.offer(.{
            .kind = .ask,
            .address = self.address,
            .payload_type_name = payload_type_name,
            .payload = payload,
            .redacted_detail = redacted_detail,
        });
        return .{ .envelope = envelope, .correlation_id = envelope.correlation_id.? };
    }

    pub fn interrupt(self: EntityRef, reason: []const u8) Allocator.Error!EntityEnvelope {
        return self.runtime.mailbox.offer(.{
            .kind = .interrupt,
            .address = self.address,
            .payload_type_name = "interrupt",
            .payload = reason,
            .redacted_detail = reason,
        });
    }
};

pub const LocalEntityRuntime = struct {
    allocator: Allocator,
    mailbox: LocalMailboxStore,
    supervisor: Supervisor,
    entities: std.ArrayList(EntityInstance) = .empty,

    pub fn init(allocator: Allocator, options: LocalEntityRuntimeOptions) LocalEntityRuntime {
        return .{
            .allocator = allocator,
            .mailbox = LocalMailboxStore.init(allocator),
            .supervisor = Supervisor.init(allocator, .{
                .id = options.supervisor_id,
                .name = options.supervisor_name,
                .strategy = options.supervisor_strategy,
                .intensity = options.restart_intensity,
            }),
        };
    }

    pub fn deinit(self: *LocalEntityRuntime) void {
        for (self.entities.items) |*instance| {
            instance.deinit(self.allocator);
        }
        self.entities.deinit(self.allocator);
        self.supervisor.deinit();
        self.mailbox.deinit();
    }

    pub fn registerEntity(
        self: *LocalEntityRuntime,
        registration: EntityRegistration,
        now_ms: u64,
    ) (Allocator.Error || EntityRuntimeError || SupervisorError)!EntityRef {
        if (self.findEntityIndex(registration.address) != null) return error.DuplicateEntity;

        var instance = EntityInstance{
            .address = try mailbox_mod.cloneEntityAddress(self.allocator, registration.address),
            .name = try self.allocator.dupe(u8, registration.name),
            .scope = EntityScope.init(self.allocator),
            .idle_timeout_ms = registration.idle_timeout_ms,
            .last_active_ms = now_ms,
            .supervisor_child_id = registration.address.id,
        };
        errdefer instance.deinit(self.allocator);

        const index = self.entities.items.len;
        try self.entities.append(self.allocator, instance);
        errdefer {
            var removed = self.entities.orderedRemove(index);
            removed.deinit(self.allocator);
        }

        try self.supervisor.addChild(.{
            .id = registration.address.id,
            .name = registration.name,
            .kind = .entity,
            .restart_mode = registration.restart_mode,
            .shutdown_order = registration.shutdown_order,
        });
        try self.supervisor.startAll(now_ms);

        return .{
            .address = self.entities.items[index].address,
            .runtime = self,
        };
    }

    pub fn ref(self: *LocalEntityRuntime, address: EntityAddress) EntityRuntimeError!EntityRef {
        const index = self.findEntityIndex(address) orelse return error.EntityNotFound;
        return .{
            .address = self.entities.items[index].address,
            .runtime = self,
        };
    }

    pub fn status(self: *const LocalEntityRuntime, address: EntityAddress) EntityRuntimeError!EntityStatus {
        const index = self.findEntityIndex(address) orelse return error.EntityNotFound;
        return self.entities.items[index].status;
    }

    pub fn restartCount(self: *const LocalEntityRuntime, address: EntityAddress) EntityRuntimeError!usize {
        const index = self.findEntityIndex(address) orelse return error.EntityNotFound;
        return self.supervisor.childRestartCount(self.entities.items[index].supervisor_child_id) catch error.EntityNotFound;
    }

    pub fn pendingCount(self: *const LocalEntityRuntime, address: EntityAddress) usize {
        return self.mailbox.pendingCount(address);
    }

    pub fn entityScope(self: *LocalEntityRuntime, address: EntityAddress) EntityRuntimeError!*EntityScope {
        const index = self.findEntityIndex(address) orelse return error.EntityNotFound;
        return &self.entities.items[index].scope;
    }

    pub fn processNext(self: *LocalEntityRuntime, address: EntityAddress, handler: anytype, now_ms: u64) anyerror!EntityProcessResult {
        const index = self.findEntityIndex(address) orelse return error.EntityNotFound;
        var instance = &self.entities.items[index];
        if (instance.status != .running and instance.status != .idle) return error.EntityNotRunning;

        const envelope = try self.mailbox.take(address);
        errdefer mailbox_mod.deinitEntityEnvelope(self.allocator, envelope);
        instance.last_active_ms = now_ms;

        if (envelope.kind == .interrupt) {
            instance.status = .interrupted;
            instance.scope.close(.{ .interrupted = 0 });
            return .{ .address = address, .envelope = envelope, .status = instance.status };
        }

        if (envelope.kind == .reply) {
            return .{ .address = address, .envelope = envelope, .status = instance.status };
        }

        const outcome = handler.handle(&instance.scope, envelope) catch |err| {
            try self.handleEntityFailure(index, err, now_ms);
            return err;
        };

        var replied = false;
        switch (outcome) {
            .noreply => {},
            .reply => |payload| if (envelope.kind == .ask) {
                const reply = try self.mailbox.storeReply(.{
                    .kind = .reply,
                    .address = address,
                    .correlation_id = envelope.correlation_id,
                    .payload_type_name = envelope.payload_type_name,
                    .payload = payload,
                });
                mailbox_mod.deinitEntityEnvelope(self.allocator, reply);
                replied = true;
            },
            .stop => {
                instance.status = .stopped;
                instance.scope.close(.success);
            },
        }

        return .{
            .address = address,
            .envelope = envelope,
            .status = instance.status,
            .replied = replied,
        };
    }

    pub fn takeReply(self: *LocalEntityRuntime, correlation_id: EntityCorrelationId) (Allocator.Error || EntityMailboxError)!EntityEnvelope {
        return self.mailbox.takeReply(correlation_id);
    }

    pub fn shutdownIdle(self: *LocalEntityRuntime, now_ms: u64) void {
        for (self.entities.items) |*instance| {
            if (instance.status != .running and instance.status != .idle) continue;
            const timeout = instance.idle_timeout_ms orelse continue;
            if (self.mailbox.pendingCount(instance.address) > 0) continue;
            if (now_ms < instance.last_active_ms + timeout) continue;
            instance.status = .stopped;
            instance.scope.close(.success);
        }
    }

    fn handleEntityFailure(self: *LocalEntityRuntime, index: usize, err: anyerror, now_ms: u64) !void {
        var instance = &self.entities.items[index];
        const decision = try self.supervisor.reportChildExit(
            instance.supervisor_child_id,
            .{ .failure = @errorName(err) },
            now_ms,
        );

        instance.scope.close(.{ .failure = @errorName(err) });
        instance.scope.deinit();
        instance.scope = EntityScope.init(self.allocator);

        if (decision.escalated) {
            instance.status = .escalated;
        } else if (decision.restarted_children > 0) {
            instance.status = .running;
        } else {
            instance.status = .failed;
        }
    }

    fn findEntityIndex(self: *const LocalEntityRuntime, address: EntityAddress) ?usize {
        for (self.entities.items, 0..) |instance, index| {
            if (instance.address.eql(address)) return index;
        }
        return null;
    }
};
