const std = @import("std");

pub const Allocator = std.mem.Allocator;

pub const LogLevel = enum {
    info,
    warn,
    err,
};

pub const LogField = struct {
    key: []const u8,
    value: []const u8,
};

pub const LogContext = struct {
    timestamp_ms: ?u64 = null,
    trace_id: ?u64 = null,
    span_id: ?u64 = null,
};

pub const LogEntry = struct {
    level: LogLevel,
    message: []const u8,
    fields: []LogField,
    timestamp_ms: ?u64 = null,
    trace_id: ?u64 = null,
    span_id: ?u64 = null,
};

pub const Logger = struct {
    allocator: Allocator,
    entries: std.ArrayList([]const u8) = .empty,
    structured_entries: std.ArrayList(LogEntry) = .empty,

    pub fn init(allocator: Allocator) Logger {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Logger) void {
        for (self.entries.items) |entry| {
            self.allocator.free(entry);
        }
        self.entries.deinit(self.allocator);

        for (self.structured_entries.items) |entry| {
            self.allocator.free(entry.message);
            for (entry.fields) |field| {
                self.allocator.free(field.key);
                self.allocator.free(field.value);
            }
            self.allocator.free(entry.fields);
        }
        self.structured_entries.deinit(self.allocator);
    }

    fn dupeFields(self: *Logger, fields: []const LogField) Allocator.Error![]LogField {
        const copied = try self.allocator.alloc(LogField, fields.len);
        errdefer self.allocator.free(copied);

        var initialized: usize = 0;
        errdefer {
            for (copied[0..initialized]) |field| {
                self.allocator.free(field.key);
                self.allocator.free(field.value);
            }
        }

        for (fields, 0..) |field, index| {
            copied[index] = .{
                .key = try self.allocator.dupe(u8, field.key),
                .value = try self.allocator.dupe(u8, field.value),
            };
            initialized += 1;
        }

        return copied;
    }

    pub fn logWithContext(
        self: *Logger,
        level: LogLevel,
        message: []const u8,
        fields: []const LogField,
        context: LogContext,
    ) Allocator.Error!void {
        const plain_message = try self.allocator.dupe(u8, message);
        errdefer self.allocator.free(plain_message);

        const structured_message = try self.allocator.dupe(u8, message);
        errdefer self.allocator.free(structured_message);

        const copied_fields = try self.dupeFields(fields);
        errdefer {
            for (copied_fields) |field| {
                self.allocator.free(field.key);
                self.allocator.free(field.value);
            }
            self.allocator.free(copied_fields);
        }

        try self.entries.append(self.allocator, plain_message);
        errdefer _ = self.entries.pop();

        try self.structured_entries.append(self.allocator, .{
            .level = level,
            .message = structured_message,
            .fields = copied_fields,
            .timestamp_ms = context.timestamp_ms,
            .trace_id = context.trace_id,
            .span_id = context.span_id,
        });
    }

    pub fn logFields(self: *Logger, level: LogLevel, message: []const u8, fields: []const LogField) Allocator.Error!void {
        try self.logWithContext(level, message, fields, .{});
    }

    pub fn log(self: *Logger, level: LogLevel, message: []const u8) Allocator.Error!void {
        try self.logFields(level, message, &.{});
    }

    pub fn info(self: *Logger, message: []const u8) Allocator.Error!void {
        try self.log(.info, message);
    }

    pub fn warn(self: *Logger, message: []const u8) Allocator.Error!void {
        try self.log(.warn, message);
    }

    pub fn err(self: *Logger, message: []const u8) Allocator.Error!void {
        try self.log(.err, message);
    }
};
