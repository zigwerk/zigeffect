# zigeffect Causal CI Handoff Design

## Summary

Add a `causal-ci-handoff` command that writes a compact agent handoff report
from the causal JSON artifacts present in `.zig-cache/causal-artifacts/`.

The CI workflow should run this command after a failed causal gate and before
artifact upload. The uploaded artifact set will then include one "start here"
text report with exact local follow-up commands.

## Problem

The current CI workflow uploads causal `.txt`, `.json`, and `.dot` artifacts on
failure. That preserves evidence, but an agent still has to inspect the bundle
and choose where to start.

The local tooling already knows the useful commands:

- `zig build causal-advice -- --file <artifact.json>`
- `zig build causal-query -- --file <artifact.json> snapshot`
- `zig build causal-query -- --file <artifact.json> cause <event_id>`

CI should include those instructions as an artifact, not rely on the agent to
reconstruct them from docs.

## Goals

- Add `zig build causal-ci-handoff`.
- Write `.zig-cache/causal-artifacts/zigeffect-causal-ci-handoff.txt`.
- Print the same report to stdout.
- Include only JSON artifacts that currently exist.
- For each JSON artifact, include exact `causal-advice` and `causal-query`
  commands.
- Include retention guidance that CI uploads only causal artifact globs.
- Include the handoff report in `zig build causal-artifacts`.
- Run the command from `.github/workflows/zigeffect-causal.yml` on failure
  before artifact upload.

## Non-Goals

- Do not parse findings or generate patches in this slice.
- Do not scan arbitrary filesystem paths.
- Do not upload successful-run handoff reports.
- Do not change causal JSON schema.
- Do not make the handoff step fail when no causal JSON artifacts exist.

## Architecture

Create `packages/zigeffect/tools/causal_handoff.zig`.

The tool imports `causal_run` so it can reuse:

- `artifact_dir`;
- `artifactPaths`;
- `scenarioRegistry`.

It owns:

- `handoff_report_path`;
- `formatCiHandoffReport(allocator, json_artifact_paths)`;
- a small static candidate builder for dogfood, package-test, scenario, and
  dev-loop JSON paths;
- executable `main` that checks which candidate JSON files exist, writes the
  report artifact, and prints it.

The tool should not infer runtime behavior. It only turns artifact presence into
deterministic next-step commands.

## Candidate Paths

The executable should check these JSON candidates:

- `.zig-cache/causal-artifacts/zigeffect-causal-dogfood.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-before.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-after.json`
- each scenario JSON from `causal_run.artifactPaths`;
- each scenario dev-loop before JSON;
- each scenario dev-loop after JSON.

This covers the current CI workflow, package-test failure capture, and local
before/after scenario loops without requiring directory scanning.

## Output Shape

```text
zigeffect causal CI handoff
artifact dir: .zig-cache/causal-artifacts
handoff: .zig-cache/causal-artifacts/zigeffect-causal-ci-handoff.txt
json artifacts: 2

- artifact .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json
  advice: zig build causal-advice -- --file .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json
  snapshot: zig build causal-query -- --file .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json snapshot
```

When no JSON artifacts exist, print:

```text
json artifacts: 0
- no causal JSON artifacts found
```

## CI Behavior

Add a workflow step before upload:

```yaml
- name: Write causal CI handoff
  if: ${{ failure() }}
  working-directory: packages/zigeffect
  run: zig build causal-ci-handoff
```

Because the command writes a `.txt` file under the causal artifact directory,
the existing upload globs will retain it automatically.

## Acceptance Criteria

- `zig build causal-ci-handoff` exits zero.
- The command writes
  `.zig-cache/causal-artifacts/zigeffect-causal-ci-handoff.txt`.
- The report lists existing JSON artifacts and exact advice/query commands.
- The report is explicit when no JSON artifacts exist.
- `zig build causal-artifacts` lists the handoff report path.
- `zig build examples` compiles and tests the new tool.
- The CI workflow runs handoff generation on failure before upload.

## Spec Self-Review

- Placeholder scan: no placeholders remain.
- Internal consistency: command and artifact path names are stable.
- Scope check: this is one handoff artifact, not a new analysis engine.
- Ambiguity check: candidate paths are explicit and no arbitrary scan is used.
