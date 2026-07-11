const std = @import("std");
const zstd = @import("zigeffect_std");

pub const contract_version: u32 = 1;
pub const component_name = "orders-domain";
pub const OrderStatus = enum { pending, processing, completed, failed };
pub const Order = struct { id: []const u8, idempotency_key: []const u8, attachment_key: []const u8, status: OrderStatus, version: u64 };
pub const CreateOrder = struct { id: []const u8, idempotency_key: []const u8, attachment_key: []const u8, attachment: []const u8 };

pub const create_schema = zstd.Schema.structSchema(CreateOrder, .{
    zstd.Schema.field("id", zstd.Schema.string().nonEmpty().maxLen(128)),
    zstd.Schema.field("idempotency_key", zstd.Schema.string().minLen(16).maxLen(256)),
    zstd.Schema.field("attachment_key", zstd.Schema.string().nonEmpty().maxLen(512)),
    zstd.Schema.field("attachment", zstd.Schema.string().maxLen(8 * 1024 * 1024)),
});

pub const State = enum { pending, processing, completed, failed };
pub const Event = union(enum) { claim, complete, fail };
pub const Definition = zstd.fx.statechart.Definition(State, Event, void, void);
pub const statechart = Definition.init(.{
    .id = "orders.processing",
    .version = 1,
    .initial = .pending,
    .states = &.{
        .{ .id = .pending }, .{ .id = .processing }, .{ .id = .completed, .kind = .final }, .{ .id = .failed, .kind = .final },
    },
    .transitions = &.{
        .{ .id = "claim", .source = .pending, .event = .claim, .target = .processing },
        .{ .id = "complete", .source = .processing, .event = .complete, .target = .completed },
        .{ .id = "fail", .source = .processing, .event = .fail, .target = .failed },
    },
});

pub fn validateCreate(command: CreateOrder) !void {
    if (std.mem.indexOf(u8, command.attachment_key, "..") != null or std.mem.startsWith(u8, command.attachment_key, "/")) return error.InvalidAttachmentKey;
    if (zstd.Secrets.containsSecret(command.id) or zstd.Secrets.containsSecret(command.idempotency_key) or zstd.Secrets.containsSecret(command.attachment_key)) return error.SecretDetected;
    const report = statechart.validate();
    if (!report.isValid()) return error.InvalidStatechart;
}

pub fn advance(status: OrderStatus, event: Event) !OrderStatus {
    const source: State = @enumFromInt(@intFromEnum(status));
    for (statechart.transitions) |transition| {
        if (transition.source == source and transition.event == Definition.eventTag(event)) {
            const target = transition.target orelse return status;
            return @enumFromInt(@intFromEnum(target));
        }
    }
    return error.InvalidOrderTransition;
}
