const machine_mod = @import("machine.zig");
const configuration_mod = @import("configuration.zig");

pub const DeterminismError = error{NondeterministicExecution};

pub fn Audit(comptime DefinitionType: type, comptime Runtime: type) type {
    return struct {
        pub const Report = struct {
            deterministic: bool,
            first_fingerprint: u64,
            second_fingerprint: u64,
        };

        pub fn step(
            definition: *const DefinitionType,
            snapshot: Runtime.Snapshot,
            event: DefinitionType.EventType,
        ) anyerror!Report {
            const first = try Runtime.step(definition, snapshot, event);
            const second = try Runtime.step(definition, snapshot, event);
            const report = Report{
                .deterministic = first.fingerprint == second.fingerprint,
                .first_fingerprint = first.fingerprint,
                .second_fingerprint = second.fingerprint,
            };
            if (!report.deterministic) return error.NondeterministicExecution;
            return report;
        }
    };
}

pub fn FlatAudit(comptime DefinitionType: type) type {
    return Audit(DefinitionType, machine_mod.Machine(DefinitionType));
}

pub fn ConfigurationAudit(comptime DefinitionType: type) type {
    return Audit(DefinitionType, configuration_mod.ConfigurationMachine(DefinitionType));
}
