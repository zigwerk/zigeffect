const std = @import("std");
const fx = @import("zigeffect");

const State = enum { idle, running, done };
const Event = enum { start, finish };
const Context = struct { attempts: u32 = 0 };
const Command = enum { begin };
const Def = fx.statechart.Definition(State, Event, Context, Command);
const Versions = fx.statechart.VersionDiff(Def);

fn allow(_: *const Context, _: *const Event) bool {
    return true;
}

fn begin(_: *Context, _: *const Event, sink: *Def.CommandSink) anyerror!void {
    try sink.emit(.begin);
}

fn definition(comptime options: struct {
    version: u32,
    description: []const u8 = "",
    running_description: []const u8 = "",
    guarded: bool = false,
    action: bool = false,
    finish_target: State = .done,
    max_commands: usize = 64,
}) Def {
    return Def.init(.{
        .id = "agent.versioned",
        .version = options.version,
        .initial = .idle,
        .description = options.description,
        .bounds = .{ .max_commands = options.max_commands },
        .states = &.{
            .{ .id = .idle },
            .{ .id = .running, .description = options.running_description },
            .{ .id = .done, .kind = .final },
        },
        .transitions = &.{
            .{
                .id = "start",
                .source = .idle,
                .event = .start,
                .target = .running,
                .guard = if (options.guarded) .{ .id = "allow", .evaluate = allow } else null,
                .actions = if (options.action) &.{.{ .id = "begin", .execute = begin }} else &.{},
            },
            .{ .id = "finish", .source = .running, .event = .finish, .target = options.finish_target },
        },
    });
}

test "statechart version diff classifies metadata-only changes" {
    const previous = definition(.{ .version = 1 });
    const next = definition(.{
        .version = 2,
        .description = "Human-visible workflow",
        .running_description = "Agent is working",
    });

    const report = Versions.compare(&previous, &next);
    try std.testing.expectEqual(fx.statechart.VersionCompatibility.metadata_only, report.compatibility);
    try std.testing.expectEqual(fx.statechart.DeploymentStrategy.new_instances_only, report.recommended_strategy);
    try std.testing.expect(report.change_count >= 2);
    try std.testing.expect(report.hasSubject(.machine, "agent.versioned"));
    try std.testing.expect(report.hasSubject(.state, "running"));
}

test "statechart version diff classifies executable behavior changes" {
    const previous = definition(.{ .version = 1 });
    const next = definition(.{ .version = 2, .guarded = true, .action = true, .finish_target = .running });

    const report = Versions.compare(&previous, &next);
    try std.testing.expectEqual(fx.statechart.VersionCompatibility.behavioral, report.compatibility);
    try std.testing.expectEqual(fx.statechart.DeploymentStrategy.drain_and_replace, report.recommended_strategy);
    try std.testing.expect(report.hasSubject(.transition, "start"));
    try std.testing.expect(report.hasSubject(.transition, "finish"));
    try std.testing.expect(report.riskAtLeast(.high));
}

test "statechart version diff fails closed for reduced bounds and version regression" {
    const previous = definition(.{ .version = 2, .max_commands = 64 });
    const reduced = definition(.{ .version = 3, .max_commands = 2 });
    const regressed = definition(.{ .version = 1 });

    const reduced_report = Versions.compare(&previous, &reduced);
    try std.testing.expectEqual(fx.statechart.VersionCompatibility.breaking, reduced_report.compatibility);
    try std.testing.expectEqual(fx.statechart.DeploymentStrategy.explicit_migration, reduced_report.recommended_strategy);
    try std.testing.expect(reduced_report.hasSubject(.bounds, "max_commands"));

    const regressed_report = Versions.compare(&previous, &regressed);
    try std.testing.expectEqual(fx.statechart.VersionCompatibility.breaking, regressed_report.compatibility);
    try std.testing.expect(regressed_report.hasKind(.version_regressed));
}

test "statechart version diff is deterministic and unchanged definitions stay unchanged" {
    const previous = definition(.{ .version = 4 });
    const next = definition(.{ .version = 5, .guarded = true });
    const left = Versions.compare(&previous, &next);
    const right = Versions.compare(&previous, &next);
    try std.testing.expectEqual(left.fingerprint, right.fingerprint);
    try std.testing.expectEqualSlices(Versions.Change, left.changes(), right.changes());

    const same = Versions.compare(&previous, &previous);
    try std.testing.expectEqual(fx.statechart.VersionCompatibility.unchanged, same.compatibility);
    try std.testing.expectEqual(@as(usize, 0), same.changes().len);
}
