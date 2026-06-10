const std = @import("std");
const workflow_journal = @import("../workflow/journal.zig");
const workflow_store = @import("../workflow/store.zig");
const runner_storage = @import("../cluster/runner_storage.zig");
const message_storage = @import("../cluster/message_storage.zig");

pub const Allocator = std.mem.Allocator;
pub const storage_catalog_schema = "zigeffect.storage.catalog.v1";
pub const storage_catalog_schema_version: u32 = 1;

pub const StorageAdapterKind = enum { journal, runner, message };

pub const StorageRecordKind = enum {
    workflow_event,
    workflow_checkpoint,
    workflow_snapshot_commit,
    runner_lease,
    message_record,
    message_reply,
};

pub const StorageSchemaCompatibility = enum { current, older, newer, unknown };

pub const StorageSchemaDescriptor = struct {
    adapter: StorageAdapterKind,
    record: StorageRecordKind,
    schema: []const u8,
    version: u32,
    description: []const u8,
};

pub const StorageSchemaCompatibilityReport = struct {
    schema: []const u8,
    expected_version: ?u32 = null,
    found_version: u32,
    compatibility: StorageSchemaCompatibility,
};

pub const StorageSchemaCatalog = struct {
    items: []const StorageSchemaDescriptor,

    pub fn find(self: StorageSchemaCatalog, schema_name: []const u8) ?StorageSchemaDescriptor {
        for (self.items) |item| {
            if (std.mem.eql(u8, item.schema, schema_name)) return item;
        }
        return null;
    }
};

const schema_catalog = [_]StorageSchemaDescriptor{
    .{
        .adapter = .journal,
        .record = .workflow_event,
        .schema = workflow_journal.workflow_journal_event_schema,
        .version = workflow_journal.workflow_journal_event_schema_version,
        .description = "append-only durable workflow event journal rows",
    },
    .{
        .adapter = .journal,
        .record = .workflow_checkpoint,
        .schema = workflow_store.workflow_checkpoint_schema,
        .version = workflow_store.workflow_checkpoint_schema_version,
        .description = "durable workflow replay checkpoint snapshots",
    },
    .{
        .adapter = .journal,
        .record = .workflow_snapshot_commit,
        .schema = workflow_store.workflow_snapshot_commit_schema,
        .version = workflow_store.workflow_snapshot_commit_schema_version,
        .description = "atomic workflow snapshot commit records",
    },
    .{
        .adapter = .runner,
        .record = .runner_lease,
        .schema = runner_storage.runner_lease_schema,
        .version = runner_storage.runner_lease_schema_version,
        .description = "cluster runner shard lease records",
    },
    .{
        .adapter = .message,
        .record = .message_record,
        .schema = message_storage.message_record_schema,
        .version = message_storage.message_record_schema_version,
        .description = "durable cluster message request records",
    },
    .{
        .adapter = .message,
        .record = .message_reply,
        .schema = message_storage.message_reply_schema,
        .version = message_storage.message_reply_schema_version,
        .description = "durable cluster message reply records",
    },
};

pub fn storageSchemaCatalog() StorageSchemaCatalog {
    return .{ .items = &schema_catalog };
}

pub fn findStorageSchema(schema_name: []const u8) ?StorageSchemaDescriptor {
    return storageSchemaCatalog().find(schema_name);
}

pub fn classifyStorageSchema(schema_name: []const u8, version: u32) StorageSchemaCompatibilityReport {
    const descriptor = findStorageSchema(schema_name) orelse return .{
        .schema = schema_name,
        .found_version = version,
        .compatibility = .unknown,
    };
    return .{
        .schema = schema_name,
        .expected_version = descriptor.version,
        .found_version = version,
        .compatibility = if (version == descriptor.version) .current else if (version < descriptor.version) .older else .newer,
    };
}

pub fn formatStorageSchemaCatalogText(allocator: Allocator, catalog: StorageSchemaCatalog) Allocator.Error![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.print(allocator, "zigeffect storage schema catalog schema={s} version={d}\n", .{
        storage_catalog_schema,
        storage_catalog_schema_version,
    });
    for (catalog.items) |item| {
        try output.print(allocator, "- adapter={s} record={s} schema={s} version={d} description={s}\n", .{
            @tagName(item.adapter),
            @tagName(item.record),
            item.schema,
            item.version,
            item.description,
        });
    }

    return output.toOwnedSlice(allocator);
}

pub fn formatStorageSchemaCatalogJson(allocator: Allocator, catalog: StorageSchemaCatalog) Allocator.Error![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\"schema\":");
    try appendJsonString(&output, allocator, storage_catalog_schema);
    try output.print(allocator, ",\"schema_version\":{d},\"items\":[", .{storage_catalog_schema_version});
    for (catalog.items, 0..) |item, index| {
        if (index != 0) try output.append(allocator, ',');
        try output.appendSlice(allocator, "{\"adapter\":");
        try appendJsonString(&output, allocator, @tagName(item.adapter));
        try output.appendSlice(allocator, ",\"record\":");
        try appendJsonString(&output, allocator, @tagName(item.record));
        try output.appendSlice(allocator, ",\"schema\":");
        try appendJsonString(&output, allocator, item.schema);
        try output.print(allocator, ",\"version\":{d},\"description\":", .{item.version});
        try appendJsonString(&output, allocator, item.description);
        try output.append(allocator, '}');
    }
    try output.appendSlice(allocator, "]}");

    return output.toOwnedSlice(allocator);
}

fn appendJsonString(output: *std.ArrayList(u8), allocator: Allocator, value: []const u8) Allocator.Error!void {
    try output.append(allocator, '"');
    for (value) |byte| {
        switch (byte) {
            '"' => try output.appendSlice(allocator, "\\\""),
            '\\' => try output.appendSlice(allocator, "\\\\"),
            '\n' => try output.appendSlice(allocator, "\\n"),
            '\r' => try output.appendSlice(allocator, "\\r"),
            '\t' => try output.appendSlice(allocator, "\\t"),
            else => try output.append(allocator, byte),
        }
    }
    try output.append(allocator, '"');
}
