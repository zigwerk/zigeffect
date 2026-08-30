const std = @import("std");

/// Central audited ownership boundary for allocator-backed zgraphy columns and
/// result values. Callers retain the allocator and release every returned
/// slice in their matching `deinit` or error rollback path.
pub fn slice(comptime T: type, allocator: std.mem.Allocator, count: usize) std.mem.Allocator.Error![]T {
    return allocator.alloc(T, count);
}

/// Central audited ownership boundary for durable copies of caller-owned
/// source metadata. The returned slice follows the same explicit ownership
/// contract as `slice`.
pub fn copy(comptime T: type, allocator: std.mem.Allocator, input: []const T) std.mem.Allocator.Error![]T {
    return allocator.dupe(T, input);
}
