# zigeffect Causal Audit-Chain Snapshot Compare Design

Date: 2026-06-11
Branch: `codex/zigeffect-causal-audit-chain-snapshot-compare`
Status: Approved for implementation

## Summary

This branch adds a read-only comparison surface for named audit-chain snapshots.
The existing snapshot tool can already name and compare causal event artifacts,
and the existing audit-chain tool can already summarize one remediation chain.
The missing bridge is a schema-stable way to compare two retained
`zigeffect.causal.audit-chain.v1` artifacts as governance evidence.

The new surface is:

```sh
zig build causal-snapshot -- audit-chain-compare <left> <right>
```

`<left>` and `<right>` use the same snapshot reference rules as ordinary
snapshot comparison: either snapshot names or explicit snapshot manifest JSON
paths. The referenced artifact in each manifest must parse as an audit-chain
artifact. The command emits text by default and has a formatter that can produce
schema-governable JSON for tests and future agents.

This does not replay runtime events, execute remediation, approve proposals,
apply registry changes, edit source, write durable production history, or grant
mutation authority.

## Goals

- Add `zigeffect.causal.audit-chain-snapshot-compare.v1`.
- Compare two snapshot manifests whose `artifact.path` values point to
  `zigeffect.causal.audit-chain.v1` JSON.
- Report left/right snapshot identity, manifest path, audit-chain artifact path,
  target, phase, assessment, approval, applied state, finding delta, and event
  classification counts.
- Report signed deltas for disappeared, persisting, appeared, missing, and
  finding-delta evidence.
- Classify the comparison as `improved`, `regressed`, `unchanged`, or
  `inconclusive` without inferring source mutation.
- Surface manifest warnings and audit-chain compatibility warnings for both
  sides.
- Emit next-query hints that lead agents back to:
  - the left and right snapshot manifests;
  - the left and right audit-chain artifacts;
  - the audit-chain snapshot compare command for repeatable before/after
    review;
  - direct manifest inspection, because audit-chain governance JSON is not a
    core causal event-run artifact.
- Update schema governance, docs, roadmap, and production hardening backlog so
  this branch becomes the handoff into the next app-facing integration fixture.

## Non-Goals

- No live runtime execution, deterministic replay, or arbitrary event-log replay.
- No source edits, registry writes, proposal application, patch application, or
  app mutation.
- No durable writes, production writes, telemetry ingestion, or network calls.
- No Cockroach adapter work.
- No non-NenDB durable backend work.
- No workbench UI rendering changes in this branch.
- No schema migration of existing `audit-chain.v1` artifacts.
- No automatic claim that a remediation is fixed. The report is evidence, not
  authorization.

## Current Context

`packages/zigeffect/tools/causal_snapshot.zig` already owns:

- snapshot manifest schema `zigeffect.causal.snapshot-manifest.v1`;
- snapshot comparison schema `zigeffect.causal.snapshot-compare.v1`;
- snapshot reference resolution for names or manifest JSON paths;
- event-level comparison through `causal_compare.runCompare`;
- replay-feasibility, deterministic registered-scenario replay reports, and
  safe scenario fork proposals.

`packages/zigeffect/tools/causal_audit_chain.zig` already owns:

- audit-chain schema `zigeffect.causal.audit-chain.v1`;
- source chain validation over session, audit, decision, proposal, before,
  after, and compare artifacts;
- classification of proposal event ids as disappeared, persisting, appeared, or
  missing;
- assessment from finding delta plus event-classification fallback;
- guardrails that preserve `applied=false` and prevent evidence from becoming
  authorization.

The new branch should not duplicate the audit-chain generator. It should parse
the generated audit-chain artifacts as immutable snapshot contents.

## Chosen Approach

### Approach A: Extend `causal-snapshot` With `audit-chain-compare`

Add audit-chain snapshot comparison to `tools/causal_snapshot.zig`. This reuses
the manifest reference machinery and keeps all snapshot-like workflows under one
command. It also lets future agents compare ordinary causal snapshots and
audit-chain snapshots with parallel mental models.

This is the chosen approach.

### Approach B: Extend `causal-audit-chain`

Add `causal-audit-chain -- compare-snapshots <left> <right>`. This would keep
all audit-chain logic inside the audit-chain tool, but it would duplicate
snapshot reference resolution and make named-state comparison less cohesive.

### Approach C: Generic `causal-snapshot -- compare`

Teach the existing compare command to detect audit-chain artifacts. This risks
turning a causal event compare report into a polymorphic governance report and
could surprise existing consumers. A separate subcommand is clearer and safer.

## Schema

Add:

```zig
pub const audit_chain_snapshot_compare_schema =
    "zigeffect.causal.audit-chain-snapshot-compare.v1";
pub const audit_chain_snapshot_compare_schema_version: u32 = 1;
```

The JSON report should include:

- `schema`;
- `schema_version`;
- `status = "ready" | "blocked"`;
- `comparison = "improved" | "regressed" | "unchanged" | "inconclusive"`;
- `left` summary;
- `right` summary;
- `deltas`;
- `warnings`;
- `limitations`;
- `guardrails`;
- `next_queries`.

Left/right summaries include:

- `snapshot`;
- `manifest_path`;
- `artifact_path`;
- `target`;
- `phase`;
- `assessment`;
- `proposal_status`;
- `approval_status`;
- `approved`;
- `applied`;
- `finding_delta`;
- `event_ids`;
- `disappeared_event_ids`;
- `persisting_event_ids`;
- `appeared_event_ids`;
- `missing_event_ids`.

`deltas` include:

- `finding_delta_delta`;
- `event_id_delta`;
- `disappeared_delta`;
- `persisting_delta`;
- `appeared_delta`;
- `missing_delta`;
- `applied_delta`.

`status` is `blocked` when either side is not a supported audit-chain artifact
or either side has `applied=true`; otherwise `ready`.

## Text Report

The text report should be deterministic:

```text
zigeffect causal audit-chain snapshot compare report
schema: zigeffect.causal.audit-chain-snapshot-compare.v1
schema version: 1
status: ready
comparison: improved
left snapshot: baseline-chain
left manifest: .zig-cache/causal-artifacts/zigeffect-causal-snapshot-baseline-chain.json
left artifact: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-audit-chain.json
left assessment: unchanged
left approved: true
left applied: false
left finding delta: +0
right snapshot: after-chain
right manifest: .zig-cache/causal-artifacts/zigeffect-causal-snapshot-after-chain.json
right artifact: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-after-audit-chain.json
right assessment: improved
right approved: true
right applied: false
right finding delta: -1
deltas:
- finding_delta_delta: -1
- disappeared_delta: +1
- persisting_delta: -1
- appeared_delta: +0
- missing_delta: +0
warnings:
- none
limitations:
- compares retained audit-chain artifacts only
- does not prove source, registry, or app mutation
guardrails:
- Audit-chain snapshot comparison is evidence, not authorization.
- applied=true requires a separate reviewed application artifact.
next queries:
- zig build causal-snapshot -- audit-chain-compare <left> <right>
- inspect left audit-chain artifact: <left-audit-chain-artifact>
- inspect right audit-chain artifact: <right-audit-chain-artifact>
```

The report intentionally avoids `causal-query` next queries because audit-chain
artifacts are governance JSON, not core event-run artifacts with an `events`
array. It also avoids `causal-snapshot manifest` over those audit-chain
artifacts for the same reason. Agents should treat this command as the
read-only comparison surface for retained audit-chain evidence.

## Comparison Rules

The comparison should favor conservative evidence:

- if either side is blocked, comparison is `inconclusive`;
- if right `applied=true` and left `applied=false`, status is `blocked` because
  this branch cannot verify the reviewed application boundary;
- if right assessment improves from `regressed` or `unchanged` to `improved`,
  comparison is `improved`;
- if right finding delta is lower than left finding delta, comparison is
  `improved`;
- if right persisting or missing evidence decreases without a rise in appeared
  evidence, comparison is `improved`;
- if right assessment is worse, right finding delta is higher, or appeared or
  missing evidence increases materially, comparison is `regressed`;
- otherwise comparison is `unchanged` when both sides are supported and
  evidence counts are equal;
- otherwise comparison is `inconclusive`.

The implementation can use simple deterministic rules now. It should not
attempt semantic natural-language comparison of summaries or guardrails.

## CLI

Add:

```sh
zig build causal-snapshot -- audit-chain-compare <left> <right>
```

The command:

1. resolves both arguments through `resolveSnapshotManifestReference`;
2. reads both manifests;
3. reads both manifest artifact paths;
4. parses both artifact paths as audit-chain JSON;
5. prints the text report.

Formatter tests should exercise both text and JSON functions directly. The CLI
can print text only in this branch; JSON is still necessary as a schema contract
for governance and future agents.

## Documentation Updates

Update:

- `packages/zigeffect/README.md`;
- `packages/zigeffect/docs/agent-guide.md`;
- `packages/zigeffect/docs/agent-observable-runtime.md`;
- `packages/zigeffect/docs/schema-governance.md`;
- `packages/zigeffect/docs/production-hardening-backlog.md`;
- `packages/zigeffect/docs/roadmap.md`;
- `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`.

The docs should make the relationship clear:

1. `causal-audit-chain` creates a read-only chain artifact.
2. `causal-snapshot -- manifest <name> <audit-chain.json>` names that chain.
3. `causal-snapshot -- audit-chain-compare <left> <right>` compares two named
   chain states.

## Test Strategy

Add red tests in `packages/zigeffect/tools/causal_snapshot.zig` for:

- formatting audit-chain snapshot compare JSON;
- formatting audit-chain snapshot compare text;
- preserving left/right manifest and artifact paths;
- producing improved, regressed, unchanged, and blocked/inconclusive outcomes;
- warning on unsupported audit-chain schema or future schema versions;
- blocking `applied=true`;
- CLI usage includes `audit-chain-compare`.

Then update schema governance and backlog tests.

## Success Criteria

- `causal-snapshot -- audit-chain-compare <left> <right>` exists and prints a
  deterministic report.
- A new schema governance entry records
  `zigeffect.causal.audit-chain-snapshot-compare.v1`.
- The report is read-only, bounded to summary fields, and does not embed full
  audit-chain artifacts.
- The report blocks unsupported or applied audit-chain artifacts.
- Docs and backlog point to the next milestone after this branch.
- Verification passes with focused Zig tests, `zig build examples`,
  `zig build test`, `bun run check`, `bun run zig:test`, and `git diff --check`.
