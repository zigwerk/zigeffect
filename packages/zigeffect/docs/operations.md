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
zig build causal-wall-clock-benchmark-baselines
zig build causal-wall-clock-benchmark-baselines -- --format json
zig build causal-production-capacity-planning
zig build causal-production-capacity-planning -- --format json
zig build causal-production-hardening-completion-audit
zig build causal-production-hardening-completion-audit -- --format json
zig build causal-load-test-observation-harness
zig build causal-load-test-observation-harness -- --format json
zig build causal-load-test-observation-harness -- observe app-request-trace --iterations 1 --format json
zig build causal-production-telemetry-capture-design
zig build causal-production-telemetry-capture-design -- --format json
zig build causal-production-telemetry-capture-fixtures
zig build causal-production-telemetry-capture-fixtures -- --format json
zig build causal-production-telemetry-capture-fixtures -- emit runtime-trace-span-event --format json
zig build causal-production-telemetry-capture-fixtures -- validate --format json
zig build causal-production-telemetry-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json approve --reason "fixtures reviewed for implementation proposal" --verified-command "zig build causal-production-telemetry-capture-fixtures -- validate --format json" --verified-command "zig build causal-schema-governance -- --format json" --verified-command "zig build causal-production-hardening-backlog -- --format json" --verified-command "zig build examples" --verified-command "zig build test"
zig build causal-production-telemetry-implementation-proposal -- --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review.json approve --reason "ready evidence reviewed for exporter boundary planning" --verified-command "zig build causal-production-telemetry-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json approve --reason \"fixtures reviewed for implementation proposal\" --verified-command \"zig build causal-production-telemetry-capture-fixtures -- validate --format json\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"" --verified-command "zig build causal-schema-governance -- --format json" --verified-command "zig build causal-production-hardening-backlog -- --format json" --verified-command "zig build examples" --verified-command "zig build test"
zig build causal-production-telemetry-exporter-boundary -- --from-proposal ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal.json approve --reason "proposal evidence reviewed for local pipeline fixtures" --verified-command "zig build causal-production-telemetry-implementation-proposal -- --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review.json approve --reason \"ready evidence reviewed for exporter boundary planning\" --verified-command \"zig build causal-production-telemetry-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json approve --reason \\\"fixtures reviewed for implementation proposal\\\" --verified-command \\\"zig build causal-production-telemetry-capture-fixtures -- validate --format json\\\" --verified-command \\\"zig build causal-schema-governance -- --format json\\\" --verified-command \\\"zig build causal-production-hardening-backlog -- --format json\\\" --verified-command \\\"zig build examples\\\" --verified-command \\\"zig build test\\\"\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"" --verified-command "zig build causal-schema-governance -- --format json" --verified-command "zig build causal-production-hardening-backlog -- --format json" --verified-command "zig build examples" --verified-command "zig build test"
zig build causal-production-telemetry-local-pipeline-fixtures -- --from-boundary ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary.json approve --reason "approved boundary reviewed for local pipeline fixtures" --verified-command "zig build causal-production-telemetry-exporter-boundary -- --from-proposal ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal.json approve --reason \"proposal evidence reviewed for local pipeline fixtures\" --verified-command \"zig build causal-production-telemetry-implementation-proposal -- --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review.json approve --reason \\\"ready evidence reviewed for exporter boundary planning\\\" --verified-command \\\"zig build causal-production-telemetry-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json approve --reason \\\\\\\"fixtures reviewed for implementation proposal\\\\\\\" --verified-command \\\\\\\"zig build causal-production-telemetry-capture-fixtures -- validate --format json\\\\\\\" --verified-command \\\\\\\"zig build causal-schema-governance -- --format json\\\\\\\" --verified-command \\\\\\\"zig build causal-production-hardening-backlog -- --format json\\\\\\\" --verified-command \\\\\\\"zig build examples\\\\\\\" --verified-command \\\\\\\"zig build test\\\\\\\"\\\" --verified-command \\\"zig build causal-schema-governance -- --format json\\\" --verified-command \\\"zig build causal-production-hardening-backlog -- --format json\\\" --verified-command \\\"zig build examples\\\" --verified-command \\\"zig build test\\\"\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"" --verified-command "zig build causal-schema-governance -- --format json" --verified-command "zig build causal-production-hardening-backlog -- --format json" --verified-command "zig build examples" --verified-command "zig build test"
zig build causal-production-telemetry-nendb-retention-fixtures -- --from-local-pipeline ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures.json approve --reason "approved local pipeline reviewed for NenDB retention fixtures" --verified-command "zig build causal-production-telemetry-local-pipeline-fixtures" --verified-command "zig build causal-nendb-storage-backend" --verified-command "zig build causal-durable-production-retention -- --format json" --verified-command "zig build causal-schema-governance -- --format json" --verified-command "zig build causal-production-hardening-backlog -- --format json" --verified-command "zig build examples" --verified-command "zig build test"
zig build causal-m9-completion-audit
zig build causal-m9-completion-audit -- --format json
zig build causal-production-hardening-backlog
zig build causal-production-deployment-runbooks
zig build causal-production-deployment-runbooks -- --format json
zig build causal-artifact-access-control
zig build causal-artifact-access-control -- --format json
zig build causal-unified-spine-contract
zig build causal-unified-spine-contract -- --format json
zig build causal-human-agent-feedback-loop
zig build causal-human-agent-feedback-loop -- --format json
zig build causal-rollout-automation-guardrails
zig build causal-rollout-automation-guardrails -- --format json
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
Alternate frontend renderers are only future adapter options if a concrete
integration requires them.

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
non-NenDB durable adapter.

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

Use `causal-wall-clock-benchmark-baselines` for local and CI timing evidence
contracts. That report is also record-only, but it describes noisy benchmark
observation fields, environment metadata, calibration policy, advisory review
gates, and the capacity-planning handoff rather than deterministic constants.

Use `causal-production-capacity-planning` after benchmark, retention,
dashboard, graph, agent-query, feedback-loop, alerting, and rollout contracts
exist. That report is planning-only: it records capacity domains, storage
assumptions, load-test fixtures, concurrency assumptions, readiness gates, and
negative capacity fixtures without running load tests or claiming production
capacity.

Use `causal-production-hardening-completion-audit` after capacity planning to
close the static hardening sweep, confirm the record-only/NenDB/SolidJS
boundaries, list remaining evidence gaps, and cite the delivered local
load-test observation harness without claiming production readiness.

Use `causal-load-test-observation-harness` for approved local observation
families after the completion audit. The catalog is deterministic by default;
the opt-in `observe` subcommand runs bounded local commands from curated argv
arrays and records advisory median/p95 timings with capped output snippets.
Do not use it for production load, telemetry ingestion, capacity sizing, CI
timing gates, shell execution, durable writes, or mutation authority.

Use `causal-production-telemetry-capture-design` after the local observation
harness to classify future telemetry capture surfaces, field contracts, and
redaction/sampling/retention/access/encryption/OTel review gates. It is
design-only and does not enable live ingestion, exporters, collector endpoints,
durable production writes, capacity claims, CI gates, non-NenDB adapters,
alternate renderers, or mutation authority.

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
authority, rollout automation, or a non-NenDB durable adapter.

## Production Hardening Backlog

Run the production-hardening backlog report after the M9 completion audit when
choosing the next hardening branch:

```sh
cd packages/zigeffect
zig build causal-production-hardening-backlog
zig build causal-production-hardening-backlog -- --format json
```

The backlog records schema
`zigeffect.causal.production-hardening-backlog.v1`, turns the deferred
production gaps into ordered future branches, and now recommends
`codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-readiness`
after the unified causal spine, deep runtime internals, app semantic trace API,
bounded agent query surface, record-only encryption-at-rest policy,
record-only alerting integrations, delivered live dashboard streaming
workbench, delivered graph visual debugging, delivered human-agent feedback
loop, delivered rollout automation guardrails, delivered wall-clock benchmark
baseline contract, and delivered production capacity planning,
completion-audit, load-test observation harness, production telemetry capture
design, fixture, readiness-review, implementation-proposal, exporter-boundary,
local-pipeline-fixtures, NenDB-retention-fixtures, workbench read-only
preview, CI artifact preview, CI harness boundary, CI archive application, CI
archive evidence policy, CI gate readiness, and CI gate application boundary
contracts, CI gate dry-run policy, CI gate dry-run evaluator, and CI gate
advisory CI report, and CI gate advisory CI report application boundary.
It keeps durable production work on the NenDB adapter path, keeps workbench UI
work on SolidJS inside `webui-dev/zig-webui`, and grants no production mutation
authority.

## Production Hardening Completion Audit

Run the production-hardening completion audit after capacity planning and use
it as the static hardening closure record:

```sh
cd packages/zigeffect
zig build causal-production-hardening-completion-audit
zig build causal-production-hardening-completion-audit -- --format json
```

The audit records schema
`zigeffect.causal.production-hardening-completion-audit.v1`, verifies the
delivered production-hardening milestones, preserves the record-only,
`mutation_authority=none`, NenDB-only, and SolidJS `zig-webui` boundaries,
records remaining evidence gaps, and recommends
the delivered `codex/zigeffect-causal-load-test-observation-harness` handoff.

Use it as closure evidence for the static hardening sweep. Do not use it to
claim production telemetry, load-test execution, capacity sizing, live alert
delivery, rollout execution, RBAC enforcement, encrypted bytes, production
dashboard hosting, durable writes, non-NenDB adapter work, alternate frontend
renderer support, or production mutation authority.

## Load-Test Observation Harness

Run the load-test observation harness after the completion audit when local
observation evidence is useful:

```sh
cd packages/zigeffect
zig build causal-load-test-observation-harness
zig build causal-load-test-observation-harness -- --format json
zig build causal-load-test-observation-harness -- observe app-request-trace --iterations 1 --format json
```

The harness records schema
`zigeffect.causal.load-test-observation-harness.v1`. It catalogs app request,
background job, artifact formatting, agent query, comparison, dev-loop,
workbench, and future CI scenario families. Observation mode is explicit and
bounded: curated argv arrays only, no shell, no production telemetry, no
production load, no capacity claim, and `mutation_authority=none`.

The harness has now been consumed by the delivered telemetry design, fixture,
readiness-review, implementation-proposal, exporter-boundary, local pipeline
fixture, NenDB retention fixture, workbench read-only preview, CI artifact
preview, CI harness boundary, CI archive application, CI archive evidence
policy, CI gate readiness, CI gate application boundary, and CI gate dry-run
policy, evaluator, advisory CI report, and advisory CI report application
boundary, and advisory CI report publication policy milestones.
The current next branch is
`codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-readiness`.

## Production Telemetry Capture Design

Run the production telemetry capture design report after the local observation
harness and before fixture work:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-capture-design
zig build causal-production-telemetry-capture-design -- --format json
```

The report records schema
`zigeffect.causal.production-telemetry-capture-design.v1`. It defines runtime,
app semantic, OTel backend, redaction/access, and local-observation correlation
surfaces plus the required future telemetry field contract. It keeps
`production_telemetry_ingestion=false`, `live_exporter_enabled=false`, and
`mutation_authority=none`.

Use it as the handoff into
`causal-production-telemetry-capture-fixtures`. Do not use it to configure
exporters, collector endpoints, OTLP sends, durable production writes, capacity
sizing, CI gates, non-NenDB adapters, alternate renderers, or mutation
authority.

## Production Telemetry Capture Fixtures

Run the fixture catalog after the production telemetry capture design report:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-capture-fixtures
zig build causal-production-telemetry-capture-fixtures -- --format json
zig build causal-production-telemetry-capture-fixtures -- emit runtime-trace-span-event --format json
zig build causal-production-telemetry-capture-fixtures -- validate --format json
```

The report records schema
`zigeffect.causal.production-telemetry-capture-fixtures.v1`. It emits safe
example records for runtime trace, app semantic, backend OTel, redaction/access,
local observation correlation, and sampling boundaries. It also emits negative
fixtures and validation checks that block live ingestion, exporters, collector
endpoints, raw payloads, credentials, unbounded attributes, sampled-out
forwarding, production capacity claims, non-NenDB storage, alternate renderers,
CI gates, and mutation authority.

Use it as the handoff into
`causal-production-telemetry-readiness-review`. Do not treat fixtures as live
telemetry, durable writes, CI gates, or production capacity evidence.

## Production Telemetry Readiness Review

Run the readiness review after writing fixture JSON:

```sh
cd packages/zigeffect
mkdir -p ../../.zig-cache/causal-artifacts
zig build causal-production-telemetry-capture-fixtures -- --format json \
  2> ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json
zig build causal-production-telemetry-readiness-review -- \
  --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json \
  approve \
  --reason "fixtures reviewed for implementation proposal" \
  --verified-command "zig build causal-production-telemetry-capture-fixtures -- validate --format json" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

The report records schema
`zigeffect.causal.production-telemetry-readiness-review.v1`. It consumes the
fixture catalog, records reviewer decision and reason, verifies coverage and
authority boundaries, requires explicit verification command evidence, and
emits `ready` or `blocked` artifacts.

Use a `ready` report as the handoff into
`causal-production-telemetry-implementation-proposal`. Do not
treat readiness as live telemetry, exporter authority, durable writes, CI gates,
production capacity evidence, or mutation authority.

Run the implementation proposal after readiness:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-implementation-proposal -- \
  --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review.json \
  approve \
  --reason "ready evidence reviewed for exporter boundary planning" \
  --verified-command "zig build causal-production-telemetry-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json approve --reason \"fixtures reviewed for implementation proposal\" --verified-command \"zig build causal-production-telemetry-capture-fixtures -- validate --format json\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

The proposal records schema
`zigeffect.causal.production-telemetry-implementation-proposal.v1`. It consumes
a ready readiness artifact, emits `approved` or `blocked` proposal artifacts,
records implementation phases, and hands off to
`codex/zigeffect-causal-production-telemetry-exporter-boundary`. Do not treat
the proposal as live telemetry, exporter authority, durable writes, CI gates,
production capacity evidence, non-NenDB adapter scope, alternate renderer
scope, or mutation authority.

Run the exporter boundary after proposal approval:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-exporter-boundary -- \
  --from-proposal ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal.json \
  approve \
  --reason "proposal evidence reviewed for local pipeline fixtures" \
  --verified-command "zig build causal-production-telemetry-implementation-proposal -- --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review.json approve --reason \"ready evidence reviewed for exporter boundary planning\" --verified-command \"zig build causal-production-telemetry-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json approve --reason \\\"fixtures reviewed for implementation proposal\\\" --verified-command \\\"zig build causal-production-telemetry-capture-fixtures -- validate --format json\\\" --verified-command \\\"zig build causal-schema-governance -- --format json\\\" --verified-command \\\"zig build causal-production-hardening-backlog -- --format json\\\" --verified-command \\\"zig build examples\\\" --verified-command \\\"zig build test\\\"\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

The boundary records schema
`zigeffect.causal.production-telemetry-exporter-boundary.v1`. It consumes an
approved proposal artifact, emits `approved` or `blocked` boundary artifacts,
records local envelope fixture names, and hands off to
`codex/zigeffect-causal-production-telemetry-local-pipeline-fixtures`. Do not
treat the boundary as live telemetry, network send, collector configuration,
OTLP serialization, durable writes, CI gates, production capacity evidence,
non-NenDB adapter scope, alternate renderer scope, or mutation authority.

Run the local pipeline fixtures after boundary approval:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-local-pipeline-fixtures -- \
  --from-boundary ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary.json \
  approve \
  --reason "approved boundary reviewed for local pipeline fixtures" \
  --verified-command "zig build causal-production-telemetry-exporter-boundary -- --from-proposal ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal.json approve --reason \"proposal evidence reviewed for local pipeline fixtures\" --verified-command \"zig build causal-production-telemetry-implementation-proposal -- --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review.json approve --reason \\\"ready evidence reviewed for exporter boundary planning\\\" --verified-command \\\"zig build causal-production-telemetry-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json approve --reason \\\\\\\"fixtures reviewed for implementation proposal\\\\\\\" --verified-command \\\\\\\"zig build causal-production-telemetry-capture-fixtures -- validate --format json\\\\\\\" --verified-command \\\\\\\"zig build causal-schema-governance -- --format json\\\\\\\" --verified-command \\\\\\\"zig build causal-production-hardening-backlog -- --format json\\\\\\\" --verified-command \\\\\\\"zig build examples\\\\\\\" --verified-command \\\\\\\"zig build test\\\\\\\"\\\" --verified-command \\\"zig build causal-schema-governance -- --format json\\\" --verified-command \\\"zig build causal-production-hardening-backlog -- --format json\\\" --verified-command \\\"zig build examples\\\" --verified-command \\\"zig build test\\\"\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

The fixture report records schema
`zigeffect.causal.production-telemetry-local-pipeline-fixtures.v1`. It consumes
an approved boundary artifact, emits `ready` or `blocked` local fixture
artifacts, records normalized envelope, redaction, access, sampling, and
correlation fixtures, and hands off to
`codex/zigeffect-causal-production-telemetry-nendb-retention-fixtures`. Do not
treat the fixtures as runtime pipeline execution, live telemetry, network send,
collector configuration, OTLP serialization, NenDB writes, durable production
writes, CI gates, production capacity evidence, non-NenDB adapter scope,
alternate renderer scope, or mutation authority.

Run the NenDB retention fixtures after local pipeline approval:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-nendb-retention-fixtures -- \
  --from-local-pipeline ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures.json \
  approve \
  --reason "approved local pipeline reviewed for NenDB retention fixtures" \
  --verified-command "zig build causal-production-telemetry-local-pipeline-fixtures" \
  --verified-command "zig build causal-nendb-storage-backend" \
  --verified-command "zig build causal-durable-production-retention -- --format json" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

The retention fixture report records schema
`zigeffect.causal.production-telemetry-nendb-retention-fixtures.v1`. It
consumes a ready local-pipeline-fixtures artifact, emits `ready` or `blocked`
NenDB retention fixture artifacts, records node, edge, retention policy,
compaction, backup, and recovery mapping fixtures, and hands off to
the delivered
`codex/zigeffect-causal-production-telemetry-workbench-readonly-preview`. Do
not treat the fixtures as runtime pipeline execution, live telemetry, network
send, collector configuration, OTLP serialization, NenDB writes, durable
production writes, compaction execution, backup execution, restore execution,
CI gates, production capacity evidence, non-NenDB adapter scope, alternate
renderer scope, or mutation authority.

Run the workbench read-only preview after NenDB retention fixture approval:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-workbench-readonly-preview -- \
  --from-retention ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures.json \
  approve \
  --reason "read-only SolidJS webui preview reviewed" \
  --verified-command "bun run zigeffect:workbench:typecheck" \
  --verified-command "bun run zigeffect:workbench:test" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

The workbench preview report records schema
`zigeffect.causal.production-telemetry-workbench-readonly-preview.v1`. It
consumes a ready NenDB retention fixture artifact, backs the read-only
`Telemetry` tab and `?sample=production-telemetry` fixture, emits `ready` or
`blocked` workbench preview artifacts, and hands off to
the delivered `codex/zigeffect-causal-production-telemetry-ci-artifact-preview`.
Do not treat
the preview as runtime pipeline execution, live telemetry, network send,
collector configuration, OTLP serialization, NenDB writes, durable production
writes, CI gates, hosted dashboard readiness, production capacity evidence,
non-NenDB adapter scope, alternate renderer scope, or mutation authority.

Run the CI artifact preview after workbench preview approval:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-artifact-preview -- \
  --from-workbench ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview.json \
  approve \
  --reason "CI artifact preview reviewed" \
  --verified-command "zig build causal-production-telemetry-workbench-readonly-preview" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

The CI artifact preview report records schema
`zigeffect.causal.production-telemetry-ci-artifact-preview.v1`. It consumes a
ready workbench preview artifact, emits `ready` or `blocked` CI artifact
preview artifacts, records a failure-only archive candidate catalog and
preview-only upload policy, and hands off to
`codex/zigeffect-causal-production-telemetry-ci-harness-boundary`. Do not treat
the preview as artifact upload execution, GitHub Actions mutation, CI gate
enablement, runtime pipeline execution, live telemetry, network send,
collector configuration, OTLP serialization, NenDB writes, durable production
writes, hosted dashboard readiness, production capacity evidence, non-NenDB
adapter scope, alternate renderer scope, or mutation authority.

Run the CI harness boundary after CI artifact preview approval:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-harness-boundary -- \
  --from-ci-preview ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview.json \
  --workflow ../../.github/workflows/zigeffect-causal.yml \
  approve \
  --reason "CI harness boundary reviewed" \
  --verified-command "zig build causal-production-telemetry-ci-artifact-preview" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build release-gate --summary none" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

The CI harness boundary report records schema
`zigeffect.causal.production-telemetry-ci-harness-boundary.v1`. It consumes a
ready CI artifact preview artifact, inspects the existing causal GitHub Actions
workflow, emits `ready` or `blocked` CI harness boundary artifacts, records
workflow required-feature checks, workflow prohibited-feature checks, and
clustering release-gate assumptions, and hands off to
`codex/zigeffect-causal-production-telemetry-ci-archive-application`. Do not
treat the boundary as workflow mutation, artifact upload execution, CI gate
enablement, runtime pipeline execution, live telemetry, network send,
collector configuration, OTLP serialization, NenDB writes, durable production
writes, hosted dashboard readiness, production cluster readiness, non-NenDB
adapter scope, alternate renderer scope, or mutation authority.

Record the CI archive application plan after CI harness boundary approval:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-archive-application -- \
  --from-harness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary.json \
  plan \
  --reason "CI archive application planned from reviewed harness boundary"
```

The CI archive application report records schema
`zigeffect.causal.production-telemetry-ci-archive-application.v1`. It consumes
a ready CI harness boundary artifact and emits `planned`, `applied`, or
`blocked` archive application artifacts. `record-applied` only records
`applied=true` after workflow-change, before, after, safe after-workflow, and
post-verification evidence are present. Do not treat plan mode as workflow
mutation, artifact upload execution, CI gate enablement, runtime pipeline
execution, live telemetry, network send, collector configuration, OTLP
serialization, NenDB writes, durable production writes, hosted dashboard
readiness, production cluster readiness, non-NenDB adapter scope, alternate
renderer scope, or mutation authority.

Run the CI archive evidence policy after the CI archive application plan:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-archive-evidence-policy -- \
  --from-archive-application ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-archive-application.json \
  approve \
  --reason "CI archive evidence policy reviewed" \
  --verified-command "zig build causal-production-telemetry-ci-archive-application" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build release-gate --summary none" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

The CI archive evidence policy report records schema
`zigeffect.causal.production-telemetry-ci-archive-evidence-policy.v1`. It
consumes a planned or applied CI archive application artifact and emits `ready`
or `blocked` policy artifacts that define allowed archive evidence classes,
required provenance metadata, interpretation rules, denied claims, negative
fixtures, blocked claims, and required verification commands. Do not treat it
as CI gate enablement, workflow mutation, artifact upload execution, runtime
pipeline execution, live telemetry, network send, collector configuration,
OTLP serialization, NenDB writes, durable production writes, hosted dashboard
readiness, production cluster readiness, non-NenDB adapter scope, alternate
renderer scope, or mutation authority.

Run the CI gate readiness after the CI archive evidence policy:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-readiness -- \
  --from-archive-evidence-policy ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-archive-evidence-policy.json \
  approve \
  --reason "CI gate readiness reviewed" \
  --verified-command "zig build causal-production-telemetry-ci-archive-evidence-policy" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build release-gate --summary none" \
  --verified-command "zig build release-gate-report" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

The CI gate readiness report records schema
`zigeffect.causal.production-telemetry-ci-gate-readiness.v1`. It consumes a
ready archive evidence policy artifact and emits `ready` or `blocked`
readiness artifacts with readiness dimensions, advisory candidate gate signals,
limited gate semantics, release-gate verification evidence, negative fixtures,
blocked claims, and required verification commands. Do not treat it as CI gate
enforcement, required status checks, workflow mutation, artifact upload
execution, runtime pipeline execution, live telemetry, network send, collector
configuration, OTLP serialization, NenDB writes, durable production writes,
hosted dashboard readiness, production cluster readiness, non-NenDB adapter
scope, alternate renderer scope, or mutation authority.

Run the CI gate application boundary after the CI gate readiness:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-application-boundary -- \
  --from-gate-readiness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-gate-readiness.json \
  plan \
  --reason "CI gate application boundary planned"
```

The CI gate application boundary report records schema
`zigeffect.causal.production-telemetry-ci-gate-application-boundary.v1`. It
consumes a ready CI gate readiness artifact and emits `planned`, `applied`, or
`blocked` boundary artifacts. It only records `applied=true` when reviewed
workflow-change evidence, before evidence, after evidence, after-workflow
content, safe after-workflow checks, and all post-application verification
commands exist. Do not treat it as CI gate enforcement, required status checks,
workflow mutation by the tool, artifact upload execution, runtime pipeline
execution, live telemetry, network send, collector configuration, OTLP
serialization, NenDB writes, durable production writes, hosted dashboard
readiness, production cluster readiness, non-NenDB adapter scope, alternate
renderer scope, or production mutation authority.

Run the CI gate dry-run policy after the gate application boundary:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-dry-run-policy -- \
  --from-gate-application-boundary ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-gate-application-boundary.json \
  approve \
  --reason "CI gate dry-run policy reviewed" \
  --verified-command "zig build causal-production-telemetry-ci-gate-application-boundary" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build release-gate --summary none" \
  --verified-command "zig build release-gate-report" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

The CI gate dry-run policy report records schema
`zigeffect.causal.production-telemetry-ci-gate-dry-run-policy.v1`. It consumes
planned or applied CI gate application boundary artifacts and emits `ready` or
`blocked` dry-run policy artifacts with advisory candidate signal policies,
bounded evidence requirements, negative fixtures, and the evaluator handoff.
Do not treat it as CI gate enforcement, required status checks, workflow
mutation by the tool, artifact upload execution, runtime pipeline execution,
live telemetry, network send, collector configuration, OTLP serialization,
NenDB writes, durable production writes, hosted dashboard readiness,
production cluster readiness, non-NenDB adapter scope, alternate renderer
scope, or production mutation authority.

Run the CI gate dry-run evaluator after the dry-run policy:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-dry-run-evaluator -- \
  --from-dry-run-policy ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-gate-dry-run-policy.json \
  evaluate \
  --reason "CI gate dry-run evidence evaluated" \
  --evidence .zig-cache/release-gate/zigeffect-release-gate.json \
  --evidence .zig-cache/causal-artifacts/zigeffect-causal-causal-scoped-fiber.json
```

The CI gate dry-run evaluator report records schema
`zigeffect.causal.production-telemetry-ci-gate-dry-run-evaluator.v1`. It
consumes ready dry-run policy artifacts and explicit bounded local or CI
evidence, emits `ready`, `advisory-findings`, or `blocked` evaluator
artifacts, and hands off to advisory CI report rendering. Do not treat it as CI
gate enforcement, required status checks, workflow mutation by the tool,
artifact upload execution, runtime pipeline execution, live telemetry, network
send, collector configuration, OTLP serialization, NenDB writes, durable
production writes, hosted dashboard readiness, production cluster readiness,
non-NenDB adapter scope, alternate renderer scope, or production mutation
authority.

Run the CI gate advisory CI report after the dry-run evaluator:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-advisory-ci-report -- \
  --from-evaluator ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-gate-dry-run-evaluator.json \
  summarize \
  --reason "CI advisory report reviewed"
```

The CI gate advisory CI report records schema
`zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report.v1`. It
consumes ready or advisory dry-run evaluator artifacts, emits local JSON/text
reviewer guidance reports, records publication channels, and hands off to the
report application boundary. Do not treat it as CI gate enforcement, required
status checks, workflow mutation by the tool, artifact upload execution,
GitHub step summary writing, pull request comments, runtime pipeline
execution, live telemetry, network send, collector configuration, OTLP
serialization, NenDB writes, durable production writes, hosted dashboard
readiness, production cluster readiness, non-NenDB adapter scope, alternate
renderer scope, or production mutation authority.

Run the CI gate advisory CI report application boundary after the advisory
report:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary -- \
  --from-report ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-gate-advisory-ci-report.json \
  plan \
  --reason "CI advisory report application boundary planned"
```

The CI gate advisory CI report application boundary records schema
`zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report-application-boundary.v1`.
It consumes ready or advisory CI report artifacts, emits planned, applied, or
blocked report application boundary artifacts, and only records `applied=true`
after reviewed publication-change evidence, before evidence, after evidence,
safe report-after content, and post-application verification. Do not treat it
as CI gate enforcement, required status checks, workflow mutation by the tool,
artifact upload execution, GitHub step summary writing, pull request comments,
runtime pipeline execution, live telemetry, network send, collector
configuration, OTLP serialization, NenDB writes, durable production writes,
hosted dashboard readiness, production cluster readiness, non-NenDB adapter
scope, alternate renderer scope, or production mutation authority.

Run the CI gate advisory CI report publication policy after an applied
application-boundary artifact exists:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy -- \
  --from-application ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-advisory-ci-report-application-boundary-applied.json \
  approve \
  --reason "CI advisory report publication policy reviewed" \
  --verified-command "zig build causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build release-gate --summary none" \
  --verified-command "zig build release-gate-report" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

The CI gate advisory CI report publication policy records schema
`zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report-publication-policy.v1`.
It consumes applied application-boundary artifacts, emits ready or blocked
publication interpretation policy artifacts, and keeps advisory CI reports
non-blocking. Do not treat it as CI gate enforcement, required status checks,
branch protection, workflow mutation by the tool, artifact upload execution,
GitHub step summary writing by the tool, pull request comments by the tool,
runtime pipeline execution, live telemetry, network send, collector
configuration, OTLP serialization, NenDB writes, durable production writes,
hosted dashboard readiness, production cluster readiness, non-NenDB adapter
scope, alternate renderer scope, or production mutation authority.

## Production Artifact Aggregation

Run the production artifact aggregation contract before starting durable
production retention:

```sh
cd packages/zigeffect
zig build causal-production-artifact-aggregation
zig build causal-production-artifact-aggregation -- --format json
```

The contract records schema
`zigeffect.causal.production-artifact-aggregation.v1`, defines aggregation
bundle semantics, source provenance fields, privacy review gates, and a
deterministic local/CI multi-source fixture. It is not live ingestion, durable
storage, dashboarding, alerting, access control, encryption, rollout
automation, or mutation authority.

## Durable Production Retention

Run the durable production retention contract after artifact aggregation and
before production deployment runbooks:

```sh
cd packages/zigeffect
zig build causal-durable-production-retention
zig build causal-durable-production-retention -- --format json
```

The contract records schema
`zigeffect.causal.durable-production-retention.v1`, consumes
`zigeffect.causal.production-artifact-aggregation.v1`, and defines the
NenDB-only retention policy for reviewed aggregation bundles. It names TTL,
compaction, backup, recovery, privacy gates, retained source fixtures, and the
deployment-runbooks handoff consumed by
`zigeffect.causal.production-deployment-runbooks.v1`.

TTL remains policy-only here because causal events do not carry wall-clock
capture timestamps and deterministic tools do not inspect clocks. Recovery
evidence must prove queryable causal lineage after restore. This contract does
not scan artifacts, write durable production state, restore data, open
dashboards, add non-NenDB durable adapter scope, or grant mutation authority.

## Production Deployment Runbooks

Run the production deployment runbooks contract after artifact aggregation and
durable retention:

```sh
cd packages/zigeffect
zig build causal-production-deployment-runbooks
zig build causal-production-deployment-runbooks -- --format json
```

The contract records schema
`zigeffect.causal.production-deployment-runbooks.v1`, consumes the aggregation
and durable-retention contracts, and defines manual deployment, rollback,
causal verification, and incident-response runbooks. It requires reviewed
artifact bundles, redaction review, NenDB adapter retention readiness, human
approval, external deploy/rollback record ids, queryable event ids, and
post-action verification commands.

Deployment and rollback execution stay outside zigeffect authority. This
contract does not deploy services, roll back services, page humans, open live
production telemetry, add non-NenDB durable adapter scope, or grant production mutation
authority. Its immediate consumer is artifact access control.

## Artifact Access Control

Run the artifact access-control contract after deployment runbooks:

```sh
cd packages/zigeffect
zig build causal-artifact-access-control
zig build causal-artifact-access-control -- --format json
```

The contract records schema `zigeffect.causal.artifact-access-control.v1`,
consumes the aggregation, durable-retention, and deployment-runbook contracts,
and defines visibility classes, role labels, permissions, access decisions,
denied-view fixtures, and access audit record fields. Roles are policy labels,
not authenticated identities. Decisions are records, not live RBAC
enforcement.

This contract does not call identity providers, encrypt or decrypt artifacts,
modify the SolidJS workbench, deploy services, roll back services, or grant
mutation authority. This contract handed off to
`codex/zigeffect-causal-unified-spine-contract`; use
`causal-production-hardening-backlog` for the current next branch.

## Unified Causal Spine Contract

Run the unified causal spine contract after artifact access control and before
deep runtime internals:

```sh
cd packages/zigeffect
zig build causal-unified-spine-contract
zig build causal-unified-spine-contract -- --format json
```

The contract records schema `zigeffect.causal.unified-spine-contract.v1`,
consumes the current runtime, app-runtime, access-control, and NenDB projection
contracts, and defines canonical runtime ids, app semantic ids, relationship
types, policy stages, derived index families, consumer contracts, and fixture
mappings.

This contract was the handoff into
`codex/zigeffect-causal-deep-runtime-internals`. The later runtime and app
semantic branches preserve the same boundaries: no non-NenDB durable adapter
scope, no alternate frontend renderer switch, and no production mutation
authority.

## Encryption At Rest Policy

Run the encryption-at-rest policy contract after artifact access control and
before alerting integrations:

```sh
cd packages/zigeffect
zig build causal-encryption-at-rest-policy
zig build causal-encryption-at-rest-policy -- --format json
```

The contract records schema
`zigeffect.causal.encryption-at-rest-policy.v1`, consumes aggregation,
durable-retention, and artifact access-control contracts, and defines
encryption domains, key owner labels, rotation evidence, encrypted artifact
fixture metadata, redaction ordering, denied fixtures, and authority
boundaries.

Redaction review precedes encryption-at-rest eligibility. Key ids are
references, never key material. This contract does not encrypt bytes, decrypt
bytes, generate keys, call a KMS, enforce live RBAC, modify the SolidJS
workbench, add non-NenDB durable adapter scope, add alternate frontend renderer
support, or grant mutation authority.

## Alerting Integrations

Run the alerting integrations contract after encryption-at-rest policy and
before the now-delivered live dashboard streaming workbench:

```sh
cd packages/zigeffect
zig build causal-alerting-integrations
zig build causal-alerting-integrations -- --format json
```

The contract records schema
`zigeffect.causal.alerting-integrations.v1`, consumes aggregation,
deployment-runbook, access-control, encryption-policy, and agent-query
contracts, and defines channel contracts, severity and routing policy,
escalation gates, payload fields, preview fixtures, denied fixtures, and
authority boundaries for Slack, Linear, Jira, SIEM, and paging handoffs.

Every fixture is record-only. This contract does not send alerts, create
tickets, forward SIEM events, page humans, call networks, read secrets, mutate
external systems, ingest production telemetry, add non-NenDB durable adapter
scope, add alternate frontend renderer support, or grant production mutation
authority.

## Live Dashboard Streaming Workbench

Run the live dashboard streaming workbench contract after alerting integrations
and before deeper graph visual debugging:

```sh
cd packages/zigeffect
zig build causal-live-dashboard-streaming-workbench
zig build causal-live-dashboard-streaming-workbench -- --format json
```

The contract records schema
`zigeffect.causal.live-dashboard-streaming-workbench.v1` and registers the
bounded stream artifact schema `zigeffect.causal.live-dashboard-stream.v1`.
The SolidJS workbench can load the sample with `?sample=live`, render Live
frames and guardrails, and render a read-only Visual Graph tab through the
lazy-loaded `@dschz/solid-g6` adapter over `@antv/g6`.

The stream and UI are local evidence surfaces only. They do not ingest
production telemetry, host a shared production dashboard, call networks, edit
source, update registries, approve remediation, add non-NenDB durable adapter
scope, add alternate frontend renderer support, or grant mutation authority.

## Human-Agent Feedback Loop

Run the human-agent feedback-loop contract after graph visual debugging when a
human workbench selection, agent query report, before/after comparison,
regression cluster, or guarded remediation handoff needs one shared record:

```sh
cd packages/zigeffect
zig build causal-human-agent-feedback-loop
zig build causal-human-agent-feedback-loop -- --format json
```

The contract records schema
`zigeffect.causal.human-agent-feedback-loop.v1`. It names the
failure-to-query, before/after trace comparison, regression clustering,
guarded remediation handoff, and future NenDB durable-history handoff stages.
It keeps `applied=false`, `mutation_authority=none`,
`workbench_mutation=false`, and `agent_mutation=false`.

Use it as an evidence index for local development agents and app-facing issue
analysis. It does not run queries, write durable history, apply proposals, edit
source, update registries, change app code, execute deployments, create alerts,
or grant mutation authority.

## Rollout Automation Guardrails

Run the rollout automation guardrails contract after the human-agent feedback
loop when canary, rollout progression, circuit-breaker, or rollback readiness
evidence needs a record-only shape:

```sh
cd packages/zigeffect
zig build causal-rollout-automation-guardrails
zig build causal-rollout-automation-guardrails -- --format json
```

The contract records schema
`zigeffect.causal.rollout-automation-guardrails.v1`. It consumes deployment
runbooks, alerting integrations, and the human-agent feedback loop. It defines
canary evidence records, progression gates, circuit-breaker decisions, rollback
readiness gates, and negative automation fixtures.

Use it as an evidence checklist only. It does not deploy services, roll back
services, shift traffic, mutate feature flags, send alerts, create tickets,
forward SIEM events, page humans, edit source, update registries, change app
code, write durable state, or grant mutation authority.

## Wall Clock Benchmark Baselines

Run the wall-clock benchmark baseline contract when a branch needs local or CI
timing evidence shape without turning timing into deterministic CI gates:

```sh
cd packages/zigeffect
zig build causal-wall-clock-benchmark-baselines
zig build causal-wall-clock-benchmark-baselines -- --format json
```

The contract records schema
`zigeffect.causal.wall-clock-benchmark-baselines.v1`. It defines scenario
families for request traces, background jobs, artifact formatting, bounded
agent queries, before/after comparison, dev-loop package tests, SolidJS
workbench build/test boundaries, and CI baseline capture. It also defines the
future baseline record fields, environment metadata, calibration policy,
advisory review gates, and agent guidance.

Use it to decide whether future timing observations are comparable. Do not use
it to fail CI automatically, estimate production capacity, run load tests, call
networks, write durable stores, mutate source/config/app/registry/deployment
state, or grant production authority.

## Production Capacity Planning

Run the production capacity planning contract after the source evidence
contracts are present and before starting the completion audit or future
load-test harness design:

```sh
cd packages/zigeffect
zig build causal-production-capacity-planning
zig build causal-production-capacity-planning -- --format json
```

The contract records schema
`zigeffect.causal.production-capacity-planning.v1`. It consumes aggregation,
NenDB retention, wall-clock benchmark baselines, live dashboard stream, visual
graph, agent query, human-agent feedback, alerting, and rollout guardrail
contracts. It defines capacity domains, storage growth assumptions, load-test
fixture plans, workbench and graph concurrency assumptions, readiness gates,
negative capacity fixtures, agent guidance, non-goals, and the completion-audit
handoff.

Use it to ask better capacity questions and to block weak claims. Do not use it
to ingest production telemetry, execute load tests, estimate production
capacity or cost, provision infrastructure, host production dashboards, write
durable stores, introduce non-NenDB adapter work, add alternate workbench
renderers, mutate source/config/app/registry/deployment/rollout/alert state, or
grant production authority.

## Completion-Audit Handoff

Run `causal-production-hardening-completion-audit` after capacity planning to
confirm the delivered hardening sequence and choose the next evidence-producing
branch. The load-test observation harness and production telemetry capture
design, fixture, readiness-review, implementation-proposal, and
exporter-boundary, local-pipeline-fixtures, NenDB-retention-fixtures,
workbench-readonly-preview, CI-artifact-preview, CI-harness-boundary,
CI-archive-application, CI-archive-evidence-policy, CI-gate-readiness, and
CI-gate-application-boundary, CI-gate-dry-run-policy, and
CI-gate-dry-run-evaluator, CI-gate-advisory-ci-report, and
CI-gate-advisory-ci-report-application-boundary, and
CI-gate-advisory-ci-report-publication-policy
reports are now delivered.
The current next branch is
`codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-readiness`.

## Production Gaps

The current operating model does not provide:

- distributed artifact aggregation;
- durable production retention beyond local files and CI uploads;
- live alert delivery, live ticket creation, SIEM forwarding, or paging
  execution;
- live RBAC enforcement over artifact bundles;
- encryption-at-rest implementation, KMS integration, or live key rotation;
- production live dashboard ingestion, multi-user hosting, or server-side
  streams;
- automated source/config mutation authority;
- gradual rollout, canary, or circuit-breaker automation;
- wall-clock CI timing gates;
- production telemetry capture, production load execution, or reviewed production
  capacity sizing.

Those belong to future production hardening. Use
`zig build causal-production-hardening-backlog` and
`zig build causal-production-hardening-completion-audit` before starting one of
those systems.
