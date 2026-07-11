const std = @import("std");
const storage = @import("zigeffect_storage_postgres");
const postgres = @import("zigeffect_postgres_libpq");
const options = @import("restart_options");

const config: storage.Config = .{ .table_prefix = "ze_restart_probe" };

const LiveDatabase = struct {
    url: []u8,

    fn init() !LiveDatabase {
        return .{ .url = try std.process.Environ.getAlloc(std.testing.environ, std.testing.allocator, "ZIGEFFECT_TEST_DATABASE_URL") };
    }

    fn deinit(self: *LiveDatabase) void {
        std.testing.allocator.free(self.url);
    }

    fn config(self: *const LiveDatabase) postgres.Config {
        return .{ .connection_url = self.url, .prepared_cache_capacity = 8 };
    }
};

fn dialect() !storage.Dialect {
    if (std.mem.eql(u8, options.database, "postgresql")) return .postgresql;
    if (std.mem.eql(u8, options.database, "cockroachdb")) return .cockroachdb;
    return error.InvalidLiveDatabaseIdentity;
}

fn cleanup(session: *postgres.Session) void {
    const suffixes = [_][]const u8{ "inbox", "outbox", "replies", "messages", "journal_archives", "journal_checkpoints", "journal_events", "journal_streams", "runner_leases" };
    for (suffixes) |suffix| {
        const sql = std.fmt.allocPrint(std.testing.allocator, "drop table if exists {s}_{s} cascade", .{ config.table_prefix, suffix }) catch continue;
        defer std.testing.allocator.free(sql);
        if (session.executeTrustedAlloc(std.testing.allocator, sql)) |value| {
            var result = value; result.deinit(std.testing.allocator);
        } else |_| {}
    }
}

test "durable state crosses a real database restart and a fresh client process" {
    var live = try LiveDatabase.init();
    defer live.deinit();
    var session = try postgres.Session.init(std.testing.allocator, live.config());
    defer session.deinit();
    if (std.mem.eql(u8, options.mode, "seed")) {
        cleanup(&session);
        var receipt = try storage.migrateAlloc(std.testing.allocator, &session, config, try dialect());
        receipt.deinit();
        var pool = try postgres.Pool.initAlloc(std.testing.allocator, std.testing.io, .{ .session = live.config(), .size = 2 });
        defer pool.deinit();
        var journal = try storage.PostgresJournalStore.init(std.testing.allocator, &pool, .{ .storage = config, .workflow_id = 801, .execution_id = 802 });
        _ = try journal.append(.{ .event = .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 801, .execution_id = 802, .idempotency_key = "restart-decision" } });
        var messages = try storage.PostgresMessageStorage.init(std.testing.allocator, &pool, .{ .storage = config });
        var submitted = try messages.submit(.{ .shard_id = 8, .envelope = .{
            .kind = .tell, .address = storage.zstd.fx.entityAddress("restart", "one"), .idempotency_key = "restart-message", .payload = "persisted",
        }, .now_ms = 1 });
        submitted.deinit(std.testing.allocator);
        var reliability = try storage.PostgresReliabilityStore.init(std.testing.allocator, &pool, .{ .storage = config });
        var outbox = try reliability.enqueue(.{ .topic = "restart", .idempotency_key = "restart-outbox", .payload = "persisted", .now_ms = 1 });
        outbox.deinit();
        return;
    }
    if (!std.mem.eql(u8, options.mode, "verify")) return error.InvalidRestartMode;
    defer cleanup(&session);
    try std.testing.expect(session.serverVersion() > 0);
    var pool = try postgres.Pool.initAlloc(std.testing.allocator, std.testing.io, .{ .session = live.config(), .size = 2 });
    defer pool.deinit();
    var journal = try storage.PostgresJournalStore.init(std.testing.allocator, &pool, .{ .storage = config, .workflow_id = 801, .execution_id = 802 });
    var state = try journal.latestState(std.testing.allocator); defer state.deinit();
    try std.testing.expectEqual(@as(u64, 1), state.last_sequence);
    const duplicate = try journal.appendIdempotent(.{ .event = .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 801, .execution_id = 802, .idempotency_key = "restart-decision" } });
    try std.testing.expect(duplicate.duplicate);
    var messages = try storage.PostgresMessageStorage.init(std.testing.allocator, &pool, .{ .storage = config });
    var pending = try messages.unprocessedByShard(8, std.testing.allocator); defer pending.deinit();
    try std.testing.expectEqual(@as(usize, 1), pending.records.len);
    try std.testing.expectEqualStrings("persisted", pending.records[0].envelope.payload);
    var reliability = try storage.PostgresReliabilityStore.init(std.testing.allocator, &pool, .{ .storage = config });
    var outbox = try reliability.claimNext(1); defer outbox.deinit();
    try std.testing.expectEqualStrings("persisted", outbox.payload);
}
