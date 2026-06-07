# zigeffect Causal Event Taxonomy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add explicit causal event-kind taxonomy helpers and artifact metadata so agents can distinguish structural evidence, finding evidence, and sampleable observability while developing zigeffect.

**Architecture:** Keep `CausalEventKind` unchanged. Add a small public `CausalEventTaxonomy` struct and helper functions in `services/causal.zig`, re-export them from `zigeffect.zig`, wire sampling through the sampleable helper, and add additive JSON/docs metadata for `causal_event_taxonomy_version`.

**Tech Stack:** Zig 0.16, Bun-managed repository scripts, `bun:test` for outer repo conventions, `zig build test` for package verification.

---

## Files

- Modify: `packages/zigeffect/src/services/causal.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`
- Modify: `packages/zigeffect/test/services_test.zig`
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
- Modify: `packages/zigeffect/docs/roadmap.md`

## Task 1: RED Taxonomy Tests

- [ ] **Step 1: Add taxonomy role tests**

Append these tests near the other causal service tests in
`packages/zigeffect/test/services_test.zig`:

```zig
test "causal event taxonomy classifies structural finding and sampleable roles" {
    try std.testing.expect(fx.isCausalStructuralEvent(.run_started));
    try std.testing.expect(fx.isCausalStructuralEvent(.resource_acquired));
    try std.testing.expect(fx.isCausalFindingEvidenceEvent(.resource_acquired));
    try std.testing.expect(fx.isCausalFindingEvidenceEvent(.fiber_forked));
    try std.testing.expect(fx.isCausalFindingEvidenceEvent(.assertion_recorded));
    try std.testing.expect(fx.isCausalSampleableEvent(.log_recorded));
    try std.testing.expect(fx.isCausalSampleableEvent(.metric_recorded));
    try std.testing.expect(fx.isCausalSampleableEvent(.span_recorded));
    try std.testing.expect(!fx.isCausalStructuralEvent(.log_recorded));
    try std.testing.expect(!fx.isCausalFindingEvidenceEvent(.log_recorded));
    try std.testing.expect(!fx.isCausalSampleableEvent(.assertion_recorded));
}

test "causal event taxonomy keeps sampleable events disjoint from finding evidence" {
    inline for (std.meta.fields(fx.CausalEventKind)) |field| {
        const kind: fx.CausalEventKind = @enumFromInt(field.value);
        if (fx.isCausalSampleableEvent(kind)) {
            try std.testing.expect(!fx.isCausalFindingEvidenceEvent(kind));
        }
        if (fx.isCausalFindingEvidenceEvent(kind)) {
            try std.testing.expect(!fx.isCausalSampleableEvent(kind));
        }
    }
}
```

- [ ] **Step 2: Add JSON taxonomy version assertion**

Extend `test "causal json and dot exports are deterministic and redacted"`:

```zig
try std.testing.expect(std.mem.indexOf(u8, json, "\"event_taxonomy_version\": 1") != null);
```

- [ ] **Step 3: Run focused tests to verify RED**

Run:

```bash
cd packages/zigeffect && zig build test --summary none
```

Expected: FAIL because `isCausalStructuralEvent`,
`isCausalFindingEvidenceEvent`, `isCausalSampleableEvent`, and
`event_taxonomy_version` do not exist yet.

## Task 2: GREEN Taxonomy API

- [ ] **Step 1: Add constants and taxonomy struct**

In `packages/zigeffect/src/services/causal.zig`, near the schema constants,
add:

```zig
pub const causal_event_taxonomy_version: u32 = 1;

pub const CausalEventTaxonomy = struct {
    structural: bool,
    finding_evidence: bool,
    sampleable: bool,
};
```

- [ ] **Step 2: Add role helpers after `CausalEventKind`**

Add:

```zig
pub fn causalEventTaxonomy(kind: CausalEventKind) CausalEventTaxonomy {
    const sampleable = switch (kind) {
        .log_recorded, .metric_recorded, .span_recorded => true,
        else => false,
    };

    const finding_evidence = switch (kind) {
        .service_required,
        .scope_closed,
        .resource_acquired,
        .resource_finalized,
        .fiber_forked,
        .fiber_started,
        .fiber_joined,
        .fiber_interrupted,
        .schedule_decision,
        .assertion_recorded,
        => true,
        else => false,
    };

    return .{
        .structural = !sampleable,
        .finding_evidence = finding_evidence,
        .sampleable = sampleable,
    };
}

pub fn isCausalStructuralEvent(kind: CausalEventKind) bool {
    return causalEventTaxonomy(kind).structural;
}

pub fn isCausalFindingEvidenceEvent(kind: CausalEventKind) bool {
    return causalEventTaxonomy(kind).finding_evidence;
}

pub fn isCausalSampleableEvent(kind: CausalEventKind) bool {
    return causalEventTaxonomy(kind).sampleable;
}
```

- [ ] **Step 3: Re-export helpers**

In both the nested `services` struct and the top-level exports in
`packages/zigeffect/src/zigeffect.zig`, add:

```zig
pub const causal_event_taxonomy_version = causal.causal_event_taxonomy_version;
pub const CausalEventTaxonomy = causal.CausalEventTaxonomy;
pub const causalEventTaxonomy = causal.causalEventTaxonomy;
pub const isCausalStructuralEvent = causal.isCausalStructuralEvent;
pub const isCausalFindingEvidenceEvent = causal.isCausalFindingEvidenceEvent;
pub const isCausalSampleableEvent = causal.isCausalSampleableEvent;
```

For top-level exports, use `services.causal` instead of `causal`.

- [ ] **Step 4: Wire sampling through taxonomy**

Update `shouldRecordBySampling`:

```zig
fn shouldRecordBySampling(self: *CausalStore, kind: CausalEventKind) bool {
    if (!isCausalSampleableEvent(kind)) return true;
    return switch (kind) {
        .log_recorded => shouldRecordEveryN(&self.log_seen_count, self.sampling.log_every_n),
        .metric_recorded => shouldRecordEveryN(&self.metric_seen_count, self.sampling.metric_every_n),
        .span_recorded => shouldRecordEveryN(&self.span_seen_count, self.sampling.span_every_n),
        else => true,
    };
}
```

- [ ] **Step 5: Emit taxonomy version in JSON**

In `formatCausalJson`, after `schema_version`, emit:

```zig
try output.print(allocator, "  \"event_taxonomy_version\": {d},\n", .{causal_event_taxonomy_version});
```

Adjust the existing `schema_version` print so commas remain valid JSON.

- [ ] **Step 6: Run focused tests**

Run:

```bash
cd packages/zigeffect && zig build test --summary none
```

Expected: PASS.

## Task 3: Docs and Roadmap

- [ ] **Step 1: Update JSON examples**

Add `"event_taxonomy_version": 1` to the root JSON examples in:

- `packages/zigeffect/README.md`
- `packages/zigeffect/docs/agent-guide.md`
- `packages/zigeffect/docs/agent-observable-runtime.md`

- [ ] **Step 2: Document role semantics**

In the agent docs, add that:

- structural events are not sampleable;
- logs, metrics, and spans are sampleable observability;
- finding evidence events are never sampleable;
- `event_taxonomy_version` identifies event-kind semantics.

- [ ] **Step 3: Update roadmap**

Add a delivered bullet:

```markdown
- Delivered: explicit causal event taxonomy helpers and taxonomy-versioned JSON
  metadata for structural, finding-evidence, and sampleable roles.
```

## Task 4: Verification and Commit

- [ ] **Step 1: Run full verification**

Run:

```bash
cd packages/zigeffect && zig build test --summary none
cd packages/zigeffect && zig build examples
bun run zig:test
cd packages/zigeffect && zig build causal-dev-loop -- baseline
cd packages/zigeffect && zig build causal-dev-loop -- after
git diff --check
```

- [ ] **Step 2: Commit implementation**

Run:

```bash
git add packages/zigeffect/src/services/causal.zig \
  packages/zigeffect/src/zigeffect.zig \
  packages/zigeffect/test/services_test.zig \
  packages/zigeffect/README.md \
  packages/zigeffect/docs/agent-guide.md \
  packages/zigeffect/docs/agent-observable-runtime.md \
  packages/zigeffect/docs/roadmap.md
git commit -m "feat(zigeffect): classify causal event taxonomy"
```

## Self-Review

- Spec coverage: The plan covers public helpers, disjoint taxonomy tests,
  sampling integration, JSON metadata, docs, and verification.
- Placeholder scan: No TBD/TODO/fill-in placeholders remain.
- Type consistency: The plan consistently uses `CausalEventTaxonomy`,
  `causal_event_taxonomy_version`, and the three role helper names.
