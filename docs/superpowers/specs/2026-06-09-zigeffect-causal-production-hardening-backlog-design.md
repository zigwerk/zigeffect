# zigeffect Causal Production Hardening Backlog Design

Date: 2026-06-09

## Purpose

This design turns the M9 production-gap register into a deterministic backlog
artifact that agents, reviewers, and future branch workers can use as the next
execution queue after the local/CI causal operating model.

M9 is complete for local and CI operation. This branch must not implement
production telemetry, production storage, production dashboards, or mutation
authority. It should instead preserve the gap register as a typed, ordered,
machine-readable artifact with explicit dependencies, non-goals, and branch
recommendations.

## Source Evidence

The authoritative source gaps are already documented by:

- `packages/zigeffect/tools/causal_m9_completion_audit.zig`;
- `packages/zigeffect/docs/m9-completion-audit.md`;
- `packages/zigeffect/docs/operations.md`;
- `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`.

Those sources identify deferred production work for distributed artifact
aggregation, durable production retention, production deployment runbooks,
alerting integrations, access control, encryption-at-rest, live dashboarding,
mutation authority, rollout automation, wall-clock benchmarks, and capacity
planning.

## Constraints

- Durable database work is NenDB adapter work only. This branch must not add or
  plan a Cockroach adapter for zigeffect causal production hardening.
- Workbench UI work remains SolidJS inside `webui-dev/zig-webui`. React stays a
  non-goal unless a later adapter proves a concrete need.
- Mutation authority remains `none`. Backlog items may describe future review
  gates, but they must not grant source, config, deployment, or production
  mutation authority.
- The artifact is deterministic. It must not inspect live systems, clocks,
  networks, filesystem state, or generated CI artifacts.
- The report is a planning and governance artifact, not a production control
  plane.

## Selected Approach

Create a new Zig report tool, `causal-production-hardening-backlog`, with text
and JSON output. The JSON schema is
`zigeffect.causal.production-hardening-backlog.v1`.

This follows the existing operating-model pattern used by
`causal-performance-budget` and `causal-m9-completion-audit`: a deterministic
tool with embedded records, focused tests, schema governance registration, docs,
and roadmap links.

## Considered Alternatives

### Markdown-only Roadmap

A markdown-only backlog would be easy to write, but agents would need to parse
prose to identify dependency order, next branch names, and non-goals. That makes
it weaker than the rest of the causal artifact system.

### Extend the M9 Completion Audit

Extending the M9 audit would keep all operating-model state in one tool, but it
would mix "is M9 complete?" with "what should production hardening do next?".
Those are different review moments. Keeping a separate backlog artifact makes
the M9 audit stable and lets future hardening branches evolve independently.

### Build Production Systems Immediately

Jumping straight to durable storage, dashboards, integrations, or rollout
automation would violate the production-gap boundary and obscure dependencies.
The next useful step is to make the queue precise before granting any production
capabilities.

## Artifact Shape

The tool should emit:

- schema name and version;
- status;
- generated-by command;
- recommendation;
- global constraints;
- non-goals;
- backlog items;
- dependency order;
- verification commands;
- recommended next branch.

Each backlog item should include:

- stable id;
- title;
- gap id from the M9 register;
- priority band;
- status;
- summary;
- depends-on list;
- deliverables;
- evidence sources;
- branch name;
- agent guidance.

## Initial Backlog Items

The first backlog should preserve these branch-ready items in dependency order:

1. `production-artifact-aggregation`
2. `durable-production-retention`
3. `production-deployment-runbooks`
4. `artifact-access-control`
5. `encryption-at-rest-policy`
6. `alerting-integrations`
7. `live-dashboard-streaming-workbench`
8. `rollout-automation-guardrails`
9. `wall-clock-benchmark-baselines`
10. `production-capacity-planning`

The recommended next branch should be
`codex/zigeffect-causal-production-artifact-aggregation`. Artifact aggregation
comes first because it defines the bundle/source/provenance contract that
durable retention, access control, dashboards, integrations, rollout evidence,
benchmarks, and capacity planning will consume.

## Documentation Updates

Add `packages/zigeffect/docs/production-hardening-backlog.md` explaining:

- when to run the report;
- how to interpret the dependency order;
- why this is not production telemetry;
- NenDB-only durable direction;
- SolidJS plus `zig-webui` workbench direction;
- non-goals and authority boundaries.

Update existing operating-model docs to point to the backlog:

- `packages/zigeffect/README.md`;
- `packages/zigeffect/docs/operations.md`;
- `packages/zigeffect/docs/schema-governance.md`;
- `packages/zigeffect/docs/roadmap.md`;
- `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`.

## Verification

The branch should pass:

- `cd packages/zigeffect && zig build causal-production-hardening-backlog`;
- `cd packages/zigeffect && zig build causal-production-hardening-backlog -- --format json`;
- `cd packages/zigeffect && zig build causal-schema-governance`;
- `cd packages/zigeffect && zig build causal-m9-completion-audit`;
- `cd packages/zigeffect && zig build examples`;
- `cd packages/zigeffect && zig build test`;
- `bun run check`;
- `bun run zig:test`;
- `git diff --check`.

## Self-Review

- No placeholders or unresolved questions remain.
- The design preserves the user's NenDB-only and SolidJS-plus-`zig-webui`
  directions.
- The branch is scoped to a deterministic backlog artifact and docs.
- Production implementation remains deferred to future branches.
