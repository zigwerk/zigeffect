const std = @import("std");
const definition_mod = @import("definition.zig");

pub const max_statechart_mutation_points: usize = 512;
pub const MutationKind = enum { transition_removed, guard_inverted, target_redirected };

pub fn MutationCatalog(comptime DefinitionType: type) type {
    const State = DefinitionType.StateType;
    return struct {
        pub const Point = struct {
            id: u64,
            kind: MutationKind,
            transition_id: []const u8,
            redirect_target: ?State = null,
            source: definition_mod.SourceRef,
        };
        pub const Report = struct {
            storage: [max_statechart_mutation_points]Point = undefined,
            count: usize = 0,
            truncated: bool = false,
            fingerprint: u64 = 0,
            pub fn points(self: *const Report) []const Point {
                return self.storage[0..self.count];
            }
        };

        pub fn enumerate(definition: *const DefinitionType) Report {
            var report = Report{};
            for (definition.transitions) |transition| {
                add(&report, definition.id, .transition_removed, transition.id, null, transition.source_ref);
                if (transition.guard != null) add(&report, definition.id, .guard_inverted, transition.id, null, transition.guard.?.source);
                for (definition.states) |state| {
                    if (transition.target != null and state.id == transition.target.?) continue;
                    add(&report, definition.id, .target_redirected, transition.id, state.id, transition.source_ref);
                }
            }
            report.fingerprint = reportFingerprint(&report);
            return report;
        }

        fn add(report: *Report, machine_id: []const u8, kind: MutationKind, transition_id: []const u8, target: ?State, source: definition_mod.SourceRef) void {
            if (report.count >= report.storage.len) {
                report.truncated = true;
                return;
            }
            report.storage[report.count] = .{
                .id = pointId(machine_id, kind, transition_id, target, source, report.count),
                .kind = kind,
                .transition_id = transition_id,
                .redirect_target = target,
                .source = source,
            };
            report.count += 1;
        }

        fn pointId(machine_id: []const u8, kind: MutationKind, transition_id: []const u8, target: ?State, source: definition_mod.SourceRef, ordinal: usize) u64 {
            var hasher = std.hash.Fnv1a_64.init();
            hashText(&hasher, machine_id);
            hashInt(&hasher, @intFromEnum(kind));
            hashText(&hasher, transition_id);
            hashText(&hasher, if (target) |value| @tagName(value) else "");
            hashText(&hasher, source.file);
            hashInt(&hasher, source.line);
            hashInt(&hasher, source.column);
            hashInt(&hasher, ordinal);
            const value = hasher.final();
            return if (value == 0) 1 else value;
        }

        fn reportFingerprint(report: *const Report) u64 {
            var hasher = std.hash.Fnv1a_64.init();
            for (report.points()) |point| hashInt(&hasher, point.id);
            hashInt(&hasher, @intFromBool(report.truncated));
            const value = hasher.final();
            return if (value == 0) 1 else value;
        }
    };
}

fn hashText(hasher: *std.hash.Fnv1a_64, value: []const u8) void {
    hashInt(hasher, value.len);
    hasher.update(value);
}

fn hashInt(hasher: *std.hash.Fnv1a_64, value: anytype) void {
    var widened: u64 = @intCast(value);
    hasher.update(std.mem.asBytes(&widened));
}
