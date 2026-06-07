# zigeffect Causal CI Artifacts Design

## Summary

Add the first repository CI workflow that runs `zigeffect` through its causal
development harness and uploads only causal artifacts when the job fails.

This turns the local dogfood lane into a real development feedback loop: agents
and humans can inspect `.txt`, `.json`, and `.dot` causal evidence from failed
CI runs without guessing which `.zig-cache` files matter.

## Problem

`zigeffect` now has local causal commands:

- `zig build causal-artifacts`
- `zig build causal-test`
- `zig build examples`
- `zig build test`

The package also has a deterministic artifact manifest. But the repository has
no `.github/workflows` directory, so CI does not yet run those commands or
preserve their artifacts. That leaves the self-improving agent workflow local
only.

## Goals

- Add a GitHub Actions workflow for `zigeffect` causal CI.
- Install Zig `0.16.0`, matching the local toolchain used by this repo.
- Print `zig build causal-artifacts` so the CI log names the artifact contract.
- Run `zig build causal-test` to generate baseline dogfood artifacts.
- Run `zig build examples`.
- Run `zig build test --summary none`, which is the causal package-test gate.
- Upload only `.zig-cache/causal-artifacts/*.txt`, `.json`, and `.dot` on job
  failure.
- Keep upload paths rooted under `packages/zigeffect`.
- Avoid uploading the rest of `.zig-cache`.

## Non-Goals

- Do not add deployment CI.
- Do not run app or marketing checks in this workflow.
- Do not make `causal-check` a required CI gate yet; it intentionally fails on
  current dogfood findings.
- Do not upload artifacts on successful runs.
- Do not add CI secret scanning or artifact redaction beyond the existing
  causal runtime safeguards.

## Workflow Shape

Create `.github/workflows/zigeffect-causal.yml`.

Triggers:

- `pull_request`
- `push` to `master`
- `workflow_dispatch`

Path filters should include:

- `.github/workflows/zigeffect-causal.yml`
- `packages/zigeffect/**`
- root `package.json`
- root `bun.lock`

Job:

1. Check out the repository.
2. Install Zig `0.16.0` with `mlugg/setup-zig`.
3. Run `zig build causal-artifacts`.
4. Run `zig build causal-test`.
5. Run `zig build examples`.
6. Run `zig build test --summary none`.
7. Upload causal artifacts only if the job fails.

The upload step uses the same globs printed by `zig build causal-artifacts`:

```yaml
packages/zigeffect/.zig-cache/causal-artifacts/*.txt
packages/zigeffect/.zig-cache/causal-artifacts/*.json
packages/zigeffect/.zig-cache/causal-artifacts/*.dot
```

## Artifact Semantics

- `.txt`: human triage and compact report output.
- `.json`: agent query, compare, and advice tooling.
- `.dot`: graph visualization.

Dogfood artifacts are generated before the package gate. If the package gate
fails and writes `package-tests` artifacts, both the baseline dogfood evidence
and the failing package evidence are available to the upload step.

## Safety

The upload step intentionally ignores missing files so failures before artifact
generation do not hide the original job failure. It uploads only the causal
artifact globs and does not upload the rest of `.zig-cache`.

Causal events are already bounded, sampling-aware, taxonomy-versioned, and
defensively redacted for common secret-shaped strings. The workflow still keeps
uploads failure-only to avoid turning every successful CI run into public
artifact distribution.

## Acceptance Criteria

- `.github/workflows/zigeffect-causal.yml` exists.
- The workflow runs the causal manifest, dogfood harness, examples, and causal
  package-test gate.
- The upload step is guarded by `if: ${{ failure() }}`.
- The upload step lists only `.txt`, `.json`, and `.dot` files under
  `packages/zigeffect/.zig-cache/causal-artifacts/`.
- Local verification of all commands passes.
- YAML parses structurally.

## Spec Self-Review

- Placeholder scan: no placeholders remain.
- Internal consistency: command names match current `packages/zigeffect`
  `build.zig` steps.
- Scope check: one CI workflow for `zigeffect`; no app, deploy, or repo-wide CI.
- Ambiguity check: artifact upload is failure-only and causal-glob-only.
