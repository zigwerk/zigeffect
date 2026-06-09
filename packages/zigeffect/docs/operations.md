# zigeffect Causal Operations

This is the operating manual for the current zigeffect causal
self-improvement runtime. It describes how humans and agents should use the
existing local and CI tools, what evidence is safe to share, and where review
or application authority stops.

## Scope And Authority

The current operating model is local/CI and record-only. The causal runtime can
produce artifacts, inspect them, compare before/after evidence, propose review
records, and record that reviewed work was applied. It does not mutate source
code, deploy production systems, page humans, write durable production stores,
or bypass human review.

`applied=false` is the default state for governance, registry, and app
remediation artifacts. `applied=true` may be recorded only by guarded
`record-applied` commands after readiness evidence, current-state evidence, and
verification evidence exist.

## Command Map

Local artifact capture:

```sh
cd packages/zigeffect
zig build causal-test
zig build causal-check
zig build causal-run -- <scenario>
zig build causal-dev-loop -- baseline [scenario]
zig build causal-dev-loop -- after [scenario]
zig build causal-dev-session -- start [scenario]
zig build causal-dev-session -- assess [scenario]
```

CI and handoff:

```sh
zig build causal-artifacts
zig build causal-ci-handoff
```

Query, compare, and advice:

```sh
zig build causal-query -- --file <artifact.json> snapshot
zig build causal-compare -- <before.json> <after.json>
zig build causal-advice -- --file <artifact.json>
zig build causal-diagnosis -- local [scenario]
```

Governance and review:

```sh
zig build causal-remediation-audit -- local [scenario]
zig build causal-remediation-decision -- local approve [scenario] --by <reviewer> --policy <policy> --reason <reason>
zig build causal-patch-proposal -- local draft [scenario] --summary <summary> --file <path> --change <description>
zig build causal-audit-chain -- local [scenario]
zig build causal-policy-decision -- local [scenario]
```

Registry application:

```sh
zig build causal-scenario-proposal -- local [scenario]
zig build causal-scenario-registry-patch -- --from-proposal <scenario-proposal.json>
zig build causal-registry-application-readiness -- --from-registry-patch <registry-patch.json> approve --reason <reason> --verified-command <command>
zig build causal-registry-apply -- --from-readiness <readiness.json> plan --reason <reason>
zig build causal-registry-apply -- --from-readiness <readiness.json> record-applied --reason <reason> --verified-command <command>
```

App remediation:

```sh
zig build causal-app-remediation-audit -- local --artifact <causal-json> --target <app-target>
zig build causal-app-policy-decision -- local --audit <app-remediation-audit-json>
zig build causal-app-human-review -- local --policy <app-policy-decision-json> approve --reviewer <name> --reason <reason>
zig build causal-app-patch-proposal -- local --policy <app-policy-decision-json> --summary <summary> --change <description>
zig build causal-app-application-readiness -- local --proposal <app-patch-proposal-json> approve --reason <reason>
zig build causal-app-apply -- --from-readiness <app-application-readiness-json> plan --reason <reason>
zig build causal-app-apply -- --from-readiness <app-application-readiness-json> record-applied --reason <reason> --verified-command <command> --source-change <path> --before <evidence> --after <evidence>
```

Snapshots and replay:

```sh
zig build causal-snapshot -- capture <name> [scenario]
zig build causal-snapshot -- manifest <name> <artifact.json>
zig build causal-snapshot -- compare <left-manifest.json> <right-manifest.json>
zig build causal-snapshot -- replay-feasibility <manifest.json>
zig build causal-snapshot -- replay-scenario <manifest.json> <scenario>
zig build causal-snapshot -- fork-proposal <manifest.json> <scenario> <fork-name>
```

Schema, workbench, and backend checks:

```sh
zig build causal-schema-governance
zig build causal-performance-budget
zig build causal-performance-budget -- --format json
zig build causal-m9-completion-audit
zig build causal-m9-completion-audit -- --format json
zig build causal-workbench -- <artifact.json>
zig build causal-workbench -- --server-only <artifact.json>
zig build causal-workbench-ui
zig build causal-backend-conformance
zig build causal-jsonl-backend
zig build causal-dot-backend
zig build causal-otel-backend
zig build causal-graph-history-backend
zig build causal-nendb-storage-backend
zig build causal-async-stream-backend
```

## Local Development Runbook

When changing causal artifact families, CI upload behavior, agent-visible
outputs, or workbench mappings, start by printing the current contracts:

```sh
cd packages/zigeffect
zig build causal-schema-governance
zig build causal-artifacts
```

For ordinary runtime work, capture a baseline before editing:

```sh
zig build causal-dev-session -- start [scenario]
```

After the change, assess the result:

```sh
zig build causal-dev-session -- assess [scenario]
```

Read the generated verdict, advice, diagnosis, and query commands before
claiming the work is complete. If the change touches a known runtime domain,
pass a registered scenario slug. If no scenario fits, use the default dogfood
lane and then decide whether a new scenario or invariant is warranted.

Use the SolidJS `webui-dev/zig-webui` workbench when graph or remediation-chain
inspection is faster than reading text artifacts:

```sh
zig build causal-workbench -- .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json
```

Always finish with the relevant verification commands. For broad zigeffect
branches, use:

```sh
cd packages/zigeffect
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
```

## CI Failure Handoff

`.github/workflows/zigeffect-causal.yml` is the current CI owner for causal
package checks. It runs on zigeffect pull requests, `master` pushes, and manual
dispatch. The workflow has `contents: read` permissions and does not mutate
source, registry, app configuration, or external systems.

On pull requests, CI captures base-commit causal baselines before running the
head checks. On failure, CI writes a handoff and uploads only causal artifacts.

Read uploaded artifacts in this order:

1. `zigeffect-causal-ci-verdict.json`
2. `zigeffect-causal-ci-handoff.txt`
3. generated `*-advice.txt`
4. generated `*-ci-compare.txt` when PR baseline artifacts exist
5. source JSON artifacts using printed `causal-query` commands

Use event ids from the JSON artifacts when diagnosing or patching. Treat
`status=persisting` advice as base-branch evidence and `status=new` advice as
PR-head evidence.

## Artifact Retention And Sharing

Local artifacts live under:

```text
.zig-cache/causal-artifacts/
```

CI uploads only these globs:

```text
packages/zigeffect/.zig-cache/causal-artifacts/*.txt
packages/zigeffect/.zig-cache/causal-artifacts/*.json
packages/zigeffect/.zig-cache/causal-artifacts/*.dot
```

Do not upload the rest of `.zig-cache`.

CI retention is configured as `retention-days: 14`. Local retention is manual:
delete `.zig-cache/causal-artifacts/` when old local evidence is no longer
needed.

Use artifact types this way:

- `.txt`: quick human triage and handoff.
- `.json`: agent-readable source of truth for queries and citations.
- `.dot`: graph visualization helper.

If retention, sampling, or truncation metadata says evidence was dropped,
sampled, or truncated, cite that limitation and avoid claiming the trace is
complete.

## Redaction Review

Redaction runs before store retention and backend emission. Event strings are
redacted before the deterministic store keeps them, before backends see them,
and before JSON, text, DOT, JSON Lines, or workbench artifacts expose them.

Before sharing artifacts:

1. Inspect the `.txt`, `.json`, and `.dot` files that will be shared.
2. Search for visible credentials, tokens, bearer values, URL credentials,
   cookies, request bodies, raw headers, and domain-specific secrets.
3. Confirm secret-shaped values are replaced with `<redacted>`.
4. Check artifact truncation metadata and cite `truncated_fields` when it is
   nonzero.
5. Treat redaction as a deterministic backstop, not complete PII
   classification.

Do not intentionally record secrets, credentials, PII, request bodies, cookies,
or raw headers in causal event labels or details. Prefer semantic labels such
as service names, config keys, route templates, and event ids.

## Human Review And Guarded Application

Governance artifacts are evidence records, not source mutation tools.

Core remediation review:

- `causal-remediation-audit` records a pending audit.
- `causal-remediation-decision` records an approve/reject review decision.
- `causal-patch-proposal` records an intended source change.
- `causal-audit-chain` compares the chain before and after a patch.
- All of these keep `applied=false`.

Registry application:

1. `causal-scenario-proposal` recommends `add-scenario`, `refine-scenario`, or
   `none`.
2. `causal-scenario-registry-patch` writes review-only JSON/text/Zig patch
   drafts.
3. `causal-registry-application-readiness` validates approval, current registry
   state, placeholder argv replacement, invariant consistency, docs, and
   verification commands.
4. A human edits `tools/causal_run.zig` and `docs/causal-scenarios.md` when a
   registry change is approved.
5. `causal-registry-apply -- record-applied` records `applied=true` only after
   source state and verification evidence pass.

App remediation:

1. `causal-app-remediation-audit` records app incident evidence.
2. `causal-app-policy-decision` evaluates source, config, migration,
   operational, and rollback gates.
3. `causal-app-human-review` is required when policy says
   `needs-human-review`.
4. `causal-app-patch-proposal` records draft app change evidence.
5. `causal-app-application-readiness` re-checks citations and verification.
6. A human applies the real source, config, migration, runbook, operational, or
   rollback change outside the causal tool.
7. `causal-app-apply -- record-applied` records `applied=true` only after
   required change evidence, before/after evidence, and post-application
   verification are recorded.

App application records are record-only. They do not grant app-source,
app-config, migration, operational, rollback, or production mutation authority.

## Workbench Operation

Open an artifact in the local workbench:

```sh
cd packages/zigeffect
zig build causal-workbench -- .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json
```

Use server-only mode for deterministic browser or agent inspection:

```sh
zig build causal-workbench -- --server-only .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json
```

The workbench is a SolidJS app launched through `webui-dev/zig-webui`. It reads
exactly one selected artifact through a bounded read-only Zig bridge and keeps
the session as `zigeffect.causal.workbench-session.v1`. It is not an approval,
policy, registry, source edit, migration, config, or mutation surface.

Use the workbench for:

- timeline inspection;
- findings review;
- graph cause paths, parent edges, and runtime lanes;
- remediation and governance chain inspection;
- app remediation gate and readiness inspection;
- metadata, retention, sampling, truncation, and backend-status review;
- copyable `causal-query` commands.

Workbench UI work should stay on the SolidJS plus `webui-dev/zig-webui` path.
React is only a future adapter option if a concrete integration requires it.

## Backend Adapter Operations

The deterministic store is authoritative. Backend adapters are sinks.

Operational rules:

- backend failures must not fail deterministic store writes;
- backend failures must be visible through backend failure counters;
- redaction runs before backend emission;
- sampling policy applies before backend emission;
- store retention does not erase already-emitted backend sink records;
- backend conformance is required before claiming compatibility.

Current adapters:

- `memory`: deterministic in-memory store.
- `json_lines`: `zigeffect.causal.event.v1` rows for portable tools and CI.
- `dot`: Graphviz DOT graph fragments; call `finish()` before writing a full
  `.dot` artifact.
- `opentelemetry`: `zigeffect.causal.otel_record.v1` span/log bridge.
- `nendb_graph`: local graph-history adapter for agent queries.
- `nendb_storage`: writer contract for `zigeffect.causal.nendb_node.v1` and
  `zigeffect.causal.nendb_edge.v1`.
- `async_stream`: non-durable incremental event stream.

NenDB support is currently a writer contract and adapter-test boundary. This
branch does not add a direct production database integration and adds no
Cockroach adapter.

## Scenario And Invariant Governance

Use `docs/causal-scenarios.md` as the registry and invariant reference.

Before proposing a new scenario or invariant:

```sh
cd packages/zigeffect
zig build causal-catalog
zig build causal-test-matrix
```

Prefer tightening an existing scenario or invariant when the relevant domain is
already partial. Add a scenario when a bug crosses a service, layer, scope,
fiber, schedule, resource, config, cause, or observability boundary and should
produce CI artifacts. Add an invariant only when the rule should be named,
queried, and reused across scenarios or findings.

Use the registry proposal, registry patch, readiness, and registry application
artifacts for reviewed scenario-registry changes. Do not edit
`tools/causal_run.zig` from generated patch snippets without human review.

## Schema Governance

Run schema governance before changing artifact fields, artifact families,
workbench mappings, CI handoff outputs, or retained artifact paths:

```sh
cd packages/zigeffect
zig build causal-schema-governance
zig build causal-schema-governance -- --format json
```

Schema governance records the official artifact families, current versions,
producers, consumers, compatibility posture, migration policy, and new-schema
checklist. When a schema change affects retained artifacts, CI upload behavior,
workbench mapping, or agent handoff, update this operations manual too.

## Performance Budget And Release Review

Run the performance budget report before changing causal overhead surfaces:

```sh
cd packages/zigeffect
zig build causal-performance-budget
zig build causal-performance-budget -- --format json
```

The report is deterministic. It checks stable constants such as app request
retention, app background-job retention, app event string bounds, and the
workbench artifact read limit. It also records documented budgets for sampling,
CI artifact retention, backend sink failure posture, and the SolidJS inside
`webui-dev/zig-webui` workbench direction.

Add release notes whenever a causal runtime change alters retention, string
bounds, sampling, backend emission, artifact schemas, workbench bounds or
bridge behavior, CI upload globs, or CI retention.

## M9 Completion Audit

Run the M9 completion audit before marking the causal operating model delivered:

```sh
cd packages/zigeffect
zig build causal-m9-completion-audit
zig build causal-m9-completion-audit -- --format json
```

The audit records the schema governance, operations docs, performance budget,
release guidance, CI workflow, artifact manifest, test matrix, workbench
direction, and production-gap register that prove the local/CI operating model.

The recommendation `deliver-m9-with-deferred-production-hardening` means the
M0-M9 causal self-improvement roadmap is complete for local/CI operation and
the documented production gaps should move to future hardening. It does not add
production dashboards, access control, durable production retention, mutation
authority, rollout automation, or a Cockroach adapter.

## Production Gaps

The current operating model does not provide:

- distributed artifact aggregation;
- durable production retention beyond local files and CI uploads;
- production deployment runbooks;
- alerting, paging, Slack, Linear, Jira, or SIEM integrations;
- RBAC or access control over artifact bundles;
- encryption-at-rest policy;
- live dashboards or streaming workbench;
- automated source/config mutation authority;
- gradual rollout, canary, or circuit-breaker automation;
- wall-clock benchmark baselines or gates;
- production capacity planning.

Those belong to later M9 branches and future production hardening. The next
operating-model branch should audit the completed M9 evidence before declaring
the operating model complete.
