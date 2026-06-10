# zigeffect Cluster Workflow Engine Implementation Plan

Date: 2026-06-10

Milestone: 35 - Cluster Workflow Engine

Spec: `docs/superpowers/specs/2026-06-10-zigeffect-cluster-workflow-engine-design.md`

## Objective

Add a shard-owned cluster workflow command layer. Workflow execution ids map to
stable cluster entity addresses, cluster transport routes commands to those
entities, and the owning runner mutates the workflow journal from inside the
entity handler. Prove that a workflow started on runner A can be recovered and
completed on runner B after shard ownership moves.

## Architecture

Create `packages/zigeffect/src/cluster/workflow_engine.zig`.

The module owns:

- workflow execution entity identity helpers
- command/result JSON schemas and codecs
- `ClusterWorkflowEngine` transport client
- `ClusterWorkflowEntityServices`
- `ClusterWorkflowEntityRegistry`
- `ClusterWorkflowEntityHandler`
- command application helpers over `JournalStore`, `WorkflowLifecycle`, and
  `DurableClock`

Command payload type:

```text
application/vnd.zigeffect.cluster.workflow-command+json
```

Entity service key:

```text
cluster.workflow.entity.services
```

## Files

Create:

- `packages/zigeffect/src/cluster/workflow_engine.zig`
- `packages/zigeffect/test/cluster_workflow_engine_test.zig`

Modify:

- `packages/zigeffect/src/cluster/root.zig`
- `packages/zigeffect/src/zigeffect.zig`
- `packages/zigeffect/test/all_test.zig`
- `packages/zigeffect/docs/architecture.md`
- `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`

## Task 1: Public Surface, Entity Identity, Command Codec

### Red

Create `cluster_workflow_engine_test.zig` and import it from `all_test.zig`.

Tests:

- `cluster workflow public exports are available`
- `cluster workflow execution address routes by execution id`
- `cluster workflow command json round-trips`
- `cluster workflow result json round-trips`
- `cluster workflow command parser rejects incompatible schema`

Run:

```bash
zig build test-raw
```

Expected result: compile failures for missing cluster workflow declarations.

### Green

Implement:

- `workflow_engine.zig` module
- `cluster_workflow_entity_type`
- `cluster_workflow_command_payload_type`
- `cluster_workflow_entity_service_key`
- `ClusterWorkflowCommandKind`
- `ClusterWorkflowCommand`
- `ClusterWorkflowCommandResult`
- `clusterWorkflowExecutionAddress`
- command/result JSON format and parse helpers
- owned deinit helpers

Export through `cluster/root.zig` and top-level `zigeffect.zig`.

Run:

```bash
bun run zigeffect:test
zig fmt --check packages/zigeffect/src/cluster/workflow_engine.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/cluster_workflow_engine_test.zig packages/zigeffect/test/all_test.zig
```

Commit:

```bash
git add packages/zigeffect/src/cluster/workflow_engine.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/cluster_workflow_engine_test.zig packages/zigeffect/test/all_test.zig
git commit -m "feat(zigeffect): add cluster workflow command protocol"
```

## Task 2: Entity Registration And Recovery

### Red

Extend tests:

- `cluster workflow registry registers execution entity with journal service`
- `cluster workflow registry recovers owned executions from journal`

Use `LocalClusterRunner`, `InMemoryRunnerStorage`, and `InMemoryJournalStore`.

Run:

```bash
zig build test-raw
```

Expected result: failures for missing registry and recovery behavior.

### Green

Implement:

- `ClusterWorkflowEntityServices`
- `ClusterWorkflowEntityRegistry.init`
- `registerExecution`
- `recoverOwnedExecutions`
- `ClusterWorkflowRecoveryReport`

Recovery scans `JournalStore.readAll`, collects unique execution ids, computes
entity shards, and registers only executions whose shard is currently owned by
the runner.

Run:

```bash
bun run zigeffect:test
zig fmt --check packages/zigeffect/src/cluster/workflow_engine.zig packages/zigeffect/test/cluster_workflow_engine_test.zig
```

Commit:

```bash
git add packages/zigeffect/src/cluster/workflow_engine.zig packages/zigeffect/test/cluster_workflow_engine_test.zig
git commit -m "feat(zigeffect): recover cluster workflow entities"
```

## Task 3: Start, Append, Complete, And Lifecycle Commands

### Red

Extend tests:

- `cluster workflow engine start stores workflow started through owning entity`
- `cluster workflow complete appends completed through owning entity`
- `cluster workflow lifecycle commands suspend resume interrupt and cancel`

Tests should submit commands through `ClusterWorkflowEngine`, process the owning
runner with `ClusterWorkflowEntityHandler`, read command replies from
`MessageStorage`, and inspect the journal.

Run:

```bash
zig build test-raw
```

Expected result: failures for missing engine client and handler command
application.

### Green

Implement:

- `ClusterWorkflowEngine.init`
- `start`, `appendEvent`, `complete`, `suspend`, `resume`, `interrupt`,
  `cancel`
- `ClusterWorkflowEntityHandler.handle`
- command application for start/append/complete/lifecycle
- `parseClusterWorkflowCommandResultFromReply`

Use `WorkflowLifecycle` for suspend/resume/interrupt/cancel when possible and
direct journal append for start/append/complete.

Run:

```bash
bun run zigeffect:test
zig fmt --check packages/zigeffect/src/cluster/workflow_engine.zig packages/zigeffect/test/cluster_workflow_engine_test.zig
```

Commit:

```bash
git add packages/zigeffect/src/cluster/workflow_engine.zig packages/zigeffect/test/cluster_workflow_engine_test.zig
git commit -m "feat(zigeffect): execute workflow commands on cluster entities"
```

## Task 4: Durable Helper Command Paths

### Red

Extend tests:

- `cluster workflow fire due timers runs through owning entity`
- `cluster workflow deferred commands resume suspended workflow`
- `cluster workflow signal commands resume suspended workflow`
- `cluster workflow queue commands resume suspended workflow`

Each test seeds a started/suspended workflow journal, sends the command through
`ClusterWorkflowEngine`, processes the runner, parses the reply, and verifies
journal replay state or event order.

Run:

```bash
zig build test-raw
```

Expected result: failures for missing helper commands.

### Green

Implement:

- `fireDueTimers`
- `completeDeferred`, `failDeferred`, `cancelDeferred`
- `sendSignal`
- `completeQueue`, `failQueue`
- internal helper event appends and resume-if-suspended behavior

Run:

```bash
bun run zigeffect:test
zig fmt --check packages/zigeffect/src/cluster/workflow_engine.zig packages/zigeffect/test/cluster_workflow_engine_test.zig
```

Commit:

```bash
git add packages/zigeffect/src/cluster/workflow_engine.zig packages/zigeffect/test/cluster_workflow_engine_test.zig
git commit -m "feat(zigeffect): route durable workflow helpers through cluster entities"
```

## Task 5: Runner Migration Acceptance

### Red

Add acceptance test:

- `workflow started on runner a resumes and completes on runner b`

Use file-backed runner/message/journal stores:

1. Runner A owns the execution shard.
2. Register execution entity on runner A.
3. Start workflow through cluster transport.
4. Runner A processes command; journal contains `workflow_started`.
5. Runner A releases ownership.
6. Runner B acquires the same shard.
7. Runner B recovers owned workflow entities from the journal.
8. Complete workflow through cluster transport.
9. Runner B processes command; journal replays to completed.

Run:

```bash
zig build test-raw
```

Expected result: any recovery or migration gap fails.

### Green

Adjust implementation only if the acceptance test exposes a gap.

Run:

```bash
bun run zigeffect:test
zig fmt --check packages/zigeffect/src/cluster/workflow_engine.zig packages/zigeffect/test/cluster_workflow_engine_test.zig
```

Commit:

```bash
git add packages/zigeffect/src/cluster/workflow_engine.zig packages/zigeffect/test/cluster_workflow_engine_test.zig
git commit -m "test(zigeffect): prove cluster workflow shard migration"
```

## Task 6: Documentation And Roadmap Closeout

Update architecture docs with `cluster/workflow_engine.zig`.

Mark Milestone 35 deliverables and acceptance complete in the roadmap.

Run full gate:

```bash
bun run zigeffect:test
cd packages/zigeffect && zig build examples
cd packages/zigeffect && zig build cluster-runner -- --help
bun run zig:test
zig fmt --check packages/zigeffect/src/cluster/workflow_engine.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/cluster_workflow_engine_test.zig packages/zigeffect/test/all_test.zig
git diff --check
rg "TO""DO|FIX""ME|st""ub|place""holder|not imple""mented|unimple""mented" packages/zigeffect/src/cluster/workflow_engine.zig packages/zigeffect/test/cluster_workflow_engine_test.zig packages/zigeffect/docs/architecture.md docs/superpowers/specs/2026-06-10-zigeffect-cluster-workflow-engine-design.md docs/superpowers/plans/2026-06-10-zigeffect-cluster-workflow-engine.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md
```

Commit:

```bash
git add packages/zigeffect/docs/architecture.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md
git commit -m "docs(zigeffect): mark cluster workflow engine complete"
```

## Completion Gate

Milestone 35 is complete when all task commits exist and the full gate passes
without marker matches.
