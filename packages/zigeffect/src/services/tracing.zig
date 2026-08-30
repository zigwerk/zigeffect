const std = @import("std");

pub const Allocator = std.mem.Allocator;
pub const TraceId = u64;
pub const SpanId = u64;

pub const TraceAttribute = struct {
    key: []const u8,
    value: []const u8,
};

pub const Span = struct {
    id: SpanId,
    trace_id: TraceId,
    parent_id: ?SpanId = null,
    name: []const u8,
    attributes: []TraceAttribute,
    ended: bool = false,
};

pub const Tracing = struct {
    allocator: Allocator,
    events: std.ArrayList([]const u8) = .empty,
    spans: std.ArrayList(Span) = .empty,
    next_trace_id: TraceId = 1,
    next_span_id: SpanId = 1,

    pub fn init(allocator: Allocator) Tracing {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Tracing) void {
        for (self.events.items) |event_name| {
            self.allocator.free(event_name);
        }
        self.events.deinit(self.allocator);

        for (self.spans.items) |span| {
            self.allocator.free(span.name);
            self.freeAttributes(span.attributes);
        }
        self.spans.deinit(self.allocator);
    }

    pub fn event(self: *Tracing, name: []const u8) Allocator.Error!void {
        try self.events.append(self.allocator, try self.allocator.dupe(u8, name));
    }

    fn copyAttributes(self: *Tracing, attributes: []const TraceAttribute) Allocator.Error![]TraceAttribute {
        const copied = try self.allocator.alloc(TraceAttribute, attributes.len);
        errdefer self.allocator.free(copied);

        var initialized: usize = 0;
        errdefer {
            for (copied[0..initialized]) |attribute| {
                self.allocator.free(attribute.key);
                self.allocator.free(attribute.value);
            }
        }

        for (attributes, 0..) |attribute, index| {
            copied[index] = .{
                .key = try self.allocator.dupe(u8, attribute.key),
                .value = try self.allocator.dupe(u8, attribute.value),
            };
            initialized += 1;
        }

        return copied;
    }

    fn freeAttributes(self: *Tracing, attributes: []TraceAttribute) void {
        for (attributes) |attribute| {
            self.allocator.free(attribute.key);
            self.allocator.free(attribute.value);
        }
        self.allocator.free(attributes);
    }

    fn traceIdForParent(self: *const Tracing, parent_id: SpanId) ?TraceId {
        for (self.spans.items) |span| {
            if (span.id == parent_id) return span.trace_id;
        }
        return null;
    }

    pub fn startSpanWithAttributes(
        self: *Tracing,
        name: []const u8,
        parent_id: ?SpanId,
        attributes: []const TraceAttribute,
    ) Allocator.Error!SpanId {
        const id = self.next_span_id;
        self.next_span_id += 1;
        errdefer self.next_span_id -= 1;

        var allocated_trace_id = false;
        const trace_id = if (parent_id) |parent|
            self.traceIdForParent(parent) orelse blk: {
                allocated_trace_id = true;
                const next = self.next_trace_id;
                self.next_trace_id += 1;
                break :blk next;
            }
        else blk: {
            allocated_trace_id = true;
            const next = self.next_trace_id;
            self.next_trace_id += 1;
            break :blk next;
        };
        errdefer {
            if (allocated_trace_id) self.next_trace_id -= 1;
        }

        const copied_name = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(copied_name);

        const copied_attributes = try self.copyAttributes(attributes);
        errdefer self.freeAttributes(copied_attributes);

        try self.spans.append(self.allocator, .{
            .id = id,
            .trace_id = trace_id,
            .parent_id = parent_id,
            .name = copied_name,
            .attributes = copied_attributes,
        });
        errdefer {
            const span = self.spans.pop().?;
            self.allocator.free(span.name);
            self.freeAttributes(span.attributes);
        }

        const entry = try std.fmt.allocPrint(self.allocator, "span:start:{s}", .{name});
        errdefer self.allocator.free(entry);
        try self.events.append(self.allocator, entry);
        return id;
    }

    pub fn startSpan(self: *Tracing, name: []const u8, parent_id: ?SpanId) Allocator.Error!SpanId {
        return self.startSpanWithAttributes(name, parent_id, &.{});
    }

    pub fn spanById(self: *const Tracing, id: SpanId) ?*const Span {
        for (self.spans.items) |*recorded| {
            if (recorded.id == id) return recorded;
        }
        return null;
    }

    pub fn spanEnded(self: *const Tracing, id: SpanId) ?bool {
        return if (self.spanById(id)) |recorded| recorded.ended else null;
    }

    pub fn spanParent(self: *const Tracing, id: SpanId) ?SpanId {
        return if (self.spanById(id)) |recorded| recorded.parent_id else null;
    }

    pub fn spanTrace(self: *const Tracing, id: SpanId) ?TraceId {
        return if (self.spanById(id)) |recorded| recorded.trace_id else null;
    }

    pub fn endSpan(self: *Tracing, id: SpanId) Allocator.Error!void {
        for (self.spans.items) |*span| {
            if (span.id == id) {
                span.ended = true;
                const entry = try std.fmt.allocPrint(self.allocator, "span:end:{s}", .{span.name});
                try self.events.append(self.allocator, entry);
                return;
            }
        }
    }

    pub fn spanStart(self: *Tracing, name: []const u8) Allocator.Error!void {
        _ = try self.startSpan(name, null);
    }

    pub fn spanEnd(self: *Tracing, name: []const u8) Allocator.Error!void {
        for (self.spans.items) |*span| {
            if (!span.ended and std.mem.eql(u8, span.name, name)) {
                span.ended = true;
                break;
            }
        }
        const entry = try std.fmt.allocPrint(self.allocator, "span:end:{s}", .{name});
        try self.events.append(self.allocator, entry);
    }
};
