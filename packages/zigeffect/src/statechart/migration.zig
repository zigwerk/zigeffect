const std = @import("std");

pub const max_snapshot_migrations: usize = 64;

pub const MigrationError = error{
    InvalidMigration,
    DuplicateMigration,
    MigrationCapacityExceeded,
    MigrationNotFound,
    ReverseMigrationUnavailable,
    InvalidMigratedSnapshot,
};

pub fn MigrationRegistry(comptime Snapshot: type) type {
    comptime {
        if (!@hasField(Snapshot, "definition_fingerprint") or !@hasField(Snapshot, "instance_id") or !@hasField(Snapshot, "revision")) {
            @compileError("statechart migration snapshots require definition_fingerprint, instance_id, and revision fields");
        }
    }
    return struct {
        const Self = @This();

        pub const MigrateFn = *const fn (snapshot: Snapshot) anyerror!Snapshot;
        pub const Entry = struct {
            id: []const u8,
            from_fingerprint: u64,
            to_fingerprint: u64,
            migrate_fn: MigrateFn,
            reverse_fn: ?MigrateFn = null,
        };
        pub const Preview = struct {
            migration_id: []const u8,
            from_fingerprint: u64,
            to_fingerprint: u64,
            reversible: bool,
            snapshot: Snapshot,
        };

        entries: [max_snapshot_migrations]Entry = undefined,
        count: usize = 0,

        pub fn init() Self {
            return .{};
        }

        pub fn register(self: *Self, entry: Entry) MigrationError!void {
            if (!validIdentifier(entry.id) or entry.from_fingerprint == 0 or entry.to_fingerprint == 0 or entry.from_fingerprint == entry.to_fingerprint) return error.InvalidMigration;
            for (self.entries[0..self.count]) |existing| {
                if (std.mem.eql(u8, existing.id, entry.id) or
                    (existing.from_fingerprint == entry.from_fingerprint and existing.to_fingerprint == entry.to_fingerprint)) return error.DuplicateMigration;
            }
            if (self.count >= self.entries.len) return error.MigrationCapacityExceeded;
            self.entries[self.count] = entry;
            self.count += 1;
        }

        pub fn dryRun(self: *const Self, snapshot: Snapshot, target_fingerprint: u64) anyerror!Preview {
            const entry = self.find(snapshot.definition_fingerprint, target_fingerprint) orelse return error.MigrationNotFound;
            const migrated = try entry.migrate_fn(snapshot);
            try validateResult(snapshot, migrated, target_fingerprint);
            if (entry.reverse_fn) |reverse_fn| {
                const reversed = try reverse_fn(migrated);
                try validateResult(migrated, reversed, snapshot.definition_fingerprint);
                if (!std.meta.eql(snapshot, reversed)) return error.InvalidMigratedSnapshot;
            }
            return .{
                .migration_id = entry.id,
                .from_fingerprint = snapshot.definition_fingerprint,
                .to_fingerprint = target_fingerprint,
                .reversible = entry.reverse_fn != null,
                .snapshot = migrated,
            };
        }

        pub fn migrate(self: *const Self, snapshot: Snapshot, target_fingerprint: u64) anyerror!Snapshot {
            return (try self.dryRun(snapshot, target_fingerprint)).snapshot;
        }

        pub fn reverse(self: *const Self, snapshot: Snapshot, target_fingerprint: u64) anyerror!Snapshot {
            for (self.entries[0..self.count]) |entry| {
                if (entry.to_fingerprint != snapshot.definition_fingerprint or entry.from_fingerprint != target_fingerprint) continue;
                const reverse_fn = entry.reverse_fn orelse return error.ReverseMigrationUnavailable;
                const reversed = try reverse_fn(snapshot);
                try validateResult(snapshot, reversed, target_fingerprint);
                return reversed;
            }
            return error.MigrationNotFound;
        }

        fn find(self: *const Self, from_fingerprint: u64, to_fingerprint: u64) ?Entry {
            for (self.entries[0..self.count]) |entry| if (entry.from_fingerprint == from_fingerprint and entry.to_fingerprint == to_fingerprint) return entry;
            return null;
        }

        fn validateResult(before: Snapshot, after: Snapshot, expected_fingerprint: u64) MigrationError!void {
            if (after.definition_fingerprint != expected_fingerprint or
                after.instance_id != before.instance_id or
                after.revision != before.revision) return error.InvalidMigratedSnapshot;
        }
    };
}

fn validIdentifier(value: []const u8) bool {
    if (value.len == 0 or value.len > 128) return false;
    for (value) |byte| if (!(std.ascii.isAlphanumeric(byte) or byte == '-' or byte == '_' or byte == '.' or byte == ':')) return false;
    return true;
}
