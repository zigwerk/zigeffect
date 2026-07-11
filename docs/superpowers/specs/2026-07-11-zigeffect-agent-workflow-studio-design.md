# ZigEffect Agent Workflow Studio And Control Plane Design

Date: 2026-07-11
Status: accepted for implementation
Depends on: `2026-07-10-zigeffect-statechart-agentic-runtime-design.md`

## Product outcome

An agent can propose a long-lived workflow as a bounded statechart program,
ZigEffect can validate and simulate the proposal, humans can inspect its exact
semantic change, policy can require approval, and the accepted version can be
deployed and operated durably with one causal evidence chain.

This is not a low-code editor. The source-controlled typed Zig definition stays
authoritative. The Studio is the review, simulation, evidence, and operations
surface over the same versioned artifacts.

## Decisions

1. A workflow instance is an addressable actor, not a network service by
   default. Service promotion remains an explicit deployment decision.
2. Agent proposals are immutable content-addressed artifacts. A proposal never
   mutates source or a running instance by itself.
3. Review, approval, application, deployment, and runtime control are distinct
   records. Approval is not application authority.
4. The Workbench remains credential-free and read-mostly. Mutations cross an
   authenticated local/host control boundary and a default-deny policy.
5. Runtime definition changes never rewrite a live snapshot silently. An
   instance is pinned to a definition fingerprint until an explicit migration,
   restart, or drain-and-replace operation succeeds.
6. Agent plans compile to generated typed Zig source and must pass the Zig
   compiler. ZigEffect will not introduce a second dynamic production
   interpreter for arbitrary JSON state machines.
7. XState remains an executable projection oracle. Native Zig semantics remain
   authoritative.
8. Reusable patterns are portable plan templates and typed generated modules,
   not hidden runtime magic.
9. All exploration, mutation, chaos, and performance evidence is bounded and
   reports truncation as incomplete.

## Requirement ledger

| ID | Requirement |
|---|---|
| AWS-001 | Immutable proposal with base/next definition identity and content digest |
| AWS-002 | Native semantic diff with states, transitions, guards, actions, invocations, bounds, and risk classification |
| AWS-003 | Review and approval records bound to the exact proposal digest |
| AWS-004 | Default-deny application policy and separate host mutation authority |
| AWS-005 | Version lineage, compatibility classification, rollback target, and migration requirement |
| AWS-006 | Agent-plan IR validation and deterministic Zig source generation |
| AWS-007 | Proof bundle containing validation, analysis, paths, coverage, determinism, XState, fault, and budget evidence |
| AWS-008 | Deterministic simulation, event injection, breakpoints, and time-travel trace |
| AWS-009 | Runtime commands for start, signal, suspend, resume, cancel, retry, checkpoint, migrate, and drain |
| AWS-010 | Fleet registry with definition, version, status, owner/fence, children, pending work, and health queries |
| AWS-011 | Immutable control receipts and causal correlation for every attempted mutation |
| AWS-012 | Definition deployment strategies: new-only, drain-and-replace, restart, and explicit migrate |
| AWS-013 | Reusable approval, retry/escalation, tool, parallel research, consensus, saga, timeout, budget, delegation, circuit-breaker, job, and remediation patterns |
| AWS-014 | Studio proposal, simulation, proof, operations, fleet, and version-diff views |
| AWS-015 | Temporal invariant, transition mutation, XState differential, migration, and virtual-world chaos verification |
| AWS-016 | CLI/scaffold workflows for propose, verify, review, approve, apply, simulate, control, fleet, and migrate |
| AWS-017 | Full-range u64-safe, redacted, bounded, versioned schemas with legacy/future-version policy |
| AWS-018 | Debug, ReleaseSafe, public API, hygiene, std, CLI, generated-project, workbench, browser, repository, and local-release evidence |

## Architecture

```text
requirements / agent plan
        |
        v
portable WorkflowPlan v1
        |
        +--> validator + risk classifier
        +--> deterministic Zig generator
        +--> simulation/model exploration
        |
        v
source-controlled typed Definition
        |
        v
Proposal v1 ----> SemanticDiff v1 ----> ProofBundle v1
        |                                  |
        +------------ Review v1 <----------+
                         |
                         v
                    Approval v1
                         |
                  host policy boundary
                         |
                         v
                   ApplicationReceipt v1
                         |
          +--------------+----------------+
          |                               |
   VersionRegistry v1              ControlRequest v1
          |                               |
          v                               v
   durable actor/workflow <-------- ControlReceipt v1
          |
          v
 catalog + causal evidence + Studio
```

### Core runtime modules

- `statechart/version.zig`: typed version identity, compatibility/risk
  classification, lineage and migration contracts. No filesystem or UI imports.
- `statechart/simulation.zig`: deterministic bounded trace, breakpoints and
  temporal invariant evaluation over native snapshots and macrosteps.
- `statechart/control.zig`: typed control requests/results and policy-neutral
  adapter interfaces. It does not grant mutation authority.
- `statechart/pattern.zig`: portable descriptors for reusable workflow patterns.
- Existing machine, actor, workflow, cluster, and causal modules remain the
  execution substrate.

### Standard-library modules

- `zigeffect-std/statechart/studio.zig`: parse/format proposal, diff, proof,
  review, approval, version-registry, fleet and control artifacts.
- `zigeffect-std/statechart/plan.zig`: portable agent plan IR, validation,
  deterministic source projection metadata and pattern expansion.
- Catalog v2 adds version history and proposal/control references while the v1
  reader remains supported.
- Atomic artifact stores use temp/current/backup rotation and explicit file
  ownership; Cloudflare/Cockroach adapters are separate application concerns.

### CLI

Extend the existing `statechart` command rather than create report-about-report
tools:

- `statechart propose <plan-or-definition>`
- `statechart verify <proposal-id>`
- `statechart review <proposal-id>`
- `statechart approve <proposal-id>`
- `statechart apply <proposal-id>`
- `statechart simulate <machine-id>`
- `statechart control <instance-id> <operation>`
- `statechart fleet [--machine <id>]`
- `statechart migrate <instance-id> --to <version>`

Every mutation command emits a receipt; `--dry-run` is mandatory support for
proposal application, deployment, and migration.

### Workbench Studio

The Studio consumes artifacts and live frames through pure TypeScript models.
It provides:

- proposal list and exact base/next identity;
- graph-level semantic diff and risk findings;
- proof/coverage/invariant matrix;
- deterministic simulator with event injection and replay scrub;
- fleet and instance operations views;
- pending commands, timers, signals, queues, children, mailbox and fence state;
- version lineage and migration readiness;
- authenticated handoff to the host control boundary for permitted actions.

The browser never edits canonical Zig directly. An agent may generate a patch,
but source application remains a separate reviewed host operation.

## Proposal and approval state model

Proposal statuses are `draft`, `verified`, `review_required`, `approved`,
`rejected`, `applied`, `superseded`, and `failed`. Status is derived from
immutable records, not overwritten in place.

An approval is valid only when all of these match:

- proposal digest;
- base and next definition fingerprints;
- proof-bundle digest;
- reviewer identity class and policy decision;
- expiry, when configured.

Any proposal or proof change invalidates the approval. Applying a stale proposal
fails before source, registry, or runtime mutation.

## Semantic compatibility and deployment

Changes are classified:

- `metadata_only`: descriptions/source references only;
- `additive`: new unreachable-by-existing-events states/transitions or expanded
  bounds with no snapshot-shape change;
- `behavioral`: guard/action/target/order/invocation or reachable path change;
- `context_migration`: context representation changes;
- `breaking`: removed/renamed active states, incompatible event/command types,
  reduced bounds below live usage, or missing migration.

Deployment strategies:

- `new_instances_only` for any accepted version;
- `drain_and_replace` for behavioral/breaking changes;
- `restart_from_initial` only with explicit operator approval;
- `migrate_snapshot` only with a registered, deterministic migration and dry-run
  evidence for every affected active configuration/history record.

Rollback deploys a prior accepted version for new instances. Existing migrated
instances require a reverse migration or drain-and-replace; rollback never
reinterprets snapshots under an old fingerprint.

## Runtime control and policy

Control requests contain request id, operation, machine/instance identity,
expected definition fingerprint, expected fence epoch, actor/workflow owner,
reason, correlation/trace/boundary ids, and dry-run status.

Operations are individually policy classified. Inspection and simulation are
read-only. Signal and retry are bounded mutations. Cancel, migrate, restart,
force-checkpoint, drain and definition application require explicit policy.
Stale fingerprints or fence epochs fail closed.

## Proof bundle

A verified proposal records:

- definition validation and static analysis;
- shortest paths and required transition/state/event coverage;
- deterministic reducer audit;
- XState supported-feature equivalence;
- temporal invariants;
- transition mutation score;
- migration dry-run results;
- virtual-world crash/redelivery/partition results where durable or clustered;
- performance/resource budgets;
- truncation, unsupported cases, redaction and toolchain identity.

No prose claim can substitute for a required proof entry.

## Reusable patterns

Patterns expand into explicit plan states/transitions and generated Zig source.
Expanded nodes use deterministic namespaced ids and remain fully visible in
artifacts, diffs, coverage and the Workbench. Each pattern declares required
events, commands, context fields, invariants and default bounds. Expansion is
pure and idempotent.

## Security and privacy

- Artifact payloads are redacted by default; raw context and credentials are
  never included.
- Proposal text, descriptions and source references are bounded and escaped.
- The Workbench stores no bearer token in artifacts or URLs after bootstrap.
- Application, migration and runtime controls require authenticated loopback or
  host-owned transport plus policy approval.
- Replay and simulation use deterministic fake services unless explicit real
  capability authority is granted.
- Every denial and stale request is retained as a bounded control receipt.

## Non-goals for this program

- Full SCXML implementation.
- A free-form drag-and-drop low-code environment.
- Collaborative CRDT source editing.
- Silent hot replacement of running definitions.
- Exactly-once guarantees from arbitrary external systems.
- A network service per statechart.

## Completion criteria

The program is complete when an agent-generated plan can be proposed, compiled,
verified, reviewed in the Studio, approved through policy, applied through host
authority, started as a durable workflow, controlled and migrated with receipts,
and investigated through one causal/catalog history, with all AWS-001 through
AWS-018 acceptance evidence passing.
