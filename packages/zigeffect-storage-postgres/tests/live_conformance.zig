const std = @import("std");
const storage = @import("zigeffect_storage_postgres");
const postgres = @import("zigeffect_postgres_libpq");
const options = @import("live_options");

const LiveDatabase = struct {
    url: []u8,

    fn init() !LiveDatabase {
        return .{ .url = try std.process.Environ.getAlloc(std.testing.environ, std.testing.allocator, "ZIGEFFECT_TEST_DATABASE_URL") };
    }

    fn deinit(self: *LiveDatabase) void {
        std.testing.allocator.free(self.url);
    }

    fn config(self: *const LiveDatabase) postgres.Config {
        return .{ .connection_url = self.url, .prepared_cache_capacity = 16 };
    }
};

fn dialect() !storage.Dialect {
    if (std.mem.eql(u8, options.database, "postgresql")) return .postgresql;
    if (std.mem.eql(u8, options.database, "cockroachdb")) return .cockroachdb;
    return error.InvalidLiveDatabaseIdentity;
}

fn dropSchema(session: *postgres.Session, allocator: std.mem.Allocator, config: storage.Config) void {
    const suffixes = [_][]const u8{ "inbox", "outbox", "replies", "messages", "journal_archives", "journal_checkpoints", "journal_events", "journal_streams", "runner_leases" };
    for (suffixes) |suffix| {
        const sql = std.fmt.allocPrint(allocator, "drop table if exists {s}_{s} cascade", .{ config.table_prefix, suffix }) catch continue;
        defer allocator.free(sql);
        if (session.executeTrustedAlloc(allocator, sql)) |result_value| {
            var result = result_value;
            result.deinit(allocator);
        } else |_| {}
    }
}

test "live migrations and fenced runner leases survive independent sessions" {
    var live = try LiveDatabase.init();
    defer live.deinit();
    const config: storage.Config = .{ .table_prefix = "ze_store_live" };

    var setup = try postgres.Session.init(std.testing.allocator, live.config());
    defer setup.deinit();
    defer dropSchema(&setup, std.testing.allocator, config);
    var receipt = try storage.migrateAlloc(std.testing.allocator, &setup, config, try dialect());
    defer receipt.deinit();
    try std.testing.expect(std.mem.indexOf(u8, receipt.json, options.database) != null);

    var pool = try postgres.Pool.initAlloc(std.testing.allocator, std.testing.io, .{
        .session = live.config(),
        .size = 3,
        .acquisition_timeout_ms = 500,
        .poll_interval_ms = 1,
    });
    defer pool.deinit();
    var leases = try storage.PostgresRunnerStorage.init(std.testing.allocator, &pool, config);
    const first_owner = storage.zstd.fx.RunnerAddress{ .machine_id = 10, .runner_id = 20 };
    const second_owner = storage.zstd.fx.RunnerAddress{ .machine_id = 11, .runner_id = 21 };
    const first = try leases.acquire(.{ .shard_id = 7, .owner = first_owner, .now_ms = 100, .ttl_ms = 50 });
    try std.testing.expectEqual(@as(u64, 1), first.epoch);
    try std.testing.expectError(error.LeaseConflict, leases.acquire(.{ .shard_id = 7, .owner = second_owner, .now_ms = 120, .ttl_ms = 50 }));
    const refreshed = try leases.refresh(.{ .shard_id = 7, .owner = first_owner, .now_ms = 130, .ttl_ms = 50 });
    try std.testing.expectEqual(@as(u64, 2), refreshed.version);
    const recovered = try leases.acquire(.{ .shard_id = 7, .owner = second_owner, .now_ms = 181, .ttl_ms = 50 });
    try std.testing.expectEqual(@as(u64, 2), recovered.epoch);
    try std.testing.expectError(error.LeaseNotOwned, leases.refresh(.{ .shard_id = 7, .owner = first_owner, .now_ms = 182, .ttl_ms = 50 }));
    const loaded = (try leases.lease(7)).?;
    try std.testing.expect(loaded.owner.eql(second_owner));
    var all = try leases.leases(std.testing.allocator);
    defer all.deinit();
    try std.testing.expectEqual(@as(usize, 1), all.leases.len);
    try leases.release(.{ .shard_id = 7, .owner = second_owner });
    try std.testing.expect((try leases.lease(7)) == null);
}

test "live journal append replay checkpoint compaction and ambiguous commit retry are durable" {
    var live = try LiveDatabase.init();
    defer live.deinit();
    const config: storage.Config = .{ .table_prefix = "ze_journal_live" };
    var setup = try postgres.Session.init(std.testing.allocator, live.config());
    defer setup.deinit();
    defer dropSchema(&setup, std.testing.allocator, config);
    var receipt = try storage.migrateAlloc(std.testing.allocator, &setup, config, try dialect());
    receipt.deinit();
    var pool = try postgres.Pool.initAlloc(std.testing.allocator, std.testing.io, .{
        .session = live.config(), .size = 3, .acquisition_timeout_ms = 500, .poll_interval_ms = 1,
    });
    defer pool.deinit();
    var journal = try storage.PostgresJournalStore.init(std.testing.allocator, &pool, .{
        .storage = config, .workflow_id = 41, .execution_id = 42,
    });
    const first: storage.zstd.fx.workflow.WorkflowEvent = .{
        .sequence = 1, .kind = .workflow_started, .workflow_id = 41, .execution_id = 42, .idempotency_key = "decision-1",
    };
    try std.testing.expectEqual(@as(u64, 1), try journal.append(.{ .expected_next_sequence = 1, .event = first }));
    const duplicate = try journal.appendIdempotent(.{ .expected_next_sequence = 1, .event = first });
    try std.testing.expect(duplicate.duplicate);
    try std.testing.expectEqual(@as(u64, 1), duplicate.sequence);
    try std.testing.expectEqual(@as(u64, 2), try journal.append(.{ .event = .{
        .sequence = 2, .kind = .activity_scheduled, .workflow_id = 41, .execution_id = 42,
        .activity_id = 9, .name = "charge", .idempotency_key = "decision-2",
    } }));
    var state = try journal.latestState(std.testing.allocator);
    defer state.deinit();
    try std.testing.expectEqual(@as(u64, 2), state.last_sequence);
    try std.testing.expectEqual(@as(usize, 1), state.activities.items.len);
    var checkpoint = try journal.publishCheckpoint(&state, 500);
    defer checkpoint.deinit();
    const compacted = try journal.compactThroughCheckpoint(2);
    try std.testing.expectEqual(@as(usize, 2), compacted.deleted_events);
    var after_compaction = try journal.readAll(std.testing.allocator);
    defer after_compaction.deinit();
    try std.testing.expectEqual(@as(usize, 0), after_compaction.events.len);
    var recovered = try journal.latestState(std.testing.allocator);
    defer recovered.deinit();
    try std.testing.expectEqual(@as(u64, 2), recovered.last_sequence);

    const Fault = struct {
        fired: bool = false,
        fn inject(context: ?*anyopaque, boundary: storage.CommitBoundary) !void {
            const self: *@This() = @ptrCast(@alignCast(context.?));
            if (boundary == .after_commit and !self.fired) {
                self.fired = true;
                return error.SimulatedLostCommitReply;
            }
        }
    };
    var fault: Fault = .{};
    journal.fault = .{ .context = &fault, .function = Fault.inject };
    const third: storage.zstd.fx.workflow.WorkflowEvent = .{
        .sequence = 3, .kind = .activity_started, .workflow_id = 41, .execution_id = 42,
        .activity_id = 9, .name = "charge", .idempotency_key = "decision-3",
    };
    try std.testing.expectError(error.SimulatedLostCommitReply, journal.appendIdempotent(.{ .event = third }));
    journal.fault = .{};
    const retried = try journal.appendIdempotent(.{ .event = third });
    try std.testing.expect(retried.duplicate);
    var final_state = try journal.latestState(std.testing.allocator);
    defer final_state.deinit();
    try std.testing.expectEqual(@as(u64, 3), final_state.last_sequence);
    try std.testing.expectEqual(storage.zstd.fx.workflow.ActivityStatus.running, final_state.activities.items[0].status);

    var completed_journal = try storage.PostgresJournalStore.init(std.testing.allocator, &pool, .{
        .storage = config, .workflow_id = 51, .execution_id = 52,
    });
    _ = try completed_journal.append(.{ .event = .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 51, .execution_id = 52, .idempotency_key = "complete-1" } });
    _ = try completed_journal.append(.{ .event = .{ .sequence = 2, .kind = .workflow_completed, .workflow_id = 51, .execution_id = 52, .idempotency_key = "complete-2" } });
    const retention = try completed_journal.applyCompletedRetention(.archive_then_compact, 900);
    try std.testing.expect(retention.compacted and retention.archived);
    try std.testing.expectEqual(@as(usize, 2), retention.deleted_events);
    var completed_state = try completed_journal.latestState(std.testing.allocator);
    defer completed_state.deinit();
    try std.testing.expectEqual(storage.zstd.fx.workflow.WorkflowStatus.completed, completed_state.workflow_status);
    var archive_count = try setup.queryAlloc(std.testing.allocator, .{ .sql = "select count(*)::bigint from ze_journal_live_journal_archives where workflow_id=51" });
    defer archive_count.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(i64, 1), archive_count.rows[0].fields[0].value.integer);
}

test "live journal rejects stale fences and serializes concurrent writers" {
    var live = try LiveDatabase.init();
    defer live.deinit();
    const config: storage.Config = .{ .table_prefix = "ze_concurrency_live" };
    var setup = try postgres.Session.init(std.testing.allocator, live.config());
    defer setup.deinit();
    defer dropSchema(&setup, std.testing.allocator, config);
    var receipt = try storage.migrateAlloc(std.testing.allocator, &setup, config, try dialect()); receipt.deinit();
    var now_result = try setup.queryAlloc(std.testing.allocator, .{ .sql = "select cast(floor(extract(epoch from current_timestamp)*1000) as int8)::text" });
    defer now_result.deinit(std.testing.allocator);
    const now = try std.fmt.parseUnsigned(u64, now_result.rows[0].fields[0].value.text, 10);
    var pool = try postgres.Pool.initAlloc(std.testing.allocator, std.testing.io, .{
        .session = live.config(), .size = 4, .acquisition_timeout_ms = 1_000, .poll_interval_ms = 1,
    });
    defer pool.deinit();
    var lease_store = try storage.PostgresRunnerStorage.init(std.testing.allocator, &pool, config);
    const owner1 = storage.zstd.fx.RunnerAddress{ .machine_id = 1, .runner_id = 1 };
    const owner2 = storage.zstd.fx.RunnerAddress{ .machine_id = 2, .runner_id = 2 };
    const first_lease = try lease_store.acquire(.{ .shard_id = 8, .owner = owner1, .now_ms = now, .ttl_ms = 60_000 });
    var stale = try storage.PostgresJournalStore.init(std.testing.allocator, &pool, .{
        .storage = config, .workflow_id = 61, .execution_id = 62, .required_fence = .{ .shard_id = 8, .epoch = first_lease.epoch },
    });
    _ = try stale.append(.{ .event = .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 61, .execution_id = 62, .idempotency_key = "fenced-1" } });
    const moved = try lease_store.acquire(.{ .shard_id = 8, .owner = owner2, .now_ms = now + 60_001, .ttl_ms = 60_000 });
    try std.testing.expectEqual(@as(u64, 2), moved.epoch);
    try std.testing.expectError(error.StaleLeaseFence, stale.append(.{ .event = .{
        .sequence = 2, .kind = .workflow_completed, .workflow_id = 61, .execution_id = 62, .idempotency_key = "fenced-2",
    } }));
    var current = try storage.PostgresJournalStore.init(std.testing.allocator, &pool, .{
        .storage = config, .workflow_id = 61, .execution_id = 62, .required_fence = .{ .shard_id = 8, .epoch = moved.epoch },
    });
    _ = try current.append(.{ .event = .{ .sequence = 2, .kind = .workflow_completed, .workflow_id = 61, .execution_id = 62, .idempotency_key = "fenced-2" } });

    var concurrent = try storage.PostgresJournalStore.init(std.heap.smp_allocator, &pool, .{ .storage = config, .workflow_id = 71, .execution_id = 72 });
    _ = try concurrent.append(.{ .event = .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 71, .execution_id = 72, .idempotency_key = "concurrent-1" } });
    const Context = struct {
        store: *storage.PostgresJournalStore,
        key: []const u8,
        succeeded: bool = false,
        conflicted: bool = false,
        fn run(self: *@This()) void {
            _ = self.store.append(.{ .event = .{ .sequence = 2, .kind = .workflow_completed, .workflow_id = 71, .execution_id = 72, .idempotency_key = self.key } }) catch |err| {
                if (err == error.SequenceConflict) self.conflicted = true;
                return;
            };
            self.succeeded = true;
        }
    };
    var first_context: Context = .{ .store = &concurrent, .key = "writer-a" };
    var second_context: Context = .{ .store = &concurrent, .key = "writer-b" };
    const first_thread = try std.Thread.spawn(.{}, Context.run, .{&first_context});
    const second_thread = try std.Thread.spawn(.{}, Context.run, .{&second_context});
    first_thread.join(); second_thread.join();
    try std.testing.expect(first_context.succeeded != second_context.succeeded);
    try std.testing.expect(first_context.conflicted != second_context.conflicted);
    var rows = try concurrent.readAll(std.testing.allocator); defer rows.deinit();
    try std.testing.expectEqual(@as(usize, 2), rows.events.len);
}

test "live message submit claim visibility redelivery ack reply and commit ambiguity are transactional" {
    var live = try LiveDatabase.init();
    defer live.deinit();
    const config: storage.Config = .{ .table_prefix = "ze_message_live" };
    var setup = try postgres.Session.init(std.testing.allocator, live.config());
    defer setup.deinit();
    defer dropSchema(&setup, std.testing.allocator, config);
    var receipt = try storage.migrateAlloc(std.testing.allocator, &setup, config, try dialect());
    receipt.deinit();
    var pool = try postgres.Pool.initAlloc(std.testing.allocator, std.testing.io, .{
        .session = live.config(), .size = 3, .acquisition_timeout_ms = 500, .poll_interval_ms = 1,
    });
    defer pool.deinit();
    var messages = try storage.PostgresMessageStorage.init(std.testing.allocator, &pool, .{
        .storage = config, .visibility_timeout_ms = 30,
    });
    const address = storage.zstd.fx.entityAddress("account", "a-1");
    const request: storage.zstd.fx.MessageEnvelope = .{
        .kind = .request, .address = address, .idempotency_key = "request-1", .payload_type_name = "Debit", .payload = "{\"amount\":7}",
    };
    var submitted = try messages.submit(.{ .shard_id = 3, .envelope = request, .now_ms = 100 });
    defer submitted.deinit(std.testing.allocator);
    try std.testing.expect(!submitted.duplicate);
    var duplicate = try messages.submit(.{ .shard_id = 3, .envelope = request, .now_ms = 101 });
    defer duplicate.deinit(std.testing.allocator);
    try std.testing.expect(duplicate.duplicate);
    const id = submitted.envelope.id;
    const claimed = try messages.claim(.{ .shard_id = 3, .message_id = id, .now_ms = 100 });
    defer storage.zstd.fx.deinitMessageEnvelope(std.testing.allocator, claimed);
    try std.testing.expectEqual(@as(u32, 1), claimed.attempt);
    try std.testing.expectError(error.MessageNotVisible, messages.claim(.{ .shard_id = 3, .message_id = id, .now_ms = 129 }));
    const redelivered = try messages.claim(.{ .shard_id = 3, .message_id = id, .now_ms = 130 });
    defer storage.zstd.fx.deinitMessageEnvelope(std.testing.allocator, redelivered);
    try std.testing.expectEqual(@as(u32, 2), redelivered.attempt);
    try messages.ack(.{ .message_id = id, .shard_id = 3, .now_ms = 131 });
    try std.testing.expect((try messages.unprocessedById(id, std.testing.allocator)) == null);

    var second = try messages.submit(.{ .shard_id = 3, .envelope = .{
        .kind = .request, .address = address, .idempotency_key = "request-2", .payload_type_name = "Balance",
    }, .now_ms = 200 });
    defer second.deinit(std.testing.allocator);
    const stored_reply = try messages.storeReply(.{ .shard_id = 3, .envelope = .{
        .kind = .reply, .address = address, .correlation_id = second.envelope.correlation_id,
        .idempotency_key = "reply-2", .payload_type_name = "BalanceResult", .payload = "7",
    }, .now_ms = 201 });
    defer storage.zstd.fx.deinitMessageEnvelope(std.testing.allocator, stored_reply);
    const loaded_reply = (try messages.reply(second.envelope.correlation_id.?, std.testing.allocator)).?;
    defer storage.zstd.fx.deinitMessageEnvelope(std.testing.allocator, loaded_reply);
    try std.testing.expectEqualStrings("7", loaded_reply.payload);
    try std.testing.expectError(error.DuplicateReply, messages.storeReply(.{ .shard_id = 3, .envelope = .{
        .kind = .reply, .address = address, .correlation_id = second.envelope.correlation_id, .idempotency_key = "reply-again",
    }, .now_ms = 202 }));

    const Fault = struct {
        fired: bool = false,
        fn inject(context: ?*anyopaque, boundary: storage.CommitBoundary) !void {
            const self: *@This() = @ptrCast(@alignCast(context.?));
            if (boundary == .after_commit and !self.fired) { self.fired = true; return error.SimulatedLostCommitReply; }
        }
    };
    var fault: Fault = .{};
    messages.fault = .{ .context = &fault, .function = Fault.inject };
    const ambiguous: storage.zstd.fx.MessageEnvelope = .{ .kind = .tell, .address = address, .idempotency_key = "ambiguous-submit" };
    try std.testing.expectError(error.SimulatedLostCommitReply, messages.submit(.{ .shard_id = 3, .envelope = ambiguous, .now_ms = 300 }));
    messages.fault = .{};
    var retry = try messages.submit(.{ .shard_id = 3, .envelope = ambiguous, .now_ms = 301 });
    defer retry.deinit(std.testing.allocator);
    try std.testing.expect(retry.duplicate);
}

test "live outbox and inbox share the application commit and preserve idempotency" {
    var live = try LiveDatabase.init();
    defer live.deinit();
    const config: storage.Config = .{ .table_prefix = "ze_reliability_live" };
    var setup = try postgres.Session.init(std.testing.allocator, live.config());
    defer setup.deinit();
    defer dropSchema(&setup, std.testing.allocator, config);
    var receipt = try storage.migrateAlloc(std.testing.allocator, &setup, config, try dialect());
    receipt.deinit();
    var created = try setup.executeTrustedAlloc(std.testing.allocator, "create table ze_reliability_live_app(id bigint primary key, value text not null)");
    created.deinit(std.testing.allocator);
    defer {
        if (setup.executeTrustedAlloc(std.testing.allocator, "drop table if exists ze_reliability_live_app")) |result_value| {
            var result = result_value; result.deinit(std.testing.allocator);
        } else |_| {}
    }
    var pool = try postgres.Pool.initAlloc(std.testing.allocator, std.testing.io, .{
        .session = live.config(), .size = 3, .acquisition_timeout_ms = 500, .poll_interval_ms = 1,
    });
    defer pool.deinit();
    var reliability = try storage.PostgresReliabilityStore.init(std.testing.allocator, &pool, .{
        .storage = config, .outbox_visibility_timeout_ms = 25,
    });
    const outbox = reliability.asOutboxStore();

    var rolled_back = try outbox.begin(std.testing.allocator);
    try rolled_back.execute(std.testing.allocator, .{
        .sql = "insert into ze_reliability_live_app(id,value) values(1,'rolled-back')",
    });
    var rolled_message = try rolled_back.enqueue(.{ .topic = "accounts", .idempotency_key = "event-rollback", .payload = "{}", .now_ms = 10 });
    rolled_message.deinit();
    try rolled_back.rollback();
    rolled_back.deinit();
    var counts = try setup.queryAlloc(std.testing.allocator, .{
        .sql = "select (select count(*) from ze_reliability_live_app)::bigint, (select count(*) from ze_reliability_live_outbox)::bigint",
    });
    defer counts.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(i64, 0), counts.rows[0].fields[0].value.integer);
    try std.testing.expectEqual(@as(i64, 0), counts.rows[0].fields[1].value.integer);

    var committed = try outbox.begin(std.testing.allocator);
    try committed.execute(std.testing.allocator, .{
        .sql = "insert into ze_reliability_live_app(id,value) values(2,'committed')",
    });
    var event = try committed.enqueue(.{ .topic = "accounts", .idempotency_key = "event-2", .payload = "{\"id\":2}", .now_ms = 20 });
    defer event.deinit();
    const inbox = try committed.recordInbox(.{ .consumer = "ledger", .idempotency_key = "command-2", .payload = "{\"id\":2}", .now_ms = 20 });
    try std.testing.expect(!inbox.duplicate);
    try committed.commit();
    committed.deinit();

    var duplicate_event = try reliability.enqueue(.{ .topic = "accounts", .idempotency_key = "event-2", .payload = "{\"id\":2}", .now_ms = 21 });
    defer duplicate_event.deinit();
    try std.testing.expect(duplicate_event.duplicate);
    try std.testing.expectError(error.IdempotencyPayloadMismatch, reliability.enqueue(.{
        .topic = "accounts", .idempotency_key = "event-2", .payload = "different", .now_ms = 22,
    }));
    const duplicate_inbox = try reliability.recordInbox(.{ .consumer = "ledger", .idempotency_key = "command-2", .payload = "{\"id\":2}", .now_ms = 21 });
    try std.testing.expect(duplicate_inbox.duplicate);
    try std.testing.expectError(error.IdempotencyPayloadMismatch, reliability.recordInbox(.{
        .consumer = "ledger", .idempotency_key = "command-2", .payload = "different", .now_ms = 22,
    }));

    var claimed = try outbox.claimNext(20);
    defer claimed.deinit();
    try std.testing.expectEqual(@as(u32, 1), claimed.attempt);
    try std.testing.expectError(error.OutboxEmpty, outbox.claimNext(44));
    var redelivered = try outbox.claimNext(45);
    defer redelivered.deinit();
    try std.testing.expectEqual(@as(u32, 2), redelivered.attempt);
    try outbox.markDelivered(redelivered.id, 46);
    try std.testing.expectError(error.OutboxEmpty, outbox.claimNext(100));
}

test "every durable store family proves before and after commit crash semantics" {
    var live = try LiveDatabase.init();
    defer live.deinit();
    const config: storage.Config = .{ .table_prefix = "ze_commit_matrix" };
    var setup = try postgres.Session.init(std.testing.allocator, live.config());
    defer setup.deinit();
    defer dropSchema(&setup, std.testing.allocator, config);
    var migration = try storage.migrateAlloc(std.testing.allocator, &setup, config, try dialect());
    migration.deinit();
    var pool = try postgres.Pool.initAlloc(std.testing.allocator, std.testing.io, .{
        .session = live.config(), .size = 3, .acquisition_timeout_ms = 500, .poll_interval_ms = 1,
    });
    defer pool.deinit();

    const Fault = struct {
        target: storage.CommitBoundary,
        fired: bool = false,
        fn inject(context: ?*anyopaque, boundary: storage.CommitBoundary) !void {
            const self: *@This() = @ptrCast(@alignCast(context.?));
            if (!self.fired and boundary == self.target) {
                self.fired = true;
                return error.InjectedCommitBoundary;
            }
        }
        fn hook(self: *@This()) storage.CommitFault { return .{ .context = self, .function = inject }; }
    };

    var journal = try storage.PostgresJournalStore.init(std.testing.allocator, &pool, .{
        .storage = config, .workflow_id = 1001, .execution_id = 1002,
    });
    var journal_before = Fault{ .target = .before_commit };
    journal.fault = journal_before.hook();
    try std.testing.expectError(error.InjectedCommitBoundary, journal.append(.{ .event = .{
        .sequence = 1, .kind = .workflow_started, .workflow_id = 1001, .execution_id = 1002, .idempotency_key = "journal-before",
    } }));
    journal.fault = .{};
    var journal_empty = try journal.readAll(std.testing.allocator);
    defer journal_empty.deinit();
    try std.testing.expectEqual(@as(usize, 0), journal_empty.events.len);

    var journal_after = Fault{ .target = .after_commit };
    journal.fault = journal_after.hook();
    try std.testing.expectError(error.InjectedCommitBoundary, journal.appendIdempotent(.{ .event = .{
        .sequence = 1, .kind = .workflow_started, .workflow_id = 1001, .execution_id = 1002, .idempotency_key = "journal-after",
    } }));
    journal.fault = .{};
    var journal_committed = try journal.readAll(std.testing.allocator);
    defer journal_committed.deinit();
    try std.testing.expectEqual(@as(usize, 1), journal_committed.events.len);

    var leases = try storage.PostgresRunnerStorage.init(std.testing.allocator, &pool, config);
    const owner = storage.zstd.fx.RunnerAddress{ .machine_id = 31, .runner_id = 32 };
    var lease_before = Fault{ .target = .before_commit };
    leases.fault = lease_before.hook();
    try std.testing.expectError(error.InjectedCommitBoundary, leases.acquire(.{ .shard_id = 41, .owner = owner, .now_ms = 1, .ttl_ms = 100 }));
    leases.fault = .{};
    try std.testing.expect((try leases.lease(41)) == null);
    var lease_after = Fault{ .target = .after_commit };
    leases.fault = lease_after.hook();
    try std.testing.expectError(error.InjectedCommitBoundary, leases.acquire(.{ .shard_id = 42, .owner = owner, .now_ms = 1, .ttl_ms = 100 }));
    leases.fault = .{};
    try std.testing.expect((try leases.lease(42)) != null);

    var messages = try storage.PostgresMessageStorage.init(std.testing.allocator, &pool, .{ .storage = config, .visibility_timeout_ms = 100 });
    const address = storage.zstd.fx.entityAddress("commit-matrix", "entity");
    var message_before = Fault{ .target = .before_commit };
    messages.fault = message_before.hook();
    try std.testing.expectError(error.InjectedCommitBoundary, messages.submit(.{ .shard_id = 51, .envelope = .{
        .kind = .tell, .address = address, .idempotency_key = "message-before",
    }, .now_ms = 1 }));
    messages.fault = .{};
    var message_count_before = try setup.queryAlloc(std.testing.allocator, .{ .sql = "select count(*)::bigint from ze_commit_matrix_messages where idempotency_key='message-before'" });
    defer message_count_before.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(i64, 0), message_count_before.rows[0].fields[0].value.integer);
    var message_after = Fault{ .target = .after_commit };
    messages.fault = message_after.hook();
    try std.testing.expectError(error.InjectedCommitBoundary, messages.submit(.{ .shard_id = 51, .envelope = .{
        .kind = .tell, .address = address, .idempotency_key = "message-after",
    }, .now_ms = 2 }));
    messages.fault = .{};
    var message_count_after = try setup.queryAlloc(std.testing.allocator, .{ .sql = "select count(*)::bigint from ze_commit_matrix_messages where idempotency_key='message-after'" });
    defer message_count_after.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(i64, 1), message_count_after.rows[0].fields[0].value.integer);

    var reliability = try storage.PostgresReliabilityStore.init(std.testing.allocator, &pool, .{ .storage = config });
    var outbox_before = Fault{ .target = .before_commit };
    reliability.fault = outbox_before.hook();
    try std.testing.expectError(error.InjectedCommitBoundary, reliability.enqueue(.{
        .topic = "commit", .idempotency_key = "outbox-before", .payload = "{}", .now_ms = 1,
    }));
    reliability.fault = .{};
    var outbox_count_before = try setup.queryAlloc(std.testing.allocator, .{ .sql = "select count(*)::bigint from ze_commit_matrix_outbox where idempotency_key='outbox-before'" });
    defer outbox_count_before.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(i64, 0), outbox_count_before.rows[0].fields[0].value.integer);
    var outbox_after = Fault{ .target = .after_commit };
    reliability.fault = outbox_after.hook();
    try std.testing.expectError(error.InjectedCommitBoundary, reliability.enqueue(.{
        .topic = "commit", .idempotency_key = "outbox-after", .payload = "{}", .now_ms = 2,
    }));
    reliability.fault = .{};
    var outbox_count_after = try setup.queryAlloc(std.testing.allocator, .{ .sql = "select count(*)::bigint from ze_commit_matrix_outbox where idempotency_key='outbox-after'" });
    defer outbox_count_after.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(i64, 1), outbox_count_after.rows[0].fields[0].value.integer);
}

test "file and SQL journals replay to the same canonical checkpoint" {
    var live = try LiveDatabase.init();
    defer live.deinit();
    const config: storage.Config = .{ .table_prefix = "ze_differential_live" };
    var setup = try postgres.Session.init(std.testing.allocator, live.config());
    defer setup.deinit();
    defer dropSchema(&setup, std.testing.allocator, config);
    var receipt = try storage.migrateAlloc(std.testing.allocator, &setup, config, try dialect()); receipt.deinit();
    var pool = try postgres.Pool.initAlloc(std.testing.allocator, std.testing.io, .{ .session = live.config(), .size = 2 });
    defer pool.deinit();
    var sql_store = try storage.PostgresJournalStore.init(std.testing.allocator, &pool, .{ .storage = config, .workflow_id = 901, .execution_id = 902 });
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var file_store = try storage.zstd.fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{ .fsync_policy = .after_append });
    defer file_store.deinit();
    const events = [_]storage.zstd.fx.workflow.WorkflowEvent{
        .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 901, .execution_id = 902, .idempotency_key = "diff-1" },
        .{ .sequence = 2, .kind = .activity_scheduled, .workflow_id = 901, .execution_id = 902, .activity_id = 77, .name = "differential", .idempotency_key = "diff-2" },
        .{ .sequence = 3, .kind = .activity_completed, .workflow_id = 901, .execution_id = 902, .activity_id = 77, .name = "differential", .idempotency_key = "diff-3" },
    };
    for (events) |event| {
        _ = try file_store.append(.{ .event = event });
        _ = try sql_store.append(.{ .event = event });
    }
    var file_state = try file_store.latestState(std.testing.allocator); defer file_state.deinit();
    var sql_state = try sql_store.latestState(std.testing.allocator); defer sql_state.deinit();
    const file_checkpoint = try storage.zstd.fx.workflow.formatWorkflowCheckpointJson(std.testing.allocator, &file_state); defer std.testing.allocator.free(file_checkpoint);
    const sql_checkpoint = try storage.zstd.fx.workflow.formatWorkflowCheckpointJson(std.testing.allocator, &sql_state); defer std.testing.allocator.free(sql_checkpoint);
    try std.testing.expectEqualStrings(file_checkpoint, sql_checkpoint);
}
