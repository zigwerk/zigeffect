const std = @import("std");
const postgres = @import("zigeffect_postgres_libpq");
pub const zstd = postgres.zstd;
const fx = zstd.fx;

pub const Sql = zstd.Sql;

pub const capability = zstd.Capability.Descriptor{
    .id = "zigeffect-storage.postgres",
    .kind = .workflow_journal,
    .maturity = .production_candidate,
    .package = "zigeffect-storage-postgres",
    .version = "0.1.0",
    .features = &.{ "workflow-journal", "checkpoints", "message-storage", "fenced-leases", "outbox-inbox" },
    .side_effects = .real,
    .conformance = .{ .schema = "zigeffect.storage-live-conformance", .version = 1, .receipt = "conformance/storage-restart-live.v1.json", .authority = .live_external, .observed_at_ms = 1783777336000, .valid_until_ms = 1791553336000, .content_sha256 = "sha256:bf137fe1648d1a46679c4a99dd440827b558074acc0d780d1e8b31379b3d8ca3" },
    .limitations = &.{
        "requires zigeffect-postgres-libpq and a compatible system libpq",
        "multi-region failover remains database-provider operated",
    },
};

pub const message_storage_capability = zstd.Capability.Descriptor{
    .id = "zigeffect-storage.postgres-messages",
    .kind = .message_storage,
    .maturity = .production_candidate,
    .package = "zigeffect-storage-postgres",
    .version = "0.1.0",
    .features = &.{ "message-storage", "transactional-claims", "visibility-timeout", "redelivery", "idempotency", "replies" },
    .side_effects = .real,
    .conformance = capability.conformance,
    .limitations = capability.limitations,
};

pub const lease_storage_capability = zstd.Capability.Descriptor{
    .id = "zigeffect-storage.postgres-leases",
    .kind = .lease_storage,
    .maturity = .production_candidate,
    .package = "zigeffect-storage-postgres",
    .version = "0.1.0",
    .features = &.{ "fenced-leases", "epochs", "refresh", "expiry", "process-restart" },
    .side_effects = .real,
    .conformance = capability.conformance,
    .limitations = capability.limitations,
};

pub const Config = struct {
    table_prefix: []const u8 = "zigeffect",

    pub fn validate(self: Config) !void {
        if (!validIdentifier(self.table_prefix) or self.table_prefix.len > 40) return error.InvalidTablePrefix;
    }
};

pub const Dialect = enum { postgresql, cockroachdb };

pub const MigrationReceipt = struct {
    allocator: std.mem.Allocator,
    json: []const u8,

    pub fn deinit(self: *MigrationReceipt) void {
        self.allocator.free(self.json);
        self.* = undefined;
    }
};

pub fn migrateAlloc(allocator: std.mem.Allocator, session: *postgres.Session, config: Config, dialect: Dialect) !MigrationReceipt {
    try config.validate();
    const p = config.table_prefix;
    const sql = try std.fmt.allocPrint(allocator,
        "create table if not exists {s}_runner_leases (" ++
            "shard_id numeric(20,0) primary key, machine_id numeric(20,0) not null, runner_id numeric(20,0) not null," ++
            "acquired_at_ms numeric(20,0) not null, refreshed_at_ms numeric(20,0) not null, expires_at_ms numeric(20,0) not null," ++
            "epoch numeric(20,0) not null, version numeric(20,0) not null);" ++
        "create table if not exists {s}_journal_streams (" ++
            "workflow_id numeric(20,0) not null, execution_id numeric(20,0) not null, next_sequence numeric(20,0) not null default 1," ++
            "base_sequence numeric(20,0) not null default 0, primary key(workflow_id, execution_id));" ++
        "create table if not exists {s}_journal_events (" ++
            "workflow_id numeric(20,0) not null, execution_id numeric(20,0) not null, sequence numeric(20,0) not null," ++
            "idempotency_key text not null, event_json text not null, created_at_ms numeric(20,0) not null," ++
            "primary key(workflow_id, execution_id, sequence)," ++
            "foreign key(workflow_id, execution_id) references {s}_journal_streams(workflow_id, execution_id) on delete cascade);" ++
        "create unique index if not exists {s}_journal_idempotency on {s}_journal_events(workflow_id, execution_id, idempotency_key) where idempotency_key <> '';" ++
        "create table if not exists {s}_journal_checkpoints (" ++
            "workflow_id numeric(20,0) not null, execution_id numeric(20,0) not null, last_sequence numeric(20,0) not null," ++
            "checkpoint_json text not null, published_at_ms numeric(20,0) not null," ++
            "primary key(workflow_id, execution_id, last_sequence)," ++
            "foreign key(workflow_id, execution_id) references {s}_journal_streams(workflow_id, execution_id) on delete cascade);" ++
        "create table if not exists {s}_journal_archives (" ++
            "workflow_id numeric(20,0) not null, execution_id numeric(20,0) not null, first_sequence numeric(20,0) not null," ++
            "last_sequence numeric(20,0) not null, event_count bigint not null, archive_jsonl text not null, archived_at_ms numeric(20,0) not null," ++
            "primary key(workflow_id, execution_id, first_sequence, last_sequence)," ++
            "foreign key(workflow_id, execution_id) references {s}_journal_streams(workflow_id, execution_id) on delete cascade);" ++
        "create table if not exists {s}_messages (" ++
            "message_id numeric(20,0) primary key, shard_id numeric(20,0) not null, kind text not null, entity_type text not null," ++
            "entity_id numeric(20,0) not null, correlation_id numeric(20,0), idempotency_key text not null," ++
            "status text not null, attempt bigint not null, visible_at_ms numeric(20,0) not null, lease_epoch numeric(20,0)," ++
            "record_json text not null, stored_at_ms numeric(20,0) not null, updated_at_ms numeric(20,0) not null);" ++
        "create unique index if not exists {s}_message_idempotency on {s}_messages(shard_id, kind, entity_type, entity_id, idempotency_key);" ++
        "create index if not exists {s}_message_ready on {s}_messages(shard_id, status, visible_at_ms);" ++
        "create table if not exists {s}_replies (" ++
            "correlation_id numeric(20,0) primary key, shard_id numeric(20,0) not null, reply_id numeric(20,0) not null unique," ++
            "lease_epoch numeric(20,0), record_json text not null, stored_at_ms numeric(20,0) not null);" ++
        "create table if not exists {s}_outbox (" ++
            "id numeric(20,0) primary key, topic text not null, idempotency_key text not null unique, payload text not null," ++
            "status text not null default 'pending', attempt bigint not null default 0, visible_at_ms numeric(20,0) not null," ++
            "created_at_ms numeric(20,0) not null, updated_at_ms numeric(20,0) not null);" ++
        "create table if not exists {s}_inbox (" ++
            "consumer text not null, idempotency_key text not null, payload_hash text not null, received_at_ms numeric(20,0) not null," ++
            "primary key(consumer, idempotency_key));",
        .{ p, p, p, p, p, p, p, p, p, p, p, p, p, p, p, p, p, p },
    );
    defer allocator.free(sql);
    var result = try session.executeTrustedAlloc(allocator, sql);
    result.deinit(allocator);
    const json = try std.fmt.allocPrint(allocator,
        "{{\"schema\":\"zigeffect.storage-postgres.migration.v1\",\"prefix\":\"{s}\",\"dialect\":\"{s}\",\"rollback_posture\":\"{s}\"}}",
        .{ p, @tagName(dialect), if (dialect == .postgresql) "transactional-schema-forward-only" else "online-ddl-forward-only" },
    );
    return .{ .allocator = allocator, .json = json };
}

pub const CommitBoundary = enum { before_commit, after_commit };
pub const CommitFault = struct {
    context: ?*anyopaque = null,
    function: ?*const fn (?*anyopaque, CommitBoundary) anyerror!void = null,

    fn hit(self: CommitFault, boundary: CommitBoundary) !void {
        if (self.function) |function| try function(self.context, boundary);
    }
};

pub const Fence = struct { shard_id: fx.ShardId, epoch: fx.ShardLeaseEpoch };

pub const PostgresRunnerStorage = struct {
    allocator: std.mem.Allocator,
    pool: *postgres.Pool,
    config: Config,
    fault: CommitFault = .{},

    pub fn init(allocator: std.mem.Allocator, pool: *postgres.Pool, config: Config) !PostgresRunnerStorage {
        try config.validate();
        return .{ .allocator = allocator, .pool = pool, .config = config };
    }

    pub fn asRunnerStorage(self: *PostgresRunnerStorage) fx.RunnerStorage {
        return .{ .context = self, .vtable = &runner_vtable };
    }

    pub fn acquire(self: *PostgresRunnerStorage, request: fx.RunnerLeaseAcquire) !fx.ShardLease {
        if (request.ttl_ms == 0 or request.now_ms > std.math.maxInt(u64) - request.ttl_ms) return error.InvalidLeaseTtl;
        var tx = try self.pool.checkoutTransaction();
        defer tx.deinit();
        const table = try tableName(self.allocator, self.config, "runner_leases");
        defer self.allocator.free(table);
        const insert_sql = try std.fmt.allocPrint(self.allocator,
            "insert into {s}(shard_id,machine_id,runner_id,acquired_at_ms,refreshed_at_ms,expires_at_ms,epoch,version) " ++
                "values($1::numeric,$2::numeric,$3::numeric,$4::numeric,$4::numeric,$5::numeric,1,1) on conflict(shard_id) do nothing",
            .{table},
        );
        defer self.allocator.free(insert_sql);
        const shard = try u64Text(self.allocator, request.shard_id); defer self.allocator.free(shard);
        const machine = try u64Text(self.allocator, request.owner.machine_id); defer self.allocator.free(machine);
        const runner = try u64Text(self.allocator, request.owner.runner_id); defer self.allocator.free(runner);
        const now = try u64Text(self.allocator, request.now_ms); defer self.allocator.free(now);
        const expires = try u64Text(self.allocator, request.now_ms + request.ttl_ms); defer self.allocator.free(expires);
        var inserted = try tx.queryAlloc(self.allocator, .{ .sql = insert_sql, .binds = &.{ .{ .text = shard }, .{ .text = machine }, .{ .text = runner }, .{ .text = now }, .{ .text = expires } } });
        inserted.deinit(self.allocator);
        const select_sql = try std.fmt.allocPrint(self.allocator,
            "select machine_id::text,runner_id::text,acquired_at_ms::text,refreshed_at_ms::text,expires_at_ms::text,epoch::text,version::text from {s} where shard_id=$1::numeric for update",
            .{table},
        );
        defer self.allocator.free(select_sql);
        var selected = try tx.queryAlloc(self.allocator, .{ .sql = select_sql, .binds = &.{.{ .text = shard }} });
        defer selected.deinit(self.allocator);
        if (selected.rows.len != 1) return error.LeaseNotFound;
        var current = try leaseFromRow(request.shard_id, selected.rows[0]);
        if (current.owner.eql(request.owner) and current.acquired_at_ms == request.now_ms and current.version == 1) {
            try self.commit(&tx);
            return current;
        }
        if (current.expires_at_ms > request.now_ms) return error.LeaseConflict;
        const update_sql = try std.fmt.allocPrint(self.allocator,
            "update {s} set machine_id=$2::numeric,runner_id=$3::numeric,acquired_at_ms=$4::numeric,refreshed_at_ms=$4::numeric," ++
                "expires_at_ms=$5::numeric,epoch=epoch+1,version=version+1 where shard_id=$1::numeric " ++
                "returning machine_id::text,runner_id::text,acquired_at_ms::text,refreshed_at_ms::text,expires_at_ms::text,epoch::text,version::text",
            .{table},
        );
        defer self.allocator.free(update_sql);
        var updated = try tx.queryAlloc(self.allocator, .{ .sql = update_sql, .binds = &.{ .{ .text = shard }, .{ .text = machine }, .{ .text = runner }, .{ .text = now }, .{ .text = expires } } });
        defer updated.deinit(self.allocator);
        current = try leaseFromRow(request.shard_id, updated.rows[0]);
        try self.commit(&tx);
        return current;
    }

    pub fn refresh(self: *PostgresRunnerStorage, request: fx.RunnerLeaseRefresh) !fx.ShardLease {
        if (request.ttl_ms == 0 or request.now_ms > std.math.maxInt(u64) - request.ttl_ms) return error.InvalidLeaseTtl;
        var tx = try self.pool.checkoutTransaction();
        defer tx.deinit();
        const table = try tableName(self.allocator, self.config, "runner_leases"); defer self.allocator.free(table);
        const shard = try u64Text(self.allocator, request.shard_id); defer self.allocator.free(shard);
        const machine = try u64Text(self.allocator, request.owner.machine_id); defer self.allocator.free(machine);
        const runner = try u64Text(self.allocator, request.owner.runner_id); defer self.allocator.free(runner);
        const now = try u64Text(self.allocator, request.now_ms); defer self.allocator.free(now);
        const expires = try u64Text(self.allocator, request.now_ms + request.ttl_ms); defer self.allocator.free(expires);
        const sql = try std.fmt.allocPrint(self.allocator,
            "update {s} set refreshed_at_ms=$4::numeric,expires_at_ms=$5::numeric,version=version+1 " ++
                "where shard_id=$1::numeric and machine_id=$2::numeric and runner_id=$3::numeric and expires_at_ms>$4::numeric " ++
                "returning machine_id::text,runner_id::text,acquired_at_ms::text,refreshed_at_ms::text,expires_at_ms::text,epoch::text,version::text",
            .{table},
        );
        defer self.allocator.free(sql);
        var result = try tx.queryAlloc(self.allocator, .{ .sql = sql, .binds = &.{ .{ .text = shard }, .{ .text = machine }, .{ .text = runner }, .{ .text = now }, .{ .text = expires } } });
        defer result.deinit(self.allocator);
        if (result.rows.len == 0) {
            const current = try self.leaseInSession(tx.session(), request.shard_id, false) orelse return error.LeaseNotFound;
            if (!current.owner.eql(request.owner)) return error.LeaseNotOwned;
            return error.LeaseExpired;
        }
        const refreshed = try leaseFromRow(request.shard_id, result.rows[0]);
        try self.commit(&tx);
        return refreshed;
    }

    pub fn release(self: *PostgresRunnerStorage, request: fx.RunnerLeaseRelease) !void {
        var tx = try self.pool.checkoutTransaction(); defer tx.deinit();
        const table = try tableName(self.allocator, self.config, "runner_leases"); defer self.allocator.free(table);
        const shard = try u64Text(self.allocator, request.shard_id); defer self.allocator.free(shard);
        const machine = try u64Text(self.allocator, request.owner.machine_id); defer self.allocator.free(machine);
        const runner = try u64Text(self.allocator, request.owner.runner_id); defer self.allocator.free(runner);
        const sql = try std.fmt.allocPrint(self.allocator, "delete from {s} where shard_id=$1::numeric and machine_id=$2::numeric and runner_id=$3::numeric returning shard_id", .{table}); defer self.allocator.free(sql);
        var result = try tx.queryAlloc(self.allocator, .{ .sql = sql, .binds = &.{ .{ .text = shard }, .{ .text = machine }, .{ .text = runner } } }); defer result.deinit(self.allocator);
        if (result.rows.len == 0) {
            const current = try self.leaseInSession(tx.session(), request.shard_id, false) orelse return error.LeaseNotFound;
            if (!current.owner.eql(request.owner)) return error.LeaseNotOwned;
            return error.LeaseNotFound;
        }
        try self.commit(&tx);
    }

    pub fn releaseAll(self: *PostgresRunnerStorage, owner: fx.RunnerAddress) !usize {
        var tx = try self.pool.checkoutTransaction(); defer tx.deinit();
        const table = try tableName(self.allocator, self.config, "runner_leases"); defer self.allocator.free(table);
        const machine = try u64Text(self.allocator, owner.machine_id); defer self.allocator.free(machine);
        const runner = try u64Text(self.allocator, owner.runner_id); defer self.allocator.free(runner);
        const sql = try std.fmt.allocPrint(self.allocator, "delete from {s} where machine_id=$1::numeric and runner_id=$2::numeric returning shard_id", .{table}); defer self.allocator.free(sql);
        var result = try tx.queryAlloc(self.allocator, .{ .sql = sql, .binds = &.{ .{ .text = machine }, .{ .text = runner } } }); defer result.deinit(self.allocator);
        const count = result.rows.len;
        try self.commit(&tx);
        return count;
    }

    pub fn lease(self: *PostgresRunnerStorage, shard_id: fx.ShardId) !?fx.ShardLease {
        var lease_handle = try self.pool.checkout(); defer lease_handle.deinit();
        return self.leaseInSession(lease_handle.session(), shard_id, false);
    }

    pub fn leases(self: *PostgresRunnerStorage, allocator: std.mem.Allocator) !fx.RunnerLeaseBatch {
        var lease_handle = try self.pool.checkout(); defer lease_handle.deinit();
        const table = try tableName(self.allocator, self.config, "runner_leases"); defer self.allocator.free(table);
        const sql = try std.fmt.allocPrint(self.allocator, "select shard_id::text,machine_id::text,runner_id::text,acquired_at_ms::text,refreshed_at_ms::text,expires_at_ms::text,epoch::text,version::text from {s} order by shard_id", .{table}); defer self.allocator.free(sql);
        var result = try lease_handle.queryAlloc(self.allocator, .{ .sql = sql }); defer result.deinit(self.allocator);
        const output = try allocator.alloc(fx.ShardLease, result.rows.len); errdefer allocator.free(output);
        for (result.rows, 0..) |row, index| output[index] = try leaseFromRowWithShard(row);
        return .{ .allocator = allocator, .leases = output };
    }

    pub fn reset(self: *PostgresRunnerStorage) void {
        var lease_handle = self.pool.checkout() catch return; defer lease_handle.deinit();
        const table = tableName(self.allocator, self.config, "runner_leases") catch return; defer self.allocator.free(table);
        const sql = std.fmt.allocPrint(self.allocator, "delete from {s}", .{table}) catch return; defer self.allocator.free(sql);
        var result = lease_handle.queryAlloc(self.allocator, .{ .sql = sql }) catch return; result.deinit(self.allocator);
    }

    fn leaseInSession(self: *PostgresRunnerStorage, session: *postgres.Session, shard_id: fx.ShardId, for_update: bool) !?fx.ShardLease {
        const table = try tableName(self.allocator, self.config, "runner_leases"); defer self.allocator.free(table);
        const shard = try u64Text(self.allocator, shard_id); defer self.allocator.free(shard);
        const sql = try std.fmt.allocPrint(self.allocator,
            "select machine_id::text,runner_id::text,acquired_at_ms::text,refreshed_at_ms::text,expires_at_ms::text,epoch::text,version::text from {s} where shard_id=$1::numeric{s}",
            .{ table, if (for_update) " for update" else "" },
        ); defer self.allocator.free(sql);
        var result = try session.queryAlloc(self.allocator, .{ .sql = sql, .binds = &.{.{ .text = shard }} }); defer result.deinit(self.allocator);
        if (result.rows.len == 0) return null;
        return try leaseFromRow(shard_id, result.rows[0]);
    }

    fn commit(self: *PostgresRunnerStorage, tx: *postgres.Transaction) !void {
        try self.fault.hit(.before_commit);
        try tx.commit();
        try self.fault.hit(.after_commit);
    }

    fn acquireAdapter(context: *anyopaque, request: fx.RunnerLeaseAcquire) anyerror!fx.ShardLease { return (@as(*PostgresRunnerStorage, @ptrCast(@alignCast(context)))).acquire(request); }
    fn refreshAdapter(context: *anyopaque, request: fx.RunnerLeaseRefresh) anyerror!fx.ShardLease { return (@as(*PostgresRunnerStorage, @ptrCast(@alignCast(context)))).refresh(request); }
    fn releaseAdapter(context: *anyopaque, request: fx.RunnerLeaseRelease) anyerror!void { return (@as(*PostgresRunnerStorage, @ptrCast(@alignCast(context)))).release(request); }
    fn releaseAllAdapter(context: *anyopaque, owner: fx.RunnerAddress) anyerror!usize { return (@as(*PostgresRunnerStorage, @ptrCast(@alignCast(context)))).releaseAll(owner); }
    fn leaseAdapter(context: *anyopaque, shard_id: fx.ShardId) anyerror!?fx.ShardLease { return (@as(*PostgresRunnerStorage, @ptrCast(@alignCast(context)))).lease(shard_id); }
    fn leasesAdapter(context: *anyopaque, allocator: std.mem.Allocator) anyerror!fx.RunnerLeaseBatch { return (@as(*PostgresRunnerStorage, @ptrCast(@alignCast(context)))).leases(allocator); }
    fn resetAdapter(context: *anyopaque) void { (@as(*PostgresRunnerStorage, @ptrCast(@alignCast(context)))).reset(); }
};

const runner_vtable: fx.RunnerStorage.VTable = .{
    .acquire = PostgresRunnerStorage.acquireAdapter,
    .refresh = PostgresRunnerStorage.refreshAdapter,
    .release = PostgresRunnerStorage.releaseAdapter,
    .release_all = PostgresRunnerStorage.releaseAllAdapter,
    .lease = PostgresRunnerStorage.leaseAdapter,
    .leases = PostgresRunnerStorage.leasesAdapter,
    .reset = PostgresRunnerStorage.resetAdapter,
};

pub const JournalConfig = struct {
    storage: Config = .{},
    workflow_id: fx.workflow.WorkflowId,
    execution_id: fx.workflow.ExecutionId,
    required_fence: ?Fence = null,
};

pub const AppendOutcome = struct {
    sequence: fx.workflow.JournalSequence,
    duplicate: bool = false,
};

pub const CheckpointRecord = struct {
    allocator: std.mem.Allocator,
    last_sequence: fx.workflow.JournalSequence,
    checkpoint_json: []const u8,
    published_at_ms: u64,

    pub fn deinit(self: *CheckpointRecord) void {
        self.allocator.free(self.checkpoint_json);
        self.* = undefined;
    }
};

pub const CompactionReport = struct {
    checkpoint_sequence: u64,
    deleted_events: usize,
};

pub const CompletedRetention = enum { keep_all, archive_then_compact, checkpoint_only };

pub const RetentionReport = struct {
    compacted: bool = false,
    archived: bool = false,
    checkpoint_sequence: u64 = 0,
    deleted_events: usize = 0,
};

pub const PostgresJournalStore = struct {
    allocator: std.mem.Allocator,
    pool: *postgres.Pool,
    config: JournalConfig,
    fault: CommitFault = .{},

    pub fn init(allocator: std.mem.Allocator, pool: *postgres.Pool, config: JournalConfig) !PostgresJournalStore {
        try config.storage.validate();
        return .{ .allocator = allocator, .pool = pool, .config = config };
    }

    pub fn asJournalStore(self: *PostgresJournalStore) fx.workflow.JournalStore {
        return .{ .context = self, .vtable = &journal_vtable };
    }

    pub fn append(self: *PostgresJournalStore, request: fx.workflow.JournalAppend) !fx.workflow.JournalSequence {
        const outcome = try self.appendInternal(request, false);
        return outcome.sequence;
    }

    /// Ambiguity-safe append used when a caller may have lost the commit reply.
    /// A retry with the same non-empty idempotency key returns the original
    /// sequence without writing a second accepted decision.
    pub fn appendIdempotent(self: *PostgresJournalStore, request: fx.workflow.JournalAppend) !AppendOutcome {
        if (request.event.idempotency_key.len == 0) return error.MissingIdempotencyKey;
        return self.appendInternal(request, true);
    }

    fn appendInternal(self: *PostgresJournalStore, request: fx.workflow.JournalAppend, ambiguity_safe: bool) !AppendOutcome {
        if (request.event.workflow_id != self.config.workflow_id or request.event.execution_id != self.config.execution_id) return error.WrongJournalStream;
        var tx = try self.pool.checkoutTransaction();
        defer tx.deinit();
        const streams = try tableName(self.allocator, self.config.storage, "journal_streams"); defer self.allocator.free(streams);
        const events = try tableName(self.allocator, self.config.storage, "journal_events"); defer self.allocator.free(events);
        const workflow = try u64Text(self.allocator, self.config.workflow_id); defer self.allocator.free(workflow);
        const execution = try u64Text(self.allocator, self.config.execution_id); defer self.allocator.free(execution);
        const ensure_sql = try std.fmt.allocPrint(self.allocator,
            "insert into {s}(workflow_id,execution_id,next_sequence,base_sequence) values($1::numeric,$2::numeric,1,0) on conflict(workflow_id,execution_id) do nothing",
            .{streams},
        ); defer self.allocator.free(ensure_sql);
        var ensured = try queryJournalAlloc(tx.session(), self.allocator, .{ .sql = ensure_sql, .binds = &.{ .{ .text = workflow }, .{ .text = execution } } });
        ensured.deinit(self.allocator);

        if (ambiguity_safe) {
            const duplicate_sql = try std.fmt.allocPrint(self.allocator,
                "select sequence::text from {s} where workflow_id=$1::numeric and execution_id=$2::numeric and idempotency_key=$3",
                .{events},
            ); defer self.allocator.free(duplicate_sql);
            var duplicate = try queryJournalAlloc(tx.session(), self.allocator, .{ .sql = duplicate_sql, .binds = &.{ .{ .text = workflow }, .{ .text = execution }, .{ .text = request.event.idempotency_key } } });
            defer duplicate.deinit(self.allocator);
            if (duplicate.rows.len != 0) {
                const sequence = try parseU64Field(duplicate.rows[0], 0);
                try tx.rollback();
                return .{ .sequence = sequence, .duplicate = true };
            }
        }

        const lock_sql = try std.fmt.allocPrint(self.allocator,
            "select next_sequence::text from {s} where workflow_id=$1::numeric and execution_id=$2::numeric for update",
            .{streams},
        ); defer self.allocator.free(lock_sql);
        var locked = try queryJournalAlloc(tx.session(), self.allocator, .{ .sql = lock_sql, .binds = &.{ .{ .text = workflow }, .{ .text = execution } } });
        defer locked.deinit(self.allocator);
        if (locked.rows.len != 1) return error.JournalStreamNotFound;
        const next_sequence = try parseU64Field(locked.rows[0], 0);
        if (request.expected_next_sequence) |expected| if (expected != next_sequence) return error.SequenceConflict;
        if (request.event.sequence != next_sequence) return error.SequenceConflict;
        try self.validateFence(tx.session());

        if (!ambiguity_safe and request.event.idempotency_key.len != 0) {
            const duplicate_sql = try std.fmt.allocPrint(self.allocator,
                "select 1::bigint from {s} where workflow_id=$1::numeric and execution_id=$2::numeric and idempotency_key=$3",
                .{events},
            ); defer self.allocator.free(duplicate_sql);
            var duplicate = try queryJournalAlloc(tx.session(), self.allocator, .{ .sql = duplicate_sql, .binds = &.{ .{ .text = workflow }, .{ .text = execution }, .{ .text = request.event.idempotency_key } } });
            defer duplicate.deinit(self.allocator);
            if (duplicate.rows.len != 0) return error.DuplicateEvent;
        }

        const event_json = try fx.workflow.formatWorkflowEventJson(self.allocator, request.event); defer self.allocator.free(event_json);
        const sequence = try u64Text(self.allocator, request.event.sequence); defer self.allocator.free(sequence);
        const insert_sql = try std.fmt.allocPrint(self.allocator,
            "insert into {s}(workflow_id,execution_id,sequence,idempotency_key,event_json,created_at_ms) values($1::numeric,$2::numeric,$3::numeric,$4,$5,floor(extract(epoch from current_timestamp)*1000))",
            .{events},
        ); defer self.allocator.free(insert_sql);
        var inserted = try queryJournalAlloc(tx.session(), self.allocator, .{ .sql = insert_sql, .binds = &.{ .{ .text = workflow }, .{ .text = execution }, .{ .text = sequence }, .{ .text = request.event.idempotency_key }, .{ .text = event_json } } });
        inserted.deinit(self.allocator);
        const advance_sql = try std.fmt.allocPrint(self.allocator,
            "update {s} set next_sequence=next_sequence+1 where workflow_id=$1::numeric and execution_id=$2::numeric",
            .{streams},
        ); defer self.allocator.free(advance_sql);
        var advanced = try queryJournalAlloc(tx.session(), self.allocator, .{ .sql = advance_sql, .binds = &.{ .{ .text = workflow }, .{ .text = execution } } });
        advanced.deinit(self.allocator);
        try self.commit(&tx);
        return .{ .sequence = request.event.sequence };
    }

    pub fn readAll(self: *PostgresJournalStore, allocator: std.mem.Allocator) !fx.workflow.JournalEventBatch {
        return self.readFromSequence(allocator, 1);
    }

    pub fn readFromSequence(self: *PostgresJournalStore, allocator: std.mem.Allocator, sequence_value: fx.workflow.JournalSequence) !fx.workflow.JournalEventBatch {
        var lease_handle = try self.pool.checkout(); defer lease_handle.deinit();
        const events = try tableName(self.allocator, self.config.storage, "journal_events"); defer self.allocator.free(events);
        const workflow = try u64Text(self.allocator, self.config.workflow_id); defer self.allocator.free(workflow);
        const execution = try u64Text(self.allocator, self.config.execution_id); defer self.allocator.free(execution);
        const sequence = try u64Text(self.allocator, sequence_value); defer self.allocator.free(sequence);
        const sql = try std.fmt.allocPrint(self.allocator,
            "select event_json from {s} where workflow_id=$1::numeric and execution_id=$2::numeric and sequence >= $3::numeric order by sequence",
            .{events},
        ); defer self.allocator.free(sql);
        var result = try lease_handle.queryAlloc(self.allocator, .{ .sql = sql, .binds = &.{ .{ .text = workflow }, .{ .text = execution }, .{ .text = sequence } } }); defer result.deinit(self.allocator);
        const output = try allocator.alloc(fx.workflow.WorkflowEvent, result.rows.len);
        var initialized: usize = 0;
        errdefer {
            for (output[0..initialized]) |event| fx.workflow.deinitWorkflowEventStrings(allocator, event);
            allocator.free(output);
        }
        for (result.rows, 0..) |row, index| {
            output[index] = try fx.workflow.parseWorkflowEventJson(allocator, try textField(row, 0));
            initialized += 1;
        }
        return .{ .allocator = allocator, .events = output };
    }

    pub fn latestState(self: *PostgresJournalStore, allocator: std.mem.Allocator) !fx.workflow.WorkflowReplayState {
        var state = if (try self.latestCheckpoint(allocator)) |checkpoint_value| blk: {
            var checkpoint = checkpoint_value;
            defer checkpoint.deinit();
            break :blk try fx.workflow.parseWorkflowCheckpointJson(allocator, checkpoint.checkpoint_json);
        } else fx.workflow.WorkflowReplayState.init(allocator);
        errdefer state.deinit();
        var events = try self.readFromSequence(allocator, state.last_sequence + 1);
        defer events.deinit();
        for (events.events) |event| try state.apply(event);
        return state;
    }

    pub fn publishCheckpoint(self: *PostgresJournalStore, state: *const fx.workflow.WorkflowReplayState, published_at_ms: u64) !CheckpointRecord {
        if (state.workflow_id != self.config.workflow_id or state.execution_id != self.config.execution_id) return error.WrongJournalStream;
        var tx = try self.pool.checkoutTransaction(); defer tx.deinit();
        const streams = try tableName(self.allocator, self.config.storage, "journal_streams"); defer self.allocator.free(streams);
        const checkpoints = try tableName(self.allocator, self.config.storage, "journal_checkpoints"); defer self.allocator.free(checkpoints);
        const workflow = try u64Text(self.allocator, self.config.workflow_id); defer self.allocator.free(workflow);
        const execution = try u64Text(self.allocator, self.config.execution_id); defer self.allocator.free(execution);
        const sequence = try u64Text(self.allocator, state.last_sequence); defer self.allocator.free(sequence);
        const published = try u64Text(self.allocator, published_at_ms); defer self.allocator.free(published);
        const lock_sql = try std.fmt.allocPrint(self.allocator, "select next_sequence::text from {s} where workflow_id=$1::numeric and execution_id=$2::numeric for update", .{streams}); defer self.allocator.free(lock_sql);
        var locked = try tx.queryAlloc(self.allocator, .{ .sql = lock_sql, .binds = &.{ .{ .text = workflow }, .{ .text = execution } } }); defer locked.deinit(self.allocator);
        if (locked.rows.len != 1 or state.last_sequence >= try parseU64Field(locked.rows[0], 0)) return error.InvalidCheckpointSequence;
        try self.validateFence(tx.session());
        const json = try fx.workflow.formatWorkflowCheckpointJson(self.allocator, state); defer self.allocator.free(json);
        const sql = try std.fmt.allocPrint(self.allocator,
            "insert into {s}(workflow_id,execution_id,last_sequence,checkpoint_json,published_at_ms) values($1::numeric,$2::numeric,$3::numeric,$4,$5::numeric) " ++
                "on conflict(workflow_id,execution_id,last_sequence) do update set checkpoint_json=excluded.checkpoint_json,published_at_ms=excluded.published_at_ms",
            .{checkpoints},
        ); defer self.allocator.free(sql);
        var result = try tx.queryAlloc(self.allocator, .{ .sql = sql, .binds = &.{ .{ .text = workflow }, .{ .text = execution }, .{ .text = sequence }, .{ .text = json }, .{ .text = published } } }); result.deinit(self.allocator);
        try self.commit(&tx);
        return .{ .allocator = self.allocator, .last_sequence = state.last_sequence, .checkpoint_json = try self.allocator.dupe(u8, json), .published_at_ms = published_at_ms };
    }

    pub fn latestCheckpoint(self: *PostgresJournalStore, allocator: std.mem.Allocator) !?CheckpointRecord {
        var lease_handle = try self.pool.checkout(); defer lease_handle.deinit();
        const checkpoints = try tableName(self.allocator, self.config.storage, "journal_checkpoints"); defer self.allocator.free(checkpoints);
        const workflow = try u64Text(self.allocator, self.config.workflow_id); defer self.allocator.free(workflow);
        const execution = try u64Text(self.allocator, self.config.execution_id); defer self.allocator.free(execution);
        const sql = try std.fmt.allocPrint(self.allocator,
            "select last_sequence::text,checkpoint_json,published_at_ms::text from {s} where workflow_id=$1::numeric and execution_id=$2::numeric order by last_sequence desc limit 1",
            .{checkpoints},
        ); defer self.allocator.free(sql);
        var result = try lease_handle.queryAlloc(self.allocator, .{ .sql = sql, .binds = &.{ .{ .text = workflow }, .{ .text = execution } } }); defer result.deinit(self.allocator);
        if (result.rows.len == 0) return null;
        return .{ .allocator = allocator, .last_sequence = try parseU64Field(result.rows[0], 0), .checkpoint_json = try allocator.dupe(u8, try textField(result.rows[0], 1)), .published_at_ms = try parseU64Field(result.rows[0], 2) };
    }

    pub fn compactThroughCheckpoint(self: *PostgresJournalStore, checkpoint_sequence: u64) !CompactionReport {
        var tx = try self.pool.checkoutTransaction(); defer tx.deinit();
        const streams = try tableName(self.allocator, self.config.storage, "journal_streams"); defer self.allocator.free(streams);
        const events = try tableName(self.allocator, self.config.storage, "journal_events"); defer self.allocator.free(events);
        const checkpoints = try tableName(self.allocator, self.config.storage, "journal_checkpoints"); defer self.allocator.free(checkpoints);
        const workflow = try u64Text(self.allocator, self.config.workflow_id); defer self.allocator.free(workflow);
        const execution = try u64Text(self.allocator, self.config.execution_id); defer self.allocator.free(execution);
        const sequence = try u64Text(self.allocator, checkpoint_sequence); defer self.allocator.free(sequence);
        const verify_sql = try std.fmt.allocPrint(self.allocator, "select 1::bigint from {s} where workflow_id=$1::numeric and execution_id=$2::numeric and last_sequence=$3::numeric for update", .{checkpoints}); defer self.allocator.free(verify_sql);
        var verified = try tx.queryAlloc(self.allocator, .{ .sql = verify_sql, .binds = &.{ .{ .text = workflow }, .{ .text = execution }, .{ .text = sequence } } }); defer verified.deinit(self.allocator);
        if (verified.rows.len != 1) return error.CheckpointNotFound;
        try self.validateFence(tx.session());
        const delete_sql = try std.fmt.allocPrint(self.allocator, "delete from {s} where workflow_id=$1::numeric and execution_id=$2::numeric and sequence <= $3::numeric returning sequence", .{events}); defer self.allocator.free(delete_sql);
        var deleted = try tx.queryAlloc(self.allocator, .{ .sql = delete_sql, .binds = &.{ .{ .text = workflow }, .{ .text = execution }, .{ .text = sequence } } }); defer deleted.deinit(self.allocator);
        const update_sql = try std.fmt.allocPrint(self.allocator, "update {s} set base_sequence=greatest(base_sequence,$3::numeric) where workflow_id=$1::numeric and execution_id=$2::numeric", .{streams}); defer self.allocator.free(update_sql);
        var updated = try tx.queryAlloc(self.allocator, .{ .sql = update_sql, .binds = &.{ .{ .text = workflow }, .{ .text = execution }, .{ .text = sequence } } }); updated.deinit(self.allocator);
        const count = deleted.rows.len;
        try self.commit(&tx);
        return .{ .checkpoint_sequence = checkpoint_sequence, .deleted_events = count };
    }

    pub fn applyCompletedRetention(self: *PostgresJournalStore, policy: CompletedRetention, now_ms: u64) !RetentionReport {
        if (policy == .keep_all) return .{};
        var state = try self.latestState(self.allocator);
        defer state.deinit();
        if (!fx.workflow.workflowStatusIsTerminal(state.workflow_status)) return error.WorkflowNotCompleted;
        var checkpoint = try self.publishCheckpoint(&state, now_ms);
        defer checkpoint.deinit();
        const compacted = if (policy == .archive_then_compact)
            try self.archiveAndCompact(checkpoint.last_sequence, now_ms)
        else
            try self.compactThroughCheckpoint(checkpoint.last_sequence);
        return .{
            .compacted = true,
            .archived = policy == .archive_then_compact,
            .checkpoint_sequence = checkpoint.last_sequence,
            .deleted_events = compacted.deleted_events,
        };
    }

    fn archiveAndCompact(self: *PostgresJournalStore, checkpoint_sequence: u64, now_ms: u64) !CompactionReport {
        var tx = try self.pool.checkoutTransaction(); defer tx.deinit();
        const streams = try tableName(self.allocator, self.config.storage, "journal_streams"); defer self.allocator.free(streams);
        const events = try tableName(self.allocator, self.config.storage, "journal_events"); defer self.allocator.free(events);
        const checkpoints = try tableName(self.allocator, self.config.storage, "journal_checkpoints"); defer self.allocator.free(checkpoints);
        const archives = try tableName(self.allocator, self.config.storage, "journal_archives"); defer self.allocator.free(archives);
        const workflow = try u64Text(self.allocator, self.config.workflow_id); defer self.allocator.free(workflow);
        const execution = try u64Text(self.allocator, self.config.execution_id); defer self.allocator.free(execution);
        const last = try u64Text(self.allocator, checkpoint_sequence); defer self.allocator.free(last);
        const now = try u64Text(self.allocator, now_ms); defer self.allocator.free(now);
        const verify_sql = try std.fmt.allocPrint(self.allocator, "select 1::bigint from {s} where workflow_id=$1::numeric and execution_id=$2::numeric and last_sequence=$3::numeric for update", .{checkpoints}); defer self.allocator.free(verify_sql);
        var verified = try tx.queryAlloc(self.allocator, .{ .sql = verify_sql, .binds = &.{ .{ .text = workflow }, .{ .text = execution }, .{ .text = last } } }); defer verified.deinit(self.allocator);
        if (verified.rows.len != 1) return error.CheckpointNotFound;
        try self.validateFence(tx.session());
        const event_sql = try std.fmt.allocPrint(self.allocator,
            "select sequence::text,event_json from {s} where workflow_id=$1::numeric and execution_id=$2::numeric and sequence <= $3::numeric order by sequence for update",
            .{events},
        ); defer self.allocator.free(event_sql);
        var rows = try tx.queryAlloc(self.allocator, .{ .sql = event_sql, .binds = &.{ .{ .text = workflow }, .{ .text = execution }, .{ .text = last } } }); defer rows.deinit(self.allocator);
        if (rows.rows.len == 0) {
            try tx.rollback();
            return .{ .checkpoint_sequence = checkpoint_sequence, .deleted_events = 0 };
        }
        var jsonl: std.ArrayList(u8) = .empty; defer jsonl.deinit(self.allocator);
        for (rows.rows, 0..) |row, index| {
            if (index != 0) try jsonl.append(self.allocator, '\n');
            try jsonl.appendSlice(self.allocator, try textField(row, 1));
        }
        const first = try u64Text(self.allocator, try parseU64Field(rows.rows[0], 0)); defer self.allocator.free(first);
        const count = try u64Text(self.allocator, rows.rows.len); defer self.allocator.free(count);
        const archive_sql = try std.fmt.allocPrint(self.allocator,
            "insert into {s}(workflow_id,execution_id,first_sequence,last_sequence,event_count,archive_jsonl,archived_at_ms) " ++
                "values($1::numeric,$2::numeric,$3::numeric,$4::numeric,$5::bigint,$6,$7::numeric) on conflict do nothing",
            .{archives},
        ); defer self.allocator.free(archive_sql);
        var archived = try tx.queryAlloc(self.allocator, .{ .sql = archive_sql, .binds = &.{ .{ .text = workflow }, .{ .text = execution }, .{ .text = first }, .{ .text = last }, .{ .text = count }, .{ .text = jsonl.items }, .{ .text = now } } }); archived.deinit(self.allocator);
        const delete_sql = try std.fmt.allocPrint(self.allocator, "delete from {s} where workflow_id=$1::numeric and execution_id=$2::numeric and sequence <= $3::numeric", .{events}); defer self.allocator.free(delete_sql);
        var deleted = try tx.queryAlloc(self.allocator, .{ .sql = delete_sql, .binds = &.{ .{ .text = workflow }, .{ .text = execution }, .{ .text = last } } }); deleted.deinit(self.allocator);
        const update_sql = try std.fmt.allocPrint(self.allocator, "update {s} set base_sequence=greatest(base_sequence,$3::numeric) where workflow_id=$1::numeric and execution_id=$2::numeric", .{streams}); defer self.allocator.free(update_sql);
        var updated = try tx.queryAlloc(self.allocator, .{ .sql = update_sql, .binds = &.{ .{ .text = workflow }, .{ .text = execution }, .{ .text = last } } }); updated.deinit(self.allocator);
        const deleted_count = rows.rows.len;
        try self.commit(&tx);
        return .{ .checkpoint_sequence = checkpoint_sequence, .deleted_events = deleted_count };
    }

    pub fn reset(self: *PostgresJournalStore) void {
        var lease_handle = self.pool.checkout() catch return; defer lease_handle.deinit();
        const streams = tableName(self.allocator, self.config.storage, "journal_streams") catch return; defer self.allocator.free(streams);
        const workflow = u64Text(self.allocator, self.config.workflow_id) catch return; defer self.allocator.free(workflow);
        const execution = u64Text(self.allocator, self.config.execution_id) catch return; defer self.allocator.free(execution);
        const sql = std.fmt.allocPrint(self.allocator, "delete from {s} where workflow_id=$1::numeric and execution_id=$2::numeric", .{streams}) catch return; defer self.allocator.free(sql);
        var result = lease_handle.queryAlloc(self.allocator, .{ .sql = sql, .binds = &.{ .{ .text = workflow }, .{ .text = execution } } }) catch return; result.deinit(self.allocator);
    }

    fn validateFence(self: *PostgresJournalStore, session: *postgres.Session) !void {
        const fence = self.config.required_fence orelse return;
        const table = try tableName(self.allocator, self.config.storage, "runner_leases"); defer self.allocator.free(table);
        const shard = try u64Text(self.allocator, fence.shard_id); defer self.allocator.free(shard);
        const epoch = try u64Text(self.allocator, fence.epoch); defer self.allocator.free(epoch);
        const sql = try std.fmt.allocPrint(self.allocator,
            "select 1::bigint from {s} where shard_id=$1::numeric and epoch=$2::numeric and expires_at_ms > floor(extract(epoch from current_timestamp)*1000)",
            .{table},
        ); defer self.allocator.free(sql);
        var result = try session.queryAlloc(self.allocator, .{ .sql = sql, .binds = &.{ .{ .text = shard }, .{ .text = epoch } } }); defer result.deinit(self.allocator);
        if (result.rows.len != 1) return error.StaleLeaseFence;
    }

    fn commit(self: *PostgresJournalStore, tx: *postgres.Transaction) !void {
        try self.fault.hit(.before_commit);
        try tx.commit();
        try self.fault.hit(.after_commit);
    }

    fn appendAdapter(context: *anyopaque, request: fx.workflow.JournalAppend) anyerror!fx.workflow.JournalSequence { return (@as(*PostgresJournalStore, @ptrCast(@alignCast(context)))).append(request); }
    fn readAllAdapter(context: *anyopaque, allocator: std.mem.Allocator) anyerror!fx.workflow.JournalEventBatch { return (@as(*PostgresJournalStore, @ptrCast(@alignCast(context)))).readAll(allocator); }
    fn readFromAdapter(context: *anyopaque, allocator: std.mem.Allocator, sequence: fx.workflow.JournalSequence) anyerror!fx.workflow.JournalEventBatch { return (@as(*PostgresJournalStore, @ptrCast(@alignCast(context)))).readFromSequence(allocator, sequence); }
    fn latestStateAdapter(context: *anyopaque, allocator: std.mem.Allocator) anyerror!fx.workflow.WorkflowReplayState { return (@as(*PostgresJournalStore, @ptrCast(@alignCast(context)))).latestState(allocator); }
    fn resetAdapter(context: *anyopaque) void { (@as(*PostgresJournalStore, @ptrCast(@alignCast(context)))).reset(); }
};

const journal_vtable: fx.workflow.JournalStore.VTable = .{
    .append = PostgresJournalStore.appendAdapter,
    .read_all = PostgresJournalStore.readAllAdapter,
    .read_from_sequence = PostgresJournalStore.readFromAdapter,
    .latest_state = PostgresJournalStore.latestStateAdapter,
    .reset = PostgresJournalStore.resetAdapter,
};

pub const MessageConfig = struct {
    storage: Config = .{},
    visibility_timeout_ms: u64 = 30_000,

    pub fn validate(self: MessageConfig) !void {
        try self.storage.validate();
        if (self.visibility_timeout_ms == 0) return error.InvalidVisibilityTimeout;
    }
};

pub const PostgresMessageStorage = struct {
    allocator: std.mem.Allocator,
    pool: *postgres.Pool,
    config: MessageConfig,
    fault: CommitFault = .{},

    pub fn init(allocator: std.mem.Allocator, pool: *postgres.Pool, config: MessageConfig) !PostgresMessageStorage {
        try config.validate();
        return .{ .allocator = allocator, .pool = pool, .config = config };
    }

    pub fn asMessageStorage(self: *PostgresMessageStorage) fx.MessageStorage {
        return .{ .context = self, .vtable = &message_vtable };
    }

    pub fn submit(self: *PostgresMessageStorage, request: fx.MessageStorageSubmit) !fx.MessageSubmitResult {
        var tx = try self.pool.checkoutTransaction(); defer tx.deinit();
        try validateOptionalFence(self.allocator, tx.session(), self.config.storage, request.shard_id, request.lease_epoch);
        var envelope = try prepareEnvelopeAlloc(self.allocator, request.envelope);
        envelope.lease_epoch = request.lease_epoch orelse envelope.lease_epoch;
        defer fx.deinitMessageEnvelope(self.allocator, envelope);
        const record: fx.StoredMessageRecord = .{
            .shard_id = request.shard_id, .envelope = envelope, .status = .pending,
            .stored_at_ms = request.now_ms, .updated_at_ms = request.now_ms, .lease_epoch = envelope.lease_epoch,
        };
        const json = try fx.formatStoredMessageRecordJson(self.allocator, record); defer self.allocator.free(json);
        const messages = try tableName(self.allocator, self.config.storage, "messages"); defer self.allocator.free(messages);
        const message_id = try u64Text(self.allocator, envelope.id); defer self.allocator.free(message_id);
        const shard = try u64Text(self.allocator, request.shard_id); defer self.allocator.free(shard);
        const entity_id = try u64Text(self.allocator, envelope.address.id); defer self.allocator.free(entity_id);
        const correlation = if (envelope.correlation_id) |value| try u64Text(self.allocator, value) else null; defer if (correlation) |value| self.allocator.free(value);
        const visible = try u64Text(self.allocator, request.now_ms); defer self.allocator.free(visible);
        const stored = try u64Text(self.allocator, request.now_ms); defer self.allocator.free(stored);
        const lease_epoch = if (envelope.lease_epoch) |value| try u64Text(self.allocator, value) else null; defer if (lease_epoch) |value| self.allocator.free(value);
        const sql = try std.fmt.allocPrint(self.allocator,
            "insert into {s}(message_id,shard_id,kind,entity_type,entity_id,correlation_id,idempotency_key,status,attempt,visible_at_ms,lease_epoch,record_json,stored_at_ms,updated_at_ms) " ++
                "values($1::numeric,$2::numeric,$3,$4,$5::numeric,$6::numeric,$7,'pending',0,$8::numeric,$9::numeric,$10,$11::numeric,$11::numeric) " ++
                "on conflict(shard_id,kind,entity_type,entity_id,idempotency_key) do nothing returning message_id",
            .{messages},
        ); defer self.allocator.free(sql);
        var inserted = try tx.queryAlloc(self.allocator, .{ .sql = sql, .binds = &.{
            .{ .text = message_id }, .{ .text = shard }, .{ .text = @tagName(envelope.kind) }, .{ .text = envelope.address.entity_type.name }, .{ .text = entity_id },
            if (correlation) |value| .{ .text = value } else .null_value, .{ .text = envelope.idempotency_key }, .{ .text = visible },
            if (lease_epoch) |value| .{ .text = value } else .null_value, .{ .text = json }, .{ .text = stored },
        } }); defer inserted.deinit(self.allocator);
        if (inserted.rows.len == 0) {
            const existing = try self.findDuplicateInSession(tx.session(), request.shard_id, envelope);
            if (existing) |existing_envelope| {
                try tx.rollback();
                return .{ .envelope = existing_envelope, .duplicate = true };
            }
            return error.DuplicateMessage;
        }
        try self.commit(&tx);
        return .{ .envelope = try fx.cloneMessageEnvelope(self.allocator, envelope) };
    }

    pub fn claim(self: *PostgresMessageStorage, request: fx.MessageStorageClaim) !fx.MessageEnvelope {
        return self.claimById(request, self.config.visibility_timeout_ms);
    }

    pub fn claimById(self: *PostgresMessageStorage, request: fx.MessageStorageClaim, visibility_timeout_ms: u64) !fx.MessageEnvelope {
        if (visibility_timeout_ms == 0 or request.now_ms > std.math.maxInt(u64) - visibility_timeout_ms) return error.InvalidVisibilityTimeout;
        var tx = try self.pool.checkoutTransaction(); defer tx.deinit();
        try validateOptionalFence(self.allocator, tx.session(), self.config.storage, request.shard_id, request.lease_epoch);
        var record = try self.lockMessage(tx.session(), request.message_id) orelse return error.MessageNotFound;
        defer record.deinit(self.allocator);
        if (record.shard_id != request.shard_id or !messageUnprocessed(record.status)) return error.MessageNotFound;
        return self.completeClaim(&tx, &record, request.now_ms, request.lease_epoch, visibility_timeout_ms);
    }

    fn completeClaim(self: *PostgresMessageStorage, tx: *postgres.Transaction, mutable: *fx.StoredMessageRecord, now_ms: u64, lease_epoch: ?fx.ShardLeaseEpoch, visibility_timeout_ms: u64) !fx.MessageEnvelope {
        const messages = try tableName(self.allocator, self.config.storage, "messages"); defer self.allocator.free(messages);
        const message_id = try u64Text(self.allocator, mutable.envelope.id); defer self.allocator.free(message_id);
        const now = try u64Text(self.allocator, now_ms); defer self.allocator.free(now);
        const availability_sql = try std.fmt.allocPrint(self.allocator, "select 1::bigint from {s} where message_id=$1::numeric and visible_at_ms <= $2::numeric", .{messages}); defer self.allocator.free(availability_sql);
        var available = try tx.queryAlloc(self.allocator, .{ .sql = availability_sql, .binds = &.{ .{ .text = message_id }, .{ .text = now } } }); defer available.deinit(self.allocator);
        if (available.rows.len == 0) return error.MessageNotVisible;
        mutable.status = .claimed;
        mutable.envelope.attempt +|= 1;
        mutable.lease_epoch = lease_epoch orelse mutable.lease_epoch;
        mutable.envelope.lease_epoch = mutable.lease_epoch;
        mutable.updated_at_ms = now_ms;
        const json = try fx.formatStoredMessageRecordJson(self.allocator, mutable.*); defer self.allocator.free(json);
        const visible = try u64Text(self.allocator, now_ms + visibility_timeout_ms); defer self.allocator.free(visible);
        const epoch = if (mutable.lease_epoch) |value| try u64Text(self.allocator, value) else null; defer if (epoch) |value| self.allocator.free(value);
        const sql = try std.fmt.allocPrint(self.allocator,
            "update {s} set status='claimed',attempt=$2::bigint,visible_at_ms=$3::numeric,lease_epoch=$4::numeric,record_json=$5,updated_at_ms=$6::numeric where message_id=$1::numeric",
            .{messages},
        ); defer self.allocator.free(sql);
        var updated = try tx.queryAlloc(self.allocator, .{ .sql = sql, .binds = &.{
            .{ .text = message_id }, .{ .integer = @intCast(mutable.envelope.attempt) }, .{ .text = visible },
            if (epoch) |value| .{ .text = value } else .null_value, .{ .text = json }, .{ .text = now },
        } }); updated.deinit(self.allocator);
        const output = try fx.cloneMessageEnvelope(self.allocator, mutable.envelope);
        errdefer fx.deinitMessageEnvelope(self.allocator, output);
        try self.commit(tx);
        return output;
    }

    pub fn claimNextAvailable(self: *PostgresMessageStorage, shard_id: fx.ShardId, now_ms: u64, lease_epoch: ?fx.ShardLeaseEpoch) !fx.MessageEnvelope {
        var tx = try self.pool.checkoutTransaction(); defer tx.deinit();
        try validateOptionalFence(self.allocator, tx.session(), self.config.storage, shard_id, lease_epoch);
        const messages = try tableName(self.allocator, self.config.storage, "messages"); defer self.allocator.free(messages);
        const shard = try u64Text(self.allocator, shard_id); defer self.allocator.free(shard);
        const now = try u64Text(self.allocator, now_ms); defer self.allocator.free(now);
        const sql = try std.fmt.allocPrint(self.allocator,
            "select record_json from {s} where shard_id=$1::numeric and status in ('pending','claimed') and visible_at_ms <= $2::numeric order by stored_at_ms,message_id for update skip locked limit 1",
            .{messages},
        ); defer self.allocator.free(sql);
        var selected = try tx.queryAlloc(self.allocator, .{ .sql = sql, .binds = &.{ .{ .text = shard }, .{ .text = now } } }); defer selected.deinit(self.allocator);
        if (selected.rows.len == 0) return error.MessageNotFound;
        var record = try fx.parseStoredMessageRecordJson(self.allocator, try textField(selected.rows[0], 0)); defer record.deinit(self.allocator);
        return self.completeClaim(&tx, &record, now_ms, lease_epoch, self.config.visibility_timeout_ms);
    }

    pub fn ack(self: *PostgresMessageStorage, request: fx.MessageStorageAck) !void {
        var tx = try self.pool.checkoutTransaction(); defer tx.deinit();
        var record = try self.lockMessage(tx.session(), request.message_id) orelse return error.MessageNotFound;
        defer record.deinit(self.allocator);
        if (request.shard_id) |shard_id| if (record.shard_id != shard_id) return error.MessageNotFound;
        try validateOptionalFence(self.allocator, tx.session(), self.config.storage, record.shard_id, request.lease_epoch);
        record.status = .acknowledged;
        record.updated_at_ms = request.now_ms;
        record.lease_epoch = request.lease_epoch orelse record.lease_epoch;
        record.envelope.lease_epoch = record.lease_epoch;
        const json = try fx.formatStoredMessageRecordJson(self.allocator, record); defer self.allocator.free(json);
        try self.updateMessageRecord(tx.session(), record, json);
        try self.commit(&tx);
    }

    pub fn storeReply(self: *PostgresMessageStorage, request: fx.MessageStorageReply) !fx.MessageEnvelope {
        const correlation_id = request.envelope.correlation_id orelse return error.MissingRequest;
        var tx = try self.pool.checkoutTransaction(); defer tx.deinit();
        try validateOptionalFence(self.allocator, tx.session(), self.config.storage, request.shard_id, request.lease_epoch);
        const messages = try tableName(self.allocator, self.config.storage, "messages"); defer self.allocator.free(messages);
        const replies = try tableName(self.allocator, self.config.storage, "replies"); defer self.allocator.free(replies);
        const correlation = try u64Text(self.allocator, correlation_id); defer self.allocator.free(correlation);
        const request_sql = try std.fmt.allocPrint(self.allocator,
            "select record_json from {s} where correlation_id=$1::numeric and kind='request' for update",
            .{messages},
        ); defer self.allocator.free(request_sql);
        var request_result = try tx.queryAlloc(self.allocator, .{ .sql = request_sql, .binds = &.{.{ .text = correlation }} }); defer request_result.deinit(self.allocator);
        if (request_result.rows.len == 0) return error.MissingRequest;
        var request_record = try fx.parseStoredMessageRecordJson(self.allocator, try textField(request_result.rows[0], 0)); defer request_record.deinit(self.allocator);
        var envelope = try prepareEnvelopeAlloc(self.allocator, request.envelope);
        envelope.lease_epoch = request.lease_epoch orelse envelope.lease_epoch;
        defer fx.deinitMessageEnvelope(self.allocator, envelope);
        const reply_record: fx.StoredReplyRecord = .{ .shard_id = request.shard_id, .envelope = envelope, .stored_at_ms = request.now_ms, .lease_epoch = envelope.lease_epoch };
        const reply_json = try fx.formatStoredReplyRecordJson(self.allocator, reply_record); defer self.allocator.free(reply_json);
        const reply_id = try u64Text(self.allocator, envelope.id); defer self.allocator.free(reply_id);
        const shard = try u64Text(self.allocator, request.shard_id); defer self.allocator.free(shard);
        const stored = try u64Text(self.allocator, request.now_ms); defer self.allocator.free(stored);
        const epoch = if (envelope.lease_epoch) |value| try u64Text(self.allocator, value) else null; defer if (epoch) |value| self.allocator.free(value);
        const insert_sql = try std.fmt.allocPrint(self.allocator,
            "insert into {s}(correlation_id,shard_id,reply_id,lease_epoch,record_json,stored_at_ms) values($1::numeric,$2::numeric,$3::numeric,$4::numeric,$5,$6::numeric) on conflict(correlation_id) do nothing returning reply_id",
            .{replies},
        ); defer self.allocator.free(insert_sql);
        var inserted = try tx.queryAlloc(self.allocator, .{ .sql = insert_sql, .binds = &.{
            .{ .text = correlation }, .{ .text = shard }, .{ .text = reply_id }, if (epoch) |value| .{ .text = value } else .null_value, .{ .text = reply_json }, .{ .text = stored },
        } }); defer inserted.deinit(self.allocator);
        if (inserted.rows.len == 0) return error.DuplicateReply;
        request_record.status = .replied;
        request_record.updated_at_ms = request.now_ms;
        const request_json = try fx.formatStoredMessageRecordJson(self.allocator, request_record); defer self.allocator.free(request_json);
        try self.updateMessageRecord(tx.session(), request_record, request_json);
        const output = try fx.cloneMessageEnvelope(self.allocator, envelope); errdefer fx.deinitMessageEnvelope(self.allocator, output);
        try self.commit(&tx);
        return output;
    }

    pub fn reply(self: *PostgresMessageStorage, correlation_id: fx.MessageCorrelationId, allocator: std.mem.Allocator) !?fx.MessageEnvelope {
        var lease_handle = try self.pool.checkout(); defer lease_handle.deinit();
        const replies = try tableName(self.allocator, self.config.storage, "replies"); defer self.allocator.free(replies);
        const correlation = try u64Text(self.allocator, correlation_id); defer self.allocator.free(correlation);
        const sql = try std.fmt.allocPrint(self.allocator, "select record_json from {s} where correlation_id=$1::numeric", .{replies}); defer self.allocator.free(sql);
        var result = try lease_handle.queryAlloc(self.allocator, .{ .sql = sql, .binds = &.{.{ .text = correlation }} }); defer result.deinit(self.allocator);
        if (result.rows.len == 0) return null;
        const record = try fx.parseStoredReplyRecordJson(allocator, try textField(result.rows[0], 0));
        return record.envelope;
    }

    pub fn unprocessedByShard(self: *PostgresMessageStorage, shard_id: fx.ShardId, allocator: std.mem.Allocator) !fx.MessageRecordBatch {
        var lease_handle = try self.pool.checkout(); defer lease_handle.deinit();
        const messages = try tableName(self.allocator, self.config.storage, "messages"); defer self.allocator.free(messages);
        const shard = try u64Text(self.allocator, shard_id); defer self.allocator.free(shard);
        const sql = try std.fmt.allocPrint(self.allocator, "select record_json from {s} where shard_id=$1::numeric and status in ('pending','claimed') order by stored_at_ms,message_id", .{messages}); defer self.allocator.free(sql);
        var result = try lease_handle.queryAlloc(self.allocator, .{ .sql = sql, .binds = &.{.{ .text = shard }} }); defer result.deinit(self.allocator);
        const records = try allocator.alloc(fx.StoredMessageRecord, result.rows.len);
        var initialized: usize = 0;
        errdefer { for (records[0..initialized]) |*record| record.deinit(allocator); allocator.free(records); }
        for (result.rows, 0..) |row, index| { records[index] = try fx.parseStoredMessageRecordJson(allocator, try textField(row, 0)); initialized += 1; }
        return .{ .allocator = allocator, .records = records };
    }

    pub fn unprocessedById(self: *PostgresMessageStorage, message_id_value: fx.MessageId, allocator: std.mem.Allocator) !?fx.StoredMessageRecord {
        var lease_handle = try self.pool.checkout(); defer lease_handle.deinit();
        const messages = try tableName(self.allocator, self.config.storage, "messages"); defer self.allocator.free(messages);
        const message_id = try u64Text(self.allocator, message_id_value); defer self.allocator.free(message_id);
        const sql = try std.fmt.allocPrint(self.allocator, "select record_json from {s} where message_id=$1::numeric and status in ('pending','claimed')", .{messages}); defer self.allocator.free(sql);
        var result = try lease_handle.queryAlloc(self.allocator, .{ .sql = sql, .binds = &.{.{ .text = message_id }} }); defer result.deinit(self.allocator);
        if (result.rows.len == 0) return null;
        return try fx.parseStoredMessageRecordJson(allocator, try textField(result.rows[0], 0));
    }

    pub fn reset(self: *PostgresMessageStorage) void {
        var lease_handle = self.pool.checkout() catch return; defer lease_handle.deinit();
        const messages = tableName(self.allocator, self.config.storage, "messages") catch return; defer self.allocator.free(messages);
        const replies = tableName(self.allocator, self.config.storage, "replies") catch return; defer self.allocator.free(replies);
        const sql = std.fmt.allocPrint(self.allocator, "delete from {s}; delete from {s}", .{ replies, messages }) catch return; defer self.allocator.free(sql);
        var result = lease_handle.session().executeTrustedAlloc(self.allocator, sql) catch return; result.deinit(self.allocator);
    }

    fn lockMessage(self: *PostgresMessageStorage, session: *postgres.Session, message_id_value: fx.MessageId) !?fx.StoredMessageRecord {
        const messages = try tableName(self.allocator, self.config.storage, "messages"); defer self.allocator.free(messages);
        const message_id = try u64Text(self.allocator, message_id_value); defer self.allocator.free(message_id);
        const sql = try std.fmt.allocPrint(self.allocator, "select record_json from {s} where message_id=$1::numeric for update", .{messages}); defer self.allocator.free(sql);
        var result = try session.queryAlloc(self.allocator, .{ .sql = sql, .binds = &.{.{ .text = message_id }} }); defer result.deinit(self.allocator);
        if (result.rows.len == 0) return null;
        return try fx.parseStoredMessageRecordJson(self.allocator, try textField(result.rows[0], 0));
    }

    fn findDuplicateInSession(self: *PostgresMessageStorage, session: *postgres.Session, shard_id: fx.ShardId, envelope: fx.MessageEnvelope) !?fx.MessageEnvelope {
        const messages = try tableName(self.allocator, self.config.storage, "messages"); defer self.allocator.free(messages);
        const shard = try u64Text(self.allocator, shard_id); defer self.allocator.free(shard);
        const entity_id = try u64Text(self.allocator, envelope.address.id); defer self.allocator.free(entity_id);
        const sql = try std.fmt.allocPrint(self.allocator,
            "select record_json from {s} where shard_id=$1::numeric and kind=$2 and entity_type=$3 and entity_id=$4::numeric and idempotency_key=$5",
            .{messages},
        ); defer self.allocator.free(sql);
        var result = try session.queryAlloc(self.allocator, .{ .sql = sql, .binds = &.{ .{ .text = shard }, .{ .text = @tagName(envelope.kind) }, .{ .text = envelope.address.entity_type.name }, .{ .text = entity_id }, .{ .text = envelope.idempotency_key } } }); defer result.deinit(self.allocator);
        if (result.rows.len == 0) return null;
        const record = try fx.parseStoredMessageRecordJson(self.allocator, try textField(result.rows[0], 0));
        return record.envelope;
    }

    fn updateMessageRecord(self: *PostgresMessageStorage, session: *postgres.Session, record: fx.StoredMessageRecord, json: []const u8) !void {
        const messages = try tableName(self.allocator, self.config.storage, "messages"); defer self.allocator.free(messages);
        const message_id = try u64Text(self.allocator, record.envelope.id); defer self.allocator.free(message_id);
        const updated = try u64Text(self.allocator, record.updated_at_ms); defer self.allocator.free(updated);
        const epoch = if (record.lease_epoch) |value| try u64Text(self.allocator, value) else null; defer if (epoch) |value| self.allocator.free(value);
        const sql = try std.fmt.allocPrint(self.allocator,
            "update {s} set status=$2,attempt=$3::bigint,lease_epoch=$4::numeric,record_json=$5,updated_at_ms=$6::numeric where message_id=$1::numeric",
            .{messages},
        ); defer self.allocator.free(sql);
        var result = try session.queryAlloc(self.allocator, .{ .sql = sql, .binds = &.{
            .{ .text = message_id }, .{ .text = @tagName(record.status) }, .{ .integer = @intCast(record.envelope.attempt) },
            if (epoch) |value| .{ .text = value } else .null_value, .{ .text = json }, .{ .text = updated },
        } }); result.deinit(self.allocator);
    }

    fn commit(self: *PostgresMessageStorage, tx: *postgres.Transaction) !void {
        try self.fault.hit(.before_commit);
        try tx.commit();
        try self.fault.hit(.after_commit);
    }

    fn submitAdapter(context: *anyopaque, request: fx.MessageStorageSubmit) anyerror!fx.MessageSubmitResult { return (@as(*PostgresMessageStorage, @ptrCast(@alignCast(context)))).submit(request); }
    fn claimAdapter(context: *anyopaque, request: fx.MessageStorageClaim) anyerror!fx.MessageEnvelope { return (@as(*PostgresMessageStorage, @ptrCast(@alignCast(context)))).claim(request); }
    fn ackAdapter(context: *anyopaque, request: fx.MessageStorageAck) anyerror!void { return (@as(*PostgresMessageStorage, @ptrCast(@alignCast(context)))).ack(request); }
    fn storeReplyAdapter(context: *anyopaque, request: fx.MessageStorageReply) anyerror!fx.MessageEnvelope { return (@as(*PostgresMessageStorage, @ptrCast(@alignCast(context)))).storeReply(request); }
    fn replyAdapter(context: *anyopaque, correlation: fx.MessageCorrelationId, allocator: std.mem.Allocator) anyerror!?fx.MessageEnvelope { return (@as(*PostgresMessageStorage, @ptrCast(@alignCast(context)))).reply(correlation, allocator); }
    fn unprocessedByShardAdapter(context: *anyopaque, shard: fx.ShardId, allocator: std.mem.Allocator) anyerror!fx.MessageRecordBatch { return (@as(*PostgresMessageStorage, @ptrCast(@alignCast(context)))).unprocessedByShard(shard, allocator); }
    fn unprocessedByIdAdapter(context: *anyopaque, id: fx.MessageId, allocator: std.mem.Allocator) anyerror!?fx.StoredMessageRecord { return (@as(*PostgresMessageStorage, @ptrCast(@alignCast(context)))).unprocessedById(id, allocator); }
    fn resetAdapter(context: *anyopaque) void { (@as(*PostgresMessageStorage, @ptrCast(@alignCast(context)))).reset(); }
};

const message_vtable: fx.MessageStorage.VTable = .{
    .submit = PostgresMessageStorage.submitAdapter,
    .claim = PostgresMessageStorage.claimAdapter,
    .ack = PostgresMessageStorage.ackAdapter,
    .store_reply = PostgresMessageStorage.storeReplyAdapter,
    .reply = PostgresMessageStorage.replyAdapter,
    .unprocessed_by_shard = PostgresMessageStorage.unprocessedByShardAdapter,
    .unprocessed_by_id = PostgresMessageStorage.unprocessedByIdAdapter,
    .reset = PostgresMessageStorage.resetAdapter,
};

pub const OutboxEnqueue = zstd.Outbox.Enqueue;
pub const OutboxMessage = zstd.Outbox.Message;
pub const InboxRecord = zstd.Outbox.InboxRecord;
pub const InboxOutcome = zstd.Outbox.InboxOutcome;

pub const ReliabilityConfig = struct {
    storage: Config = .{},
    outbox_visibility_timeout_ms: u64 = 30_000,

    pub fn validate(self: ReliabilityConfig) !void {
        try self.storage.validate();
        if (self.outbox_visibility_timeout_ms == 0) return error.InvalidVisibilityTimeout;
    }
};

pub const PostgresReliabilityStore = struct {
    allocator: std.mem.Allocator,
    pool: *postgres.Pool,
    config: ReliabilityConfig,
    fault: CommitFault = .{},

    pub fn init(allocator: std.mem.Allocator, pool: *postgres.Pool, config: ReliabilityConfig) !PostgresReliabilityStore {
        try config.validate();
        return .{ .allocator = allocator, .pool = pool, .config = config };
    }

    pub fn asOutboxStore(self: *PostgresReliabilityStore) zstd.Outbox.Store {
        return .{ .pointer = self, .begin_fn = beginOutboxAdapter, .claim_fn = claimOutboxAdapter, .delivered_fn = deliveredOutboxAdapter };
    }

    pub fn begin(self: *PostgresReliabilityStore) !UnitOfWork {
        return .{ .store = self, .transaction = try self.pool.checkoutTransaction() };
    }

    pub fn enqueue(self: *PostgresReliabilityStore, request: OutboxEnqueue) !OutboxMessage {
        var unit = try self.begin(); defer unit.deinit();
        var message = try unit.enqueue(request);
        errdefer message.deinit();
        try unit.commit();
        return message;
    }

    pub fn recordInbox(self: *PostgresReliabilityStore, request: InboxRecord) !InboxOutcome {
        var unit = try self.begin(); defer unit.deinit();
        const outcome = try unit.recordInbox(request);
        try unit.commit();
        return outcome;
    }

    pub fn claimNext(self: *PostgresReliabilityStore, now_ms: u64) !OutboxMessage {
        if (now_ms > std.math.maxInt(u64) - self.config.outbox_visibility_timeout_ms) return error.InvalidVisibilityTimeout;
        var tx = try self.pool.checkoutTransaction(); defer tx.deinit();
        const table = try tableName(self.allocator, self.config.storage, "outbox"); defer self.allocator.free(table);
        const now = try u64Text(self.allocator, now_ms); defer self.allocator.free(now);
        const select_sql = try std.fmt.allocPrint(self.allocator,
            "select id::text,topic,idempotency_key,payload,attempt::text,visible_at_ms::text from {s} " ++
                "where status in ('pending','claimed') and visible_at_ms <= $1::numeric order by created_at_ms,id for update skip locked limit 1",
            .{table},
        ); defer self.allocator.free(select_sql);
        var selected = try tx.queryAlloc(self.allocator, .{ .sql = select_sql, .binds = &.{.{ .text = now }} }); defer selected.deinit(self.allocator);
        if (selected.rows.len == 0) return error.OutboxEmpty;
        var message = try outboxFromRow(self.allocator, selected.rows[0]); errdefer message.deinit();
        message.attempt +|= 1;
        message.visible_at_ms = now_ms + self.config.outbox_visibility_timeout_ms;
        const id = try u64Text(self.allocator, message.id); defer self.allocator.free(id);
        const visible = try u64Text(self.allocator, message.visible_at_ms); defer self.allocator.free(visible);
        const update_sql = try std.fmt.allocPrint(self.allocator,
            "update {s} set status='claimed',attempt=$2::bigint,visible_at_ms=$3::numeric,updated_at_ms=$4::numeric where id=$1::numeric",
            .{table},
        ); defer self.allocator.free(update_sql);
        var updated = try tx.queryAlloc(self.allocator, .{ .sql = update_sql, .binds = &.{ .{ .text = id }, .{ .integer = @intCast(message.attempt) }, .{ .text = visible }, .{ .text = now } } }); updated.deinit(self.allocator);
        try self.commit(&tx);
        return message;
    }

    pub fn markDelivered(self: *PostgresReliabilityStore, id_value: u64, now_ms: u64) !void {
        var tx = try self.pool.checkoutTransaction(); defer tx.deinit();
        const table = try tableName(self.allocator, self.config.storage, "outbox"); defer self.allocator.free(table);
        const id = try u64Text(self.allocator, id_value); defer self.allocator.free(id);
        const now = try u64Text(self.allocator, now_ms); defer self.allocator.free(now);
        const sql = try std.fmt.allocPrint(self.allocator, "update {s} set status='delivered',updated_at_ms=$2::numeric where id=$1::numeric returning id", .{table}); defer self.allocator.free(sql);
        var result = try tx.queryAlloc(self.allocator, .{ .sql = sql, .binds = &.{ .{ .text = id }, .{ .text = now } } }); defer result.deinit(self.allocator);
        if (result.rows.len == 0) return error.OutboxMessageNotFound;
        try self.commit(&tx);
    }

    fn enqueueInSession(self: *PostgresReliabilityStore, session: *postgres.Session, request: OutboxEnqueue) !OutboxMessage {
        if (request.topic.len == 0 or request.idempotency_key.len == 0) return error.InvalidOutboxMessage;
        const id_value = request.id orelse outboxId(request.idempotency_key);
        const table = try tableName(self.allocator, self.config.storage, "outbox"); defer self.allocator.free(table);
        const id = try u64Text(self.allocator, id_value); defer self.allocator.free(id);
        const now = try u64Text(self.allocator, request.now_ms); defer self.allocator.free(now);
        const sql = try std.fmt.allocPrint(self.allocator,
            "insert into {s}(id,topic,idempotency_key,payload,status,attempt,visible_at_ms,created_at_ms,updated_at_ms) " ++
                "values($1::numeric,$2,$3,$4,'pending',0,$5::numeric,$5::numeric,$5::numeric) on conflict(idempotency_key) do nothing " ++
                "returning id::text,topic,idempotency_key,payload,attempt::text,visible_at_ms::text",
            .{table},
        ); defer self.allocator.free(sql);
        var inserted = try session.queryAlloc(self.allocator, .{ .sql = sql, .binds = &.{ .{ .text = id }, .{ .text = request.topic }, .{ .text = request.idempotency_key }, .{ .text = request.payload }, .{ .text = now } } }); defer inserted.deinit(self.allocator);
        if (inserted.rows.len != 0) return outboxFromRow(self.allocator, inserted.rows[0]);
        const lookup_sql = try std.fmt.allocPrint(self.allocator,
            "select id::text,topic,idempotency_key,payload,attempt::text,visible_at_ms::text from {s} where idempotency_key=$1",
            .{table},
        ); defer self.allocator.free(lookup_sql);
        var existing = try session.queryAlloc(self.allocator, .{ .sql = lookup_sql, .binds = &.{.{ .text = request.idempotency_key }} }); defer existing.deinit(self.allocator);
        if (existing.rows.len != 1) return error.OutboxConflict;
        var message = try outboxFromRow(self.allocator, existing.rows[0]); errdefer message.deinit();
        if (!std.mem.eql(u8, message.topic, request.topic) or !std.mem.eql(u8, message.payload, request.payload)) return error.IdempotencyPayloadMismatch;
        message.duplicate = true;
        return message;
    }

    fn recordInboxInSession(self: *PostgresReliabilityStore, session: *postgres.Session, request: InboxRecord) !InboxOutcome {
        if (request.consumer.len == 0 or request.idempotency_key.len == 0) return error.InvalidInboxRecord;
        const table = try tableName(self.allocator, self.config.storage, "inbox"); defer self.allocator.free(table);
        const hash = payloadHash(request.payload);
        const now = try u64Text(self.allocator, request.now_ms); defer self.allocator.free(now);
        const sql = try std.fmt.allocPrint(self.allocator,
            "insert into {s}(consumer,idempotency_key,payload_hash,received_at_ms) values($1,$2,$3,$4::numeric) on conflict(consumer,idempotency_key) do nothing returning payload_hash",
            .{table},
        ); defer self.allocator.free(sql);
        var inserted = try session.queryAlloc(self.allocator, .{ .sql = sql, .binds = &.{ .{ .text = request.consumer }, .{ .text = request.idempotency_key }, .{ .text = &hash }, .{ .text = now } } }); defer inserted.deinit(self.allocator);
        if (inserted.rows.len != 0) return .{};
        const lookup_sql = try std.fmt.allocPrint(self.allocator, "select payload_hash from {s} where consumer=$1 and idempotency_key=$2", .{table}); defer self.allocator.free(lookup_sql);
        var existing = try session.queryAlloc(self.allocator, .{ .sql = lookup_sql, .binds = &.{ .{ .text = request.consumer }, .{ .text = request.idempotency_key } } }); defer existing.deinit(self.allocator);
        if (existing.rows.len != 1) return error.InboxConflict;
        if (!std.mem.eql(u8, try textField(existing.rows[0], 0), &hash)) return error.IdempotencyPayloadMismatch;
        return .{ .duplicate = true };
    }

    fn commit(self: *PostgresReliabilityStore, tx: *postgres.Transaction) !void {
        try self.fault.hit(.before_commit);
        try tx.commit();
        try self.fault.hit(.after_commit);
    }

    fn beginOutboxAdapter(raw: *anyopaque, allocator: std.mem.Allocator) !zstd.Outbox.UnitOfWork {
        const self: *PostgresReliabilityStore = @ptrCast(@alignCast(raw));
        const box = try allocator.create(OutboxUnitBox); errdefer allocator.destroy(box);
        box.* = .{ .allocator = allocator, .inner = try self.begin() };
        return .{ .pointer = box, .execute_fn = OutboxUnitBox.execute, .enqueue_fn = OutboxUnitBox.enqueue, .inbox_fn = OutboxUnitBox.recordInbox, .commit_fn = OutboxUnitBox.commit, .rollback_fn = OutboxUnitBox.rollback, .deinit_fn = OutboxUnitBox.deinit };
    }
    fn claimOutboxAdapter(raw: *anyopaque, now_ms: u64) !OutboxMessage { return (@as(*PostgresReliabilityStore, @ptrCast(@alignCast(raw)))).claimNext(now_ms); }
    fn deliveredOutboxAdapter(raw: *anyopaque, id: u64, now_ms: u64) !void { return (@as(*PostgresReliabilityStore, @ptrCast(@alignCast(raw)))).markDelivered(id, now_ms); }
};

pub const UnitOfWork = struct {
    store: *PostgresReliabilityStore,
    transaction: postgres.Transaction,
    finished: bool = false,

    pub fn session(self: *UnitOfWork) *postgres.Session {
        return self.transaction.session();
    }

    pub fn enqueue(self: *UnitOfWork, request: OutboxEnqueue) !OutboxMessage {
        if (self.finished) return error.UnitOfWorkFinished;
        return self.store.enqueueInSession(self.session(), request);
    }

    pub fn recordInbox(self: *UnitOfWork, request: InboxRecord) !InboxOutcome {
        if (self.finished) return error.UnitOfWorkFinished;
        return self.store.recordInboxInSession(self.session(), request);
    }

    pub fn commit(self: *UnitOfWork) !void {
        if (self.finished) return;
        try self.store.commit(&self.transaction);
        self.finished = true;
    }

    pub fn rollback(self: *UnitOfWork) !void {
        if (self.finished) return;
        try self.transaction.rollback();
        self.finished = true;
    }

    pub fn deinit(self: *UnitOfWork) void {
        self.transaction.deinit();
        self.finished = true;
    }
};

const OutboxUnitBox = struct {
    allocator: std.mem.Allocator,
    inner: UnitOfWork,
    fn cast(raw: *anyopaque) *OutboxUnitBox { return @ptrCast(@alignCast(raw)); }
    fn execute(raw: *anyopaque, allocator: std.mem.Allocator, statement: Sql.Statement) !void { var result = try cast(raw).inner.session().queryAlloc(allocator, statement); result.deinit(allocator); }
    fn enqueue(raw: *anyopaque, request: zstd.Outbox.Enqueue) !zstd.Outbox.Message { return cast(raw).inner.enqueue(request); }
    fn recordInbox(raw: *anyopaque, request: zstd.Outbox.InboxRecord) !zstd.Outbox.InboxOutcome { return cast(raw).inner.recordInbox(request); }
    fn commit(raw: *anyopaque) !void { return cast(raw).inner.commit(); }
    fn rollback(raw: *anyopaque) !void { return cast(raw).inner.rollback(); }
    fn deinit(raw: *anyopaque) void { const self = cast(raw); self.inner.deinit(); const allocator = self.allocator; allocator.destroy(self); }
};

fn prepareEnvelopeAlloc(allocator: std.mem.Allocator, envelope_value: fx.MessageEnvelope) !fx.MessageEnvelope {
    var envelope = try fx.cloneMessageEnvelope(allocator, envelope_value);
    if (envelope.id == 0) {
        var correlation_buffer: [20]u8 = undefined;
        const key = if (envelope.idempotency_key.len != 0)
            envelope.idempotency_key
        else if (envelope.correlation_id) |correlation|
            std.fmt.bufPrint(&correlation_buffer, "{d}", .{correlation}) catch unreachable
        else
            "";
        envelope.id = fx.messageId(envelope.address, envelope.kind, key);
    }
    if (envelope.kind == .request and envelope.correlation_id == null) envelope.correlation_id = fx.messageCorrelationId(envelope.id);
    return envelope;
}

fn outboxId(idempotency_key: []const u8) u64 {
    return std.hash.Fnv1a_64.hash(idempotency_key);
}

fn payloadHash(payload: []const u8) [64]u8 {
    var digest: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(payload, &digest, .{});
    return std.fmt.bytesToHex(digest, .lower);
}

fn outboxFromRow(allocator: std.mem.Allocator, row: Sql.Row) !OutboxMessage {
    const topic = try allocator.dupe(u8, try textField(row, 1));
    errdefer allocator.free(topic);
    const key = try allocator.dupe(u8, try textField(row, 2));
    errdefer allocator.free(key);
    const payload = try allocator.dupe(u8, try textField(row, 3));
    errdefer allocator.free(payload);
    return .{
        .allocator = allocator,
        .id = try parseU64Field(row, 0),
        .topic = topic,
        .idempotency_key = key,
        .payload = payload,
        .attempt = try std.fmt.parseUnsigned(u32, try textField(row, 4), 10),
        .visible_at_ms = try parseU64Field(row, 5),
    };
}

fn messageUnprocessed(status: fx.MessageDeliveryStatus) bool {
    return status == .pending or status == .claimed;
}

fn validateOptionalFence(
    allocator: std.mem.Allocator,
    session: *postgres.Session,
    config: Config,
    shard_id: fx.ShardId,
    lease_epoch: ?fx.ShardLeaseEpoch,
) !void {
    const epoch_value = lease_epoch orelse return;
    const table = try tableName(allocator, config, "runner_leases"); defer allocator.free(table);
    const shard = try u64Text(allocator, shard_id); defer allocator.free(shard);
    const epoch = try u64Text(allocator, epoch_value); defer allocator.free(epoch);
    const sql = try std.fmt.allocPrint(allocator,
        "select 1::bigint from {s} where shard_id=$1::numeric and epoch=$2::numeric and expires_at_ms > floor(extract(epoch from current_timestamp)*1000)",
        .{table},
    ); defer allocator.free(sql);
    var result = try session.queryAlloc(allocator, .{ .sql = sql, .binds = &.{ .{ .text = shard }, .{ .text = epoch } } }); defer result.deinit(allocator);
    if (result.rows.len != 1) return error.StaleLeaseFence;
}

fn validIdentifier(value: []const u8) bool {
    if (value.len == 0 or !(std.ascii.isAlphabetic(value[0]) or value[0] == '_')) return false;
    for (value[1..]) |byte| if (!(std.ascii.isAlphanumeric(byte) or byte == '_')) return false;
    return true;
}

fn tableName(allocator: std.mem.Allocator, config: Config, suffix: []const u8) ![]u8 {
    try config.validate();
    return std.fmt.allocPrint(allocator, "{s}_{s}", .{ config.table_prefix, suffix });
}

fn u64Text(allocator: std.mem.Allocator, value: u64) ![]u8 {
    return std.fmt.allocPrint(allocator, "{d}", .{value});
}

fn textField(row: Sql.Row, index: usize) ![]const u8 {
    if (index >= row.fields.len) return error.MissingField;
    return switch (row.fields[index].value) { .text => |value| value, else => error.InvalidFieldType };
}

fn queryJournalAlloc(session: *postgres.Session, allocator: std.mem.Allocator, statement: Sql.Statement) !Sql.QueryResult {
    return switch (session.queryClassifiedAlloc(allocator, statement)) {
        .success => |result| result,
        .failure => |failure| switch (failure.class()) {
            .conflict => error.SequenceConflict,
            .timeout => error.StorageTimeout,
            .unavailable => error.StorageUnavailable,
            .unauthorized => error.StorageUnauthorized,
            .capacity => error.StorageCapacityExceeded,
            .canceled => error.StorageCanceled,
            .corrupt_data => error.StorageCorruptData,
            .unsupported => error.StorageUnsupported,
            .internal => error.StorageInternal,
        },
    };
}

fn parseU64Field(row: Sql.Row, index: usize) !u64 {
    return std.fmt.parseUnsigned(u64, try textField(row, index), 10);
}

fn leaseFromRow(shard_id: fx.ShardId, row: Sql.Row) !fx.ShardLease {
    return .{
        .shard_id = shard_id,
        .owner = .{ .machine_id = try parseU64Field(row, 0), .runner_id = try parseU64Field(row, 1) },
        .acquired_at_ms = try parseU64Field(row, 2),
        .refreshed_at_ms = try parseU64Field(row, 3),
        .expires_at_ms = try parseU64Field(row, 4),
        .epoch = try parseU64Field(row, 5),
        .version = try parseU64Field(row, 6),
    };
}

fn leaseFromRowWithShard(row: Sql.Row) !fx.ShardLease {
    return .{
        .shard_id = try parseU64Field(row, 0),
        .owner = .{ .machine_id = try parseU64Field(row, 1), .runner_id = try parseU64Field(row, 2) },
        .acquired_at_ms = try parseU64Field(row, 3),
        .refreshed_at_ms = try parseU64Field(row, 4),
        .expires_at_ms = try parseU64Field(row, 5),
        .epoch = try parseU64Field(row, 6),
        .version = try parseU64Field(row, 7),
    };
}

test "configuration rejects injectable table prefixes" {
    try std.testing.expectError(error.InvalidTablePrefix, (Config{ .table_prefix = "safe;drop table x" }).validate());
    try (Config{ .table_prefix = "tenant_42" }).validate();
}

test "capability is backed by restart conformance and bounded limitations" {
    try capability.validate();
    try message_storage_capability.validate();
    try lease_storage_capability.validate();
    try std.testing.expectEqual(zstd.Capability.Maturity.production_candidate, capability.maturity);
    try std.testing.expect(capability.limitations.len >= 2);
}
