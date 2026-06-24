# zigeffect Hardening Milestones Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Harden zigeffect's central claim: the same program runs on deterministic, zio-coroutine, and OS-thread executors while producing a trustworthy causal graph that agents can query and humans can inspect live.

**Architecture:** Work proceeds from proof surface to distributed boundary. First keep documentation truthful, then strengthen the structural comparator, prove live browser rendering, cross a real loopback socket, harden redaction, and finally broaden the small honesty gate that keeps agents from producing motion-shaped artifacts.

**Tech Stack:** Zig 0.16-style APIs in `packages/zigeffect`, zio adapter code in `packages/zigeffect-zio`, Bun/SolidJS workbench code in `packages/zigeffect/workbench`, Bash hygiene checks, and `bun:test` for workbench tests.

---

## File Structure

- Modify: `packages/zigeffect/docs/roadmap.md` for the canonical M0-M5 roadmap and acceptance criteria.
- Modify: `docs/superpowers/2026-06-24-future-agent-briefing.md` for agent handoff sequencing.
- Modify: `packages/zigeffect/src/services/causal_structural.zig` for structural fact extraction and comparison.
- Modify: `packages/zigeffect/test/causal_structural_test.zig` for red/green comparator regressions.
- Modify: `packages/zigeffect/workbench/src/liveAttach.ts` and workbench tests for live-browser proof.
- Add: `docs/superpowers/specs/2026-06-24-zigeffect-live-debugging-browser-proof.md` and `.png` for the captured browser proof.
- Modify: `packages/zigeffect/src/cluster/transport.zig` for the loopback socket transport.
- Modify: `packages/zigeffect/test/cluster_transport_test.zig` for loopback transport conformance and trace equivalence.
- Add: `packages/zigeffect/test/causal_redaction_sentinel_test.zig` for cross-export secret leakage coverage.
- Modify: `packages/zigeffect/workbench/src/collector/frame.ts` and tests for workbench payload redaction.

---

### Task 0: Status Truth and Roadmap Hygiene

**Files:**
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `docs/superpowers/2026-06-24-future-agent-briefing.md`
- Modify as found: stale comments in `packages/zigeffect/**`

- [x] **Step 1: Add M0-M5 milestones to the roadmap**

Record these milestones in `packages/zigeffect/docs/roadmap.md`:

```text
M0 Status truth and roadmap hygiene
M1 Stronger structural equivalence
M2 Live debugging browser proof
M3 One real loopback cluster transport
M4 Secret and trace redaction hardening
M5 Broader agent honesty gate
```

- [x] **Step 2: Mirror the milestone order in the future-agent briefing**

Update `docs/superpowers/2026-06-24-future-agent-briefing.md` so a future agent starts with status truth, then structural equivalence, live proof, loopback transport, redaction, and the honesty gate.

- [x] **Step 3: Sweep for stale current-status claims**

Run:

```bash
rg -n "not yet built|unsupported|human still needs|manual confirmation|future adapter work" \
  packages/zigeffect packages/zigeffect-zio docs/superpowers/2026-06-24-future-agent-briefing.md
```

Expected: any remaining matches are either historical context or accurately describe an open milestone.

- [x] **Step 4: Verify docs and hygiene gates**

Run:

```bash
git diff --check
packages/zigeffect/tools/check_tool_hygiene.sh
```

Expected: both commands pass.

---

### Task 1: Stronger Structural Equivalence

**Files:**
- Modify: `packages/zigeffect/test/causal_structural_test.zig`
- Modify: `packages/zigeffect/src/services/causal_structural.zig`
- Verify: existing executor tests that call `fx.causalStructurallyEquivalent`

- [x] **Step 1: Add red regression tests**

Add tests showing that traces with the same event kinds, cause-kind pairs, and
terminal fiber states are not equivalent when they differ in:

```text
parent/lineage shape
scope/resource pairing
fiber ownership under a scope
important finding-evidence ownership
```

- [x] **Step 2: Run the focused test and confirm RED**

Run:

```bash
cd packages/zigeffect && zig build test-raw
```

Expected: the new structural-equivalence tests fail because the comparator still
accepts at least one false-positive pair.

- [x] **Step 3: Add semantic graph facts**

Extend `buildFacts` in `packages/zigeffect/src/services/causal_structural.zig`
with id-insensitive facts for:

```text
parent:<parent-kind>-><child-kind>
scope-event:<kind>:<same-scope-shape>
resource-pair:<acquire-kind>:<finalize-kind>:<same-resource-or-scope>
fiber-scope-terminal:<terminal-kind>:<same-scope-presence>
finding-evidence:<kind>:<scope/fiber/resource presence>
```

Keep event ids out of fact keys so deterministic and real schedulers can still
reorder events.

- [x] **Step 4: Run focused and executor-equivalence tests**

Run:

```bash
cd packages/zigeffect && zig build test-raw
```

Expected: the new regression tests pass, and existing deterministic/zio/thread-pool
structural-equivalence tests remain green.

---

### Task 2: Live Debugging Browser Proof

**Files:**
- Modify: `packages/zigeffect/workbench/src/liveAttach.ts`
- Add: `packages/zigeffect/workbench/src/liveAttach.e2e.test.ts` if Playwright or equivalent browser automation is already available.
- Add alternative: `docs/superpowers/specs/2026-06-24-zigeffect-live-debugging-browser-proof.md` if automation is blocked.

- [x] **Step 1: Verify existing workbench test runner**

Run:

```bash
bun run zigeffect:workbench:test
```

Expected: existing workbench tests pass before adding browser coverage.

- [x] **Step 2: Add browser-level proof**

Captured a browser proof with the Codex in-app browser: Vite workbench at
`?live=ws://127.0.0.1:4500/live`, Bun collector on port 4500, and freshly
generated `zig build live-stream` NDJSON posted through `/ingest`.

- [x] **Step 3: Verify live proof**

Run:

```bash
bun run zigeffect:workbench:test
bun run zigeffect:workbench:build
```

Expected: tests and build pass, or the proof doc contains exact reproduction
commands and screenshots. Delivered screenshot:
`docs/superpowers/specs/2026-06-24-zigeffect-live-debugging-browser-proof.png`.

---

### Task 3: One Real Loopback Cluster Transport

**Files:**
- Modify: `packages/zigeffect/src/cluster/transport.zig`
- Modify: `packages/zigeffect/src/cluster/root.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`
- Modify: `packages/zigeffect/test/cluster_transport_test.zig`

- [x] **Step 1: Write a loopback conformance test**

Create a test that sends a cluster message through a real localhost socket and
asserts that the receive side observes the same envelope fields as the in-memory
transport.

- [x] **Step 2: Confirm RED**

Run:

```bash
cd packages/zigeffect && zig build test-raw
```

Expected: the loopback transport type or constructor is missing.

- [x] **Step 3: Implement the minimal socket transport**

Implemented `LoopbackSocketClusterTransport` in the core package behind the
existing `ClusterTransport` vtable. It uses the same `ZIGFX/1` frame format over
localhost TCP and keeps limits, close ordering, and metrics explicit.

- [x] **Step 4: Compare causal traces**

Run an in-memory cluster scenario and the same loopback scenario, then assert
`fx.causalStructurallyEquivalent` over their traces.

---

### Task 4: Secret and Trace Redaction Hardening

**Files:**
- Add: `packages/zigeffect/test/causal_redaction_sentinel_test.zig`
- Modify: `packages/zigeffect/src/services/causal.zig` if the redaction boundary misses a sentinel.
- Modify: exporters only when tests prove an exporter bypasses the boundary.

- [x] **Step 1: Add sentinel corpus tests**

Use fake values such as:

```text
sk-test-1234567890
Bearer secret-token-123
postgresql://user:password@example.invalid/db
session_id=secret-session-123
```

Assert none of them appear in supported causal export payloads.

- [x] **Step 2: Confirm RED only if a leak exists**

Run:

```bash
cd packages/zigeffect && zig build test-raw
```

Expected: either a real leak fails the test, or the test passes and becomes a
regression guard.

- [x] **Step 3: Fix leaks at the causal boundary**

Prefer sanitizing event detail/metadata before exporter-specific code sees it.
Transport auth credentials now serialize as the causal redaction marker, and
collector `LiveFrame` labels sanitize known secret shapes before the browser sees
them.

---

### Task 5: Broader Agent Honesty Gate

**Files:**
- Modify: `packages/zigeffect/tools/check_tool_hygiene.sh`
- Modify: `packages/zigeffect/tools/check_tool_hygiene_test.sh`

- [x] **Step 1: Add failing hygiene regression fixtures**

Create temporary files inside the hygiene test for stale current-status claims
and repeated report-tool naming patterns.

- [x] **Step 2: Confirm RED**

Run:

```bash
bash packages/zigeffect/tools/check_tool_hygiene_test.sh
```

Expected: the new fixture passes before the checker understands the new rule,
so the test script fails.

- [x] **Step 3: Implement narrow checks**

Extend the checker with hardcoded, source-backed stale-claim patterns. Avoid
general prose linting; this gate only catches known failure modes.

- [x] **Step 4: Verify**

Run:

```bash
bash -n packages/zigeffect/tools/check_tool_hygiene.sh
bash packages/zigeffect/tools/check_tool_hygiene_test.sh
packages/zigeffect/tools/check_tool_hygiene.sh
```

Expected: all pass.

---

## Self-Review

- Spec coverage: all five requested tracks are represented as milestones M1-M5, with M0 added for ongoing doc truth.
- Placeholder scan: no `TBD`, `TODO`, or "implement later" placeholders remain.
- Type consistency: the plan uses existing names where known (`causalStructurallyEquivalent`, `ClusterTransport`, `LiveFrame`) and explicitly leaves file placement to existing package structure where the repo does not yet have a zio test directory.
