# Agent Workflow Studio

Agent Workflow Studio is the governed authoring and operations layer for
ZigEffect statecharts. It lets agents compose visible workflow logic while
keeping typed Zig definitions, deterministic reducers and durable journals as
the production authority.

## End-to-end lifecycle

1. An agent creates a bounded `zigeffect.statechart.workflow-plan.v1` document
   or expands one of the reusable patterns.
2. `zigeffect statechart compile` validates hierarchy, terminal behavior,
   references, identifiers and secret-free metadata, then deterministically
   generates a typed Zig definition. Generated guards fail closed.
3. Native validation, static analysis, model paths, deterministic simulation,
   temporal invariants, mutation points, XState differential execution, fault
   tests and performance budgets produce a proof bundle.
4. A proposal binds the base and next versions, fingerprints, definition digest
   and semantic-diff digest.
5. A human review binds the exact proposal and proof digests. An approval binds
   that exact review and expires closed.
6. A separately authorized host control policy checks the live definition
   fingerprint, fence epoch, requested operation and immutable governance chain.
7. Application produces a digest-bound receipt with a causal event identity.
   The catalog retains every definition version and the Workbench renders the
   logic, proof, governance chain, fleet health and execution overlay.

Approval and mutation authority are intentionally different capabilities. The
`GovernedControlPolicy` returns `human_review` when the chain is valid but the
host has not granted mutation authority.

## Author workflow

List and expand patterns:

```sh
zigeffect statechart patterns --json
zigeffect statechart pattern parallel_research --namespace research.release --json
```

Preview compilation without writing:

```sh
zigeffect statechart compile workflows/release.json
```

Apply an inspected source generation:

```sh
zigeffect statechart compile workflows/release.json \
  --output src/statecharts/release.zig --apply
```

The plan is an authoring IR, not a dynamic production interpreter. Review the
generated source, implement guards/actions through typed Effect services, and
compile it through the normal application tests.

## Governance artifact workflow

Each command previews to stdout unless both `--output` and `--apply` are used.
Paths must be relative, bounded, and remain inside the selected project root.

```sh
zigeffect statechart propose proposal-input.json \
  --output .zigeffect/statecharts/proposals/release-v2.json --apply
zigeffect statechart verify proof-input.json \
  --output .zigeffect/statecharts/proofs/release-v2.json --apply
zigeffect statechart review review-input.json \
  --output .zigeffect/statecharts/reviews/release-v2.json --apply
zigeffect statechart approve approval-input.json \
  --output .zigeffect/statecharts/approvals/release-v2.json --apply
```

All artifact digests are recomputed when parsed and formatted. Full-range u64
identities are decimal strings on the wire. Secret-shaped metadata, stale proof
fingerprints, mismatched review/approval digests, incomplete proof, time travel,
expiry and rejected decisions fail closed.

## Runtime operations

The core `ControlPlane(Event)` is adapter- and policy-neutral. It supports
inspect, start, typed signal, suspend, resume, cancel, retry, checkpoint, drain,
restart and migrate operations. Every request carries an idempotency identity,
expected definition fingerprint, expected fence epoch, reason and optional
causal correlation/trace/boundary identities.

No policy means deny. A dry run performs validation but never calls the runtime
adapter. Duplicate requests do not reapply. Stale fingerprints and epochs are
rejected before policy or mutation. Actor-system and durable workflow adapters
cover their native operations; deployment hosts provide start/checkpoint/
restart/migrate adapters because those operations own process, storage and
orchestration resources outside a reducer.

The fleet registry is bounded and rejects stale owner epochs. Its portable
snapshot reports definition, version, status, health, owner, parent, pending
commands/timers/signals/children and mailbox depth. Read it with:

```sh
zigeffect statechart fleet --json
zigeffect statechart controls --json
```

## Versioning and deployment

`VersionDiff` classifies metadata-only, additive, behavioral, context-migration
and breaking changes without executing reducers. It includes state hierarchy,
transitions, guard/action identities, invocations, completion mapping and
runtime bounds, then recommends one of:

- new instances only;
- drain and replace;
- restart from initial state;
- explicit snapshot migration.

Catalog history permits multiple versions of one machine ID and rejects only a
duplicate `(id, version)` or fingerprint. `show` resolves the latest version;
`versions` returns the complete immutable history.

Snapshot migrations are registered by exact source/target fingerprints. Dry-run
preserves instance ID and revision. A migration advertised as reversible must
round-trip to the exact original snapshot before it is accepted.

## Workbench operator workflow

Open the Statechart graph to inspect nested logic, active configuration,
coverage, source references, replay and XState equivalence. Open Statechart
Studio to inspect:

- agent-authored states, negative paths, guards and transitions;
- definition version/fingerprint and semantic diff;
- validation, analysis, determinism, XState, temporal, fault, performance and
  mutation evidence;
- proposal → proof → human review → approval → application bindings;
- fleet owner, health and pending work.

The Workbench treats artifact strings as inert text. Runtime mutations must go
through an authenticated host boundary and the native control policy; UI state
is never authority.

## Security and failure checklist

- Keep typed reducers pure and emit commands for external work.
- Require explicit mutation authority in addition to human approval.
- Compare the live fingerprint and fence epoch immediately before mutation.
- Reject incomplete, truncated, unsupported or stale proof evidence.
- Persist control and application receipts with causal correlation.
- Use decimal-string u64 identities in portable artifacts.
- Bound plans, definitions, macrosteps, traces, fleets, artifacts and mailboxes.
- Dry-run and reverse-check every snapshot migration.
- Exercise catalog temp-write/rotation recovery, duplicate delivery, stale
  leases, crash-after-commit and command-receipt recovery.
- Run Debug, ReleaseSafe, public API, tool hygiene, standard-library, CLI,
  generated-project, Workbench and local release gates before deployment.
