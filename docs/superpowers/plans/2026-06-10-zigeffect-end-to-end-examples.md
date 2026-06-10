# zigeffect End-To-End Examples Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement Milestone 44 by adding six runnable, tested examples for local durable workflows and Erlang-style local clustering.

**Architecture:** Each example is a standalone Zig module under `packages/zigeffect/examples/` with a typed scenario report, a `main` entry point, and tests in the same file. `packages/zigeffect/build.zig` wires each example as both an executable and a test artifact under the existing `examples` aggregate step. The examples use existing workflow and cluster APIs only.

**Tech Stack:** Zig, zigeffect workflow journal/context APIs, zigeffect cluster runtime APIs, Zig build system, Bun wrapper verification commands.

---

## File Responsibilities

Create:

- `packages/zigeffect/examples/workflow_approval.zig`: file-backed approval signal workflow with reopen/replay.
- `packages/zigeffect/examples/workflow_queue_worker.zig`: durable queue offer, claim, complete, replay, and ack.
- `packages/zigeffect/examples/workflow_timer_signal.zig`: durable timer plus durable signal in one workflow execution.
- `packages/zigeffect/examples/local_actor.zig`: local entity actor with tell, ask, state, and reply.
- `packages/zigeffect/examples/multi_runner_cluster.zig`: two local cluster runners sharing file-backed message and runner storage.
- `packages/zigeffect/examples/cluster_workflow_migration.zig`: workflow start on runner A, recovery and completion on runner B.

Modify:

- `packages/zigeffect/build.zig`: add module, executable, test artifact, and `examples_step` dependencies for each new example.
- `packages/zigeffect/README.md`: list the new examples and the aggregate command.
- `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`: mark M44 deliverables and acceptance complete after verification.
- `docs/superpowers/plans/2026-06-10-zigeffect-end-to-end-examples.md`: check off tasks as they are completed.

## Shared Build Pattern

Use this build pattern for each example, replacing the variable, path, and
binary names:

```zig
const workflow_approval_example_module = b.createModule(.{
    .root_source_file = b.path("examples/workflow_approval.zig"),
    .target = target,
    .optimize = optimize,
});
workflow_approval_example_module.addImport("zigeffect", zigeffect);

const workflow_approval_example = b.addExecutable(.{
    .name = "zigeffect-workflow-approval-example",
    .root_module = workflow_approval_example_module,
});

const workflow_approval_example_tests = b.addTest(.{
    .name = "zigeffect-workflow-approval-example-tests",
    .root_module = workflow_approval_example_module,
});
const run_workflow_approval_example_tests = b.addRunArtifact(workflow_approval_example_tests);
```

Add matching `examples_step` dependencies:

```zig
examples_step.dependOn(&workflow_approval_example.step);
examples_step.dependOn(&run_workflow_approval_example_tests.step);
```

## Task 1: Local Approval Workflow Example

**Files:**

- Create: `packages/zigeffect/examples/workflow_approval.zig`
- Modify: `packages/zigeffect/build.zig`

- [x] **Step 1: Add the failing example shell and build wiring**

Create `workflow_approval.zig` with:

```zig
const std = @import("std");
const fx = @import("zigeffect");

const ApprovalReport = struct {
    workflow_id: fx.workflow.WorkflowId,
    execution_id: fx.workflow.ExecutionId,
    first_pass_suspended: bool,
    approved_value: u64,
    final_status: fx.workflow.WorkflowStatus,
    event_count: usize,
};

fn runApprovalWorkflowExample(allocator: std.mem.Allocator, dir: *std.Io.Dir) !ApprovalReport {
    _ = allocator;
    _ = dir;
    return error.ExpectedApprovalScenario;
}

pub fn main(init: std.process.Init) !void {
    var cwd = std.Io.Dir.cwd();
    const path = ".zig-cache/zigeffect-examples/workflow-approval";
    cwd.deleteTree(init.io, path) catch {};
    try cwd.createDirPath(init.io, path);
    var dir = try cwd.openDir(init.io, path, .{});
    defer dir.close(init.io);

    const report = try runApprovalWorkflowExample(init.gpa, &dir);
    std.debug.print(
        "approval workflow: workflow_id={d} execution_id={d} approved={d} events={d}\n",
        .{ report.workflow_id, report.execution_id, report.approved_value, report.event_count },
    );
}

test "approval workflow suspends then resumes from a durable signal after reopen" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const report = try runApprovalWorkflowExample(std.testing.allocator, &tmp.dir);
    try std.testing.expect(report.first_pass_suspended);
    try std.testing.expectEqual(@as(u64, 42), report.approved_value);
    try std.testing.expectEqual(fx.workflow.WorkflowStatus.running, report.final_status);
    try std.testing.expect(report.event_count >= 4);
}
```

Wire the module into `build.zig` using the shared build pattern with:

- path: `examples/workflow_approval.zig`
- binary name: `zigeffect-workflow-approval-example`
- test name: `zigeffect-workflow-approval-example-tests`

- [x] **Step 2: Run the failing example gate**

Run:

```bash
(cd packages/zigeffect && zig build examples)
```

Expected: FAIL from `error.ExpectedApprovalScenario` in the new example test.

- [x] **Step 3: Implement the approval scenario**

Implement `runApprovalWorkflowExample` with:

- `const Approval = fx.workflow.Signal("approval", u64);`
- a `fx.Codec(u64)` that encodes and decodes decimal text;
- `workflow_id = fx.workflow.workflowId("approval")`;
- `execution_id = fx.workflow.executionId("approval", "case-42")`;
- first file-store open, `workflow_started` append, and `WorkflowContext.waitForSignal` returning `.suspended`;
- second file-store open and `DurableSignal.send(Approval, codec, 42, "operator:42")`;
- third file-store open and `WorkflowContext.waitForSignal` returning `.received`;
- `latestState` and `readAll` to populate the report.

The first append should use:

```zig
_ = try journal.append(.{ .event = .{
    .sequence = 1,
    .kind = .workflow_started,
    .workflow_id = workflow_id,
    .execution_id = execution_id,
    .name = "approval",
    .status = "running",
    .idempotency_key = "approval:case-42",
} });
```

- [x] **Step 4: Verify and commit**

Run:

```bash
(cd packages/zigeffect && zig build examples)
zig fmt --check packages/zigeffect/examples/workflow_approval.zig packages/zigeffect/build.zig
```

Expected: PASS.

Commit:

```bash
git add packages/zigeffect/examples/workflow_approval.zig packages/zigeffect/build.zig
git diff --cached --check
git commit -m "example(zigeffect): add approval workflow"
```

## Task 2: Durable Queue Worker Example

**Files:**

- Create: `packages/zigeffect/examples/workflow_queue_worker.zig`
- Modify: `packages/zigeffect/build.zig`

- [x] **Step 1: Add the failing example shell and build wiring**

Create `workflow_queue_worker.zig` with a report:

```zig
const QueueWorkerReport = struct {
    queue_id: fx.workflow.QueueId,
    account_id: u64,
    worker_id: []const u8,
    completed_value: u64,
    acked_once: bool,
    event_count: usize,
};
```

Add `runQueueWorkerExample(allocator: std.mem.Allocator) !QueueWorkerReport`
that returns `error.ExpectedQueueWorkerScenario`, a `main` that prints the
report, and a test named:

```zig
test "durable queue worker offers claims completes and replays ack" { ... }
```

The test asserts:

- `account_id == 42`
- `worker_id` equals `"worker-a"`
- `completed_value == 99`
- `acked_once`
- `event_count >= 6`

Wire the module with:

- path: `examples/workflow_queue_worker.zig`
- binary name: `zigeffect-workflow-queue-worker-example`
- test name: `zigeffect-workflow-queue-worker-example-tests`

- [x] **Step 2: Run the failing example gate**

Run:

```bash
(cd packages/zigeffect && zig build examples)
```

Expected: FAIL from `error.ExpectedQueueWorkerScenario`.

- [x] **Step 3: Implement the durable queue scenario**

Implement:

- `Payload = struct { account_id: u64 }`;
- `Email = fx.workflow.Queue("email", Payload, u64, error{DeliveryFailed})`
  with idempotency key `"email:{account_id}"`;
- payload codec as decimal account id;
- result codec as decimal `u64`;
- in-memory journal with `workflow_started`;
- first `WorkflowContext.queue` call returning `.suspended`;
- `DurableQueue.claim(Email, payload_codec, "worker-a")` returning the offered
  item;
- `DurableQueue.complete(Email, item_id, result_codec, 99)`;
- second `WorkflowContext.queue` call returning `.completed`;
- third `WorkflowContext.queue` call returning the same `.completed` value;
- a final read of journal events proving exactly one `queue_acked` event.

- [x] **Step 4: Verify and commit**

Run:

```bash
(cd packages/zigeffect && zig build examples)
zig fmt --check packages/zigeffect/examples/workflow_queue_worker.zig packages/zigeffect/build.zig
```

Expected: PASS.

Commit:

```bash
git add packages/zigeffect/examples/workflow_queue_worker.zig packages/zigeffect/build.zig
git diff --cached --check
git commit -m "example(zigeffect): add durable queue worker"
```

## Task 3: Timer And Signal Workflow Example

**Files:**

- Create: `packages/zigeffect/examples/workflow_timer_signal.zig`
- Modify: `packages/zigeffect/build.zig`

- [x] **Step 1: Add the failing example shell and build wiring**

Create `workflow_timer_signal.zig` with:

```zig
const TimerSignalReport = struct {
    timer_id: fx.workflow.TimerId,
    fired_timers: usize,
    signal_value: u64,
    timer_events: usize,
    signal_events: usize,
};
```

Add `runTimerSignalExample(allocator: std.mem.Allocator) !TimerSignalReport`
that returns `error.ExpectedTimerSignalScenario`, a `main`, and a test named:

```zig
test "timer and signal workflow resumes both durable waits" { ... }
```

The test asserts:

- `timer_id == fx.workflow.timerId("review-timeout")`
- `fired_timers == 1`
- `signal_value == 7`
- `timer_events >= 2`
- `signal_events >= 1`

Wire the module with:

- path: `examples/workflow_timer_signal.zig`
- binary name: `zigeffect-workflow-timer-signal-example`
- test name: `zigeffect-workflow-timer-signal-example-tests`

- [x] **Step 2: Run the failing example gate**

Run:

```bash
(cd packages/zigeffect && zig build examples)
```

Expected: FAIL from `error.ExpectedTimerSignalScenario`.

- [x] **Step 3: Implement the timer and signal scenario**

Implement:

- fake clock starting at `1_000`;
- in-memory journal with `workflow_started`;
- `WorkflowContext.sleep("review-timeout", 250)` returning `.suspended`;
- `DurableClock.dueTimers(1_249)` returning zero timers;
- `DurableClock.fireDueTimers(1_250)` returning one fired timer;
- replayed `WorkflowContext.sleep("review-timeout", 250)` returning `.fired`;
- `Approval = fx.workflow.Signal("approval", u64)`;
- `WorkflowContext.waitForSignal(Approval, codec)` returning `.suspended`;
- `DurableSignal.send(Approval, codec, 7, "signal:approval:7")`;
- replayed `waitForSignal` returning `.received`.

Count timer events from `.timer_scheduled` and `.timer_fired`, and signal
events from `.signal_received`.

- [x] **Step 4: Verify and commit**

Run:

```bash
(cd packages/zigeffect && zig build examples)
zig fmt --check packages/zigeffect/examples/workflow_timer_signal.zig packages/zigeffect/build.zig
```

Expected: PASS.

Commit:

```bash
git add packages/zigeffect/examples/workflow_timer_signal.zig packages/zigeffect/build.zig
git diff --cached --check
git commit -m "example(zigeffect): add timer signal workflow"
```

## Task 4: Local Actor Example

**Files:**

- Create: `packages/zigeffect/examples/local_actor.zig`
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Add the failing example shell and build wiring**

Create `local_actor.zig` with:

```zig
const LocalActorReport = struct {
    address: fx.EntityAddress,
    processed: usize,
    final_value: u64,
    reply_payload: []const u8,
};
```

Add `runLocalActorExample(allocator: std.mem.Allocator) !LocalActorReport`
that returns `error.ExpectedLocalActorScenario`, a `main`, and a test named:

```zig
test "local actor processes tell ask state and reply" { ... }
```

The test asserts:

- `processed == 2`
- `final_value == 1`
- `reply_payload` equals `"value=1"`

Wire the module with:

- path: `examples/local_actor.zig`
- binary name: `zigeffect-local-actor-example`
- test name: `zigeffect-local-actor-example-tests`

- [ ] **Step 2: Run the failing example gate**

Run:

```bash
(cd packages/zigeffect && zig build examples)
```

Expected: FAIL from `error.ExpectedLocalActorScenario`.

- [ ] **Step 3: Implement the local actor scenario**

Implement:

- `LocalEntityRuntime.init(allocator, .{})`;
- `address = fx.entityAddress("counter", "local-example")`;
- `runtime.registerEntity(.{ .address = address, .name = "counter-local-example" }, 1_000)`;
- `counter_value: u64 = 0` stored through entity scope key `"counter-value"`;
- `ref.tell("text", "inc", "increment counter")`;
- `ref.ask("text", "get", "read counter")`;
- handler that increments state on payload `"inc"` and replies with
  `"value=1"` on ask;
- two `runtime.processNext(address, Handler, now_ms)` calls;
- `runtime.takeReply(ask.correlation_id)`;
- pending count equals zero.

The report can store `reply_payload = "value=1"` as a static slice.

- [ ] **Step 4: Verify and commit**

Run:

```bash
(cd packages/zigeffect && zig build examples)
zig fmt --check packages/zigeffect/examples/local_actor.zig packages/zigeffect/build.zig
```

Expected: PASS.

Commit:

```bash
git add packages/zigeffect/examples/local_actor.zig packages/zigeffect/build.zig
git diff --cached --check
git commit -m "example(zigeffect): add local actor"
```

## Task 5: Multi-Runner Local Cluster Example

**Files:**

- Create: `packages/zigeffect/examples/multi_runner_cluster.zig`
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Add the failing example shell and build wiring**

Create `multi_runner_cluster.zig` with:

```zig
const MultiRunnerReport = struct {
    runner_a_shards: usize,
    runner_b_shards: usize,
    runner_a_dispatched: usize,
    runner_b_dispatched: usize,
    runner_a_reply: []const u8,
    runner_b_reply: []const u8,
};
```

Add `runMultiRunnerExample(allocator: std.mem.Allocator, dir: *std.Io.Dir) !MultiRunnerReport`
that returns `error.ExpectedMultiRunnerScenario`, a `main` using
`.zig-cache/zigeffect-examples/multi-runner-cluster`, and a test named:

```zig
test "multi runner cluster routes messages through shared storage" { ... }
```

The test asserts:

- `runner_a_shards == 4`
- `runner_b_shards == 4`
- both dispatch counts equal one;
- both replies equal `"value=ok"`.

Wire the module with:

- path: `examples/multi_runner_cluster.zig`
- binary name: `zigeffect-multi-runner-cluster-example`
- test name: `zigeffect-multi-runner-cluster-example-tests`

- [ ] **Step 2: Run the failing example gate**

Run:

```bash
(cd packages/zigeffect && zig build examples)
```

Expected: FAIL from `error.ExpectedMultiRunnerScenario`.

- [ ] **Step 3: Implement the multi-runner scenario**

Implement:

- two `FileRunnerStorage.open` calls over the shared dir;
- two `FileMessageStorage.open` calls over the shared dir;
- runner A at index 0 of 2 and runner B at index 1 of 2, shard count 8;
- `acquireBalancedShards(1_000)` on both runners;
- helper `addressForShard(shard_id, shard_count)` that searches `"entity-{shard}-{index}"`;
- register one entity on shard 0 through runner A and one on shard 1 through
  runner B;
- per-entity `seen` ArrayList services;
- route an ask to each entity through `runner_a.router`;
- handler that records payload and replies `"value=ok"`;
- `runner_a.tick(Handler, 1_100)` and `runner_b.tick(Handler, 1_100)`;
- read replies from the shared message storage.

- [ ] **Step 4: Verify and commit**

Run:

```bash
(cd packages/zigeffect && zig build examples)
zig fmt --check packages/zigeffect/examples/multi_runner_cluster.zig packages/zigeffect/build.zig
```

Expected: PASS.

Commit:

```bash
git add packages/zigeffect/examples/multi_runner_cluster.zig packages/zigeffect/build.zig
git diff --cached --check
git commit -m "example(zigeffect): add multi-runner cluster"
```

## Task 6: Cluster Workflow Migration Example

**Files:**

- Create: `packages/zigeffect/examples/cluster_workflow_migration.zig`
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Add the failing example shell and build wiring**

Create `cluster_workflow_migration.zig` with:

```zig
const ClusterWorkflowMigrationReport = struct {
    workflow_id: fx.workflow.WorkflowId,
    execution_id: fx.workflow.ExecutionId,
    started_status: []const u8,
    recovered_executions: usize,
    completed_status: []const u8,
    final_status: fx.workflow.WorkflowStatus,
};
```

Add `runClusterWorkflowMigrationExample(allocator: std.mem.Allocator, dir: *std.Io.Dir) !ClusterWorkflowMigrationReport`
that returns `error.ExpectedClusterWorkflowMigrationScenario`, a `main` using
`.zig-cache/zigeffect-examples/cluster-workflow-migration`, and a test named:

```zig
test "cluster workflow migrates from runner a to runner b" { ... }
```

The test asserts:

- `started_status` equals `"running"`;
- `recovered_executions == 1`;
- `completed_status` equals `"completed"`;
- `final_status == .completed`.

Wire the module with:

- path: `examples/cluster_workflow_migration.zig`
- binary name: `zigeffect-cluster-workflow-migration-example`
- test name: `zigeffect-cluster-workflow-migration-example-tests`

- [ ] **Step 2: Run the failing example gate**

Run:

```bash
(cd packages/zigeffect && zig build examples)
```

Expected: FAIL from `error.ExpectedClusterWorkflowMigrationScenario`.

- [ ] **Step 3: Implement the cluster workflow migration scenario**

Implement:

- shared `FileRunnerStorage`, `FileMessageStorage`, and
  `workflow.FileJournalStore`;
- runner A with shard count 8 and runner count 1;
- `ClusterWorkflowEntityRegistry.registerExecution` on runner A for
  `workflow_id = fx.workflow.workflowId("approval")` and
  `execution_id = fx.workflow.executionId("approval", "migration")`;
- `InProcessClusterTransport` over runner A message storage;
- `ClusterWorkflowEngine.start("approval", "migration")`;
- helper `processWorkflowSubmission(runner, message_storage, submission, now_ms)`
  that ticks `fx.ClusterWorkflowEntityHandler`, reads the reply, and parses it
  with `fx.parseClusterWorkflowCommandResultFromReply`;
- runner A shutdown;
- runner B over the same dir and same journal;
- `ClusterWorkflowEntityRegistry.recoverOwnedExecutions` on runner B;
- `engine.complete(workflow_id, execution_id, "value=approved-after-migration")`;
- final `journal_store.latestState`.

- [ ] **Step 4: Verify and commit**

Run:

```bash
(cd packages/zigeffect && zig build examples)
zig fmt --check packages/zigeffect/examples/cluster_workflow_migration.zig packages/zigeffect/build.zig
```

Expected: PASS.

Commit:

```bash
git add packages/zigeffect/examples/cluster_workflow_migration.zig packages/zigeffect/build.zig
git diff --cached --check
git commit -m "example(zigeffect): add cluster workflow migration"
```

## Task 7: README, Roadmap, And Full Verification

**Files:**

- Modify: `packages/zigeffect/README.md`
- Modify: `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
- Modify: `docs/superpowers/plans/2026-06-10-zigeffect-end-to-end-examples.md`

- [ ] **Step 1: Update README example list**

Add the six new examples to the README docs list:

```markdown
- [Workflow Approval Example](examples/workflow_approval.zig)
- [Workflow Queue Worker Example](examples/workflow_queue_worker.zig)
- [Workflow Timer Signal Example](examples/workflow_timer_signal.zig)
- [Local Actor Example](examples/local_actor.zig)
- [Multi-Runner Cluster Example](examples/multi_runner_cluster.zig)
- [Cluster Workflow Migration Example](examples/cluster_workflow_migration.zig)
```

Keep the existing `zig build examples` command as the aggregate example gate.

- [ ] **Step 2: Mark M44 complete**

Update the M44 roadmap block:

```markdown
- [x] Add local approval workflow example.
- [x] Add durable queue worker example.
- [x] Add timer and signal workflow example.
- [x] Add local actor example.
- [x] Add multi-runner cluster example.
- [x] Add cluster workflow migration example.
```

and:

```markdown
- [x] `zig build examples` compiles and runs all examples.
```

- [ ] **Step 3: Run full verification**

Run:

```bash
(cd packages/zigeffect && zig build examples)
bun run zigeffect:test
bun run zig:test
zig fmt --check \
  packages/zigeffect/examples/workflow_approval.zig \
  packages/zigeffect/examples/workflow_queue_worker.zig \
  packages/zigeffect/examples/workflow_timer_signal.zig \
  packages/zigeffect/examples/local_actor.zig \
  packages/zigeffect/examples/multi_runner_cluster.zig \
  packages/zigeffect/examples/cluster_workflow_migration.zig \
  packages/zigeffect/build.zig
git diff --check
rg -n 'T''BD|TO''DO|FIX''ME|st''ub|place''holder|not imple''mented|unimple''mented|fi''ll in|add app''ropriate|sim''ilar to' \
  packages/zigeffect/examples/workflow_approval.zig \
  packages/zigeffect/examples/workflow_queue_worker.zig \
  packages/zigeffect/examples/workflow_timer_signal.zig \
  packages/zigeffect/examples/local_actor.zig \
  packages/zigeffect/examples/multi_runner_cluster.zig \
  packages/zigeffect/examples/cluster_workflow_migration.zig \
  packages/zigeffect/build.zig \
  packages/zigeffect/README.md \
  docs/superpowers/specs/2026-06-10-zigeffect-end-to-end-examples-design.md \
  docs/superpowers/plans/2026-06-10-zigeffect-end-to-end-examples.md \
  docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md
git status --short
```

Expected: build and test commands pass, format and diff checks pass, marker
scan exits with no matches, and only intentional docs remain uncommitted before
the final docs commit.

- [ ] **Step 4: Commit docs**

Commit:

```bash
git add packages/zigeffect/README.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md docs/superpowers/plans/2026-06-10-zigeffect-end-to-end-examples.md
git diff --cached --check
git commit -m "docs(zigeffect): mark end-to-end examples complete"
```

## Self-Review

- The plan covers every M44 deliverable with a dedicated example file.
- Every example has a test that runs through `zig build examples`.
- Build wiring follows the existing package pattern.
- File-backed examples use temp dirs in tests and `.zig-cache/zigeffect-examples`
  paths in `main`.
- The final gate includes package examples, package tests, repo Zig tests,
  formatting, diff hygiene, marker scan, and status.
