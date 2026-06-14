# zigeffect Self-Improving AI Engine Readiness

Date: 2026-06-14

This document is the current operating map for using `zigeffect`'s causal
runtime to improve `zigeffect` itself, then to help agents understand apps built
with `zigeffect`.

## Current State

The local engine-AI loop is ready for agent-assisted development. It can run
causal scenarios, capture before/after artifacts, emit bounded query commands,
summarize findings, produce remediation/audit records, and keep a human-review
handoff chain.

The app-AI loop is ready as an advisory substrate. It can consume app semantic
trace artifacts, classify incidents, draft remediation reports, apply policy
gates, and prepare reviewed application records. It is not an autonomous app
mutation engine.

The audit-chain/data-pattern branch
`codex/zigeffect-causal-audit-chain-comparison` is superseded by master. Its
core work was re-landed and expanded in newer master commits for
`causal_audit_chain`, `fx.data`, `fx.match`, `fx.pattern`, and `fx.traits`.
Do not merge that old branch tip wholesale; it predates the clustering,
workflow, and causal agent work now present on master.

## Root Commands

From the repository root:

```sh
bun run zigeffect:self-improve:start
# edit zigeffect
bun run zigeffect:self-improve:assess
bun run zigeffect:self-improve:agent
bun run zigeffect:self-improve:feedback-loop
```

Pass a scenario after `--` when the work is narrow:

```sh
bun run zigeffect:self-improve:start -- causal-scoped-fiber
bun run zigeffect:self-improve:assess -- causal-scoped-fiber
bun run zigeffect:self-improve:agent -- causal-scoped-fiber
```

Use the lower-level harness commands when a task only needs one phase:

```sh
bun run zigeffect:causal-dev-test
bun run zigeffect:causal-loop:baseline
bun run zigeffect:causal-loop:after
bun run zigeffect:causal-ci-handoff
```

## Engine AI

Engine AI means agents improving `packages/zigeffect` with causal evidence from
`zigeffect` itself.

The ready path is:

1. Capture baseline evidence with `causal-dev-session -- start`.
2. Make a focused code or doc change.
3. Run `causal-dev-session -- assess` to execute after-capture, agent report,
   diagnosis, remediation plan, and remediation audit.
4. Read event ids, findings, query reports, compare reports, and advice before
   claiming behavioral impact.
5. Run the normal verification commands for the code touched.

The engine can prepare registry proposals and application records, but source
changes still happen through normal reviewed edits. A record may say
`applied=true` only after the actual reviewed update and before/after
verification happened.

## App AI

App AI means agents understanding and improving applications that use
`zigeffect`.

The ready path is advisory:

- app traces use the shared causal event model;
- app remediation audits classify likely issue type and evidence ids;
- app policy gates identify whether a source, config, migration, operational,
  rollback, or human-review path is required;
- app application records preserve the before/after and review boundary.

The app path cannot write app data, mutate config, run migrations, deploy,
enforce CI, update GitHub, write production telemetry, or auto-apply patches.

## Shared Evidence Surface

Both paths use the same evidence discipline:

- `zigeffect.causal.v1` event artifacts are the source of truth.
- `causal-query` is the bounded machine interface.
- The SolidJS `zig-webui` workbench is the human read-only interface.
- Reports and policies are evidence records, not authority.
- Redaction, bounded memory, artifact truncation, and sampling limits are part
  of the runtime contract.
- NenDB is the durable storage direction, but the live self-improving loop does
  not write NenDB records today.
- Cockroach scope is intentionally excluded from this loop.

## Ready Checklist

Before assigning an agent to a self-improvement task:

- choose a scenario with `bun run zigeffect:causal-catalog`;
- run `bun run zigeffect:self-improve:start -- <scenario>`;
- keep the task scoped to one runtime or docs concern;
- run `bun run zigeffect:self-improve:assess -- <scenario>` after edits;
- cite compare/advice/query evidence in the summary;
- run package verification before committing.

## Remaining Gates

These are deliberately not ready as autonomous behavior:

- live upstream NenDB writes from the self-improving loop;
- durable cross-session learning memory;
- production telemetry ingestion;
- app source/config/migration mutation;
- deployment, rollout, or GitHub workflow mutation;
- required status check enforcement;
- model training or unreviewed automatic patch application.

The next useful branch should run the first real self-improvement session using
this loop on a small `zigeffect` issue, then preserve the artifacts and compare
report as an example for future agents.
