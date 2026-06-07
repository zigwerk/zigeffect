# zigeffect Causal Before/After Compare Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `zig build causal-compare -- <before.json> <after.json>` so agents can compare saved causal artifacts before and after zigeffect changes.

**Architecture:** Create a focused `causal_compare.zig` tool that parses the existing causal JSON event shape, computes event and finding deltas, formats a stable text report, and exposes a Zig build step. Keep comparison independent from `causal_query.zig` so query and diff logic remain separately testable.

**Tech Stack:** Zig 0.16, `std.json.parseFromSlice`, `std.process.Init`, `std.Io.Dir`, existing zigeffect build/tool patterns.

---

## File Structure

- Create `packages/zigeffect/tools/causal_compare.zig`
  Owns JSON parsing, finding count recomputation, event diffing, report
  formatting, CLI behavior, and tests.
- Modify `packages/zigeffect/build.zig`
  Adds `causal-compare` and includes compare tool tests in `examples`.
- Modify `packages/zigeffect/README.md`
  Documents the compare command.
- Modify `packages/zigeffect/docs/agent-guide.md`
  Explains before/after comparison in the agent workflow.
- Modify `packages/zigeffect/docs/agent-observable-runtime.md`
  Updates Phase 0 with compare support.
- Modify `packages/zigeffect/docs/causal-scenarios.md`
  Adds comparison guidance after running scenarios.
- Modify `docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md`
  Updates Milestone 6 status.

## Task 1: Add Red Compare Tool Tests And Build Wiring

**Files:**

- Create `packages/zigeffect/tools/causal_compare.zig`
- Modify `packages/zigeffect/build.zig`

- [ ] **Step 1: Create test-only compare tool**

Create `packages/zigeffect/tools/causal_compare.zig` with:

```zig
const std = @import("std");

const before_json =
    \\{
    \\  "events": [
    \\    {"id":1,"kind":"run_started","run_id":1,"parent_id":null,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"scenario","type_name":"Command","status":"started","redacted_detail":""},
    \\    {"id":2,"kind":"service_required","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"Config","type_name":"Config","status":"missing","redacted_detail":"missing provider"}
    \\  ]
    \\}
;

const after_json =
    \\{
    \\  "events": [
    \\    {"id":1,"kind":"run_started","run_id":1,"parent_id":null,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"scenario","type_name":"Command","status":"started","redacted_detail":""},
    \\    {"id":2,"kind":"service_required","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"Config","type_name":"Config","status":"provided","redacted_detail":"provider added"},
    \\    {"id":3,"kind":"exit_recorded","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"scenario","type_name":"Command","status":"success","redacted_detail":""}
    \\  ]
    \\}
;

test "compare report includes event and finding deltas" {
    const report = try runCompare(std.testing.allocator, before_json, after_json);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect causal compare report") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "before events: 2") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "after events: 3") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "event delta: +1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "before findings: 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "after findings: 0") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "finding delta: -1") != null);
}

test "compare report lists added removed and changed events" {
    const report = try runCompare(std.testing.allocator, before_json, after_json);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "added events:") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "- event id=3 kind=exit_recorded") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "removed events:") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "- none") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "changed events:") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "- before event id=2 kind=service_required") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "- after event id=2 kind=service_required") != null);
}
```

- [ ] **Step 2: Wire compare tool into `build.zig`**

Add module, executable, run step with forwarded args, test artifact, and include
the executable and tests in `examples_step`.

- [ ] **Step 3: Verify red**

Run:

```sh
cd packages/zigeffect && zig build examples
```

Expected: fail because `runCompare` is undefined.

## Task 2: Implement Compare Engine

**Files:**

- Modify `packages/zigeffect/tools/causal_compare.zig`

- [ ] **Step 1: Add artifact and event types**

Define:

```zig
const Artifact = struct { events: []Event };
const Event = struct {
    id: u64,
    kind: []const u8,
    run_id: ?u64,
    parent_id: ?u64,
    fiber_id: ?u64,
    scope_id: ?u64,
    trace_id: ?u64,
    span_id: ?u64,
    label: []const u8,
    type_name: []const u8,
    status: []const u8,
    redacted_detail: []const u8,
};
```

- [ ] **Step 2: Implement event comparison helpers**

Add helpers:

- `findEvent(events, id)`;
- `eventsEqual(before, after)`;
- `findingCount(events)`;
- `appendEventLine(output, allocator, prefix, event)`;
- `appendSignedDelta(output, allocator, label, delta)`.

- [ ] **Step 3: Implement `runCompare`**

Parse both JSON strings, compute added/removed/changed events and finding delta,
and format the report.

- [ ] **Step 4: Verify green**

Run:

```sh
cd packages/zigeffect && zig build examples
```

Expected: pass.

## Task 3: Add Compare CLI

**Files:**

- Modify `packages/zigeffect/tools/causal_compare.zig`

- [ ] **Step 1: Add `main(init: std.process.Init) !void`**

CLI behavior:

- requires exactly two arguments after the executable;
- reads both files with `std.Io.Dir.cwd().readFileAlloc`;
- runs `runCompare`;
- prints the report;
- unknown/missing args print usage and exit `1`.

- [ ] **Step 2: Verify with generated artifacts**

Run:

```sh
cd packages/zigeffect && zig build causal-test
cd packages/zigeffect && zig build causal-compare -- .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json
```

Expected: compare exits zero and reports zero event and finding deltas.

## Task 4: Update Docs

**Files:**

- Modify `packages/zigeffect/README.md`
- Modify `packages/zigeffect/docs/agent-guide.md`
- Modify `packages/zigeffect/docs/agent-observable-runtime.md`
- Modify `packages/zigeffect/docs/causal-scenarios.md`
- Modify `docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md`

- [ ] **Step 1: Document command usage**

Add:

```sh
zig build causal-compare -- <before.json> <after.json>
```

Explain that it compares event and finding deltas.

- [ ] **Step 2: Update roadmap**

Mark Milestone 6 as first compare slice delivered and note remaining automated
capture loop.

## Task 5: Verification And Commit

**Files:**

- All modified files.

- [ ] **Step 1: Run compare workflow**

Run:

```sh
cd packages/zigeffect && zig build causal-test
cd packages/zigeffect && zig build causal-compare -- .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json
```

Expected: compare exits zero and reports zero deltas.

- [ ] **Step 2: Run broad verification**

Run:

```sh
cd packages/zigeffect && zig build test
cd packages/zigeffect && zig build examples
bun run zig:test
git diff --check
```

Expected: all pass.

- [ ] **Step 3: Commit**

Run:

```sh
git add docs/superpowers/specs/2026-06-07-zigeffect-causal-before-after-compare-design.md docs/superpowers/plans/2026-06-07-zigeffect-causal-before-after-compare.md docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md packages/zigeffect/tools/causal_compare.zig packages/zigeffect/build.zig packages/zigeffect/README.md packages/zigeffect/docs/agent-guide.md packages/zigeffect/docs/agent-observable-runtime.md packages/zigeffect/docs/causal-scenarios.md
git commit -m "feat(zigeffect): add causal artifact comparison"
```

Expected: commit succeeds.

## Self-Review

- Spec coverage: The plan covers compare command, event deltas, finding deltas,
  docs, build wiring, and verification.
- Placeholder scan: No unfinished markers or underspecified implementation
  steps remain.
- Scope check: This is the first Milestone 6 slice. Automated before/after
  capture around patch application remains a later milestone.
