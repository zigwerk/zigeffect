# zigeffect Causal CI Generated Advice Design

## Summary

Extend `zig build causal-ci-handoff` so failed CI bundles contain generated
causal advice reports, not only commands telling agents how to produce advice
later.

The command should keep writing
`.zig-cache/causal-artifacts/zigeffect-causal-ci-handoff.txt`, and it should
also write one advice `.txt` artifact for each existing causal JSON artifact it
finds.

## Problem

The current CI handoff report is useful but still asks the next agent to run
`zig build causal-advice` locally for each JSON artifact. That is acceptable
for local development, but in CI handoff the uploaded bundle should already
contain the first layer of deterministic analysis.

`causal_advice.buildAdviceReport` already turns saved JSON evidence into
non-mutating actions. CI should reuse that implementation instead of creating
another analysis path.

## Goals

- Reuse `causal_advice.buildAdviceReport`.
- For each existing JSON artifact discovered by `causal-ci-handoff`, write an
  advice report under `.zig-cache/causal-artifacts/`.
- Name generated reports deterministically by appending `-advice.txt` to the
  JSON artifact basename.
- Include the generated advice report path in the handoff report.
- Keep exact local `causal-advice` and `causal-query` commands in the handoff.
- Let CI upload generated advice reports through the existing `.txt` glob.

## Non-Goals

- Do not generate patches.
- Do not add baseline-aware advice in this slice.
- Do not execute query reports for every artifact.
- Do not scan arbitrary directories.
- Do not fail if no JSON artifacts exist.

## Architecture

Modify `packages/zigeffect/tools/causal_handoff.zig`.

Add:

- `adviceReportPathForJsonArtifact(allocator, json_path)`;
- `writeAdviceReportsForArtifacts(io, allocator, json_artifact_paths)`;
- handoff report lines for generated advice report paths.

The report path transform is:

```text
.zig-cache/causal-artifacts/zigeffect-causal-dogfood.json
-> .zig-cache/causal-artifacts/zigeffect-causal-dogfood-advice.txt
```

`main` should:

1. collect existing JSON artifact paths;
2. write generated advice reports for those paths;
3. format and write the handoff report;
4. print the handoff report.

## Output Shape

```text
- artifact .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json
  advice report: .zig-cache/causal-artifacts/zigeffect-causal-dogfood-advice.txt
  advice: zig build causal-advice -- --file .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json
  snapshot: zig build causal-query -- --file .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json snapshot
```

## CI Behavior

The existing workflow step remains:

```yaml
- name: Write causal CI handoff
  if: ${{ failure() }}
  working-directory: packages/zigeffect
  run: zig build causal-ci-handoff
```

Because generated advice reports are `.txt` files under
`.zig-cache/causal-artifacts/`, the existing upload globs retain them.

## Acceptance Criteria

- `zig build causal-ci-handoff` exits zero.
- Existing JSON artifacts produce generated `*-advice.txt` reports.
- The handoff report lists generated advice report paths.
- `zig build examples` covers the new path transform and handoff content.
- `bun run zig:test` remains green.
- Docs tell agents that CI bundles now include generated advice reports.

## Spec Self-Review

- Placeholder scan: no placeholders remain.
- Internal consistency: generated advice report names are deterministic.
- Scope check: this adds generated advice only, not baseline comparison.
- Ambiguity check: no JSON artifacts means no generated advice and still a
  successful handoff.
