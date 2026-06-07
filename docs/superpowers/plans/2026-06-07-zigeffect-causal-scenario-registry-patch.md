# zigeffect Causal Scenario Registry Patch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `zig build causal-scenario-registry-patch -- --from-proposal <scenario-proposal.json>`, a review-only artifact generator that turns scenario proposals into JSON/text/Zig registry patch drafts.

**Architecture:** Create `packages/zigeffect/tools/causal_scenario_registry_patch.zig` as a focused parser, validator, snippet formatter, and artifact writer. It reads `zigeffect.causal.scenario-proposal.v1`, consults the current `causal_run` registry and invariant catalog for conflicts, writes registry-patch artifacts, and never edits source. Build wiring, artifact manifest, and docs are updated after the tool has tested behavior.

**Tech Stack:** Zig 0.16, existing `causal_run` registry APIs, Zig std JSON parser, Bun repo verification commands.

---

## Files

- Create: `packages/zigeffect/tools/causal_scenario_registry_patch.zig`
  - Owns CLI option parsing, proposal structs, validation, path derivation,
    identifier generation, registry conflict checks, JSON/text/snippet
    formatting, and artifact IO.
- Modify: `packages/zigeffect/build.zig`
  - Adds the tool module, tests, executable, build step, and examples aggregate
    dependencies.
- Modify: `packages/zigeffect/tools/causal_artifacts.zig`
  - Adds registry-patch JSON/text/Zig paths to the retention manifest and tests.
- Modify: `packages/zigeffect/README.md`
  - Documents command usage after `causal-scenario-proposal`.
- Modify: `packages/zigeffect/docs/agent-guide.md`
  - Adds agent guidance for reviewing registry patch drafts.
- Modify: `packages/zigeffect/docs/causal-scenarios.md`
  - Adds command and artifact paths.
- Modify: `packages/zigeffect/docs/roadmap.md`
  - Marks the reviewable registry patch slice delivered after implementation.
- Modify:
  `docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md`
  - Updates the remediation-control roadmap with registry patch drafting.
- Modify:
  `docs/superpowers/specs/2026-06-07-zigeffect-self-improving-dev-harness-roadmap.md`
  - Updates Milestone 5 next/delivered text.

## Tasks

### Task 0: Documentation Checkpoint

**Files:**
- Create:
  `docs/superpowers/specs/2026-06-07-zigeffect-causal-scenario-registry-patch-design.md`
- Create:
  `docs/superpowers/plans/2026-06-07-zigeffect-causal-scenario-registry-patch.md`

- [ ] Write the design with command shape, schemas, validation,
  recommendation handling, output artifacts, and acceptance criteria.
- [ ] Write this implementation plan with files, scope, TDD checkpoints, and
  verification commands.
- [ ] Run:

```sh
git diff --check
printf '%s\n' \
  '\bTB''D\b' \
  '\bTO''DO\b' \
  'implement late''r' \
  'fill in detail''s' \
  'Similar to Tas''k' \
  'appropriate error handlin''g' > /tmp/zigeffect-registry-patch-plan-patterns.txt
rg -n -f /tmp/zigeffect-registry-patch-plan-patterns.txt docs/superpowers/specs/2026-06-07-zigeffect-causal-scenario-registry-patch-design.md docs/superpowers/plans/2026-06-07-zigeffect-causal-scenario-registry-patch.md
```

Expected: `git diff --check` prints nothing; `rg` exits nonzero with no
matches.

- [ ] Commit:

```sh
git add docs/superpowers/specs/2026-06-07-zigeffect-causal-scenario-registry-patch-design.md docs/superpowers/plans/2026-06-07-zigeffect-causal-scenario-registry-patch.md
git commit -m "docs(zigeffect): plan causal scenario registry patches"
```

### Task 1: Options, Paths, And Identifier Helpers

**Files:**
- Create: `packages/zigeffect/tools/causal_scenario_registry_patch.zig`
- Modify: `packages/zigeffect/build.zig`

- [ ] Write failing tests:

```zig
test "registry patch parses from-proposal option and rejects invalid shapes" {
    const options = try parseOptions(&.{
        "zigeffect-causal-scenario-registry-patch",
        "--from-proposal",
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-scenario-proposal.json",
    });
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-scenario-proposal.json",
        options.proposal_path,
    );

    try std.testing.expectError(error.MissingProposalPath, parseOptions(&.{
        "zigeffect-causal-scenario-registry-patch",
    }));
    try std.testing.expectError(error.UnknownFlag, parseOptions(&.{
        "zigeffect-causal-scenario-registry-patch",
        "--proposal",
        "x.json",
    }));
    try std.testing.expectError(error.InvalidProposalPath, parseOptions(&.{
        "zigeffect-causal-scenario-registry-patch",
        "--from-proposal",
        "proposal.json",
    }));
}

test "registry patch output paths are derived from proposal path" {
    const paths = try registryPatchPathsFromProposal(
        std.testing.allocator,
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-scenario-proposal.json",
    );
    defer paths.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-registry-patch.json",
        paths.json,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-registry-patch.txt",
        paths.text,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-registry-patch.zig",
        paths.zig,
    );
}

test "registry patch identifiers are stable Zig identifiers" {
    const identifier = try identifierFromSlug(std.testing.allocator, "learned-dogfood-service-resolution");
    defer std.testing.allocator.free(identifier);
    try std.testing.expectEqualStrings("learned_dogfood_service_resolution", identifier);

    const digit = try identifierFromSlug(std.testing.allocator, "123-example");
    defer std.testing.allocator.free(digit);
    try std.testing.expectEqualStrings("scenario_123_example", digit);
}
```

- [ ] Wire the test module into `build.zig`.
- [ ] Run `cd packages/zigeffect && zig build examples`.
- [ ] Confirm the new tests fail because the helpers are not implemented.
- [ ] Implement minimal `Options`, `RegistryPatchPaths`, `parseOptions`,
  `registryPatchPathsFromProposal`, `identifierFromSlug`, and `usage`.
- [ ] Run `cd packages/zigeffect && zig build examples`.
- [ ] Commit:

```sh
git add packages/zigeffect/tools/causal_scenario_registry_patch.zig packages/zigeffect/build.zig
git commit -m "feat(zigeffect): add causal registry patch path helpers"
```

### Task 2: Proposal Parsing And Validation

**Files:**
- Modify: `packages/zigeffect/tools/causal_scenario_registry_patch.zig`

- [ ] Add sample proposal JSON strings for `add-scenario`, `refine-scenario`,
  and `none`.
- [ ] Write failing tests:

```zig
test "registry patch validates add scenario proposal and registry conflict" {
    var parsed = try std.json.parseFromSlice(ScenarioProposal, std.testing.allocator, sample_add_scenario_proposal_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const validation = try validateScenarioProposal(parsed.value);
    try std.testing.expectEqual(Recommendation.add_scenario, validation.recommendation);
    try std.testing.expect(!validation.scenario_conflict);
    try std.testing.expectEqualStrings("learned-dogfood-service-resolution", parsed.value.proposed_scenario.?.slug);
}

test "registry patch validates no-op proposal" {
    var parsed = try std.json.parseFromSlice(ScenarioProposal, std.testing.allocator, sample_none_proposal_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const validation = try validateScenarioProposal(parsed.value);
    try std.testing.expectEqual(Recommendation.none, validation.recommendation);
    try std.testing.expect(!validation.has_patch_snippet);
}

test "registry patch rejects unsupported schema and unknown enum values" {
    var parsed = try std.json.parseFromSlice(ScenarioProposal, std.testing.allocator, sample_add_scenario_proposal_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    var bad_schema = parsed.value;
    bad_schema.schema = "other.schema";
    try std.testing.expectError(error.UnsupportedProposalSchema, validateScenarioProposal(bad_schema));

    var bad_owner = parsed.value;
    bad_owner.proposed_scenario.?.owner = "not_a_subsystem";
    try std.testing.expectError(error.UnknownOwner, validateScenarioProposal(bad_owner));
}
```

- [ ] Implement `ScenarioProposal`, `ProposedScenario`,
  `ProposedInvariant`, `Evidence`, `Recommendation`, `ValidationResult`, and
  validation helpers.
- [ ] Run `cd packages/zigeffect && zig build examples`.
- [ ] Commit:

```sh
git add packages/zigeffect/tools/causal_scenario_registry_patch.zig
git commit -m "feat(zigeffect): validate causal scenario proposal patches"
```

### Task 3: Snippet And Report Formatting

**Files:**
- Modify: `packages/zigeffect/tools/causal_scenario_registry_patch.zig`

- [ ] Write failing tests for `formatRegistryPatchReports`:

```zig
test "registry patch formats add-scenario JSON text and Zig snippet" {
    const reports = try formatRegistryPatchReports(std.testing.allocator, .{
        .source_proposal_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-scenario-proposal.json",
        .proposal_json = sample_add_scenario_proposal_json,
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"schema\": \"zigeffect.causal.registry-patch.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"patch_status\": \"review-required\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"scenario_conflict\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "patch_status: review-required") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.zig, "const learned_dogfood_service_resolution_invariants") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.zig, ".slug = \"learned-dogfood-service-resolution\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.zig, ".owner = .service_resolution") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.zig, "REVIEW: replace this placeholder") != null);
}

test "registry patch formats none proposal as no-op" {
    const reports = try formatRegistryPatchReports(std.testing.allocator, .{
        .source_proposal_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-scenario-proposal.json",
        .proposal_json = sample_none_proposal_json,
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"patch_status\": \"no-op\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "no registry patch recommended") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.zig, "No registry patch recommended") != null);
}

test "registry patch formats refine proposal as review guidance" {
    const reports = try formatRegistryPatchReports(std.testing.allocator, .{
        .source_proposal_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-scenario-proposal.json",
        .proposal_json = sample_refine_scenario_proposal_json,
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"recommendation\": \"refine-scenario\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "review existing scenario: causal-scoped-fiber") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.zig, "Review existing scenario entry") != null);
}
```

- [ ] Implement JSON string escaping, array formatting, enum mapping,
  known/new invariant classification, scenario snippet formatting, no-op
  formatting, and refine guidance formatting.
- [ ] Run `cd packages/zigeffect && zig build examples`.
- [ ] Commit:

```sh
git add packages/zigeffect/tools/causal_scenario_registry_patch.zig
git commit -m "feat(zigeffect): format causal registry patch reports"
```

### Task 4: CLI Artifact IO And Integration

**Files:**
- Modify: `packages/zigeffect/tools/causal_scenario_registry_patch.zig`
- Modify: `packages/zigeffect/build.zig`

- [ ] Add executable build step `causal-scenario-registry-patch`.
- [ ] Implement required proposal reader and JSON/text/Zig artifact writers.
- [ ] Run default integration:

```sh
cd packages/zigeffect
zig build causal-dev-session -- start
zig build causal-dev-session -- assess
zig build causal-remediation-decision -- local approve --reason "Registry patch integration check"
zig build causal-patch-proposal -- local approved --summary "Registry patch integration proposal" --file packages/zigeffect/tools/causal_scenario_registry_patch.zig --change "Generate reviewable scenario registry patch drafts"
zig build causal-audit-chain -- local
zig build causal-scenario-proposal -- local
zig build causal-scenario-registry-patch -- --from-proposal .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-scenario-proposal.json
```

Expected: default text report includes `patch_status: review-required`; Zig
snippet includes a scenario entry and `REVIEW` placeholder argv note.

- [ ] Run clear scenario no-op integration:

```sh
cd packages/zigeffect
zig build causal-dev-session -- start causal-scoped-fiber
zig build causal-dev-session -- assess causal-scoped-fiber
zig build causal-remediation-decision -- local approve causal-scoped-fiber --reason "Registry patch no-op check"
zig build causal-patch-proposal -- local approved causal-scoped-fiber --summary "Registry patch no-op scenario" --file packages/zigeffect/examples/causal_scoped_fiber.zig --change "Do not generate registry changes for clear evidence"
zig build causal-audit-chain -- local causal-scoped-fiber
zig build causal-scenario-proposal -- local causal-scoped-fiber
zig build causal-scenario-registry-patch -- --from-proposal .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-scenario-proposal.json
```

Expected: scenario text report includes `patch_status: no-op` and the Zig
snippet says no registry patch is recommended.

- [ ] Commit:

```sh
git add packages/zigeffect/tools/causal_scenario_registry_patch.zig packages/zigeffect/build.zig
git commit -m "feat(zigeffect): write causal registry patch artifacts"
```

### Task 5: Manifest, Docs, Roadmaps, And Verification

**Files:**
- Modify: `packages/zigeffect/tools/causal_artifacts.zig`
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/causal-scenarios.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify:
  `docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md`
- Modify:
  `docs/superpowers/specs/2026-06-07-zigeffect-self-improving-dev-harness-roadmap.md`

- [ ] Add registry-patch JSON/text/Zig paths to the causal artifact manifest
  and manifest tests.
- [ ] Document `zig build causal-scenario-registry-patch -- --from-proposal <path>`.
- [ ] Mark Milestone 5's reviewable registry patch slice delivered.
- [ ] Verify:

```sh
git diff --check
cd packages/zigeffect && zig build causal-artifacts
cd packages/zigeffect && zig build examples
cd packages/zigeffect && zig build test --summary none
bun run check
bun run zig:test
```

- [ ] Commit:

```sh
git add docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md docs/superpowers/specs/2026-06-07-zigeffect-self-improving-dev-harness-roadmap.md packages/zigeffect/README.md packages/zigeffect/docs/agent-guide.md packages/zigeffect/docs/causal-scenarios.md packages/zigeffect/docs/roadmap.md packages/zigeffect/tools/causal_artifacts.zig
git commit -m "docs(zigeffect): document causal registry patch drafts"
```

## Self-Review

- Spec coverage: tasks cover command shape, schema, validation,
  recommendation handling, path derivation, output artifacts, CLI IO, manifest,
  docs, and final verification.
- Scope check: automatic source editing and policy application are out of
  scope. The generated Zig snippet remains review-only.
- TDD check: Tasks 1, 2, and 3 require red tests before helper, validation, and
  formatter implementation; Task 4 performs integration after tested behavior
  exists.
- Type consistency: command name is `causal-scenario-registry-patch`; schema is
  `zigeffect.causal.registry-patch.v1`; artifact suffix is `registry-patch`.
