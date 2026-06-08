const std = @import("std");

pub const Allocator = std.mem.Allocator;

pub const traits = @import("traits/root.zig");
pub const data = @import("data/root.zig");
pub const match = @import("match/root.zig");
pub const pattern = @import("pattern/root.zig");

pub const core = struct {
    pub const result = @import("core/result.zig");
    pub const scope = @import("core/scope.zig");
    pub const context = @import("core/context.zig");

    pub const Cause = result.Cause;
    pub const CauseTree = result.CauseTree;
    pub const Exit = result.Exit;
    pub const FinalizerExit = result.FinalizerExit;
    pub const Scope = scope.Scope;
    pub const Context = context.Context;
};

pub const dependency = struct {
    pub const service_sets = @import("dependency/services.zig");
    pub const contracts = @import("dependency/contracts.zig");
    pub const narrowing = @import("dependency/narrowing.zig");
    pub const report = @import("dependency/report.zig");
    pub const validation = @import("dependency/validation.zig");

    pub const ServiceSet = service_sets.ServiceSet;
    pub const DependencyError = service_sets.DependencyError;
    pub const DependencyReport = report.DependencyReport;
    pub const assertEffectEnvironment = contracts.assertEffectEnvironment;
    pub const ServiceEnv = narrowing.ServiceEnv;
    pub const validateRequirements = validation.validateRequirements;
    pub const requirementsSatisfiedBy = validation.requirementsSatisfiedBy;
    pub const staticRequirementsSatisfied = validation.staticRequirementsSatisfied;
    pub const assertStaticRequirementsSatisfied = validation.assertStaticRequirementsSatisfied;
};

pub const effect = struct {
    pub const program = @import("effect/effect.zig");
    pub const resource = @import("effect/resource.zig");
    pub const schedule = @import("effect/schedule.zig");

    pub const Effect = program.Effect;
    pub const acquireRelease = resource.acquireRelease;
    pub const acquireReleaseValue = resource.acquireReleaseValue;
    pub const Schedule = schedule.Schedule;
    pub const ScheduleProgram = schedule.ScheduleProgram;
};

pub const runtime = struct {
    pub const runner = @import("runtime/runtime.zig");
    pub const fiber = @import("runtime/fiber.zig");
    pub const coordination = @import("runtime/coordination.zig");
    pub const backend = @import("runtime/backend.zig");
    pub const managed_runner = @import("runtime/runner.zig");

    pub const Runtime = runner.Runtime;
    pub const Fiber = fiber.Fiber;
    pub const FiberRuntime = fiber.FiberRuntime;
    pub const BackendKind = backend.BackendKind;
    pub const BackendCapabilities = backend.BackendCapabilities;
    pub const deterministicBackend = backend.deterministicBackend;
    pub const runManagedScope = managed_runner.runManagedScope;
    pub const exitManagedScope = managed_runner.exitManagedScope;
    pub const DeferredAwaitState = coordination.DeferredAwaitState;
    pub const QueueOfferState = coordination.QueueOfferState;
    pub const QueueTakeState = coordination.QueueTakeState;
    pub const SemaphoreAcquireState = coordination.SemaphoreAcquireState;
    pub const Deferred = coordination.Deferred;
    pub const Queue = coordination.Queue;
    pub const Semaphore = coordination.Semaphore;
};

pub const layer = struct {
    pub const definitions = @import("layer/layer.zig");
    pub const graph = @import("layer/graph.zig");

    pub const Layer = definitions.Layer;
    pub const LayerWithError = definitions.LayerWithError;
    pub const EffectLayer = definitions.EffectLayer;
    pub const ContextBuilderLayer = definitions.ContextBuilderLayer;
    pub const ProvidedLayer = definitions.ProvidedLayer;
    pub const RequiredLayer = definitions.RequiredLayer;
    pub const MergeLayer = definitions.MergeLayer;
    pub const LayerGraph = graph.LayerGraph;
    pub const LayerGraphEnv = graph.LayerGraphEnv;
    pub const LayerGraphRuntime = graph.LayerGraphRuntime;
    pub const layerGraph = graph.layerGraph;
};

pub const services = struct {
    pub const clock = @import("services/clock.zig");
    pub const logger = @import("services/logger.zig");
    pub const config = @import("services/config.zig");
    pub const metrics = @import("services/metrics.zig");
    pub const tracing = @import("services/tracing.zig");
    pub const memory_file_system = @import("services/memory_file_system.zig");
    pub const observability = @import("services/observability.zig");
    pub const causal = @import("services/causal.zig");
    pub const causal_backend = @import("services/causal_backend.zig");

    pub const Clock = clock.Clock;
    pub const FakeClock = clock.FakeClock;
    pub const Logger = logger.Logger;
    pub const ConfigError = config.ConfigError;
    pub const ConfigEntry = config.ConfigEntry;
    pub const Config = config.Config;
    pub const ConfigEnv = config.ConfigEnv;
    pub const Metrics = metrics.Metrics;
    pub const Tracing = tracing.Tracing;
    pub const MemoryFileSystem = memory_file_system.MemoryFileSystem;
    pub const formatObservabilityReport = observability.formatObservabilityReport;
    pub const CausalEventKind = causal.CausalEventKind;
    pub const CausalEvent = causal.CausalEvent;
    pub const CausalSnapshot = causal.CausalSnapshot;
    pub const CausalLineage = causal.CausalLineage;
    pub const CausalFindingKind = causal.CausalFindingKind;
    pub const CausalFinding = causal.CausalFinding;
    pub const CausalFindings = causal.CausalFindings;
    pub const CausalStore = causal.CausalStore;
    pub const CausalStoreOptions = causal.CausalStoreOptions;
    pub const CausalSamplingPolicy = causal.CausalSamplingPolicy;
    pub const CausalEventTaxonomy = causal.CausalEventTaxonomy;
    pub const causal_json_schema = causal.causal_json_schema;
    pub const causal_json_schema_version = causal.causal_json_schema_version;
    pub const causal_event_taxonomy_version = causal.causal_event_taxonomy_version;
    pub const causal_redaction_marker = causal.causal_redaction_marker;
    pub const causal_truncation_marker = causal.causal_truncation_marker;
    pub const causalEventTaxonomy = causal.causalEventTaxonomy;
    pub const isCausalStructuralEvent = causal.isCausalStructuralEvent;
    pub const isCausalFindingEvidenceEvent = causal.isCausalFindingEvidenceEvent;
    pub const isCausalSampleableEvent = causal.isCausalSampleableEvent;
    pub const formatCausalReport = causal.formatCausalReport;
    pub const formatCausalCiReport = causal.formatCausalCiReport;
    pub const formatCausalJson = causal.formatCausalJson;
    pub const formatCausalDot = causal.formatCausalDot;
    pub const CausalBackendKind = causal_backend.CausalBackendKind;
    pub const CausalBackend = causal_backend.CausalBackend;
};

pub const testing = struct {
    pub const test_env = @import("testing/test_env.zig");

    pub const TestFixtureRegistry = test_env.TestFixtureRegistry;
    pub const TestServices = test_env.TestServices;
    pub const TestEnv = test_env.TestEnv;
    pub const expectDependencyReportMissing = test_env.expectDependencyReportMissing;
    pub const expectDependencyReportDuplicate = test_env.expectDependencyReportDuplicate;
    pub const expectCauseFinalizerFailure = test_env.expectCauseFinalizerFailure;
    pub const expectCauseDefect = test_env.expectCauseDefect;
    pub const expectCauseInterruption = test_env.expectCauseInterruption;
    pub const formatScheduleDelayAssertionReport = test_env.formatScheduleDelayAssertionReport;
    pub const formatFiberStatusAssertionReport = test_env.formatFiberStatusAssertionReport;
    pub const formatQueueStateAssertionReport = test_env.formatQueueStateAssertionReport;
    pub const expectScheduleDelay = test_env.expectScheduleDelay;
    pub const expectFiberStatus = test_env.expectFiberStatus;
    pub const expectQueueLen = test_env.expectQueueLen;
    pub const expectQueueShutdown = test_env.expectQueueShutdown;
};

pub const ScopeError = core.scope.ScopeError;
pub const FinalizerRegistrationError = core.scope.FinalizerRegistrationError;
pub const DependencyError = dependency.service_sets.DependencyError;
pub const FiberId = runtime.fiber.FiberId;
pub const FiberStatus = runtime.fiber.FiberStatus;
pub const FiberPrimitiveError = runtime.coordination.FiberPrimitiveError;
pub const DeferredAwaitState = runtime.coordination.DeferredAwaitState;
pub const QueueOfferState = runtime.coordination.QueueOfferState;
pub const QueueTakeState = runtime.coordination.QueueTakeState;
pub const SemaphoreAcquireState = runtime.coordination.SemaphoreAcquireState;
pub const BackendKind = runtime.backend.BackendKind;
pub const BackendCapabilities = runtime.backend.BackendCapabilities;
pub const deterministicBackend = runtime.backend.deterministicBackend;

pub const ServiceSet = dependency.service_sets.ServiceSet;
pub const DependencyIssueKind = dependency.report.DependencyIssueKind;
pub const DependencyIssue = dependency.report.DependencyIssue;
pub const DependencyReport = dependency.report.DependencyReport;
pub const formatDependencyReport = dependency.report.formatDependencyReport;
pub const validateRequirements = dependency.validation.validateRequirements;
pub const requirementsSatisfiedBy = dependency.validation.requirementsSatisfiedBy;
pub const staticRequirementsSatisfied = dependency.validation.staticRequirementsSatisfied;
pub const assertStaticRequirementsSatisfied = dependency.validation.assertStaticRequirementsSatisfied;
pub const assertEffectEnvironment = dependency.contracts.assertEffectEnvironment;
pub const ServiceEnv = dependency.narrowing.ServiceEnv;
pub const validateLayerRequirements = dependency.validation.validateLayerRequirements;

pub const Cause = core.result.Cause;
pub const CauseTree = core.result.CauseTree;
pub const Exit = core.result.Exit;
pub const FinalizerExit = core.result.FinalizerExit;
pub const finalizerExitFromExit = core.result.finalizerExitFromExit;
pub const exitWithFinalizerFailure = core.result.exitWithFinalizerFailure;
pub const causeTreeWithFinalizerFailure = core.result.causeTreeWithFinalizerFailure;
pub const exitToResult = core.result.exitToResult;
pub const causeHasFinalizerFailure = core.result.causeHasFinalizerFailure;
pub const causeHasDefect = core.result.causeHasDefect;
pub const causeHasInterruption = core.result.causeHasInterruption;
pub const formatCause = core.result.formatCause;
pub const formatExit = core.result.formatExit;

pub const serviceNotFound = core.context.serviceNotFound;
pub const Context = core.context.Context;
pub const Scope = core.scope.Scope;

pub const Clock = services.clock.Clock;
pub const FakeClock = services.clock.FakeClock;

pub const Effect = effect.Effect;
pub const EffectLayer = layer.definitions.EffectLayer;
pub const RequiredEffect = effect.program.RequiredEffect;
pub const OnExitEffect = effect.program.OnExitEffect;
pub const EnsuringEffect = effect.program.EnsuringEffect;
pub const MapEffect = effect.program.MapEffect;
pub const FlatMapEffect = effect.program.FlatMapEffect;
pub const TapEffect = effect.program.TapEffect;
pub const MapErrorEffect = effect.program.MapErrorEffect;
pub const CatchAllEffect = effect.program.CatchAllEffect;
pub const OrElseEffect = effect.program.OrElseEffect;
pub const TapErrorEffect = effect.program.TapErrorEffect;
pub const retryEffect = effect.program.retryEffect;
pub const repeatEffect = effect.program.repeatEffect;
pub const acquireRelease = effect.resource.acquireRelease;
pub const acquireReleaseValue = effect.resource.acquireReleaseValue;

pub const Deferred = runtime.coordination.Deferred;
pub const Queue = runtime.coordination.Queue;
pub const Semaphore = runtime.coordination.Semaphore;
pub const Fiber = runtime.fiber.Fiber;
pub const FiberRuntime = runtime.fiber.FiberRuntime;
pub const Runtime = runtime.runner.Runtime;

pub const Layer = layer.definitions.Layer;
pub const LayerWithError = layer.definitions.LayerWithError;
pub const ContextBuilderLayer = layer.definitions.ContextBuilderLayer;
pub const ProvidedLayer = layer.definitions.ProvidedLayer;
pub const RequiredLayer = layer.definitions.RequiredLayer;
pub const MergeLayer = layer.definitions.MergeLayer;
pub const LayerGraph = layer.graph.LayerGraph;
pub const LayerGraphEnv = layer.graph.LayerGraphEnv;
pub const LayerGraphRuntime = layer.graph.LayerGraphRuntime;
pub const layerGraph = layer.graph.layerGraph;

pub const Schedule = effect.schedule.Schedule;
pub const ScheduleProgram = effect.schedule.ScheduleProgram;
pub const Logger = services.logger.Logger;
pub const ConfigError = services.config.ConfigError;
pub const ConfigEntry = services.config.ConfigEntry;
pub const Config = services.config.Config;
pub const ConfigEnv = services.config.ConfigEnv;
pub const Metrics = services.metrics.Metrics;
pub const Tracing = services.tracing.Tracing;
pub const MemoryFileSystem = services.memory_file_system.MemoryFileSystem;
pub const formatObservabilityReport = services.observability.formatObservabilityReport;
pub const CausalEventKind = services.causal.CausalEventKind;
pub const CausalEvent = services.causal.CausalEvent;
pub const CausalSnapshot = services.causal.CausalSnapshot;
pub const CausalLineage = services.causal.CausalLineage;
pub const CausalFindingKind = services.causal.CausalFindingKind;
pub const CausalFinding = services.causal.CausalFinding;
pub const CausalFindings = services.causal.CausalFindings;
pub const CausalStore = services.causal.CausalStore;
pub const CausalStoreOptions = services.causal.CausalStoreOptions;
pub const CausalSamplingPolicy = services.causal.CausalSamplingPolicy;
pub const CausalEventTaxonomy = services.causal.CausalEventTaxonomy;
pub const causal_json_schema = services.causal.causal_json_schema;
pub const causal_json_schema_version = services.causal.causal_json_schema_version;
pub const causal_event_taxonomy_version = services.causal.causal_event_taxonomy_version;
pub const causal_redaction_marker = services.causal.causal_redaction_marker;
pub const causal_truncation_marker = services.causal.causal_truncation_marker;
pub const causalEventTaxonomy = services.causal.causalEventTaxonomy;
pub const isCausalStructuralEvent = services.causal.isCausalStructuralEvent;
pub const isCausalFindingEvidenceEvent = services.causal.isCausalFindingEvidenceEvent;
pub const isCausalSampleableEvent = services.causal.isCausalSampleableEvent;
pub const formatCausalReport = services.causal.formatCausalReport;
pub const formatCausalCiReport = services.causal.formatCausalCiReport;
pub const formatCausalJson = services.causal.formatCausalJson;
pub const formatCausalDot = services.causal.formatCausalDot;
pub const CausalBackendKind = services.causal_backend.CausalBackendKind;
pub const CausalBackend = services.causal_backend.CausalBackend;
pub const TestFixtureRegistry = testing.test_env.TestFixtureRegistry;
pub const TestServices = testing.test_env.TestServices;
pub const TestEnv = testing.test_env.TestEnv;

pub const Option = data.Option;
pub const Either = data.Either;
pub const Duration = data.Duration;
pub const BigDecimal = data.BigDecimal;
pub const DateTime = data.DateTime;
pub const Data = data.Data;
pub const Redacted = data.Redacted;
pub const Chunk = data.Chunk;
pub const HashSet = data.HashSet;
