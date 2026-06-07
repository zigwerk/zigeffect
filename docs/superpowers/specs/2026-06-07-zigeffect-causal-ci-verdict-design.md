# zigeffect Causal CI Verdict Design

## Purpose

Agents working on `zigeffect` should have one stable first-read artifact that
answers: what happened, is there new evidence, and which report should be read
next? The current CI handoff is useful, but it is a text list of artifacts and
commands. It does not give agents a compact structured verdict.

This slice adds a generated CI verdict JSON artifact:

```text
.zig-cache/causal-artifacts/zigeffect-causal-ci-verdict.json
```

The verdict is written by `zig build causal-ci-handoff`, because that tool is
already the CI aggregation point and already knows which JSON artifacts,
baselines, compare reports, and advice reports exist.

## Current State

`causal-ci-handoff` already:

- discovers known causal JSON artifact paths;
- pairs head artifacts with baseline JSON files when available;
- writes generated advice reports for all discovered artifacts;
- writes generated compare reports for paired artifacts;
- writes `zigeffect-causal-ci-handoff.txt` with exact follow-up commands.

The missing piece is a structured summary that an agent can parse without first
walking every advice and compare report.

## Verdict Format

The JSON verdict should be intentionally small and deterministic:

```json
{
  "schema": "zigeffect.causal.ci-verdict.v1",
  "schema_version": 1,
  "status": "attention",
  "next_action": "inspect-new-advice",
  "json_artifacts": 2,
  "baseline_pairs": 1,
  "actions": 3,
  "new_actions": 1,
  "persisting_actions": 2,
  "observed_actions": 0,
  "artifacts": [
    {
      "json_path": ".zig-cache/causal-artifacts/zigeffect-causal-package-tests.json",
      "baseline_path": ".zig-cache/causal-artifacts/zigeffect-causal-ci-baseline-package-tests.json",
      "advice_report_path": ".zig-cache/causal-artifacts/zigeffect-causal-package-tests-advice.txt",
      "compare_report_path": ".zig-cache/causal-artifacts/zigeffect-causal-package-tests-ci-compare.txt",
      "actions": 1,
      "new_actions": 1,
      "persisting_actions": 0,
      "observed_actions": 0
    }
  ]
}
```

### Status Values

- `clear`: no discovered artifact has advice actions.
- `attention`: one or more artifacts have advice actions.

### Next Action Values

- `inspect-new-advice`: at least one action has `status=new`.
- `inspect-observed-advice`: at least one action has `status=observed` and no
  new action exists.
- `inspect-persisting-advice`: only persisting actions exist.
- `none`: no advice actions exist.

This keeps the first slice simple. It does not try to infer severity,
ownership, or an automatic fix.

## Counting Rules

The verdict should count advice actions by parsing generated `*-advice.txt`
reports. The action lines already use stable text:

```text
- action <name> status=<observed|new|persisting> event=<id> ...
```

For each artifact:

- `actions` counts every line beginning with `- action `;
- `new_actions` counts action lines containing ` status=new `;
- `persisting_actions` counts action lines containing ` status=persisting `;
- `observed_actions` counts action lines containing ` status=observed `.

Aggregate counts are the sums across artifacts. This avoids reimplementing the
advice engine and keeps verdict semantics tied to the actual generated advice
reports.

## Handoff Integration

The text handoff should point at the verdict file near the header:

```text
verdict: .zig-cache/causal-artifacts/zigeffect-causal-ci-verdict.json
```

The artifact manifest should list the verdict JSON under default artifacts so
CI and agents know it is part of the retained bundle.

## Failure Modes

- If no JSON artifacts exist, the verdict should still be written with
  `status=clear`, `next_action=none`, zero counts, and an empty `artifacts`
  array.
- If an advice report is missing, handoff should fail. The verdict must not
  summarize incomplete evidence.
- If a path contains JSON-special characters, the verdict must escape it.

## Exit Criteria

- `zig build causal-ci-handoff` writes
  `.zig-cache/causal-artifacts/zigeffect-causal-ci-verdict.json`.
- The verdict includes aggregate action counts and per-artifact action counts.
- The verdict distinguishes `new`, `persisting`, and `observed` advice.
- The text handoff points at the verdict path.
- The artifact manifest lists the verdict path.
- `zig build examples`, `zig build test --summary none`, `bun run zig:test`,
  and `git diff --check` pass.
