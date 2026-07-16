const std = @import("std");
const causal = @import("../services/causal.zig");
const identity_mod = @import("runtime_identity.zig");

pub const ResourceError = error{
    ForeignHandle,
    StaleHandle,
    ResourceTableClosed,
};

var next_resource_table_id = std.atomic.Value(u64).init(1);

pub fn ResourceHandle(comptime T: type) type {
    return struct {
        pub const ResourceType = T;

        table_id: u64,
        slot: u32,
        generation: u64,
    };
}

pub fn ResourceTable(comptime T: type) type {
    return struct {
        const Self = @This();
        const Handle = ResourceHandle(T);

        const Slot = struct {
            value: T = undefined,
            occupied: bool = false,
            generation: u64 = 1,
            resource_id: ?u64 = null,
            acquired_event_id: ?u64 = null,
        };

        allocator: std.mem.Allocator,
        release: ?*const fn (*T) void,
        table_id: u64,
        slots: std.ArrayList(Slot) = .empty,
        closed: bool = false,
        causal_store: ?*causal.CausalStore = null,
        causal_run_id: ?u64 = null,
        causal_scope_id: ?u64 = null,

        pub fn init(allocator: std.mem.Allocator, release: ?*const fn (*T) void) Self {
            var id = next_resource_table_id.fetchAdd(1, .monotonic);
            if (id == 0) id = next_resource_table_id.fetchAdd(1, .monotonic);
            return .{
                .allocator = allocator,
                .release = release,
                .table_id = id,
            };
        }

        pub fn attachCausal(self: *Self, store: *causal.CausalStore, run_id: u64, scope_id: u64) void {
            self.causal_store = store;
            self.causal_run_id = run_id;
            self.causal_scope_id = scope_id;
        }

        pub fn deinit(self: *Self) void {
            if (!self.closed) {
                for (self.slots.items) |*slot| {
                    if (!slot.occupied) continue;
                    self.closeSlot(slot, null) catch {};
                }
                self.closed = true;
            }
            self.slots.deinit(self.allocator);
            self.* = undefined;
        }

        pub fn open(
            self: *Self,
            value: T,
            source_ref_id: ?u64,
        ) (ResourceError || std.mem.Allocator.Error)!Handle {
            if (self.closed) return error.ResourceTableClosed;

            var index: usize = 0;
            while (index < self.slots.items.len and self.slots.items[index].occupied) : (index += 1) {}
            if (index == self.slots.items.len) try self.slots.append(self.allocator, .{});
            const slot = &self.slots.items[index];
            slot.value = value;
            slot.occupied = true;
            slot.resource_id = null;
            slot.acquired_event_id = null;

            if (self.causal_store) |store| {
                slot.resource_id = store.nextResourceId();
                slot.acquired_event_id = store.record(.{
                    .kind = .resource_acquired,
                    .run_id = self.causal_run_id,
                    .scope_id = self.causal_scope_id,
                    .resource_id = slot.resource_id,
                    .source_ref_id = source_ref_id,
                    .type_name = identity_mod.boundedTypeName(T),
                    .status = "success",
                }) catch |err| {
                    self.releaseSlotValue(slot);
                    slot.occupied = false;
                    return err;
                };
            }

            return .{
                .table_id = self.table_id,
                .slot = @intCast(index),
                .generation = slot.generation,
            };
        }

        pub fn close(
            self: *Self,
            handle: Handle,
            source_ref_id: ?u64,
        ) (ResourceError || std.mem.Allocator.Error)!void {
            const slot = self.resolveSlot(handle) catch |err| {
                self.recordInvalidHandle(err, source_ref_id);
                return err;
            };
            try self.closeSlot(slot, source_ref_id);
        }

        pub fn with(
            self: *Self,
            handle: Handle,
            comptime callback: anytype,
        ) SafeBorrowReturn(T, callback) {
            return self.withAt(handle, null, callback);
        }

        pub fn withAt(
            self: *Self,
            handle: Handle,
            source_ref_id: ?u64,
            comptime callback: anytype,
        ) SafeBorrowReturn(T, callback) {
            const slot = self.resolveSlot(handle) catch |err| {
                self.recordInvalidHandle(err, source_ref_id);
                return err;
            };
            return callback(&slot.value);
        }

        fn resolveSlot(self: *Self, handle: Handle) ResourceError!*Slot {
            if (self.closed) return error.ResourceTableClosed;
            if (handle.table_id != self.table_id) return error.ForeignHandle;
            if (handle.slot >= self.slots.items.len) return error.StaleHandle;
            const slot = &self.slots.items[handle.slot];
            if (!slot.occupied or slot.generation != handle.generation) return error.StaleHandle;
            return slot;
        }

        fn closeSlot(self: *Self, slot: *Slot, source_ref_id: ?u64) std.mem.Allocator.Error!void {
            const resource_id = slot.resource_id;
            const acquired_event_id = slot.acquired_event_id;
            self.releaseSlotValue(slot);
            slot.occupied = false;
            slot.resource_id = null;
            slot.acquired_event_id = null;
            slot.generation +%= 1;
            if (slot.generation == 0) slot.generation = 1;

            if (self.causal_store) |store| {
                _ = try store.record(.{
                    .kind = .resource_finalized,
                    .run_id = self.causal_run_id,
                    .scope_id = self.causal_scope_id,
                    .resource_id = resource_id,
                    .parent_id = acquired_event_id,
                    .source_ref_id = source_ref_id,
                    .type_name = identity_mod.boundedTypeName(T),
                    .status = "success",
                });
            }
        }

        fn releaseSlotValue(self: *Self, slot: *Slot) void {
            if (self.release) |release| release(&slot.value);
        }

        fn recordInvalidHandle(self: *Self, err: ResourceError, source_ref_id: ?u64) void {
            const store = self.causal_store orelse return;
            _ = store.record(.{
                .kind = .assertion_recorded,
                .run_id = self.causal_run_id,
                .scope_id = self.causal_scope_id,
                .source_ref_id = source_ref_id,
                .type_name = "resource-handle",
                .status = "failure",
                .redacted_detail = @errorName(err),
            }) catch {};
        }
    };
}

pub fn isAgentSendable(comptime T: type) bool {
    return !containsPointerBearingState(T);
}

pub fn assertAgentSendable(comptime T: type) void {
    if (!isAgentSendable(T)) {
        @compileError(
            "zigeffect agent message is not sendable\n\n" ++
                "type: " ++ @typeName(T) ++ "\n\n" ++
                "Use a value-only Schema/Codec message or a generational ResourceHandle; raw pointers, slices, allocators, and functions cannot cross an agent-safe concurrency boundary.",
        );
    }
}

fn SafeBorrowReturn(comptime T: type, comptime callback: anytype) type {
    const info = functionInfo(callback);
    if (info.params.len != 1 or info.params[0].type == null or info.params[0].type.? != *T) {
        @compileError(
            "zigeffect safe borrow callback mismatch\n\n" ++
                "Expected callback: fn (*" ++ @typeName(T) ++ ") R.",
        );
    }
    const Return = info.return_type orelse @compileError("zigeffect safe borrow callback must declare a return type");
    return switch (@typeInfo(Return)) {
        .error_union => |error_union| result: {
            assertSafeBorrowPayload(error_union.payload);
            break :result (ResourceError || error_union.error_set)!error_union.payload;
        },
        else => result: {
            assertSafeBorrowPayload(Return);
            break :result ResourceError!Return;
        },
    };
}

fn assertSafeBorrowPayload(comptime T: type) void {
    if (containsPointerBearingState(T)) {
        @compileError(
            "zigeffect safe borrow return contains pointer-bearing state\n\n" ++
                "return type: " ++ @typeName(T) ++ "\n\n" ++
                "Return an owned value, scalar, tagged union, or generational handle instead of a pointer, slice, allocator, or function.",
        );
    }
}

fn functionInfo(comptime callback: anytype) std.builtin.Type.Fn {
    return switch (@typeInfo(@TypeOf(callback))) {
        .@"fn" => |info| info,
        .pointer => |pointer| switch (@typeInfo(pointer.child)) {
            .@"fn" => |info| info,
            else => @compileError("zigeffect safe borrow callback must be a function"),
        },
        else => @compileError("zigeffect safe borrow callback must be a function"),
    };
}

fn containsPointerBearingState(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .pointer, .@"fn", .@"opaque", .@"anyframe", .frame => true,
        .optional => |optional| containsPointerBearingState(optional.child),
        .error_union => |error_union| containsPointerBearingState(error_union.payload),
        .array => |array| containsPointerBearingState(array.child),
        .vector => |vector| containsPointerBearingState(vector.child),
        .@"struct" => |struct_info| result: {
            inline for (struct_info.fields) |field| {
                if (containsPointerBearingState(field.type)) break :result true;
            }
            break :result false;
        },
        .@"union" => |union_info| result: {
            inline for (union_info.fields) |field| {
                if (containsPointerBearingState(field.type)) break :result true;
            }
            break :result false;
        },
        else => false,
    };
}
