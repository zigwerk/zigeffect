# Zigeffect App-Facing Eight-Level Evaluator Design

## Context

The eight-level policy producer now emits ready, rejected, and blocked local
policy artifacts from applied eight-level application-boundary evidence. Ready
policy artifacts are still interpretation evidence only: they do not grant CI,
GitHub, app runtime, storage, deployment, public upload, production-health,
auto-apply, registry, or mutation authority.

This milestone adds the matching eight-level evaluator producer. It consumes an
approved eight-level policy artifact plus bounded local request and support
evidence, then emits read-only evaluator artifacts for agents, reviewers,
non-blocking CI advisory readers, and the SolidJS `webui-dev/zig-webui`
workbench.

## Design

Promote the existing seven-level evaluator producer into a short physical alias
while preserving the fully expanded artifact schema lineage. The physical file,
build step, executable, docs path, branch, and next branch use short names
because the expanded eight-level names are no longer ergonomic for filesystems
or branch handling.

- Tool: `packages/zigeffect/tools/causal_app_facing_eight_level_evaluator.zig`
- Build step: `causal-app-facing-eight-level-evaluator`
- Executable: `zigeffect-causal-app-facing-eight-level-evaluator`
- Docs: `packages/zigeffect/docs/app-facing-eight-level-evaluator.md`
- Current branch: `codex/zigeffect-causal-app-facing-eight-level-evaluator`
- Next branch if ready: `codex/zigeffect-causal-app-facing-nine-level-report`
- Recommendation: `start-app-facing-nine-level-report`

The next report branch is named nine-level because evaluator-to-report handoff
adds one more `evaluation-report` layer to the fully expanded schema lineage.
The short alias keeps the human-facing branch manageable while the emitted
schema remains explicit.

## Schemas

The source policy schema is:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1
```

The emitted evaluator schema is:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1
```

The tool accepts only local file inputs. It reads the source policy JSON, one or
more request files, and optional support evidence files. Output remains local
JSON and text only.

## Behavior

The command shape is:

```bash
zig build causal-app-facing-eight-level-evaluator -- \
  --from-policy <eight-level-policy.json> \
  evaluate \
  --reason <reason> \
  --request <path>... \
  [--evidence <path>]... \
  [--by <actor>] \
  [--policy <policy>] \
  [--out-prefix <path-prefix>]
```

Ready output requires:

- source schema equals the eight-level policy schema and version `1`;
- source decision is `approve`;
- source policy status is `ready` and `ready_for_next_branch=true`;
- source policy, inherited application-boundary evidence, and all authority
  flags preserve `mutation_authority=none`;
- inherited eight-level application-boundary, eight-level report, policy,
  request, support evidence, denied claim, negative fixture, publication, and
  verification fields are present;
- at least one bounded safe request file is supplied;
- request and support files classify as local, redacted, or bounded evidence;
- SolidJS `webui-dev/zig-webui` read-only posture remains present;
- all CI, GitHub, app, runtime, durable storage, NenDB, adapter, deployment,
  hosted dashboard, production health, public upload, auto-apply, registry, and
  mutation authority flags stay disabled.

Missing support evidence produces `advisory-findings` when the source policy and
request evidence are otherwise safe. Rejected or blocked source policy, unsafe
request files, unsafe support evidence, unbounded redaction posture, public
upload claims, app runtime claims, NenDB write claims, Cockroach claims, or
authority drift produces `blocked`.

## Data Flow

1. Read the eight-level policy artifact.
2. Read local request files and optional support evidence files.
3. Classify each input as request JSON, request text, policy JSON, causal JSON,
   causal text, workbench text, or denied content.
4. Evaluate source policy readiness, inherited evidence, and file posture.
5. Emit deterministic JSON and text evaluator artifacts.
6. Hand ready or advisory evaluator artifacts to the nine-level report branch.

## Governance

Schema governance must register the eight-level evaluator schema with
`emitted_by = causal-app-facing-eight-level-evaluator`. The production hardening
backlog must mark `app-facing-eight-level-evaluator` delivered, update the
recommendation to `start-app-facing-nine-level-report`, and point the next
branch to `codex/zigeffect-causal-app-facing-nine-level-report`.

Compatibility tags must preserve the current posture: `strict-v1`,
`record-only`, `advisory-only`, `source-eight-level-policy`,
`bounded-explicit-evidence`, `local-report-only`, `read-only-consumption`,
`bounded-agent-context`, `app-facing`, `solid-webui`, `webui-dev/zig-webui`,
and all no-authority tags.

## Testing

Use TDD:

- stable schema, branch, recommendation, next-branch, and alias constants;
- option parsing accepts `--from-policy`, `evaluate`, `--request`,
  `--evidence`, `--by`, `--policy`, and `--out-prefix`;
- default output path replaces the eight-level policy suffix with the
  eight-level evaluator suffix and compacts long paths;
- safe request plus support evidence emits `ready`;
- missing support evidence emits `advisory-findings` without authority;
- rejected or blocked source policy emits `blocked`;
- unsafe request/support evidence emits `blocked`;
- generated JSON is parseable;
- schema governance contains the eight-level evaluator schema;
- production backlog recommendation moves to the nine-level report branch.

## Verification

Fresh verification for this milestone must include:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_eight_level_evaluator.zig
zig build causal-app-facing-eight-level-evaluator -- --help
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```

The real artifact check must generate ready, advisory, and blocked evaluator
artifacts from `.zig-cache/causal-artifacts/app-facing-ci-eight-level-policy.json`
and confirm the ready artifact has no failed evaluator checks.

## Non-Goals

This branch does not create required status checks, mutate workflows, call
GitHub APIs, write PR comments, upload public artifacts, mutate app config or
app data, integrate app runtime projections, capture raw prompts or payloads,
write durable storage, write NenDB, execute NenDB adapters, add Cockroach work,
deploy, prove production health, create hosted dashboards, auto-apply, mutate
registries, or grant mutation authority.
