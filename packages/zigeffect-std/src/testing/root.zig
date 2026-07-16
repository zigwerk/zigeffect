const std = @import("std");
const Secrets = @import("../secrets/root.zig");
const fx = @import("zigeffect");

pub const SuiteReceipt = fx.testing.SuiteReceipt;

pub const Contract = @import("contract.zig");
pub const Scenario = Contract.Scenario;
pub const FaultProfile = Contract.FaultProfile;
pub const FaultKind = Contract.FaultKind;
pub const TestStatus = Contract.TestStatus;
pub const AssertionStatus = Contract.AssertionStatus;
pub const AssertionResult = Contract.AssertionResult;
pub const CausalEventIdSpace = Contract.CausalEventIdSpace;
pub const Completeness = Contract.Completeness;
pub const MinimalCase = Contract.MinimalCase;
pub const MemorySummary = Contract.MemorySummary;
pub const CausalSummary = Contract.CausalSummary;
pub const ExecutionIdentity = Contract.ExecutionIdentity;
pub const CoverageDimension = Contract.CoverageDimension;
pub const CoverageTarget = Contract.CoverageTarget;
pub const CoverageHit = Contract.CoverageHit;
pub const CoverageSummary = Contract.CoverageSummary;
pub const EvidenceKind = Contract.EvidenceKind;
pub const EvidenceSummary = Contract.EvidenceSummary;
pub const NamedEvidence = Contract.NamedEvidence;
pub const TestReceipt = Contract.TestReceipt;
pub const ParsedReceipt = Contract.ParsedReceipt;
pub const TestRunReceipt = Contract.TestRunReceipt;
pub const ParsedRunReceipt = Contract.ParsedRunReceipt;
pub const parseReceipt = Contract.parseReceipt;
pub const parseRunReceipt = Contract.parseRunReceipt;

pub const Protocol = @import("protocol.zig");
pub const Coverage = @import("coverage.zig");
pub const Schedules = @import("schedules.zig");
pub const Models = @import("models.zig");
pub const StatechartExplorer = Models.StatechartExplorer;
pub const Differential = @import("differential.zig");
pub const DifferentialExecutor = Differential.Executor;
pub const DifferentialOutcome = Differential.Outcome;
pub const runDifferentialAlloc = Differential.runAlloc;
pub const VirtualWorld = @import("virtual_world.zig");
pub const Sandbox = @import("sandbox.zig");
pub const Mutation = @import("mutation.zig");
pub const MutationPoint = Mutation.Point;
pub const MutationOutcome = Mutation.Outcome;
pub const runMutationsAlloc = Mutation.runAlloc;
pub const Budgets = @import("budgets.zig");

pub const Context = @import("context.zig");
pub const TestContext = Context.TestContext;
pub const TestContextOptions = Context.Options;
pub const Artifact = Context.Artifact;
pub const FixtureRegistry = Context.FixtureRegistry;

pub const Assertions = @import("assertions.zig");
pub const AssertionRecorder = Assertions.Recorder;
pub const EventPattern = Assertions.EventPattern;

pub const Faults = @import("faults.zig");
pub const FaultCase = Faults.FaultCase;
pub const FaultMatrix = Faults.FaultMatrix;
pub const runFaultMatrix = Faults.runMatrix;
pub const exploreSchedules = Schedules.explore;

pub const Generators = @import("generators.zig");
pub const Seeded = Generators.Seeded;
pub const PropertyOptions = Generators.PropertyOptions;

pub const Snapshots = @import("snapshots.zig");
pub const Snapshot = Snapshots.Snapshot;
pub const SnapshotKind = Snapshots.Kind;
pub const SnapshotUpdatePlan = Snapshots.UpdatePlan;

pub const TestingError = error{SecretLeak};

pub fn assertEqualJson(expected: []const u8, actual: []const u8) !void {
    try std.testing.expectEqualStrings(expected, actual);
}

pub fn assertNoSentinelSecrets(text: []const u8) TestingError!void {
    if (Secrets.containsSecret(text)) return TestingError.SecretLeak;
}

test "Testing assertNoSentinelSecrets catches leaks" {
    try assertNoSentinelSecrets("plain text");
    try std.testing.expectError(TestingError.SecretLeak, assertNoSentinelSecrets("sentinel-secret-for-tests"));
}

test "Testing exports agent-first scenario and receipt contracts" {
    try std.testing.expectEqualStrings("zigeffect.test-receipt.v1", Contract.receipt_schema);
    try std.testing.expect(@hasDecl(Scenario, "validate"));
    try std.testing.expect(@hasDecl(TestReceipt, "jsonAlloc"));
    try std.testing.expect(@hasDecl(TestRunReceipt, "jsonAlloc"));
    try std.testing.expectEqualStrings("zigeffect.test-suite-receipt.v2", SuiteReceipt.schema);
    try std.testing.expect(@hasDecl(TestContext, "finishAlloc"));
    try std.testing.expect(@hasDecl(AssertionRecorder, "equal"));
    try std.testing.expect(@hasDecl(AssertionRecorder, "applicationService"));
    try std.testing.expect(@hasDecl(AssertionRecorder, "applicationDependency"));
    try std.testing.expect(@hasDecl(AssertionRecorder, "applicationHealthy"));
    try std.testing.expect(@hasDecl(FaultMatrix, "standard"));
    try std.testing.expect(@hasDecl(Generators, "generate"));
    try std.testing.expect(@hasDecl(Snapshot, "compareAlloc"));
    inline for (.{ "Protocol", "Coverage", "Schedules", "Models", "Differential", "VirtualWorld", "Sandbox", "Mutation", "Budgets" }) |name| {
        try std.testing.expect(@hasDecl(@This(), name));
    }
}
