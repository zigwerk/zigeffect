const std = @import("std");
const causal = @import("causal.zig");
const causal_backend = @import("causal_backend.zig");

pub const Allocator = std.mem.Allocator;

pub const CausalDotBackendOptions = struct {
    max_bytes: ?usize = null,
    include_graph_header: bool = true,
};

pub const CausalDotBackendError = error{
    CausalDotBackendFull,
    CausalDotBackendFinished,
};

pub const CausalDotBackendState = struct {
    allocator: Allocator,
    output: *std.ArrayList(u8),
    max_bytes: ?usize = null,
    include_graph_header: bool = true,
    opened: bool = false,
    finished: bool = false,
    written_event_count: u64 = 0,
    failed_write_count: u64 = 0,

    pub fn init(allocator: Allocator, output: *std.ArrayList(u8), options: CausalDotBackendOptions) CausalDotBackendState {
        return .{
            .allocator = allocator,
            .output = output,
            .max_bytes = options.max_bytes,
            .include_graph_header = options.include_graph_header,
        };
    }

    pub fn backend(self: *CausalDotBackendState) causal_backend.CausalBackend {
        return .{
            .kind = .dot,
            .state = self,
            .record = recordDotBackend,
        };
    }

    pub fn finish(self: *CausalDotBackendState) anyerror!void {
        if (self.finished) return;
        if (self.include_graph_header and !self.opened) {
            var header = std.ArrayList(u8).empty;
            defer header.deinit(self.allocator);
            causal.appendCausalDotGraphHeader(&header, self.allocator) catch |err| {
                self.failed_write_count += 1;
                return err;
            };
            try self.appendFragment(header.items);
            self.opened = true;
        }
        if (self.include_graph_header) {
            var footer = std.ArrayList(u8).empty;
            defer footer.deinit(self.allocator);
            causal.appendCausalDotGraphFooter(&footer, self.allocator) catch |err| {
                self.failed_write_count += 1;
                return err;
            };
            try self.appendFragment(footer.items);
        }
        self.finished = true;
    }

    pub fn writtenEventCount(self: *const CausalDotBackendState) u64 {
        return self.written_event_count;
    }

    pub fn failedWriteCount(self: *const CausalDotBackendState) u64 {
        return self.failed_write_count;
    }

    pub fn isFinished(self: *const CausalDotBackendState) bool {
        return self.finished;
    }

    fn appendFragment(self: *CausalDotBackendState, fragment: []const u8) anyerror!void {
        if (self.max_bytes) |max_bytes| {
            if (self.output.items.len > max_bytes or fragment.len > max_bytes - self.output.items.len) {
                self.failed_write_count += 1;
                return error.CausalDotBackendFull;
            }
        }

        self.output.appendSlice(self.allocator, fragment) catch |err| {
            self.failed_write_count += 1;
            return err;
        };
    }
};

pub fn formatCausalDotEvent(allocator: Allocator, event: causal.CausalEvent) Allocator.Error![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try causal.appendCausalDotEvent(&output, allocator, event);

    return output.toOwnedSlice(allocator);
}

fn recordDotBackend(raw: ?*anyopaque, event: causal.CausalEvent) anyerror!void {
    const state: *CausalDotBackendState = @ptrCast(@alignCast(raw.?));
    if (state.finished) {
        state.failed_write_count += 1;
        return error.CausalDotBackendFinished;
    }
    if (state.include_graph_header and !state.opened) {
        var header = std.ArrayList(u8).empty;
        defer header.deinit(state.allocator);
        causal.appendCausalDotGraphHeader(&header, state.allocator) catch |err| {
            state.failed_write_count += 1;
            return err;
        };
        try state.appendFragment(header.items);
        state.opened = true;
    }
    const fragment = formatCausalDotEvent(state.allocator, event) catch |err| {
        state.failed_write_count += 1;
        return err;
    };
    defer state.allocator.free(fragment);
    try state.appendFragment(fragment);
    state.written_event_count += 1;
}
