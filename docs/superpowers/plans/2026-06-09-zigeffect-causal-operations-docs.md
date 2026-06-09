# zigeffect Causal Operations Docs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a single operations manual for the current local/CI zigeffect causal runtime operating model and link it from existing docs.

**Architecture:** This is a docs-only M9 branch. Create `packages/zigeffect/docs/operations.md` as the operational front door, then update the README, agent docs, scenario docs, schema governance docs, package roadmap, and master roadmap to point at it. Preserve current authority boundaries: local/CI, record-only application evidence, SolidJS plus `webui-dev/zig-webui` workbench, and NenDB-only durable direction for now.

**Tech Stack:** Markdown documentation, existing Zig/Bun verification commands.

---

## File Structure

- Create: `packages/zigeffect/docs/operations.md`
  - Owns the local/CI causal operations runbook and links to deeper docs.
- Modify: `packages/zigeffect/README.md`
  - Adds the operations manual to the docs list and short command area.
- Modify: `packages/zigeffect/docs/agent-guide.md`
  - Adds an agent-facing rule to use the operations manual for handoff and authority boundaries.
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
  - Links M9 operating practice to the operations manual.
- Modify: `packages/zigeffect/docs/causal-scenarios.md`
  - Links scenario artifact retention and scenario governance to the operations manual.
- Modify: `packages/zigeffect/docs/schema-governance.md`
  - Links schema changes to operational artifact retention and workbench procedures.
- Modify: `packages/zigeffect/docs/roadmap.md`
  - Marks operations docs delivered and leaves performance budget next.
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
  - Updates M9 progress and immediate queue.

---

### Task 1: Add The Operations Manual

**Files:**
- Create: `packages/zigeffect/docs/operations.md`

- [ ] **Step 1: Create the operations manual**

Create `packages/zigeffect/docs/operations.md` with these sections:

```md
# zigeffect Causal Operations

## Scope And Authority

## Command Map

## Local Development Runbook

## CI Failure Handoff

## Artifact Retention And Sharing

## Redaction Review

## Human Review And Guarded Application

## Workbench Operation

## Backend Adapter Operations

## Scenario And Invariant Governance

## Schema Governance

## Production Gaps
```

The manual must include these exact operating facts:

- Current authority is local/CI and record-only.
- CI has `contents: read`.
- CI uploads only `.txt`, `.json`, and `.dot` from
  `packages/zigeffect/.zig-cache/causal-artifacts/`.
- CI retention is 14 days.
- First-read CI order is verdict JSON, handoff TXT, generated advice, compare
  reports, then source JSON through `causal-query`.
- Redaction runs before store retention and backend emission.
- The workbench is SolidJS through `webui-dev/zig-webui`, bounded to one
  read-only artifact, and not a mutation surface.
- Backend adapters are sinks; the deterministic store is authoritative.
- NenDB support is a writer contract/adapter-test boundary only in this branch.
- `applied=true` appears only in guarded `record-applied` records after
  readiness, current-state evidence, and verification evidence.
- No Cockroach adapter, production alerting, production mutation authority, or
  durable production retention is added by this branch.

- [ ] **Step 2: Check manual coverage**

Run:

```sh
rg -n "Scope And Authority|CI Failure Handoff|Artifact Retention And Sharing|Redaction Review|Human Review And Guarded Application|Workbench Operation|Backend Adapter Operations|Scenario And Invariant Governance|Schema Governance|Production Gaps" packages/zigeffect/docs/operations.md
```

Expected: one hit for each section heading.

---

### Task 2: Link Existing Docs To Operations

**Files:**
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
- Modify: `packages/zigeffect/docs/causal-scenarios.md`
- Modify: `packages/zigeffect/docs/schema-governance.md`

- [ ] **Step 1: Update README**

Add `Causal Operations` to the documentation links near the existing zigeffect
docs list:

```md
- [Causal Operations](docs/operations.md)
```

Add this paragraph near the causal artifact/CI command area:

```md
For the full local/CI operating contract, use
[docs/operations.md](docs/operations.md). It defines artifact retention,
failure handoff order, redaction review, review gates, guarded application
records, workbench operation, backend adapter expectations, and production
gaps.
```

- [ ] **Step 2: Update agent guide**

Add this paragraph near the CI artifact retention/handoff section:

```md
Use [operations.md](operations.md) as the first-read operating contract for
handoffs. It defines which artifacts may be shared, which file to read first,
when `applied=true` may be recorded, and which production behaviors are still
out of scope.
```

- [ ] **Step 3: Update observable runtime docs**

Add this paragraph near the CI/local tool section:

```md
The current production operating model is documented in
[operations.md](operations.md). It is local/CI, record-only, and explicit about
artifact sharing, review gates, workbench operation, backend sink contracts,
and production gaps.
```

- [ ] **Step 4: Update scenario docs**

Add this paragraph near artifact retention or scenario governance:

```md
For handoff, retention, redaction review, guarded application, and CI first-read
order, use [operations.md](operations.md). This scenario guide remains the
registry and invariant reference.
```

- [ ] **Step 5: Update schema governance docs**

Add this paragraph near the command or checklist section:

```md
When a schema change affects retained artifacts, CI upload behavior, workbench
mapping, or agent handoff, also update [operations.md](operations.md).
```

- [ ] **Step 6: Check links**

Run:

```sh
rg -n "operations\\.md" packages/zigeffect/README.md packages/zigeffect/docs/agent-guide.md packages/zigeffect/docs/agent-observable-runtime.md packages/zigeffect/docs/causal-scenarios.md packages/zigeffect/docs/schema-governance.md
```

Expected: one or more hits in every listed file.

---

### Task 3: Update Roadmaps

**Files:**
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Update package roadmap**

In the causal runtime delivered list, add:

```md
- Delivered: `docs/operations.md` is the local/CI causal runtime operations
  manual for artifact retention, CI handoff, redaction review, review gates,
  guarded application records, workbench operation, backend adapter
  expectations, schema governance, and scenario governance.
```

Keep performance budgets and deeper production integrations in future work.

- [ ] **Step 2: Update master roadmap M9 ledger**

Change the M9 row to:

```md
| M9 Operating model | active | schema governance and operations docs exist; performance budget and release template remain | move to performance budget |
```

Update the immediate branch queue to:

```md
1. `codex/zigeffect-causal-performance-budget`
   - Add measurable causal instrumentation overhead budgets and release-note
     guidance before declaring the operating model production-grade.
```

- [ ] **Step 3: Check roadmap wording**

Run:

```sh
rg -n "operations docs exist|causal-performance-budget|docs/operations\\.md|performance budget" packages/zigeffect/docs/roadmap.md docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
```

Expected: roadmap hits proving operations docs delivered and performance budget remains next.

---

### Task 4: Verify And Commit

**Files:**
- All files changed by Tasks 1 through 3.

- [ ] **Step 1: Run docs structure checks**

Run:

```sh
rg -n "contents: read|retention-days: 14|<redacted>|webui-dev/zig-webui|record-applied|NenDB|No Cockroach" packages/zigeffect/docs/operations.md
rg -n "operations\\.md" packages/zigeffect/README.md packages/zigeffect/docs/agent-guide.md packages/zigeffect/docs/agent-observable-runtime.md packages/zigeffect/docs/causal-scenarios.md packages/zigeffect/docs/schema-governance.md
```

Expected: all required phrases are present.

- [ ] **Step 2: Run full verification**

Run:

```sh
bun run check
bun run zig:test
git diff --check
```

Expected: all commands exit 0.

- [ ] **Step 3: Inspect git status**

Run:

```sh
git status --short --branch
```

Expected: only intended operations-docs files are modified or added. The
pre-existing unrelated untracked durable roadmap file remains untracked and
unstaged.

- [ ] **Step 4: Commit implementation**

Stage only intended files:

```sh
git add packages/zigeffect/docs/operations.md \
  packages/zigeffect/README.md \
  packages/zigeffect/docs/agent-guide.md \
  packages/zigeffect/docs/agent-observable-runtime.md \
  packages/zigeffect/docs/causal-scenarios.md \
  packages/zigeffect/docs/schema-governance.md \
  packages/zigeffect/docs/roadmap.md \
  docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
```

Commit:

```sh
git commit -m "docs(zigeffect): add causal operations manual"
```

Expected: commit succeeds and the unrelated durable roadmap file remains
untracked.
