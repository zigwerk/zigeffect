const std = @import("std");
const fx = @import("zigeffect");

const Snapshot = struct {
    definition_fingerprint: u64,
    instance_id: u64,
    revision: u64,
    value: u32,
};
const Registry = fx.statechart.MigrationRegistry(Snapshot);

fn migrateV1ToV2(snapshot: Snapshot) anyerror!Snapshot {
    var next = snapshot;
    next.definition_fingerprint = 22;
    next.value += 1;
    return next;
}

fn migrateV2ToV1(snapshot: Snapshot) anyerror!Snapshot {
    var previous = snapshot;
    previous.definition_fingerprint = 11;
    previous.value -= 1;
    return previous;
}

fn invalidMigration(snapshot: Snapshot) anyerror!Snapshot {
    var invalid = snapshot;
    invalid.instance_id += 1;
    invalid.definition_fingerprint = 33;
    return invalid;
}

test "statechart migration dry run validates identity and reverse availability" {
    var registry = Registry.init();
    try registry.register(.{
        .id = "review-v1-v2",
        .from_fingerprint = 11,
        .to_fingerprint = 22,
        .migrate_fn = migrateV1ToV2,
        .reverse_fn = migrateV2ToV1,
    });
    const original = Snapshot{ .definition_fingerprint = 11, .instance_id = 7, .revision = 9, .value = 4 };
    const preview = try registry.dryRun(original, 22);
    try std.testing.expectEqual(@as(u32, 5), preview.snapshot.value);
    try std.testing.expect(preview.reversible);
    try std.testing.expectEqual(@as(u32, 4), original.value);
    const reversed = try registry.reverse(preview.snapshot, 11);
    try std.testing.expectEqual(original, reversed);
}

test "statechart migration rejects duplicate paths stale sources and corrupt identity" {
    var registry = Registry.init();
    try registry.register(.{ .id = "valid", .from_fingerprint = 11, .to_fingerprint = 22, .migrate_fn = migrateV1ToV2 });
    try std.testing.expectError(error.DuplicateMigration, registry.register(.{ .id = "duplicate", .from_fingerprint = 11, .to_fingerprint = 22, .migrate_fn = migrateV1ToV2 }));
    try registry.register(.{ .id = "invalid", .from_fingerprint = 22, .to_fingerprint = 33, .migrate_fn = invalidMigration });
    try std.testing.expectError(error.MigrationNotFound, registry.dryRun(.{ .definition_fingerprint = 99, .instance_id = 7, .revision = 1, .value = 0 }, 22));
    try std.testing.expectError(error.InvalidMigratedSnapshot, registry.dryRun(.{ .definition_fingerprint = 22, .instance_id = 7, .revision = 1, .value = 0 }, 33));
}
