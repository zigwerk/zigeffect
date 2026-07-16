const std = @import("std");
const External = @import("../external/root.zig");
const Secrets = @import("../secrets/root.zig");

pub const Kind = enum { cache, broker, object_storage, outbox };
pub const Status = enum { started, succeeded, failed };
pub const Fact = struct { sequence: u64, boundary: Kind, operation: []const u8, status: Status, key_fingerprint: u64 = 0, failure_class: ?External.Class = null };

pub const Observer = struct {
    pointer: *anyopaque,
    record_fn: *const fn (*anyopaque, Kind, []const u8, Status, u64, ?External.Class) void,
    pub fn from(comptime T: type, pointer: *T) Observer {
        return .{ .pointer = pointer, .record_fn = struct {
            fn call(raw: *anyopaque, kind: Kind, operation: []const u8, status: Status, key: u64, failure: ?External.Class) void {
                (@as(*T, @ptrCast(@alignCast(raw)))).record(kind, operation, status, key, failure);
            }
        }.call };
    }
    pub fn emit(self: Observer, kind: Kind, operation: []const u8, status: Status, key: []const u8, failure: ?External.Class) void {
        self.record_fn(self.pointer, kind, operation, status, std.hash.Wyhash.hash(0, key), failure);
    }
};

pub const Recorder = struct {
    allocator: std.mem.Allocator,
    facts: std.ArrayList(Fact) = .empty,
    dropped: usize = 0,
    max_facts: usize = 4096,
    pub fn init(allocator: std.mem.Allocator) Recorder {
        return .{ .allocator = allocator };
    }
    pub fn deinit(self: *Recorder) void {
        for (self.facts.items) |fact| self.allocator.free(fact.operation);
        self.facts.deinit(self.allocator);
    }
    pub fn asObserver(self: *Recorder) Observer {
        return Observer.from(Recorder, self);
    }
    pub fn record(self: *Recorder, kind: Kind, operation: []const u8, status: Status, key: u64, failure: ?External.Class) void {
        if (self.facts.items.len == self.max_facts or Secrets.containsSecret(operation)) {
            self.dropped += 1;
            return;
        }
        const owned = self.allocator.dupe(u8, operation) catch {
            self.dropped += 1;
            return;
        };
        self.facts.append(self.allocator, .{ .sequence = self.facts.items.len + 1, .boundary = kind, .operation = owned, .status = status, .key_fingerprint = key, .failure_class = failure }) catch {
            self.allocator.free(owned);
            self.dropped += 1;
        };
    }
    pub fn workbenchJsonAlloc(self: *const Recorder, allocator: std.mem.Allocator) ![]u8 {
        return Secrets.safeJsonAlloc(allocator, .{ .schema = "zigeffect.boundary-facts.v1", .facts = self.facts.items, .dropped = self.dropped }, .{});
    }
};

pub fn classForError(err: anyerror) External.Class {
    return External.classifyError(err);
}

test "boundary observer fingerprints keys and emits secret-safe Workbench facts" {
    var recorder = Recorder.init(std.testing.allocator);
    defer recorder.deinit();
    recorder.asObserver().emit(.cache, "get", .succeeded, "customer-1", null);
    try std.testing.expectEqual(@as(usize, 1), recorder.facts.items.len);
    try std.testing.expect(recorder.facts.items[0].key_fingerprint != 0);
    const json = try recorder.workbenchJsonAlloc(std.testing.allocator);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "customer-1") == null);
}
