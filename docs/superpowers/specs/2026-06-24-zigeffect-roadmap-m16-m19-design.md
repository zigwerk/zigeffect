# zigeffect Roadmap M16-M19 Design

Date: 2026-06-24

## Goal

Continue the roadmap beyond M15 by turning the remaining frontier into bounded,
tested runtime and workbench capabilities:

- M16: engine-applied live commands.
- M17: visual semantic diff UX.
- M18: durable ops adapters.
- M19: multi-runner causal lineage stitching.

## Design

### M16 Engine-Applied Live Commands

The collector already accepts and broadcasts command frames. The engine now
needs a policy-bound executor that turns those frames into
`AgentInterventionRequest`s and invokes `AgentInterventionPolicy`.

Add `services/causal_live_command.zig` with:

- `CausalLiveCommandRequest`: command id, command kind, actor, reason, redacted
  detail, and optional run/scope/fiber/schedule/resource ids.
- `CausalLiveCommandResult`: command id, known/unknown kind, intervention
  decision, applied bit, and event ids emitted by the intervention layer.
- `applyCausalLiveCommand`: validates the command kind, rejects unknown commands
  by recording an alert fact, and delegates known commands to
  `applyAgentIntervention`.

The browser remains non-authoritative. Policy still decides whether anything is
applied.

### M17 Visual Semantic Diff UX

`diffCausalGraphs` exists in Zig. The workbench needs to render a portable diff
artifact without requiring a live Zig process.

Add a TypeScript model for `semantic_diff` data embedded in an artifact:

- summary counters for resolved/introduced findings, added/removed terminal
  fiber facts, resource finalizations, and lineage edges;
- sections for finding/resource/fiber/lineage entries;
- warnings when an artifact claims to have a diff but its shape is partial.

Add a `Diff` tab to the workbench that displays the summary and entries. The UI
does not mutate the graph; it is read-only evidence for agents and humans.

### M18 Durable Ops Adapters

`CausalOpsPolicy` exists, and `CausalNendbStorageBackendState` can already query
stored events. Add a small adapter that applies the ops policy to stored
snapshots before returning causal artifacts and retention decisions.

Add `services/causal_ops_storage.zig` with:

- `CausalOpsArtifactReadResult`: access decision plus optional snapshot.
- `readCausalOpsArtifact`: checks deployment metadata and actor/scope access
  before snapshot reads.
- `checkCausalOpsRetention`: maps a storage state and retention policy into the
  ops policy and records alert facts when thresholds are crossed.

This is an adapter over the in-repo durable storage abstraction, not a hosted
ops service.

### M19 Multi-Runner Causal Lineage Stitching

Cluster transport now propagates origin causal ids. Add a stitcher that merges
local runner traces into one agent-queryable lineage view.

Add `services/causal_runner_lineage.zig` with:

- `CausalRunnerTrace`: runner id plus event slice.
- `CausalRunnerLineage`: cloned event snapshot and cross-runner edge facts.
- `stitchCausalRunnerLineage`: merges runner traces and emits edge facts when
  an event's `cause_event_id` references an event from another runner.

This proves deployed-runner lineage as data without claiming full service
discovery or process orchestration.

## Testing

- Zig tests cover unknown and approved live commands.
- Workbench tests cover parsing and rendering semantic diff artifacts.
- Zig tests cover denied/allowed ops storage reads and retention alerts.
- Zig tests cover cross-runner edge stitching from `cause_event_id`.
- Roadmap/docs are updated after implementation.

## Non-Goals

- No browser-side policy authority.
- No real TLS deployment, load balancer, or service discovery.
- No new report-only tools.
- No mutation outside the existing `AgentInterventionPolicy` gate.
