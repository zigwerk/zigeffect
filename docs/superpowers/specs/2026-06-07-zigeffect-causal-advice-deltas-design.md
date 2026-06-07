# zigeffect Causal Advice Deltas Design

## Summary

Extend `causal-advice` so it can compare before and after causal artifacts and
label each advice action as `new`, `persisting`, or `observed`.

The current command remains valid:

```sh
zig build causal-advice -- --file <after.json>
```

The new form is:

```sh
zig build causal-advice -- --before <before.json> --file <after.json>
```

`zig build causal-dev-loop -- after` should use the new before-aware path so its
advice report distinguishes fresh regressions from already-known fixture
evidence.

## Problem

The first advice report turns causal evidence into next actions, but it cannot
tell whether an action is new after a patch or persisted from the baseline.
That weakens the self-improving loop: a development agent should respond very
differently to "this patch introduced a missing service" versus "the dogfood
fixture intentionally still contains the same missing service evidence."

## Goals

- Preserve single-artifact advice output.
- Add optional before/after advice comparison.
- Mark actions from after artifacts as:
  - `new` when no matching action existed before;
  - `persisting` when the same action existed before;
  - `observed` when no before artifact is supplied.
- Use stable action signatures rather than raw event ids alone.
- Make `causal-dev-loop -- after` write before-aware advice reports.
- Keep the report line-oriented and deterministic.

## Non-Goals

- Do not parse compare report text.
- Do not add probabilistic scoring.
- Do not suppress persisting actions; agents should still see known evidence.
- Do not add remediation or patch generation.
- Do not introduce a JSON advice schema in this slice.

## Action Signature

An advice action signature is:

```txt
action name + event kind + label + type_name + status + run_id? + scope_id?
```

Event ids remain printed for direct query commands, but they are not enough for
cross-artifact comparison because event ids can shift when new events are
inserted before a finding.

## Output Shape

Single artifact:

```txt
- action provide-missing-service status=observed event=3 kind=service_required label=Config
```

Before/after artifact:

```txt
- action provide-missing-service status=persisting event=3 kind=service_required label=Config
- action inspect-command-failure status=new event=9 kind=assertion_recorded label=package-tests
```

The header should include the baseline when supplied:

```txt
zigeffect causal advice report
artifact: .zig-cache/causal-artifacts/after.json
baseline: .zig-cache/causal-artifacts/before.json
actions: 4
```

## CLI

Accept these forms:

```sh
zig build causal-advice -- --file <after.json>
zig build causal-advice -- <after.json>
zig build causal-advice -- --before <before.json> --file <after.json>
zig build causal-advice -- --file <after.json> --before <before.json>
```

Invalid or missing flag values should print usage and exit nonzero without a
Zig stack trace.

## Development Loop Integration

`runAfter` already has both `before` and `after` JSON. It should call a new
before-aware helper, then write the same advice path:

```zig
causal_advice.buildAdviceReportWithBaseline(
    allocator,
    before,
    paths.before_json_path,
    after,
    paths.after_json_path,
)
```

Dogfood after advice should therefore mark the four intentional fixture actions
as `persisting`.

## Testing

Tests should cover:

- single artifact actions use `status=observed`;
- matching before/after actions use `status=persisting`;
- after-only actions use `status=new`;
- matching does not rely on identical event ids;
- CLI accepts `--before <before> --file <after>` in either flag order;
- `causal-dev-loop -- after` writes persisting actions for unchanged dogfood
  evidence.

## Acceptance Criteria

- `zig build causal-advice -- --file <artifact>` still works.
- `zig build causal-advice -- --before <before> --file <after>` works.
- Development loop advice reports contain `status=persisting` for unchanged
  dogfood evidence.
- New after-only advice fixtures produce `status=new`.
- `zig build examples`, `zig build test`, and `bun run zig:test` pass.

## Roadmap Position

This is the next Milestone 7 slice after deterministic advice reports. It makes
the self-improvement loop more useful by separating regressions from stable
known evidence without adding policy-sensitive remediation.

## Spec Self-Review

- Placeholder scan: no unresolved placeholders remain.
- Internal consistency: status names are stable across output, CLI, loop, and
  tests.
- Scope check: this is one local tooling extension. Compare report parsing and
  remediation remain out of scope.
- Ambiguity check: raw event ids are query targets, not comparison keys.
