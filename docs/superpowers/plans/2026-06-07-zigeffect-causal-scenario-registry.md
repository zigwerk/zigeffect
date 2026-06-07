# zigeffect Causal Scenario Registry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a scenario registry and invariant catalog to the zigeffect causal development harness.

**Architecture:** Extend `packages/zigeffect/tools/causal_run.zig` with scenario metadata, invariant metadata, registry lookup helpers, and a catalog output mode. Keep command execution and artifact writing in the same tool for this slice, and add a `causal-catalog` build step that prints the registry without running scenarios.

**Tech Stack:** Zig 0.16, zigeffect causal APIs, `std.process.Init`, Zig build steps, Markdown docs.

---

## File Structure

- Modify `packages/zigeffect/tools/causal_run.zig`
  Adds registry metadata, invariant catalog, catalog formatting, more registered
  scenarios, and tests.
- Modify `packages/zigeffect/build.zig`
  Adds `causal-catalog`.
- Modify `packages/zigeffect/README.md`
  Documents catalog and scenario registry commands.
- Modify `packages/zigeffect/docs/agent-guide.md`
  Explains how agents use the registry before running or fixing scenarios.
- Modify `packages/zigeffect/docs/agent-observable-runtime.md`
  Updates Phase 0 with the scenario registry and invariant catalog.
- Create `packages/zigeffect/docs/causal-scenarios.md`
  Documents current scenarios, invariants, and how to add a new scenario.
- Modify `docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md`
  Updates Milestone 5 status after implementation.

## Task 1: Add Red Registry And Catalog Tests

**Files:**

- Modify `packages/zigeffect/tools/causal_run.zig`

- [ ] **Step 1: Add registry metadata tests**

Append tests:

```zig
test "scenario registry records owners purposes policies invariants and paths" {
    const scenarios = scenarioRegistry();
    try std.testing.expect(scenarios.len >= 6);

    const missing = try scenarioByName("missing-service-compile-fail");
    try std.testing.expectEqual(RuntimeSubsystem.service_resolution, missing.owner);
    try std.testing.expectEqual(ExpectedFindingsPolicy.expected_failure_command_emits_assertion, missing.finding_policy);
    try std.testing.expect(missing.purpose.len > 0);
    try std.testing.expect(missing.invariant_ids.len >= 2);

    const scoped_fiber = try scenarioByName("causal-scoped-fiber");
    try std.testing.expectEqual(RuntimeSubsystem.fiber_runtime, scoped_fiber.owner);
    try std.testing.expectEqual(Expectation.expected_pass, scoped_fiber.expectation);

    const paths = try artifactPaths(std.testing.allocator, scoped_fiber.slug);
    defer paths.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-causal-scoped-fiber.json",
        paths.json_path,
    );
}

test "invariant catalog maps findings to runtime rules" {
    const invariant = try invariantById("scoped-fiber-must-finish-before-scope-close");
    try std.testing.expectEqual(RuntimeSubsystem.fiber_runtime, invariant.subsystem);
    try std.testing.expectEqual(fx.CausalFindingKind.fiber_pending_after_scope_close, invariant.finding_kind.?);
    try std.testing.expect(std.mem.indexOf(u8, invariant.detection_query, "causal.fibers pending") != null);
}

test "catalog output lists scenarios invariants and artifact paths" {
    const catalog = try formatCatalog(std.testing.allocator);
    defer std.testing.allocator.free(catalog);

    try std.testing.expect(std.mem.indexOf(u8, catalog, "zigeffect causal scenario registry") != null);
    try std.testing.expect(std.mem.indexOf(u8, catalog, "scenario missing-service-compile-fail") != null);
    try std.testing.expect(std.mem.indexOf(u8, catalog, "owner: service_resolution") != null);
    try std.testing.expect(std.mem.indexOf(u8, catalog, "scenario causal-scoped-fiber") != null);
    try std.testing.expect(std.mem.indexOf(u8, catalog, "invariant scoped-fiber-must-finish-before-scope-close") != null);
    try std.testing.expect(std.mem.indexOf(u8, catalog, ".zig-cache/causal-artifacts/zigeffect-causal-causal-scoped-fiber.json") != null);
}
```

- [ ] **Step 2: Verify red**

Run:

```sh
cd packages/zigeffect && zig build examples
```

Expected: fail because `scenarioRegistry`, `RuntimeSubsystem`,
`ExpectedFindingsPolicy`, `invariantById`, and `formatCatalog` do not exist.

## Task 2: Implement Registry And Invariant Catalog

**Files:**

- Modify `packages/zigeffect/tools/causal_run.zig`

- [ ] **Step 1: Add metadata types**

Add:

```zig
pub const RuntimeSubsystem = enum {
    command_harness,
    service_resolution,
    scope_lifecycle,
    fiber_runtime,
    schedule_retry,
    package,
};

pub const ExpectedFindingsPolicy = enum {
    none_when_command_passes,
    failure_artifact_on_command_failure,
    expected_failure_command_emits_assertion,
};

pub const Invariant = struct {
    id: []const u8,
    subsystem: RuntimeSubsystem,
    finding_kind: ?fx.CausalFindingKind,
    rule: []const u8,
    detection_query: []const u8,
};
```

Extend `Scenario` with:

```zig
owner: RuntimeSubsystem,
purpose: []const u8,
finding_policy: ExpectedFindingsPolicy,
invariant_ids: []const []const u8,
```

- [ ] **Step 2: Add scenario argv constants**

Add argv constants for:

- `examples/causal_scoped_fiber.zig`
- `examples/causal_retry_exhaustion.zig`
- `examples/causal_cleanup_failure.zig`
- `examples/causal_missing_config.zig`

Use `zig test --dep zigeffect -Mroot=<example> -Mzigeffect=src/zigeffect.zig`
with scenario-specific cache dirs.

- [ ] **Step 3: Replace branch lookup with registry slices**

Add `scenario_registry` and `scenarioRegistry()`.

Update `scenarioByName` to loop over the registry.

- [ ] **Step 4: Add invariant catalog helpers**

Add `invariant_catalog`, `invariantCatalog()`, and `invariantById()`.

- [ ] **Step 5: Add catalog formatter**

Implement:

```zig
pub fn formatCatalog(allocator: std.mem.Allocator) std.mem.Allocator.Error![]const u8
```

The formatter prints scenario metadata, artifact paths, invariant ids, invariant
rules, and detection queries.

- [ ] **Step 6: Verify green**

Run:

```sh
cd packages/zigeffect && zig build examples
```

Expected: pass.

## Task 3: Add Catalog CLI And Build Step

**Files:**

- Modify `packages/zigeffect/tools/causal_run.zig`
- Modify `packages/zigeffect/build.zig`

- [ ] **Step 1: Add `catalog` mode**

In `main`, if the single argument is `catalog`, format and print the catalog
then return without running a scenario.

Update usage text to include `catalog`.

- [ ] **Step 2: Add `causal-catalog` build step**

In `packages/zigeffect/build.zig`, add:

```zig
const run_causal_catalog_tool = b.addRunArtifact(causal_run_tool);
run_causal_catalog_tool.addArg("catalog");
const causal_catalog_step = b.step("causal-catalog", "Print the zigeffect causal scenario registry and invariant catalog");
causal_catalog_step.dependOn(&run_causal_catalog_tool.step);
```

- [ ] **Step 3: Verify catalog command**

Run:

```sh
cd packages/zigeffect && zig build causal-catalog
```

Expected: exits zero and prints registered scenarios and invariants.

## Task 4: Update Documentation

**Files:**

- Create `packages/zigeffect/docs/causal-scenarios.md`
- Modify `packages/zigeffect/README.md`
- Modify `packages/zigeffect/docs/agent-guide.md`
- Modify `packages/zigeffect/docs/agent-observable-runtime.md`
- Modify `docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md`

- [ ] **Step 1: Create scenario documentation**

Create `packages/zigeffect/docs/causal-scenarios.md` with:

- current commands;
- current scenario list;
- invariant catalog summary;
- steps for turning a bug into a scenario.

- [ ] **Step 2: Update existing docs**

Mention:

- `zig build causal-catalog`;
- `zig build causal-run -- catalog`;
- using the catalog before proposing changes;
- adding scenarios when bugs reveal new invariants.

- [ ] **Step 3: Update roadmap status**

Change Milestone 5 status to show the first registry/catalog slice delivered.

## Task 5: Verification And Commit

**Files:**

- All modified files.

- [ ] **Step 1: Run catalog**

Run:

```sh
cd packages/zigeffect && zig build causal-catalog
```

Expected: exits zero and prints scenarios and invariants.

- [ ] **Step 2: Run direct catalog mode**

Run:

```sh
cd packages/zigeffect && zig build causal-run -- catalog
```

Expected: exits zero and prints the same catalog.

- [ ] **Step 3: Run an example scenario**

Run:

```sh
cd packages/zigeffect && zig build causal-run -- causal-scoped-fiber
```

Expected: exits zero while the example test passes.

- [ ] **Step 4: Run existing causal commands**

Run:

```sh
cd packages/zigeffect && zig build causal-capture-missing-service
cd packages/zigeffect && zig build causal-dev-test
```

Expected: both pass.

- [ ] **Step 5: Run broad verification**

Run:

```sh
cd packages/zigeffect && zig build test
cd packages/zigeffect && zig build examples
bun run zig:test
git diff --check
```

Expected: all pass.

- [ ] **Step 6: Commit**

Run:

```sh
git add docs/superpowers/specs/2026-06-07-zigeffect-causal-scenario-registry-design.md docs/superpowers/plans/2026-06-07-zigeffect-causal-scenario-registry.md docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md packages/zigeffect/tools/causal_run.zig packages/zigeffect/build.zig packages/zigeffect/README.md packages/zigeffect/docs/agent-guide.md packages/zigeffect/docs/agent-observable-runtime.md packages/zigeffect/docs/causal-scenarios.md
git commit -m "feat(zigeffect): add causal scenario registry"
```

Expected: commit succeeds.

## Self-Review

- Spec coverage: The plan covers registry fields, invariant mapping, catalog
  output, build step, docs, and verification.
- Placeholder scan: No unfinished markers or underspecified implementation
  steps remain.
- Scope check: This is a Milestone 5 first slice. JSON registry export and
  before/after trace comparison remain later milestones.
