# zigeffect Causal CI Artifacts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a GitHub Actions workflow that runs the `zigeffect` causal development harness and uploads causal artifacts on failure.

**Architecture:** The workflow is a thin CI wrapper around existing `packages/zigeffect` build steps. It installs Zig, prints the artifact manifest, generates dogfood artifacts, runs examples, runs the causal package-test gate, and uploads only the causal artifact globs when the job fails.

**Tech Stack:** GitHub Actions YAML, Zig 0.16.0, existing `packages/zigeffect` build steps, `actions/checkout`, `mlugg/setup-zig`, `actions/upload-artifact`.

---

## Files

- Create: `.github/workflows/zigeffect-causal.yml`
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
- Modify: `packages/zigeffect/docs/causal-scenarios.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md`

## Task 1: Add CI Workflow

- [ ] **Step 1: Create the workflow**

Create `.github/workflows/zigeffect-causal.yml` with:

```yaml
name: zigeffect causal

on:
  pull_request:
    paths:
      - ".github/workflows/zigeffect-causal.yml"
      - "packages/zigeffect/**"
      - "package.json"
      - "bun.lock"
  push:
    branches:
      - master
    paths:
      - ".github/workflows/zigeffect-causal.yml"
      - "packages/zigeffect/**"
      - "package.json"
      - "bun.lock"
  workflow_dispatch:

permissions:
  contents: read

jobs:
  zigeffect-causal:
    name: zigeffect causal
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Zig
        uses: mlugg/setup-zig@v2.2.1
        with:
          version: 0.16.0

      - name: Print causal artifact manifest
        working-directory: packages/zigeffect
        run: zig build causal-artifacts

      - name: Generate causal dogfood artifacts
        working-directory: packages/zigeffect
        run: zig build causal-test

      - name: Compile and test examples
        working-directory: packages/zigeffect
        run: zig build examples

      - name: Run causal package test gate
        working-directory: packages/zigeffect
        run: zig build test --summary none

      - name: Upload causal artifacts on failure
        if: ${{ failure() }}
        uses: actions/upload-artifact@v4
        with:
          name: zigeffect-causal-artifacts-${{ github.run_id }}-${{ github.run_attempt }}
          if-no-files-found: ignore
          retention-days: 14
          path: |
            packages/zigeffect/.zig-cache/causal-artifacts/*.txt
            packages/zigeffect/.zig-cache/causal-artifacts/*.json
            packages/zigeffect/.zig-cache/causal-artifacts/*.dot
```

- [ ] **Step 2: Verify workflow content**

Run:

```sh
sed -n '1,220p' .github/workflows/zigeffect-causal.yml
```

Expected: the workflow includes `zig build causal-artifacts`,
`zig build causal-test`, `zig build examples`, `zig build test --summary none`,
and the upload step uses only causal artifact globs.

## Task 2: Update Documentation

- [ ] **Step 1: Update agent-facing docs**

Document that `.github/workflows/zigeffect-causal.yml` is the first CI harness
for the self-improving loop. The docs must say:

- CI prints the manifest.
- CI generates dogfood artifacts before the package gate.
- CI uploads causal artifacts only on failure.
- CI uploads `.txt`, `.json`, and `.dot` causal artifacts only.

- [ ] **Step 2: Update roadmap docs**

Mark the first CI workflow slice as delivered in:

- `packages/zigeffect/docs/roadmap.md`
- `docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md`

## Task 3: Verification And Commit

- [ ] **Step 1: Run local causal commands**

Run:

```sh
cd packages/zigeffect && zig build causal-artifacts
cd packages/zigeffect && zig build causal-test
cd packages/zigeffect && zig build examples
cd packages/zigeffect && zig build test --summary none
```

Expected: all commands exit zero.

- [ ] **Step 2: Check workflow and diff hygiene**

Run:

```sh
git diff --check
git status --short --branch
```

Expected: no whitespace errors; only intended files are modified.

- [ ] **Step 3: Commit**

Run:

```sh
git add .github/workflows/zigeffect-causal.yml \
  docs/superpowers/specs/2026-06-07-zigeffect-causal-ci-artifacts-design.md \
  docs/superpowers/plans/2026-06-07-zigeffect-causal-ci-artifacts.md \
  docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md \
  packages/zigeffect/docs/agent-guide.md \
  packages/zigeffect/docs/agent-observable-runtime.md \
  packages/zigeffect/docs/causal-scenarios.md \
  packages/zigeffect/docs/roadmap.md
git commit -m "ci(zigeffect): upload causal artifacts on failure"
```

## Self-Review

- Spec coverage: The workflow, docs, verification, and commit are covered.
- Placeholder scan: no placeholder-only steps remain.
- Type consistency: command names and artifact globs match the manifest command.
