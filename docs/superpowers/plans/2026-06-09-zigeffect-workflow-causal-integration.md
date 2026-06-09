# zigeffect Workflow Causal Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Map durable workflow journal histories into the existing causal runtime, causal query tools, DOT graphs, and dogfood artifacts.

**Architecture:** Add `workflow/causal.zig` as a durable journal to causal event adapter. Extend `services/causal.zig` with one structural workflow event kind, then reuse `CausalStore`, `formatCausalReport`, `formatCausalJson`, and `formatCausalDot`. Extend `causal_query.zig` and the causal dogfood harness with workflow-aware queries and a deterministic crash-recovery scenario.

**Tech Stack:** Zig 0.16, existing workflow journal/replay/inspect modules, existing causal store/query/DOT/dogfood modules, Bun project scripts.

---

## File Structure

- Create `packages/zigeffect/src/workflow/causal.zig`
  - Owns workflow event to causal event mapping, store building, report
    formatting, JSON formatting, DOT formatting, and workflow finding helpers.
- Modify `packages/zigeffect/src/workflow/root.zig`
  - Exposes workflow causal mapping/report helpers.
- Modify `packages/zigeffect/src/services/causal.zig`
  - Adds `workflow_event_recorded` to `CausalEventKind` and taxonomy.
- Modify `packages/zigeffect/src/zigeffect.zig`
  - Exposes any new causal event kind through the existing facade.
- Modify `packages/zigeffect/tools/causal_query.zig`
  - Adds `workflow` and `workflow-findings` queries.
- Modify `packages/zigeffect/tools/causal_test.zig`
  - Adds workflow crash-recovery dogfood scenario artifacts.
- Modify `packages/zigeffect/tools/causal_run.zig`
  - Adds a stable scenario registry entry when the harness requires one.
- Modify `packages/zigeffect/test/workflow_test.zig`
  - Adds workflow causal mapping and DOT tests.
- Modify `packages/zigeffect/docs/architecture.md`
  - Documents workflow causal adapter ownership.
- Modify `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
  - Marks Milestone 19 complete after verification.

## Task 1: Causal Event Kind And Workflow Mapping

**Files:**
- Modify `packages/zigeffect/src/services/causal.zig`
- Create `packages/zigeffect/src/workflow/causal.zig`
- Modify `packages/zigeffect/src/workflow/root.zig`
- Modify `packages/zigeffect/test/workflow_test.zig`

- [x] **Step 1: Write failing workflow mapping test**

Add `workflow causal mapping links journal events to causal ids`. Build workflow
events for start, suspend, resume, activity retry, and failure. Assert mapped
causal events have:

```text
kind: workflow_event_recorded
run_id: 7
scope_id: 8
trace_id: 7
span_id: workflow sequence
parent_id: parent_sequence when present
type_name: workflow.<workflow_event_kind>
```

- [x] **Step 2: Verify red**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: FAIL because `workflow_event_recorded` and workflow causal mapping do
not exist.

- [x] **Step 3: Implement event kind and mapper**

Add `.workflow_event_recorded` to `CausalEventKind` and classify it as
structural, finding evidence, and not sampleable. Add:

```zig
pub fn mapWorkflowEventToCausal(event: journal_mod.WorkflowEvent) causal_mod.CausalEvent
pub fn mapWorkflowEventsToCausal(allocator: Allocator, events: []const journal_mod.WorkflowEvent) Allocator.Error!causal_mod.CausalSnapshot
```

- [x] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

## Task 2: Workflow Causal Reports, Findings, And DOT

**Files:**
- Modify `packages/zigeffect/src/workflow/causal.zig`
- Modify `packages/zigeffect/test/workflow_test.zig`

- [ ] **Step 1: Write failing report and DOT tests**

Add tests for:

- `workflow causal report explains failure retry suspend and resume`
- `workflow causal dot renders workflow history`

The report test asserts text contains `workflow_failed`,
`activity_retry_scheduled`, `workflow_suspended`, and `workflow_resumed`. The
DOT test asserts `digraph zigeffect_causal`, `workflow.workflow_failed`, and a
parent edge from the workflow start to a later workflow row.

- [ ] **Step 2: Verify red**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: FAIL because workflow causal report and DOT helpers do not exist.

- [ ] **Step 3: Implement report, JSON, findings, and DOT helpers**

Add:

```zig
pub fn buildWorkflowCausalStore(allocator: Allocator, events: []const journal_mod.WorkflowEvent) !causal_mod.CausalStore
pub fn formatWorkflowCausalReport(allocator: Allocator, events: []const journal_mod.WorkflowEvent) ![]const u8
pub fn formatWorkflowCausalJson(allocator: Allocator, events: []const journal_mod.WorkflowEvent) ![]const u8
pub fn formatWorkflowCausalDot(allocator: Allocator, events: []const journal_mod.WorkflowEvent) ![]const u8
```

The report helper calls `formatCausalReport`. The JSON helper calls
`formatCausalJson`. The DOT helper calls `formatCausalDot`.

- [ ] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

## Task 3: Causal Query Workflow Filters

**Files:**
- Modify `packages/zigeffect/tools/causal_query.zig`

- [ ] **Step 1: Write failing query tests**

Add tests:

- `causal query selects workflow events by run`
- `causal query selects workflow findings by run`

Use JSON with `workflow_event_recorded` events for suspend, resume, retry, and
failure. Assert query output includes the matching workflow events and excludes
other runs.

- [ ] **Step 2: Verify red**

Run:

```bash
cd packages/zigeffect && zig build examples --summary all
```

Expected: FAIL because `workflow` and `workflow-findings` queries are missing.

- [ ] **Step 3: Implement query filters**

Add query names:

```text
workflow <run_id>
workflow-findings <run_id>
```

`workflow` filters `kind == "workflow_event_recorded"` and `run_id`.
`workflow-findings` filters workflow causal events whose `type_name` or status
represents failure, retry, suspend, or resume evidence.

- [ ] **Step 4: Verify green**

Run:

```bash
cd packages/zigeffect && zig build examples --summary all
```

Expected: PASS.

## Task 4: Workflow Crash-Recovery Dogfood Scenario

**Files:**
- Modify `packages/zigeffect/tools/causal_test.zig`
- Modify `packages/zigeffect/tools/causal_run.zig` if the scenario registry
  needs a new entry.

- [ ] **Step 1: Write failing dogfood tests**

Add tests that build workflow crash-recovery artifacts and assert:

- text report mentions workflow crash recovery;
- JSON contains `workflow_event_recorded`;
- DOT contains `workflow.workflow_suspended` and `workflow.workflow_resumed`;
- causal findings mention workflow failure and retry evidence.

- [ ] **Step 2: Verify red**

Run:

```bash
cd packages/zigeffect && zig build examples --summary all
```

Expected: FAIL because workflow dogfood artifacts are not implemented.

- [ ] **Step 3: Implement dogfood scenario**

Build deterministic workflow journal rows in the tool, map them through
`formatWorkflowCausalReport`, `formatWorkflowCausalJson`, and
`formatWorkflowCausalDot`, and expose them through the causal artifact manifest
or scenario registry with the slug `workflow-crash-recovery`.

- [ ] **Step 4: Verify green**

Run:

```bash
cd packages/zigeffect && zig build examples --summary all
```

Expected: PASS.

## Task 5: Docs, Roadmap, Full Gate, And Commit

**Files:**
- Modify `packages/zigeffect/docs/architecture.md`
- Modify `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
- Add `docs/superpowers/specs/2026-06-09-zigeffect-workflow-causal-integration-design.md`
- Add `docs/superpowers/plans/2026-06-09-zigeffect-workflow-causal-integration.md`

- [ ] **Step 1: Update architecture docs**

Document `workflow/causal.zig` ownership and query/dogfood reuse of causal
tooling.

- [ ] **Step 2: Run full gate**

Run:

```bash
bun run zigeffect:test
cd packages/zigeffect && zig build examples
cd packages/zigeffect && zig build causal-query -- --file .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json workflow 1
cd packages/zigeffect && zig build causal-query -- --file .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json workflow-findings 1
bun run zig:test
zig fmt --check packages/zigeffect/src/workflow/causal.zig packages/zigeffect/src/workflow/root.zig packages/zigeffect/src/services/causal.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/tools/causal_query.zig packages/zigeffect/tools/causal_test.zig packages/zigeffect/tools/causal_run.zig packages/zigeffect/test/workflow_test.zig
git diff --check
rg -n 'T''BD|TO''DO|implement la''ter|fill in de''tails|appropriate error hand''ling|handle edge ca''ses|Similar to Ta''sk|deferred bu''cket|par''ked' packages/zigeffect/src/workflow packages/zigeffect/src/services packages/zigeffect/tools packages/zigeffect/test/workflow_test.zig packages/zigeffect/docs/architecture.md docs/superpowers/specs/2026-06-09-zigeffect-workflow-causal-integration-design.md docs/superpowers/plans/2026-06-09-zigeffect-workflow-causal-integration.md
```

Expected: compile/test commands PASS, causal workflow queries print workflow
events/findings, format and diff checks exit 0, and the placeholder scan exits 1
with no matches.

- [ ] **Step 3: Mark Milestone 19 complete**

After the full gate passes, mark all Milestone 19 deliverables and acceptance
boxes complete in
`docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`.

- [ ] **Step 4: Commit**

Run:

```bash
git add docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md docs/superpowers/plans/2026-06-09-zigeffect-workflow-causal-integration.md docs/superpowers/specs/2026-06-09-zigeffect-workflow-causal-integration-design.md packages/zigeffect/docs/architecture.md packages/zigeffect/src/workflow/causal.zig packages/zigeffect/src/workflow/root.zig packages/zigeffect/src/services/causal.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/tools/causal_query.zig packages/zigeffect/tools/causal_test.zig packages/zigeffect/tools/causal_run.zig packages/zigeffect/test/workflow_test.zig
git commit -m "feat(zigeffect): add workflow causal integration"
```
