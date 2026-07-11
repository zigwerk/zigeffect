const std = @import("std");

pub const max_version_changes: usize = 512;

pub const VersionCompatibility = enum {
    unchanged,
    metadata_only,
    additive,
    behavioral,
    context_migration,
    breaking,
};

pub const DeploymentStrategy = enum {
    new_instances_only,
    drain_and_replace,
    restart_from_initial,
    explicit_migration,
};

pub const VersionRisk = enum { low, medium, high, critical };

pub const VersionSubject = enum {
    machine,
    state,
    transition,
    completion,
    bounds,
    type_contract,
};

pub const VersionChangeKind = enum {
    version_advanced,
    version_regressed,
    invalid_previous_definition,
    invalid_next_definition,
    machine_id_changed,
    initial_state_changed,
    machine_metadata_changed,
    state_added,
    state_removed,
    state_structure_changed,
    state_behavior_changed,
    state_metadata_changed,
    transition_added,
    transition_removed,
    transition_behavior_changed,
    transition_metadata_changed,
    completion_added,
    completion_removed,
    completion_behavior_changed,
    completion_metadata_changed,
    bound_increased,
    bound_decreased,
};

pub fn VersionDiff(comptime DefinitionType: type) type {
    const State = DefinitionType.StateType;

    return struct {
        const Self = @This();

        pub const Change = struct {
            id: u64,
            kind: VersionChangeKind,
            subject: VersionSubject,
            subject_id: []const u8,
            compatibility: VersionCompatibility,
            risk: VersionRisk,
            detail: []const u8,
        };

        pub const Report = struct {
            definition_id: []const u8,
            from_version: u32,
            to_version: u32,
            from_fingerprint: u64,
            to_fingerprint: u64,
            compatibility: VersionCompatibility = .unchanged,
            recommended_strategy: DeploymentStrategy = .new_instances_only,
            risk: VersionRisk = .low,
            change_storage: [max_version_changes]Change = undefined,
            change_count: usize = 0,
            truncated: bool = false,
            fingerprint: u64 = 0,

            pub fn changes(self: *const Report) []const Change {
                return self.change_storage[0..self.change_count];
            }

            pub fn hasSubject(self: *const Report, subject: VersionSubject, subject_id: []const u8) bool {
                for (self.changes()) |change| {
                    if (change.subject == subject and std.mem.eql(u8, change.subject_id, subject_id)) return true;
                }
                return false;
            }

            pub fn hasKind(self: *const Report, kind: VersionChangeKind) bool {
                for (self.changes()) |change| if (change.kind == kind) return true;
                return false;
            }

            pub fn riskAtLeast(self: *const Report, minimum: VersionRisk) bool {
                return @intFromEnum(self.risk) >= @intFromEnum(minimum);
            }

            fn add(
                self: *Report,
                kind: VersionChangeKind,
                subject: VersionSubject,
                subject_id: []const u8,
                compatibility: VersionCompatibility,
                risk: VersionRisk,
                detail: []const u8,
            ) void {
                if (self.change_count >= self.change_storage.len) {
                    self.truncated = true;
                    self.promote(.breaking, .critical);
                    return;
                }
                self.change_storage[self.change_count] = .{
                    .id = changeId(self, kind, subject, subject_id, self.change_count),
                    .kind = kind,
                    .subject = subject,
                    .subject_id = subject_id,
                    .compatibility = compatibility,
                    .risk = risk,
                    .detail = detail,
                };
                self.change_count += 1;
                self.promote(compatibility, risk);
            }

            fn promote(self: *Report, compatibility: VersionCompatibility, risk: VersionRisk) void {
                if (@intFromEnum(compatibility) > @intFromEnum(self.compatibility)) self.compatibility = compatibility;
                if (@intFromEnum(risk) > @intFromEnum(self.risk)) self.risk = risk;
                self.recommended_strategy = strategyFor(self.compatibility);
            }
        };

        pub fn compare(previous: *const DefinitionType, next: *const DefinitionType) Report {
            var report = Report{
                .definition_id = next.id,
                .from_version = previous.version,
                .to_version = next.version,
                .from_fingerprint = previous.fingerprint(),
                .to_fingerprint = next.fingerprint(),
            };

            if (!previous.validate().isValid()) report.add(
                .invalid_previous_definition,
                .machine,
                previous.id,
                .breaking,
                .critical,
                "previous definition is invalid",
            );
            if (!next.validate().isValid()) report.add(
                .invalid_next_definition,
                .machine,
                next.id,
                .breaking,
                .critical,
                "next definition is invalid",
            );

            if (!std.mem.eql(u8, previous.id, next.id)) report.add(
                .machine_id_changed,
                .machine,
                next.id,
                .breaking,
                .critical,
                "machine identity changed",
            );
            if (next.version < previous.version) {
                report.add(.version_regressed, .machine, next.id, .breaking, .critical, "definition version regressed");
            } else if (next.version > previous.version) {
                report.add(.version_advanced, .machine, next.id, .metadata_only, .low, "definition version advanced");
            }
            if (previous.initial != next.initial) report.add(
                .initial_state_changed,
                .machine,
                @tagName(next.initial),
                .breaking,
                .critical,
                "initial state changed",
            );
            if (!std.mem.eql(u8, previous.description, next.description) or !sourceEqual(previous.source, next.source)) {
                report.add(.machine_metadata_changed, .machine, next.id, .metadata_only, .low, "machine metadata changed");
            }

            compareBounds(&report, previous.bounds, next.bounds);
            compareCompletion(&report, previous, next);

            for (previous.states) |old_state| {
                const new_state = findState(next, old_state.id) orelse {
                    report.add(.state_removed, .state, @tagName(old_state.id), .breaking, .critical, "state removed");
                    continue;
                };
                if (!stateStructureEqual(old_state, new_state)) report.add(
                    .state_structure_changed,
                    .state,
                    @tagName(old_state.id),
                    .breaking,
                    .critical,
                    "state kind, parent, or initial child changed",
                );
                if (!stateBehaviorEqual(old_state, new_state)) report.add(
                    .state_behavior_changed,
                    .state,
                    @tagName(old_state.id),
                    .behavioral,
                    .high,
                    "state entry, exit, or invocation behavior changed",
                );
                if (!stateMetadataEqual(old_state, new_state)) report.add(
                    .state_metadata_changed,
                    .state,
                    @tagName(old_state.id),
                    .metadata_only,
                    .low,
                    "state metadata changed",
                );
            }
            for (next.states) |new_state| {
                if (findState(previous, new_state.id) == null) report.add(
                    .state_added,
                    .state,
                    @tagName(new_state.id),
                    .additive,
                    .medium,
                    "state added",
                );
            }

            for (previous.transitions) |old_transition| {
                const new_transition = findTransition(next, old_transition.id) orelse {
                    report.add(.transition_removed, .transition, old_transition.id, .behavioral, .high, "transition removed");
                    continue;
                };
                if (!transitionBehaviorEqual(old_transition, new_transition)) report.add(
                    .transition_behavior_changed,
                    .transition,
                    old_transition.id,
                    .behavioral,
                    .high,
                    "transition selection or executable behavior changed",
                );
                if (!transitionMetadataEqual(old_transition, new_transition)) report.add(
                    .transition_metadata_changed,
                    .transition,
                    old_transition.id,
                    .metadata_only,
                    .low,
                    "transition metadata changed",
                );
            }
            for (next.transitions) |new_transition| {
                if (findTransition(previous, new_transition.id) != null) continue;
                const changes_existing_selection = findState(previous, new_transition.source) != null;
                report.add(
                    .transition_added,
                    .transition,
                    new_transition.id,
                    if (changes_existing_selection) .behavioral else .additive,
                    if (changes_existing_selection) .high else .medium,
                    if (changes_existing_selection) "transition added to an existing source state" else "transition added",
                );
            }

            report.fingerprint = reportFingerprint(&report);
            return report;
        }

        fn findState(definition: *const DefinitionType, state: State) ?DefinitionType.StateNode {
            for (definition.states) |candidate| if (candidate.id == state) return candidate;
            return null;
        }

        fn findTransition(definition: *const DefinitionType, id: []const u8) ?DefinitionType.Transition {
            for (definition.transitions) |candidate| if (std.mem.eql(u8, candidate.id, id)) return candidate;
            return null;
        }

        fn compareCompletion(report: *Report, previous: *const DefinitionType, next: *const DefinitionType) void {
            if (previous.completion == null and next.completion != null) {
                report.add(.completion_added, .completion, next.completion.?.id, .behavioral, .high, "completion mapping added");
                return;
            }
            if (previous.completion != null and next.completion == null) {
                report.add(.completion_removed, .completion, previous.completion.?.id, .behavioral, .high, "completion mapping removed");
                return;
            }
            if (previous.completion) |old| if (next.completion) |new| {
                if (!std.mem.eql(u8, old.id, new.id)) report.add(
                    .completion_behavior_changed,
                    .completion,
                    new.id,
                    .behavioral,
                    .high,
                    "completion identity changed",
                );
                if (!std.mem.eql(u8, old.description, new.description) or !sourceEqual(old.source, new.source)) report.add(
                    .completion_metadata_changed,
                    .completion,
                    new.id,
                    .metadata_only,
                    .low,
                    "completion metadata changed",
                );
            };
        }

        fn compareBounds(report: *Report, previous: anytype, next: @TypeOf(previous)) void {
            compareBound(report, "max_states", previous.max_states, next.max_states);
            compareBound(report, "max_transitions", previous.max_transitions, next.max_transitions);
            compareBound(report, "max_commands", previous.max_commands, next.max_commands);
            compareBound(report, "max_internal_events", previous.max_internal_events, next.max_internal_events);
            compareBound(report, "max_microsteps", previous.max_microsteps, next.max_microsteps);
            compareBound(report, "max_hierarchy_depth", previous.max_hierarchy_depth, next.max_hierarchy_depth);
        }

        fn compareBound(report: *Report, id: []const u8, previous: usize, next: usize) void {
            if (next < previous) report.add(.bound_decreased, .bounds, id, .breaking, .critical, "runtime bound decreased");
            if (next > previous) report.add(.bound_increased, .bounds, id, .additive, .medium, "runtime bound increased");
        }

        fn stateStructureEqual(left: DefinitionType.StateNode, right: DefinitionType.StateNode) bool {
            return left.kind == right.kind and left.parent == right.parent and left.initial == right.initial;
        }

        fn stateBehaviorEqual(left: DefinitionType.StateNode, right: DefinitionType.StateNode) bool {
            return actionsEqual(left.entry_actions, right.entry_actions) and
                actionsEqual(left.exit_actions, right.exit_actions) and
                invocationsEqual(left.invocations, right.invocations);
        }

        fn stateMetadataEqual(left: DefinitionType.StateNode, right: DefinitionType.StateNode) bool {
            return std.mem.eql(u8, left.description, right.description) and
                sourceEqual(left.source, right.source) and
                actionMetadataEqual(left.entry_actions, right.entry_actions) and
                actionMetadataEqual(left.exit_actions, right.exit_actions) and
                invocationMetadataEqual(left.invocations, right.invocations);
        }

        fn transitionBehaviorEqual(left: DefinitionType.Transition, right: DefinitionType.Transition) bool {
            return left.source == right.source and
                left.event == right.event and
                left.target == right.target and
                left.kind == right.kind and
                left.reenter == right.reenter and
                optionalGuardIdEqual(left.guard, right.guard) and
                actionsEqual(left.actions, right.actions);
        }

        fn transitionMetadataEqual(left: DefinitionType.Transition, right: DefinitionType.Transition) bool {
            if (!std.mem.eql(u8, left.description, right.description) or !sourceEqual(left.source_ref, right.source_ref)) return false;
            if (!guardMetadataEqual(left.guard, right.guard)) return false;
            return actionMetadataEqual(left.actions, right.actions);
        }

        fn actionsEqual(left: []const DefinitionType.Action, right: []const DefinitionType.Action) bool {
            if (left.len != right.len) return false;
            for (left, right) |a, b| if (!std.mem.eql(u8, a.id, b.id)) return false;
            return true;
        }

        fn actionMetadataEqual(left: []const DefinitionType.Action, right: []const DefinitionType.Action) bool {
            if (left.len != right.len) return false;
            for (left, right) |a, b| {
                if (!std.mem.eql(u8, a.description, b.description) or !sourceEqual(a.source, b.source)) return false;
            }
            return true;
        }

        fn invocationsEqual(left: []const DefinitionType.Invocation, right: []const DefinitionType.Invocation) bool {
            if (left.len != right.len) return false;
            for (left, right) |a, b| {
                if (!std.mem.eql(u8, a.id, b.id) or !std.mem.eql(u8, a.start.id, b.start.id)) return false;
                if ((a.stop == null) != (b.stop == null)) return false;
                if (a.stop) |a_stop| if (!std.mem.eql(u8, a_stop.id, b.stop.?.id)) return false;
            }
            return true;
        }

        fn invocationMetadataEqual(left: []const DefinitionType.Invocation, right: []const DefinitionType.Invocation) bool {
            if (left.len != right.len) return false;
            for (left, right) |a, b| {
                if (!std.mem.eql(u8, a.description, b.description) or !sourceEqual(a.source, b.source)) return false;
                if (!std.mem.eql(u8, a.start.description, b.start.description) or !sourceEqual(a.start.source, b.start.source)) return false;
                if (a.stop) |a_stop| {
                    const b_stop = b.stop orelse return false;
                    if (!std.mem.eql(u8, a_stop.description, b_stop.description) or !sourceEqual(a_stop.source, b_stop.source)) return false;
                }
            }
            return true;
        }

        fn optionalGuardIdEqual(left: ?DefinitionType.Guard, right: ?DefinitionType.Guard) bool {
            if ((left == null) != (right == null)) return false;
            if (left) |a| return std.mem.eql(u8, a.id, right.?.id);
            return true;
        }

        fn guardMetadataEqual(left: ?DefinitionType.Guard, right: ?DefinitionType.Guard) bool {
            if ((left == null) != (right == null)) return false;
            if (left) |a| {
                const b = right.?;
                return std.mem.eql(u8, a.description, b.description) and sourceEqual(a.source, b.source);
            }
            return true;
        }

        fn sourceEqual(left: anytype, right: @TypeOf(left)) bool {
            return std.mem.eql(u8, left.file, right.file) and
                std.mem.eql(u8, left.declaration, right.declaration) and
                left.line == right.line and left.column == right.column;
        }

        fn changeId(report: *const Report, kind: VersionChangeKind, subject: VersionSubject, id: []const u8, ordinal: usize) u64 {
            var hasher = std.hash.Fnv1a_64.init();
            hashInt(&hasher, report.from_fingerprint);
            hashInt(&hasher, report.to_fingerprint);
            hashInt(&hasher, @intFromEnum(kind));
            hashInt(&hasher, @intFromEnum(subject));
            hashText(&hasher, id);
            hashInt(&hasher, ordinal);
            const value = hasher.final();
            return if (value == 0) 1 else value;
        }

        fn reportFingerprint(report: *const Report) u64 {
            var hasher = std.hash.Fnv1a_64.init();
            hashText(&hasher, report.definition_id);
            hashInt(&hasher, report.from_version);
            hashInt(&hasher, report.to_version);
            hashInt(&hasher, report.from_fingerprint);
            hashInt(&hasher, report.to_fingerprint);
            hashInt(&hasher, @intFromEnum(report.compatibility));
            hashInt(&hasher, @intFromEnum(report.risk));
            for (report.changes()) |change| hashInt(&hasher, change.id);
            hashInt(&hasher, @intFromBool(report.truncated));
            const value = hasher.final();
            return if (value == 0) 1 else value;
        }
    };
}

pub fn strategyFor(compatibility: VersionCompatibility) DeploymentStrategy {
    return switch (compatibility) {
        .unchanged, .metadata_only, .additive => .new_instances_only,
        .behavioral => .drain_and_replace,
        .context_migration, .breaking => .explicit_migration,
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
