# zigeffect Causal Artifact Manifest Design

## Summary

Add a `causal-artifacts` command that prints a deterministic manifest of
zigeffect causal artifacts and CI retention guidance.

```sh
cd packages/zigeffect
zig build causal-artifacts
```

The output should name stable artifact paths, roles, upload globs, and retention
notes so agents and CI jobs do not guess which files matter after causal
development checks fail.

## Problem

The causal runtime now writes many useful artifacts:

- dogfood reports;
- command scenario artifacts;
- package-test failure artifacts;
- before/after development loop JSON;
- compare reports;
- query reports;
- advice reports.

This is useful locally, but CI and agents still need a stable retention map.
Without one, each automation has to rediscover which `.zig-cache` files to
preserve and which are only transient build cache.

## Goals

- Add `zig build causal-artifacts`.
- Print line-oriented text suitable for humans, agents, and CI logs.
- Include upload globs for `.txt`, `.json`, and `.dot` causal artifacts.
- Include default dogfood and development-loop paths.
- Include scenario-specific report, JSON, and DOT paths from the scenario
  registry.
- Include scenario-loop before, after, compare, query, and advice paths.
- Include safety notes: artifacts are redacted and bounded, but still should be
  reviewed before public upload.

## Non-Goals

- Do not scan the filesystem in this slice.
- Do not upload artifacts.
- Do not create CI workflow files.
- Do not add JSON manifest output yet.
- Do not change artifact paths.

## Architecture

Create `packages/zigeffect/tools/causal_artifacts.zig`.

The tool imports `causal_run` so it can use:

- `causal_run.artifact_dir`;
- `causal_run.scenarioRegistry()`;
- `causal_run.artifactPaths()`.

It owns:

- `formatArtifactManifest(allocator)`;
- executable `main`;
- tests for default paths, scenario paths, dev-loop paths, and retention notes.

## Output Shape

```txt
zigeffect causal artifact manifest
artifact dir: .zig-cache/causal-artifacts
retention: upload causal artifacts on failed causal checks and after-phase dev loops
ci upload globs:
- .zig-cache/causal-artifacts/*.txt
- .zig-cache/causal-artifacts/*.json
- .zig-cache/causal-artifacts/*.dot

default artifacts:
- dogfood report .zig-cache/causal-artifacts/zigeffect-causal-dogfood.txt
- dev-loop advice .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-advice.txt

scenario artifacts:
- scenario package-tests
  report: .zig-cache/causal-artifacts/zigeffect-causal-package-tests.txt
```

## CI Guidance

CI should generally:

1. run `zig build test` or a targeted `causal-dev-loop`;
2. always upload `.zig-cache/causal-artifacts/*.txt`,
   `.zig-cache/causal-artifacts/*.json`, and
   `.zig-cache/causal-artifacts/*.dot` when the causal check fails;
3. prefer `.txt` for quick human triage, `.json` for agent queries, and `.dot`
   for graph visualization;
4. avoid uploading the rest of `.zig-cache`;
5. review artifacts before public distribution.

## Testing

Tests should cover:

- header and artifact directory;
- CI upload globs;
- dogfood artifact paths;
- default dev-loop advice path;
- at least one scenario artifact path;
- at least one scenario dev-loop advice path;
- safety notes.

## Acceptance Criteria

- `zig build causal-artifacts` exits zero and prints the manifest.
- `zig build examples` compiles and tests the tool.
- `zig build test --summary none` passes.
- `bun run zig:test` passes.
- Docs mention the manifest command and CI retention usage.

## Roadmap Position

This is a Milestone 8 hardening slice. It does not make the runtime more
powerful, but it makes the existing self-improvement artifacts practical for CI
and repeatable agent workflows.

## Spec Self-Review

- Placeholder scan: no unresolved placeholders remain.
- Internal consistency: command name, artifact directory, and globs are stable.
- Scope check: one local manifest command; no CI workflow creation or upload.
- Ambiguity check: the manifest enumerates expected stable paths, not current
  filesystem state.
