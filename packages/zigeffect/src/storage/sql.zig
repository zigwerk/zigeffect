const std = @import("std");
const schema_mod = @import("schema.zig");

pub const Allocator = std.mem.Allocator;
pub const storage_sql_plan_schema = "zigeffect.storage.sql-plan.v1";
pub const storage_sql_plan_schema_version: u32 = 1;

pub const SqlStorageDialect = enum { postgresql, cockroachdb };
pub const SqlStorageStatementKind = enum { create_schema, create_table, create_index };

pub const SqlStorageStatement = struct {
    name: []const u8,
    adapter: schema_mod.StorageAdapterKind,
    kind: SqlStorageStatementKind,
    sql: []const u8,
};

pub const SqlStorageMigrationPlan = struct {
    dialect: SqlStorageDialect,
    schemas: []const schema_mod.StorageSchemaDescriptor,
    statements: []const SqlStorageStatement,
};

const create_workflow_journal_events =
    \\CREATE TABLE IF NOT EXISTS zigeffect_workflow_journal_events (
    \\  sequence BIGINT PRIMARY KEY,
    \\  workflow_id BIGINT NOT NULL,
    \\  execution_id BIGINT NOT NULL,
    \\  event_kind TEXT NOT NULL,
    \\  idempotency_key TEXT NOT NULL,
    \\  schema TEXT NOT NULL,
    \\  schema_version INTEGER NOT NULL,
    \\  payload_json JSONB NOT NULL
    \\)
;

const create_workflow_checkpoints =
    \\CREATE TABLE IF NOT EXISTS zigeffect_workflow_checkpoints (
    \\  last_sequence BIGINT PRIMARY KEY,
    \\  workflow_id BIGINT,
    \\  execution_id BIGINT,
    \\  workflow_status TEXT NOT NULL,
    \\  schema TEXT NOT NULL,
    \\  schema_version INTEGER NOT NULL,
    \\  checkpoint_json JSONB NOT NULL,
    \\  written_at_ms BIGINT NOT NULL
    \\)
;

const create_workflow_snapshot_commits =
    \\CREATE TABLE IF NOT EXISTS zigeffect_workflow_snapshot_commits (
    \\  last_sequence BIGINT PRIMARY KEY,
    \\  checkpoint_name TEXT NOT NULL,
    \\  segment_name TEXT NOT NULL,
    \\  archive_name TEXT,
    \\  schema TEXT NOT NULL,
    \\  schema_version INTEGER NOT NULL,
    \\  commit_json JSONB NOT NULL,
    \\  committed_at_ms BIGINT NOT NULL
    \\)
;

const create_cluster_runner_leases =
    \\CREATE TABLE IF NOT EXISTS zigeffect_cluster_runner_leases (
    \\  shard_id INTEGER PRIMARY KEY,
    \\  owner_machine_key TEXT NOT NULL,
    \\  owner_runner_key TEXT NOT NULL,
    \\  acquired_at_ms BIGINT NOT NULL,
    \\  refreshed_at_ms BIGINT NOT NULL,
    \\  expires_at_ms BIGINT NOT NULL,
    \\  epoch BIGINT NOT NULL,
    \\  version BIGINT NOT NULL,
    \\  schema TEXT NOT NULL,
    \\  schema_version INTEGER NOT NULL,
    \\  lease_json JSONB NOT NULL
    \\)
;

const create_cluster_messages =
    \\CREATE TABLE IF NOT EXISTS zigeffect_cluster_messages (
    \\  message_id BIGINT PRIMARY KEY,
    \\  shard_id INTEGER NOT NULL,
    \\  status TEXT NOT NULL,
    \\  entity_type TEXT NOT NULL,
    \\  entity_id TEXT NOT NULL,
    \\  idempotency_key TEXT NOT NULL,
    \\  correlation_id BIGINT,
    \\  attempt INTEGER NOT NULL,
    \\  schema TEXT NOT NULL,
    \\  schema_version INTEGER NOT NULL,
    \\  payload_json JSONB NOT NULL,
    \\  stored_at_ms BIGINT NOT NULL,
    \\  updated_at_ms BIGINT NOT NULL
    \\)
;

const create_cluster_replies =
    \\CREATE TABLE IF NOT EXISTS zigeffect_cluster_replies (
    \\  correlation_id BIGINT PRIMARY KEY,
    \\  shard_id INTEGER NOT NULL,
    \\  message_id BIGINT NOT NULL,
    \\  entity_type TEXT NOT NULL,
    \\  entity_id TEXT NOT NULL,
    \\  schema TEXT NOT NULL,
    \\  schema_version INTEGER NOT NULL,
    \\  reply_json JSONB NOT NULL,
    \\  stored_at_ms BIGINT NOT NULL
    \\)
;

const sql_statements = [_]SqlStorageStatement{
    .{
        .name = "create_workflow_journal_events",
        .adapter = .journal,
        .kind = .create_table,
        .sql = create_workflow_journal_events,
    },
    .{
        .name = "create_workflow_checkpoints",
        .adapter = .journal,
        .kind = .create_table,
        .sql = create_workflow_checkpoints,
    },
    .{
        .name = "create_workflow_snapshot_commits",
        .adapter = .journal,
        .kind = .create_table,
        .sql = create_workflow_snapshot_commits,
    },
    .{
        .name = "create_cluster_runner_leases",
        .adapter = .runner,
        .kind = .create_table,
        .sql = create_cluster_runner_leases,
    },
    .{
        .name = "create_cluster_messages",
        .adapter = .message,
        .kind = .create_table,
        .sql = create_cluster_messages,
    },
    .{
        .name = "create_cluster_replies",
        .adapter = .message,
        .kind = .create_table,
        .sql = create_cluster_replies,
    },
};

pub fn sqlStorageMigrationPlan(dialect: SqlStorageDialect) SqlStorageMigrationPlan {
    return .{
        .dialect = dialect,
        .schemas = schema_mod.storageSchemaCatalog().items,
        .statements = &sql_statements,
    };
}

pub fn formatSqlStorageMigrationPlanText(allocator: Allocator, plan: SqlStorageMigrationPlan) Allocator.Error![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.print(allocator, "zigeffect storage migration plan schema={s} version={d} dialect={s}\n", .{
        storage_sql_plan_schema,
        storage_sql_plan_schema_version,
        @tagName(plan.dialect),
    });
    try output.print(allocator, "schemas={d} statements={d}\n", .{ plan.schemas.len, plan.statements.len });
    for (plan.statements) |statement| {
        try output.print(allocator, "\n-- {s} adapter={s} kind={s}\n{s};\n", .{
            statement.name,
            @tagName(statement.adapter),
            @tagName(statement.kind),
            statement.sql,
        });
    }

    return output.toOwnedSlice(allocator);
}

pub fn formatSqlStorageMigrationPlanJson(allocator: Allocator, plan: SqlStorageMigrationPlan) Allocator.Error![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\"schema\":");
    try appendJsonString(&output, allocator, storage_sql_plan_schema);
    try output.print(allocator, ",\"schema_version\":{d},\"dialect\":", .{storage_sql_plan_schema_version});
    try appendJsonString(&output, allocator, @tagName(plan.dialect));
    try output.appendSlice(allocator, ",\"schemas\":[");
    for (plan.schemas, 0..) |schema, index| {
        if (index != 0) try output.append(allocator, ',');
        try output.appendSlice(allocator, "{\"adapter\":");
        try appendJsonString(&output, allocator, @tagName(schema.adapter));
        try output.appendSlice(allocator, ",\"record\":");
        try appendJsonString(&output, allocator, @tagName(schema.record));
        try output.appendSlice(allocator, ",\"schema\":");
        try appendJsonString(&output, allocator, schema.schema);
        try output.print(allocator, ",\"version\":{d}", .{schema.version});
        try output.append(allocator, '}');
    }
    try output.appendSlice(allocator, "],\"statements\":[");
    for (plan.statements, 0..) |statement, index| {
        if (index != 0) try output.append(allocator, ',');
        try output.appendSlice(allocator, "{\"name\":");
        try appendJsonString(&output, allocator, statement.name);
        try output.appendSlice(allocator, ",\"adapter\":");
        try appendJsonString(&output, allocator, @tagName(statement.adapter));
        try output.appendSlice(allocator, ",\"kind\":");
        try appendJsonString(&output, allocator, @tagName(statement.kind));
        try output.appendSlice(allocator, ",\"sql\":");
        try appendJsonString(&output, allocator, statement.sql);
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
            0x00...0x08, 0x0b, 0x0c, 0x0e...0x1f => try output.print(allocator, "\\u{x:0>4}", .{byte}),
            else => try output.append(allocator, byte),
        }
    }
    try output.append(allocator, '"');
}
