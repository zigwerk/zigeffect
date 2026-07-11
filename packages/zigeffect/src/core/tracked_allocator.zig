const std = @import("std");
const causal = @import("../services/causal.zig");
const sync = @import("../runtime/sync.zig");

pub const AllocationRecord = struct {
    address: usize,
    size: usize,
    alignment: std.mem.Alignment,
    return_address: usize,
    source_ref_id: ?u64 = null,
    live: bool = true,
};

pub const MemorySafetySnapshot = struct {
    allocations: usize,
    frees: usize,
    resizes: usize,
    remaps: usize,
    live_allocations: usize,
    live_bytes: usize,
    peak_bytes: usize,
    invalid_frees: usize,
    out_of_memory: usize,
};

pub const TrackedAllocator = struct {
    backing: std.mem.Allocator,
    records: std.ArrayList(AllocationRecord) = .empty,
    lock: sync.SpinLock = .{},
    allocations: usize = 0,
    frees: usize = 0,
    resizes: usize = 0,
    remaps: usize = 0,
    live_allocations: usize = 0,
    live_bytes: usize = 0,
    peak_bytes: usize = 0,
    invalid_frees: usize = 0,
    out_of_memory: usize = 0,

    pub fn init(backing: std.mem.Allocator) TrackedAllocator {
        return .{ .backing = backing };
    }

    pub fn allocator(self: *TrackedAllocator) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &vtable };
    }

    pub fn deinit(self: *TrackedAllocator) void {
        self.lock.lock();
        for (self.records.items) |*record| {
            if (!record.live) continue;
            // SAFETY: every live record came from backing.rawAlloc/rawRemap with
            // this exact address, size, and alignment and has not been freed.
            const ptr: [*]u8 = @ptrFromInt(record.address);
            self.backing.rawFree(ptr[0..record.size], record.alignment, 0);
            record.live = false;
        }
        self.records.deinit(self.backing);
        self.lock.unlock();
        self.* = undefined;
    }

    pub fn allocAt(
        self: *TrackedAllocator,
        comptime T: type,
        count: usize,
        source_ref_id: ?u64,
    ) std.mem.Allocator.Error![]T {
        const memory = try self.allocator().alloc(T, count);
        self.markSource(memory.ptr, source_ref_id);
        return memory;
    }

    pub fn createAt(
        self: *TrackedAllocator,
        comptime T: type,
        source_ref_id: ?u64,
    ) std.mem.Allocator.Error!*T {
        const value = try self.allocator().create(T);
        self.markSource(value, source_ref_id);
        return value;
    }

    pub fn sourceRefFor(self: *TrackedAllocator, pointer: anytype) ?u64 {
        const address = @intFromPtr(pointer);
        self.lock.lock();
        defer self.lock.unlock();
        const record = self.findLive(address) orelse return null;
        return record.source_ref_id;
    }

    /// Checked free for agent-safe code. Unlike `Allocator.free`, this validates
    /// ownership before Zig's debug-mode poison write, so a duplicate/foreign
    /// slice becomes evidence instead of touching invalid memory.
    pub fn freeChecked(self: *TrackedAllocator, memory: anytype) bool {
        const info = @typeInfo(@TypeOf(memory)).pointer;
        comptime std.debug.assert(info.size == .slice);
        const bytes: []u8 = @ptrCast(@constCast(std.mem.absorbSentinel(memory)));
        if (bytes.len == 0) return true;
        const alignment = std.mem.Alignment.fromByteUnits(info.alignment orelse @alignOf(info.child));

        self.lock.lock();
        defer self.lock.unlock();
        const record = self.findLive(@intFromPtr(bytes.ptr)) orelse {
            self.invalid_frees += 1;
            return false;
        };
        if (record.size != bytes.len or record.alignment != alignment) {
            self.invalid_frees += 1;
            return false;
        }
        @memset(bytes, undefined);
        self.backing.rawFree(bytes, alignment, @returnAddress());
        record.live = false;
        self.frees += 1;
        self.live_allocations -= 1;
        self.live_bytes -= record.size;
        return true;
    }

    pub fn snapshot(self: *TrackedAllocator) MemorySafetySnapshot {
        self.lock.lock();
        defer self.lock.unlock();
        return .{
            .allocations = self.allocations,
            .frees = self.frees,
            .resizes = self.resizes,
            .remaps = self.remaps,
            .live_allocations = self.live_allocations,
            .live_bytes = self.live_bytes,
            .peak_bytes = self.peak_bytes,
            .invalid_frees = self.invalid_frees,
            .out_of_memory = self.out_of_memory,
        };
    }

    pub fn recordCausalSummary(
        self: *TrackedAllocator,
        store: *causal.CausalStore,
        run_id: ?u64,
        scope_id: ?u64,
        source_ref_id: ?u64,
    ) std.mem.Allocator.Error!void {
        const current = self.snapshot();
        var detail_buffer: [256]u8 = undefined;
        const detail = std.fmt.bufPrint(
            &detail_buffer,
            "allocations={d} frees={d} live={d} live_bytes={d} peak_bytes={d} invalid_frees={d} oom={d}",
            .{ current.allocations, current.frees, current.live_allocations, current.live_bytes, current.peak_bytes, current.invalid_frees, current.out_of_memory },
        ) catch "tracked allocator summary exceeded fixed buffer";
        _ = try store.record(.{
            .kind = .metric_recorded,
            .run_id = run_id,
            .scope_id = scope_id,
            .source_ref_id = source_ref_id,
            .label = "tracked-allocator",
            .type_name = "MemorySafetySnapshot",
            .status = "captured",
            .redacted_detail = detail,
        });
        if (current.invalid_frees > 0 or current.out_of_memory > 0 or current.live_allocations > 0) {
            _ = try store.record(.{
                .kind = .assertion_recorded,
                .run_id = run_id,
                .scope_id = scope_id,
                .source_ref_id = source_ref_id,
                .label = "tracked-allocator",
                .type_name = "MemorySafetyViolation",
                .status = "failure",
                .redacted_detail = detail,
            });
        }
    }

    fn markSource(self: *TrackedAllocator, pointer: anytype, source_ref_id: ?u64) void {
        const address = @intFromPtr(pointer);
        self.lock.lock();
        defer self.lock.unlock();
        const record = self.findLive(address) orelse return;
        record.source_ref_id = source_ref_id;
    }

    fn findLive(self: *TrackedAllocator, address: usize) ?*AllocationRecord {
        var index = self.records.items.len;
        while (index > 0) {
            index -= 1;
            const record = &self.records.items[index];
            if (record.live and record.address == address) return record;
        }
        return null;
    }

    fn allocFn(
        raw: *anyopaque,
        len: usize,
        alignment: std.mem.Alignment,
        return_address: usize,
    ) ?[*]u8 {
        // SAFETY: allocator() installs this vtable only with ptr = *TrackedAllocator.
        const self: *TrackedAllocator = @ptrCast(@alignCast(raw));
        const memory = self.backing.rawAlloc(len, alignment, return_address) orelse {
            self.lock.lock();
            self.out_of_memory += 1;
            self.lock.unlock();
            return null;
        };

        self.lock.lock();
        self.records.append(self.backing, .{
            .address = @intFromPtr(memory),
            .size = len,
            .alignment = alignment,
            .return_address = return_address,
        }) catch {
            self.out_of_memory += 1;
            self.lock.unlock();
            self.backing.rawFree(memory[0..len], alignment, return_address);
            return null;
        };
        self.allocations += 1;
        self.live_allocations += 1;
        self.live_bytes += len;
        self.peak_bytes = @max(self.peak_bytes, self.live_bytes);
        self.lock.unlock();
        return memory;
    }

    fn resizeFn(
        raw: *anyopaque,
        memory: []u8,
        alignment: std.mem.Alignment,
        new_len: usize,
        return_address: usize,
    ) bool {
        // SAFETY: allocator() installs this vtable only with ptr = *TrackedAllocator.
        const self: *TrackedAllocator = @ptrCast(@alignCast(raw));
        self.lock.lock();
        defer self.lock.unlock();
        const record = self.findLive(@intFromPtr(memory.ptr)) orelse {
            self.invalid_frees += 1;
            return false;
        };
        if (record.size != memory.len or record.alignment != alignment) {
            self.invalid_frees += 1;
            return false;
        }
        self.resizes += 1;
        if (!self.backing.rawResize(memory, alignment, new_len, return_address)) return false;
        self.live_bytes = self.live_bytes - record.size + new_len;
        self.peak_bytes = @max(self.peak_bytes, self.live_bytes);
        record.size = new_len;
        record.return_address = return_address;
        return true;
    }

    fn remapFn(
        raw: *anyopaque,
        memory: []u8,
        alignment: std.mem.Alignment,
        new_len: usize,
        return_address: usize,
    ) ?[*]u8 {
        // SAFETY: allocator() installs this vtable only with ptr = *TrackedAllocator.
        const self: *TrackedAllocator = @ptrCast(@alignCast(raw));
        self.lock.lock();
        defer self.lock.unlock();
        const record = self.findLive(@intFromPtr(memory.ptr)) orelse {
            self.invalid_frees += 1;
            return null;
        };
        if (record.size != memory.len or record.alignment != alignment) {
            self.invalid_frees += 1;
            return null;
        }
        self.remaps += 1;
        const result = self.backing.rawRemap(memory, alignment, new_len, return_address) orelse return null;
        self.live_bytes = self.live_bytes - record.size + new_len;
        self.peak_bytes = @max(self.peak_bytes, self.live_bytes);
        record.address = @intFromPtr(result);
        record.size = new_len;
        record.return_address = return_address;
        return result;
    }

    fn freeFn(
        raw: *anyopaque,
        memory: []u8,
        alignment: std.mem.Alignment,
        return_address: usize,
    ) void {
        // SAFETY: allocator() installs this vtable only with ptr = *TrackedAllocator.
        const self: *TrackedAllocator = @ptrCast(@alignCast(raw));
        self.lock.lock();
        defer self.lock.unlock();
        const record = self.findLive(@intFromPtr(memory.ptr)) orelse {
            self.invalid_frees += 1;
            return;
        };
        if (record.size != memory.len or record.alignment != alignment) {
            self.invalid_frees += 1;
            return;
        }
        self.backing.rawFree(memory, alignment, return_address);
        record.live = false;
        self.frees += 1;
        self.live_allocations -= 1;
        self.live_bytes -= record.size;
    }

    const vtable = std.mem.Allocator.VTable{
        .alloc = allocFn,
        .resize = resizeFn,
        .remap = remapFn,
        .free = freeFn,
    };
};
