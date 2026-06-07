# zigeffect Causal Artifact Manifest Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `zig build causal-artifacts`, a deterministic manifest of causal artifact paths and CI retention guidance.

**Architecture:** Create a small `causal_artifacts.zig` tool that formats a text manifest from static dev-loop paths and the existing `causal_run` scenario registry. Wire it into `build.zig` with tests and examples aggregate coverage.

**Tech Stack:** Zig 0.16, existing `causal_run` registry, Zig build system, Bun repository scripts.

---

## Files

- Create: `packages/zigeffect/tools/causal_artifacts.zig`
- Modify: `packages/zigeffect/build.zig`
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
- Modify: `packages/zigeffect/docs/causal-scenarios.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md`

## Task 1: RED Tool Tests

- [ ] **Step 1: Create failing tool contract**

Create `packages/zigeffect/tools/causal_artifacts.zig` with
`formatArtifactManifest` intentionally unimplemented and tests expecting:

```txt
zigeffect causal artifact manifest
artifact dir: .zig-cache/causal-artifacts
.zig-cache/causal-artifacts/*.txt
.zig-cache/causal-artifacts/zigeffect-causal-dogfood.json
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-advice.txt
.zig-cache/causal-artifacts/zigeffect-causal-package-tests.json
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-advice.txt
review before public upload
```

- [ ] **Step 2: Wire build step**

Add `causal-artifacts` executable and tests to `packages/zigeffect/build.zig`,
importing `causal_run`.

- [ ] **Step 3: Verify RED**

Run:

```sh
cd packages/zigeffect && zig build examples
```

Expected: fail because `formatArtifactManifest` is not implemented.

## Task 2: Implement Manifest Formatting

- [ ] **Step 1: Add manifest header and CI globs**

Print header, artifact dir, retention summary, and globs for `.txt`, `.json`,
and `.dot`.

- [ ] **Step 2: Add default artifact paths**

Print dogfood report/json/dot and dev-loop before/after/compare/query/advice
paths.

- [ ] **Step 3: Add scenario paths**

Iterate `causal_run.scenarioRegistry()` and print each scenario's report, JSON,
and DOT paths.

- [ ] **Step 4: Add scenario loop paths**

For each scenario, print before, after, compare, query, and advice paths.

- [ ] **Step 5: Add safety notes**

Print notes that artifacts are redacted and bounded but should be reviewed
before public upload, and that CI should avoid uploading the rest of
`.zig-cache`.

- [ ] **Step 6: Verify GREEN**

Run:

```sh
cd packages/zigeffect && zig build examples
```

Expected: pass.

## Task 3: Runtime Command And Docs

- [ ] **Step 1: Verify command output**

Run:

```sh
cd packages/zigeffect && zig build causal-artifacts
```

Expected: output includes upload globs and scenario artifact paths.

- [ ] **Step 2: Update docs**

Document:

- `zig build causal-artifacts`;
- upload globs;
- keep `.txt`, `.json`, and `.dot`;
- do not upload all `.zig-cache`;
- `.json` artifacts are for query/advice tooling.

## Task 4: Verification And Commit

- [ ] **Step 1: Run full verification**

Run:

```sh
cd packages/zigeffect && zig build causal-artifacts
cd packages/zigeffect && zig build examples
cd packages/zigeffect && zig build test --summary none
bun run zig:test
git diff --check
```

- [ ] **Step 2: Commit**

Run:

```sh
git add docs/superpowers/specs/2026-06-07-zigeffect-causal-artifact-manifest-design.md \
  docs/superpowers/plans/2026-06-07-zigeffect-causal-artifact-manifest.md \
  docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md \
  packages/zigeffect/tools/causal_artifacts.zig \
  packages/zigeffect/build.zig \
  packages/zigeffect/README.md \
  packages/zigeffect/docs/agent-guide.md \
  packages/zigeffect/docs/agent-observable-runtime.md \
  packages/zigeffect/docs/causal-scenarios.md \
  packages/zigeffect/docs/roadmap.md
git commit -m "feat(zigeffect): add causal artifact manifest"
```

## Self-Review

- Spec coverage: The plan covers command, manifest content, scenario registry
  paths, docs, verification, and commit.
- Placeholder scan: No placeholder-only implementation steps remain.
- Type consistency: The plan consistently uses `causal-artifacts`,
  `causal_artifacts.zig`, and `.zig-cache/causal-artifacts`.
