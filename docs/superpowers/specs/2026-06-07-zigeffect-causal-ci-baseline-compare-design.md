# zigeffect Causal CI Baseline Compare Design

## Purpose

`zigeffect` CI should give a development agent more than "this run failed".
When a pull request fails, the uploaded causal bundle should also say whether
the actionable evidence is new relative to the pull request base commit or was
already present there.

This design extends the current causal CI handoff lane. The handoff already
lists JSON artifacts and writes deterministic `*-advice.txt` reports. The next
slice makes those reports baseline-aware when a matching baseline artifact is
available, and teaches CI to capture that baseline for pull requests.

## Current State

The repository already has these causal development surfaces:

- `zig build causal-test` writes deterministic dogfood text, JSON, and DOT.
- `zig build test --summary none` is the normal package-test gate and writes
  package-test causal artifacts on failure.
- `zig build causal-compare -- <before.json> <after.json>` compares saved
  artifacts.
- `zig build causal-advice -- --before <before.json> --file <after.json>`
  marks actions as `status=persisting` or `status=new`.
- `zig build causal-dev-loop -- baseline|after [scenario]` writes local
  before/after, compare, query, and advice artifacts.
- `zig build causal-ci-handoff` writes a first-read CI failure report and
  generated single-artifact advice reports.

The gap is that clean CI checkouts do not naturally have a before artifact. A
handoff report can only become delta-aware if CI captures a base-commit
baseline and leaves it in the head checkout artifact directory before the
failure handoff runs.

## Options Considered

### Option A: Pair Only Existing Local Before/After Files

The handoff could detect `*-after.json` and pair it with `*-before.json` if both
files already exist. This is useful for local dev-loop runs, but it does not
solve pull request CI because the job starts from a clean checkout.

### Option B: Download Artifacts From A Previous Successful Main Run

CI could download the last successful main-branch causal artifact bundle and
compare the pull request against it. This is powerful, but it adds GitHub API
coupling, artifact retention edge cases, and ambiguity when several relevant
base commits exist.

### Option C: Capture The Pull Request Base In The Same Job

CI can fetch the pull request base SHA, add a temporary git worktree, run a
small causal baseline there, and copy selected baseline JSON files into the
head checkout before running the current head checks. This keeps the comparison
deterministic, requires no external artifact lookup, and ties the baseline to
the exact PR base commit.

Recommended first slice: Option C, plus the local pair detection from Option A.

## Artifact Contract

The head checkout artifact directory remains:

```text
.zig-cache/causal-artifacts
```

For pull request CI, the workflow should copy base-commit baseline JSON files
into that directory before running head checks:

```text
.zig-cache/causal-artifacts/zigeffect-causal-ci-baseline-dogfood.json
.zig-cache/causal-artifacts/zigeffect-causal-ci-baseline-package-tests.json
```

The head artifacts keep their current names:

```text
.zig-cache/causal-artifacts/zigeffect-causal-dogfood.json
.zig-cache/causal-artifacts/zigeffect-causal-package-tests.json
```

The handoff should also continue to support local dev-loop pairs:

```text
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-before.json
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-after.json
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-before.json
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-after.json
```

## Pairing Rules

`causal-ci-handoff` should inspect every existing JSON artifact candidate and
resolve a baseline as follows:

1. `zigeffect-causal-dogfood.json` pairs with
   `zigeffect-causal-ci-baseline-dogfood.json` when the baseline file exists.
2. `zigeffect-causal-package-tests.json` pairs with
   `zigeffect-causal-ci-baseline-package-tests.json` when the baseline file
   exists.
3. Any artifact ending in `-after.json` pairs with the same path ending in
   `-before.json` when that baseline file exists.
4. All other artifacts keep the current single-artifact advice behavior.

For paired artifacts, the generated advice report should call
`causal_advice.buildAdviceReportWithBaseline`. For unpaired artifacts, it should
continue to call `causal_advice.buildAdviceReport`.

## Generated Reports

For every existing JSON artifact:

```text
<artifact-stem>-advice.txt
```

For every paired artifact:

```text
<artifact-stem>-ci-compare.txt
```

If the artifact already follows the local dev-loop `-after.json` naming shape,
the compare path should use the existing local convention:

```text
<after-stem-without--after>-compare.txt
```

Examples:

```text
zigeffect-causal-package-tests.json
-> zigeffect-causal-package-tests-advice.txt
-> zigeffect-causal-package-tests-ci-compare.txt

zigeffect-causal-dev-loop-causal-scoped-fiber-after.json
-> zigeffect-causal-dev-loop-causal-scoped-fiber-advice.txt
-> zigeffect-causal-dev-loop-causal-scoped-fiber-compare.txt
```

## Handoff Output

The handoff should remain the first file an agent reads. For paired artifacts,
it should include:

```text
- artifact <after.json>
  baseline: <before.json>
  compare report: <compare.txt>
  advice report: <advice.txt>
  compare: zig build causal-compare -- <before.json> <after.json>
  advice: zig build causal-advice -- --before <before.json> --file <after.json>
  snapshot: zig build causal-query -- --file <after.json> snapshot
```

For unpaired artifacts, it should keep the current shape:

```text
- artifact <artifact.json>
  advice report: <advice.txt>
  advice: zig build causal-advice -- --file <artifact.json>
  snapshot: zig build causal-query -- --file <artifact.json> snapshot
```

The report header should include a baseline-pair count so agents can tell
whether CI produced delta-aware evidence:

```text
baseline pairs: 2
```

## CI Workflow

For `pull_request` events, the workflow should:

1. fetch the exact base SHA;
2. add a temporary worktree for that SHA;
3. run base dogfood capture from that worktree;
4. run base package-test scenario baseline from that worktree;
5. copy the two baseline JSON files into the head checkout artifact directory;
6. run the current head checks as it already does;
7. run `zig build causal-ci-handoff` on failure.

The base capture should not run on `push` to `master`; there is no separate PR
base to compare against there.

## Failure Modes

- If base capture fails, the PR should fail. A bad or unbuildable base commit is
  not a trustworthy baseline.
- If no matching baseline file exists, handoff should still write
  single-artifact advice exactly as it does today.
- If compare or baseline-aware advice parsing fails, handoff should fail rather
  than upload misleading reports.
- Uploaded artifacts should still be limited to causal `.txt`, `.json`, and
  `.dot` files.

## Testing Strategy

Unit tests should prove:

- dogfood and package-test artifact names resolve to their CI baseline files;
- `-after.json` resolves to `-before.json`;
- unpaired artifacts remain single-artifact advice;
- paired handoff output includes baseline, compare, and before-aware advice
  commands;
- generated paired advice includes `status=persisting` and `status=new` when
  the before/after sample requires both;
- compare reports are written for paired artifacts.

Workflow verification should prove the YAML contains the base capture step and
the existing failure-only upload contract remains intact.

## Exit Criteria

- `zig build causal-ci-handoff` writes baseline-aware advice and compare reports
  when baseline JSON files exist.
- `zig build causal-ci-handoff` keeps single-artifact advice when no baseline is
  present.
- Pull request CI captures base dogfood and package-test baseline JSON files
  before current head checks.
- The handoff report tells agents which artifacts are paired and which are not.
- `zig build examples`, `zig build test --summary none`, `bun run zig:test`,
  and `git diff --check` pass.
