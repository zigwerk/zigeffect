# zigeffect Causal Production Hardening Backlog

`causal-production-hardening-backlog` is the deterministic branch queue for
production hardening after the M9 local/CI operating model. It converts the M9
production-gap register into ordered backlog items with dependencies,
constraints, non-goals, evidence sources, verification commands, and the next
recommended branch.

## Command

```sh
cd packages/zigeffect
zig build causal-production-hardening-backlog
zig build causal-production-hardening-backlog -- --format json
```

The text report is for maintainers. The JSON report uses schema
`zigeffect.causal.production-hardening-backlog.v1` for agents and automated
roadmap checks.

## What The Report Means

The report is a planning and governance artifact. It does not ingest production
telemetry, write durable production state, deploy services, page humans,
enforce RBAC, encrypt data, open a production dashboard, or mutate source and
config.

The recommendation `start-production-telemetry-ci-gate-required-status-check-enforcement-policy` means the
aggregation bundle contract, NenDB-only durable-retention contract, manual
production deployment runbooks, record-only artifact access-control contract,
unified causal spine contract, deep runtime internals, app semantic trace API,
bounded agent query surface, record-only encryption-at-rest policy, and
record-only alerting integrations now exist, and the read-only live dashboard
streaming workbench now has a stream contract, local fixture, Live tab, and
Solid G6 visual graph adapter boundary. Graph visual debugging is also
delivered: Visual Graph supports cause, topology, ownership, and lineage
perspectives; `?sample=visual-graph` loads the graph debugging fixture; and
browser verification covers desktop/mobile plus nonblank G6 canvas evidence.
The human-agent feedback loop is also delivered: it connects workbench
selection, bounded agent queries, before/after comparison, local regression
clustering records, guarded remediation handoff, and future NenDB history
handoff while preserving `mutation_authority=none`.
Rollout automation guardrails are also delivered: they define canary evidence,
rollout progression gates, circuit-breaker decisions, rollback readiness gates,
and negative automation fixtures without granting rollout authority.
Wall-clock benchmark baselines are also delivered: they define local and CI
benchmark scenario families, baseline record fields, environment metadata,
calibration policy, advisory review gates, and agent guidance without running
benchmarks or creating timing-based CI gates.
Production capacity planning is also delivered: it defines source evidence,
capacity domains, storage assumptions, load-test fixture plans, workbench and
graph concurrency assumptions, readiness gates, negative capacity fixtures, and
completion-audit handoff without running load tests or claiming production
capacity.
The production-hardening completion audit is also delivered: it verifies the
delivered hardening milestones, preserves record-only, `mutation_authority=none`,
NenDB-only, and SolidJS `zig-webui` boundaries, records remaining evidence
gaps, and blocks over-claims before any evidence-producing follow-up branch.
The load-test observation harness is also delivered: it catalogs approved local
scenario families, runs bounded local observations from curated argv arrays,
emits median/p95 records with bounded snippets, and keeps observations
advisory, local-only, and record-only.
The production telemetry capture design is also delivered: it defines safe
future capture surfaces, field contracts, redaction, sampling, retention,
access, encryption, OTel bridge review, negative fixtures, and local
observation separation without enabling live ingestion or exporter authority.
The production telemetry capture fixtures are also delivered: they define safe
example records, selected fixture output, negative fixtures, and validation
checks without enabling live ingestion, exporter authority, durable production
writes, CI gates, capacity claims, or mutation authority.
The production telemetry readiness review is also delivered: it consumes
fixture JSON, records reviewer decision and reason, verifies coverage and
authority boundaries, requires explicit verification command evidence, and
emits ready or blocked artifacts before any implementation proposal branch.
The production telemetry implementation proposal is also delivered: it consumes
a ready readiness-review artifact, records proposer decision and reason,
verifies readiness and proposal evidence, emits approved or blocked proposal
artifacts, records implementation phases, and preserves non-live authority
before any exporter-boundary branch.
The production telemetry exporter boundary is also delivered: it consumes an
approved implementation-proposal artifact, verifies source proposal evidence,
records a no-network exporter boundary contract, local envelope fixture names,
and required verification evidence, and preserves disabled network send,
collector endpoint, OTLP serialization, live telemetry, durable writes, CI
gates, non-NenDB adapter scope, alternate renderer scope, and mutation
authority before any local pipeline fixture branch.
The production telemetry local pipeline fixtures are also delivered: they
consume an approved exporter-boundary artifact, record fixture-only local
envelope shaping, redaction, access, sampling, and correlation evidence, and
preserve disabled runtime pipeline execution, live telemetry, network send,
collector endpoint, OTLP serialization, durable writes, CI gates, non-NenDB
adapter scope, alternate renderer scope, and mutation authority before any
NenDB retention fixture branch.
The production telemetry NenDB retention fixtures are also delivered: they
consume ready local-pipeline-fixtures artifacts, record NenDB node and edge
mapping fixtures, retention policy constants, compaction markers, backup and
recovery markers, and preserve disabled runtime pipeline execution, live
telemetry, network send, collector endpoint, OTLP serialization, durable writes,
NenDB writes, CI gates, non-NenDB adapter scope, alternate renderer scope, and
mutation authority before any workbench preview branch.
The production telemetry workbench read-only preview is also delivered: it
consumes ready NenDB retention fixture artifacts, adds a read-only SolidJS
`webui-dev/zig-webui` Telemetry tab and development sample, emits ready or
blocked workbench preview artifacts, and preserves disabled runtime pipeline
execution, live telemetry, network send, collector endpoint, OTLP
serialization, durable writes, NenDB writes, CI gates, hosted dashboard claims,
alternate renderer scope, and mutation authority before any CI artifact preview
branch.
The production telemetry CI artifact preview is also delivered: it consumes
ready workbench preview artifacts, records a preview-only CI archive candidate
catalog and upload policy, emits ready or blocked CI artifact preview
artifacts, and preserves disabled artifact upload execution, workflow mutation,
CI gates, runtime pipeline execution, live telemetry, network send, collector
endpoint, OTLP serialization, durable writes, NenDB writes, hosted dashboard
claims, alternate renderer scope, and mutation authority before any CI harness
boundary branch.
The production telemetry CI harness boundary is also delivered: it consumes
ready CI artifact preview evidence, inspects the existing causal GitHub Actions
workflow, records workflow required-feature checks, workflow prohibited-feature
checks, and clustering release-gate assumptions, emits ready or blocked CI
harness boundary artifacts, and preserves disabled workflow mutation, artifact
upload execution, CI gates, runtime pipeline execution, live telemetry, network
send, collector endpoint, OTLP serialization, durable writes, NenDB writes,
hosted dashboard claims, production cluster claims, alternate renderer scope,
and mutation authority before any CI archive application branch.
The production telemetry CI archive application is also delivered: it consumes
ready CI harness boundary evidence and emits guarded planned, applied, or
blocked archive application artifacts. It only records `applied=true` after
workflow-change evidence, before evidence, after evidence, safe after-workflow
checks, and post-application verification commands are present. It preserves
disabled local workflow mutation, artifact upload execution, CI gates, runtime
pipeline execution, live telemetry, network send, collector endpoint, OTLP
serialization, durable writes, NenDB writes, hosted dashboard claims,
production cluster claims, alternate renderer scope, and mutation authority
before any archive evidence policy branch.
The production telemetry CI archive evidence policy is also delivered: it
consumes planned or applied CI archive application artifacts, defines allowed
archive evidence classes, required metadata, interpretation rules, denied
claims, and negative fixtures, and preserves disabled CI gates, workflow
mutation, artifact upload execution, runtime pipeline execution, live
telemetry, network send, collector endpoint, OTLP serialization, durable
writes, NenDB writes, hosted dashboard claims, production cluster claims,
alternate renderer scope, and mutation authority before any CI gate readiness
branch.
The production telemetry CI gate readiness branch is also delivered: it
consumes ready archive evidence policy artifacts, records advisory readiness
dimensions, candidate gate signals, limited gate semantics, release-gate
verification evidence, and negative fixtures, and preserves disabled CI gate
enforcement, required status checks, workflow mutation, artifact upload
execution, runtime pipeline execution, live telemetry, network send, collector
endpoint, OTLP serialization, durable writes, NenDB writes, hosted dashboard
claims, production cluster claims, alternate renderer scope, and mutation
authority before any gate application boundary branch.
The production telemetry CI gate application boundary branch is also delivered:
it consumes ready gate readiness artifacts and records planned or blocked
boundary evidence before dry-run policy work.
The production telemetry CI gate dry-run policy branch is also delivered: it
consumes planned or applied application boundary artifacts and records advisory
candidate signal policies, bounded evidence requirements, and negative
fixtures before evaluator work.
The production telemetry CI gate dry-run evaluator branch is also delivered:
it consumes ready dry-run policy artifacts plus explicit bounded local or CI
evidence, classifies evidence, records observed, advisory, or blocked signals,
and preserves disabled CI gate enforcement, required status checks, workflow
mutation, artifact upload execution, live telemetry, network send, durable
writes, NenDB writes, hosted dashboard claims, production cluster claims,
alternate renderer scope, and mutation authority before any advisory CI report
branch.
The production telemetry CI gate advisory CI report branch is also delivered:
it consumes ready or advisory evaluator artifacts, renders local JSON/text
reviewer guidance, records publication channels, and preserves disabled CI
gate enforcement, required status checks, workflow mutation, artifact upload
execution, GitHub step summary writes, pull request comments, live telemetry,
network send, durable writes, NenDB writes, hosted dashboard claims,
production cluster claims, alternate renderer scope, and mutation authority
before any report application boundary branch.
The production telemetry CI gate advisory CI report application boundary branch
is also delivered: it consumes ready or advisory CI report artifacts, records
planned, applied, or blocked report publication boundary evidence, and
preserves disabled report publication by the tool, CI uploads, GitHub step
summary writes, pull request comments, required checks, workflow mutation, live
telemetry, network send, durable writes, NenDB writes, hosted dashboard claims,
production cluster claims, alternate renderer scope, and mutation authority
before any publication policy branch.
The production telemetry CI gate advisory CI report publication policy branch
is also delivered: it consumes applied application-boundary artifacts, records
allowed and denied interpretations for externally published advisory reports,
and preserves non-blocking advisory semantics before any required-status-check
readiness branch. The required-status-check readiness branch is now delivered
and records activation-disabled candidate checks plus guardrails before any
application boundary. The required-status-check application-boundary branch is
also delivered and records planned or externally applied required-check
boundary evidence. The required-status-check policy branch is also delivered:
it consumes planned or applied application-boundary artifacts, preserves
`source_applied`, records denied GitHub mutation and merge-blocking
inferences, and hands off toward enforcement-readiness while keeping every
tool-side mutation authority disabled.
The required-status-check enforcement-readiness branch is also delivered: it
requires externally applied source policy plus explicit required check names,
branch-protection evidence, workflow or check-run evidence, failure-mode
evidence, owner approval, rollback evidence, and verification commands before
the future enforcement application-boundary branch may start. It still denies
active required-check enforcement, merge blocking, GitHub mutation by the tool,
workflow mutation by the tool, CI upload execution, live telemetry, durable
writes, NenDB writes, production cluster claims, and mutation authority.
The required-status-check enforcement application-boundary branch is also
delivered: it consumes ready enforcement-readiness evidence and records planned
or externally applied active required-check enforcement evidence. It only
allows `applied=true` with reviewed branch-protection before/after evidence,
workflow or check-run evidence, failure-mode evidence, owner approval,
rollback evidence, complete verification, and merge-blocking evidence when
that claim is made. It still denies GitHub mutation by the tool, workflow
mutation by the tool, CI upload execution, live telemetry, durable writes,
NenDB writes, production cluster claims, and mutation authority.
The next branch should be
`codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-policy`.

## Dependency Order

The backlog currently orders future production-hardening branches as:

1. `production-artifact-aggregation` delivered
2. `durable-production-retention` delivered
3. `production-deployment-runbooks` delivered
4. `artifact-access-control` delivered
5. `unified-causal-spine-contract` delivered
6. `deep-runtime-internals` delivered
7. `app-semantic-trace-api` delivered
8. `agent-query-interface` partial
9. `encryption-at-rest-policy` delivered
10. `alerting-integrations` delivered
11. `live-dashboard-streaming-workbench` delivered
12. `workbench-graph-visual-debugging` delivered
13. `human-agent-feedback-loop` delivered
14. `rollout-automation-guardrails` delivered
15. `wall-clock-benchmark-baselines` delivered
16. `production-capacity-planning` delivered
17. `production-hardening-completion-audit` delivered
18. `load-test-observation-harness` delivered
19. `production-telemetry-capture-design` delivered
20. `production-telemetry-capture-fixtures` delivered
21. `production-telemetry-readiness-review` delivered
22. `production-telemetry-implementation-proposal` delivered
23. `production-telemetry-exporter-boundary` delivered
24. `production-telemetry-local-pipeline-fixtures` delivered
25. `production-telemetry-nendb-retention-fixtures` delivered
26. `production-telemetry-workbench-readonly-preview` delivered
27. `production-telemetry-ci-artifact-preview` delivered
28. `production-telemetry-ci-harness-boundary` delivered
29. `production-telemetry-ci-archive-application` delivered
30. `production-telemetry-ci-archive-evidence-policy` delivered
31. `production-telemetry-ci-gate-readiness` delivered
32. `production-telemetry-ci-gate-application-boundary` delivered
33. `production-telemetry-ci-gate-dry-run-policy` delivered
34. `production-telemetry-ci-gate-dry-run-evaluator` delivered
35. `production-telemetry-ci-gate-advisory-ci-report` delivered
36. `production-telemetry-ci-gate-advisory-ci-report-application-boundary` delivered
37. `production-telemetry-ci-gate-advisory-ci-report-publication-policy` delivered
38. `production-telemetry-ci-gate-required-status-check-readiness` delivered
39. `production-telemetry-ci-gate-required-status-check-application-boundary` delivered
40. `production-telemetry-ci-gate-required-status-check-policy` delivered
41. `production-telemetry-ci-gate-required-status-check-enforcement-readiness` delivered
42. `production-telemetry-ci-gate-required-status-check-enforcement-application-boundary` delivered

The ordering is intentionally conservative. It keeps contracts and review
boundaries ahead of production behavior. The `agent-query-interface` item is
split: runtime bounded JSON queries and app semantic `trace_data` are
delivered, while cross-run comparison remains future work.

## Authority Boundaries

Durable database work is NenDB adapter work only. Do not use this backlog to add
non-NenDB durable adapter scope to zigeffect causal production hardening.

Durable retention is documented in
[durable-production-retention.md](durable-production-retention.md). It defines
TTL, compaction, backup, recovery, and verification fixture contracts without
adding live ingestion or production mutation authority.

Deployment runbooks are documented in
[production-deployment-runbooks.md](production-deployment-runbooks.md). They
define manual deploy, rollback, causal verification, and incident-response
gates without adding deployment automation, rollback automation, alerting, or
production mutation authority.

Artifact access control is documented in
[artifact-access-control.md](artifact-access-control.md). It defines visibility
classes, role labels, permissions, decisions, denied-view fixtures, and audit
record fields without live RBAC enforcement, identity providers, workbench
mutation, or production mutation authority.

Encryption-at-rest policy is documented in
[encryption-at-rest-policy.md](encryption-at-rest-policy.md). It defines
encryption domains, key owner labels, rotation evidence, encrypted artifact
fixture metadata, redaction ordering, denied fixtures, and authority boundaries
without encrypting bytes, decrypting bytes, generating keys, calling a KMS,
enforcing live RBAC, or granting production mutation authority.

Alerting integrations are documented in
[alerting-integrations.md](alerting-integrations.md). They define record-only
channel contracts, severity and routing policy, escalation gates, payload
fields, preview fixtures, denied fixtures, and authority boundaries without
sending alerts, creating tickets, forwarding SIEM events, paging humans,
calling networks, reading secrets, or granting production mutation authority.

The live dashboard streaming workbench is documented in
[live-dashboard-streaming-workbench.md](live-dashboard-streaming-workbench.md).
It defines `zigeffect.causal.live-dashboard-stream.v1`, a bounded local stream
fixture, Live and Visual Graph workbench tabs, and the first
`@dschz/solid-g6` adapter boundary without opening production telemetry,
executing commands, enforcing RBAC, writing durable stores, or granting
mutation authority.

Workbench work remains SolidJS inside `webui-dev/zig-webui`. Alternate
frontend renderer work remains a non-goal unless a later adapter proves a
concrete need.

The unified causal spine is documented in
[unified-spine-contract.md](unified-spine-contract.md). It defines stable
runtime ids (`run_id`, `event_id`, `parent_event_id`, `cause_id`, `fiber_id`,
`scope_id`, `layer_id`, `service_key`, and `resource_id`), app semantic ids
(`artifact_id`, `domain_entity_ref`, `data_subject_ref`, and `schema_ref`), and
relationship types (`caused_by`, `parent_of`, `requires`, `provides`, `reads`,
`writes`, `transforms`, `emits`, `owns`, and `finalizes`). Runtime internals and
app semantics should emit into that spine before UI, agent, and durable-store
projections consume it.

Humans and agents consume the same evidence model, but they need different
surfaces. The SolidJS `zig-webui` workbench is the human control room for
reading, viewing, managing, and understanding what happened. The agent
interface is a compact query surface for bounded graph slices, evidence ids,
diffs, redaction state, truncation state, confidence, and recommended next
queries.

The live dashboard and streaming workbench branch added the first graph adapter
boundary. It starts with `@dschz/solid-g6` as the SolidJS integration layer,
keeps the zigeffect causal graph model as the source of truth, lazy-loads the
large graph chunk, and keeps direct `@antv/g6` engine API usage
`not-required`.

The dedicated graph visual debugging branch delivered cause, topology,
ownership, and lineage perspectives in the Visual Graph tab. It adds
perspective controls, selection details, legend and warning panels, richer G6
adapter metadata, the `?sample=visual-graph` fixture, and desktop/mobile
nonblank canvas verification. Treat `solid-flow` as optional later editor
research for editable remediation planning, not as a default dashboard
dependency.

The human-agent feedback loop is documented in
[human-agent-feedback-loop.md](human-agent-feedback-loop.md). It emits
`zigeffect.causal.human-agent-feedback-loop.v1` through
`zig build causal-human-agent-feedback-loop` and keeps the feedback loop
record-only.

Rollout automation guardrails are documented in
[rollout-automation-guardrails.md](rollout-automation-guardrails.md). They emit
`zigeffect.causal.rollout-automation-guardrails.v1` through
`zig build causal-rollout-automation-guardrails` and keep canary progression,
circuit breakers, and rollback readiness record-only.

Wall-clock benchmark baselines are documented in
[wall-clock-benchmark-baselines.md](wall-clock-benchmark-baselines.md). They
emit `zigeffect.causal.wall-clock-benchmark-baselines.v1` through
`zig build causal-wall-clock-benchmark-baselines` and keep local and CI timing
evidence advisory, environment-scoped, and record-only.

Production capacity planning is documented in
[production-capacity-planning.md](production-capacity-planning.md). It emits
`zigeffect.causal.production-capacity-planning.v1` through
`zig build causal-production-capacity-planning` and keeps capacity domains,
storage assumptions, load-test fixture plans, dashboard and graph concurrency
assumptions, agent guidance, readiness gates, and negative capacity fixtures
record-only.

Production hardening completion audit is documented in
[production-hardening-completion-audit.md](production-hardening-completion-audit.md).
It emits `zigeffect.causal.production-hardening-completion-audit.v1` through
`zig build causal-production-hardening-completion-audit`, audits the delivered
production-hardening report sequence, records remaining evidence gaps, and
keeps every authority boundary explicit.

Load-test observation harness is documented in
[load-test-observation-harness.md](load-test-observation-harness.md). It emits
`zigeffect.causal.load-test-observation-harness.v1` through
`zig build causal-load-test-observation-harness`, catalogs approved local
scenario families, and can run bounded local observations without production
load, production telemetry, capacity claims, shell execution, or mutation
authority.

Production telemetry capture design is documented in
[production-telemetry-capture-design.md](production-telemetry-capture-design.md).
It emits `zigeffect.causal.production-telemetry-capture-design.v1` through
`zig build causal-production-telemetry-capture-design`, defines future capture
surfaces, field contracts, review gates, negative fixtures, and preserves local
observation boundaries, NenDB-only durable direction, SolidJS `zig-webui`
workbench direction, and `mutation_authority=none`.

Production telemetry capture fixtures are documented in
[production-telemetry-capture-fixtures.md](production-telemetry-capture-fixtures.md).
They emit `zigeffect.causal.production-telemetry-capture-fixtures.v1` through
`zig build causal-production-telemetry-capture-fixtures`, provide safe example
records, selected fixture output, negative fixtures, validation checks, and
preserve `mutation_authority=none`, disabled live telemetry, disabled durable
writes, disabled CI gates, NenDB-only durable direction, and SolidJS
`zig-webui` workbench direction.

Production telemetry readiness review is documented in
[production-telemetry-readiness-review.md](production-telemetry-readiness-review.md).
It emits `zigeffect.causal.production-telemetry-readiness-review.v1` through
`zig build causal-production-telemetry-readiness-review`, consumes fixture JSON,
records reviewer decision and reason, verifies coverage and authority
boundaries, requires explicit verification command evidence, and preserves
`applied=false`, `mutation_authority=none`, disabled live telemetry, disabled
durable writes, disabled CI gates, NenDB-only durable direction, and SolidJS
`zig-webui` workbench direction.

Production telemetry implementation proposal is documented in
[production-telemetry-implementation-proposal.md](production-telemetry-implementation-proposal.md).
It emits
`zigeffect.causal.production-telemetry-implementation-proposal.v1` through
`zig build causal-production-telemetry-implementation-proposal`, consumes ready
readiness-review JSON, records proposer decision and reason, verifies readiness
and proposal command evidence, emits approved or blocked proposal artifacts,
and preserves `applied=false`, `mutation_authority=none`, disabled live
telemetry, disabled durable writes, disabled CI gates, NenDB-only durable
direction, and SolidJS `zig-webui` workbench direction.

Production telemetry exporter boundary is documented in
[production-telemetry-exporter-boundary.md](production-telemetry-exporter-boundary.md).
It emits `zigeffect.causal.production-telemetry-exporter-boundary.v1` through
`zig build causal-production-telemetry-exporter-boundary`, consumes approved
implementation-proposal JSON, verifies proposal evidence, records
exporter-neutral no-network boundaries and local envelope fixture names, and
preserves `applied=false`, `mutation_authority=none`, disabled live telemetry,
disabled network send, disabled collector endpoint configuration, disabled
OTLP serialization, disabled durable writes, disabled CI gates, NenDB-only
durable direction, and SolidJS `zig-webui` workbench direction.

Production telemetry local pipeline fixtures are documented in
[production-telemetry-local-pipeline-fixtures.md](production-telemetry-local-pipeline-fixtures.md).
They emit
`zigeffect.causal.production-telemetry-local-pipeline-fixtures.v1` through
`zig build causal-production-telemetry-local-pipeline-fixtures`, consume
approved exporter-boundary JSON, verify no-network boundary evidence, record a
fixture-only local envelope catalog plus redaction and sampling checks, and
preserve `applied=false`, `mutation_authority=none`, disabled live telemetry,
disabled network send, disabled collector endpoint configuration, disabled
OTLP serialization, disabled runtime pipeline execution, disabled durable
writes, disabled CI gates, NenDB-only durable direction, and SolidJS
`zig-webui` workbench direction.

Production telemetry NenDB retention fixtures are documented in
[production-telemetry-nendb-retention-fixtures.md](production-telemetry-nendb-retention-fixtures.md).
They emit
`zigeffect.causal.production-telemetry-nendb-retention-fixtures.v1` through
`zig build causal-production-telemetry-nendb-retention-fixtures`, consume ready
local-pipeline-fixtures JSON, verify source local-pipeline evidence, record
NenDB node, edge, retention, compaction, backup, and recovery mapping fixtures,
and preserve `applied=false`, `mutation_authority=none`, disabled live
telemetry, disabled network send, disabled collector endpoint configuration,
disabled OTLP serialization, disabled runtime pipeline execution, disabled
durable writes, disabled NenDB writes, disabled CI gates, NenDB-only durable
direction, and SolidJS `zig-webui` workbench direction.

Production telemetry workbench read-only preview is documented in
[production-telemetry-workbench-readonly-preview.md](production-telemetry-workbench-readonly-preview.md).
It emits `zigeffect.causal.production-telemetry-workbench-readonly-preview.v1`
through `zig build causal-production-telemetry-workbench-readonly-preview`,
consumes ready NenDB retention fixture JSON, backs the read-only `Telemetry`
tab and `?sample=production-telemetry`, records source checks, authority
boundary evidence, mapping fixtures, validation checks, blocked claims, and
required verification commands, and preserves `applied=false`,
`mutation_authority=none`, disabled live telemetry, disabled network send,
disabled collector endpoint configuration, disabled OTLP serialization,
disabled runtime pipeline execution, disabled durable writes, disabled NenDB
writes, disabled CI gates, NenDB-only durable direction, and SolidJS
`zig-webui` workbench direction.

The delivered CI artifact preview branch used ready workbench preview artifacts
to define a CI artifact preview before any durable production writes, live
ingestion, exporters, capacity claims, CI gates, or mutation authority are
considered.

Production telemetry CI artifact preview is documented in
[production-telemetry-ci-artifact-preview.md](production-telemetry-ci-artifact-preview.md).
It emits `zigeffect.causal.production-telemetry-ci-artifact-preview.v1`
through `zig build causal-production-telemetry-ci-artifact-preview`, consumes a
ready workbench preview artifact, records source checks, authority boundary
evidence, mapping fixture ids, a failure-only artifact candidate catalog,
preview-only upload policy, validation checks, blocked claims, and required
verification commands, and preserves `applied=false`,
`mutation_authority=none`, disabled artifact upload execution, disabled
workflow mutation, disabled CI gates, disabled live telemetry, disabled network
send, disabled collector endpoint configuration, disabled OTLP serialization,
disabled runtime pipeline execution, disabled durable writes, disabled NenDB
writes, NenDB-only durable direction, and SolidJS `zig-webui` workbench
direction.

Production telemetry CI harness boundary is documented in
[production-telemetry-ci-harness-boundary.md](production-telemetry-ci-harness-boundary.md).
It emits `zigeffect.causal.production-telemetry-ci-harness-boundary.v1`
through `zig build causal-production-telemetry-ci-harness-boundary`, consumes a
ready CI artifact preview artifact, inspects the existing causal GitHub Actions
workflow, records workflow required-feature checks, workflow prohibited-feature
checks, clustering release-gate assumptions, blocked claims, and required
verification commands, and preserves `applied=false`,
`mutation_authority=none`, disabled artifact upload execution, disabled
workflow mutation, disabled CI gates, disabled live telemetry, disabled network
send, disabled collector endpoint configuration, disabled OTLP serialization,
disabled runtime pipeline execution, disabled durable writes, disabled NenDB
writes, NenDB-only durable direction, and SolidJS `zig-webui` workbench
direction.

Production telemetry CI archive application is documented in
[production-telemetry-ci-archive-application.md](production-telemetry-ci-archive-application.md).
It emits `zigeffect.causal.production-telemetry-ci-archive-application.v1`
through `zig build causal-production-telemetry-ci-archive-application`,
consumes a ready CI harness boundary artifact, records plan or record-applied
application state, workflow-change evidence, before evidence, after evidence,
safe after-workflow checks, blocked claims, and required verification
commands, and preserves disabled local workflow mutation, disabled artifact
upload execution, disabled CI gates, disabled live telemetry, disabled network
send, disabled collector endpoint configuration, disabled OTLP serialization,
disabled runtime pipeline execution, disabled durable writes, disabled NenDB
writes, NenDB-only durable direction, and SolidJS `zig-webui` workbench
direction.

Ready CI archive application artifacts are the source evidence for archive
evidence policy work; they do not themselves approve CI telemetry gates,
durable production writes, live ingestion, exporters, capacity claims,
production cluster claims, or mutation authority.

Production telemetry CI archive evidence policy is documented in
[production-telemetry-ci-archive-evidence-policy.md](production-telemetry-ci-archive-evidence-policy.md).
It emits
`zigeffect.causal.production-telemetry-ci-archive-evidence-policy.v1` through
`zig build causal-production-telemetry-ci-archive-evidence-policy`, consumes
planned or applied CI archive application artifacts, records archive evidence
classes, provenance metadata requirements, interpretation rules, denied
claims, negative fixtures, blocked claims, and required verification commands,
and preserves disabled workflow mutation, disabled artifact upload execution,
disabled CI gates, disabled live telemetry, disabled network send, disabled
collector endpoint configuration, disabled OTLP serialization, disabled
runtime pipeline execution, disabled durable writes, disabled NenDB writes,
NenDB-only durable direction, and SolidJS `zig-webui` workbench direction.

Ready archive evidence policy artifacts are the source evidence for CI gate
readiness; they do not themselves approve CI telemetry gates, durable
production writes, live ingestion, exporters, capacity claims, production
cluster claims, or mutation authority.

Production telemetry CI gate readiness is documented in
[production-telemetry-ci-gate-readiness.md](production-telemetry-ci-gate-readiness.md).
It emits `zigeffect.causal.production-telemetry-ci-gate-readiness.v1` through
`zig build causal-production-telemetry-ci-gate-readiness`, consumes ready
archive evidence policy artifacts, records readiness dimensions, advisory
candidate gate signals, limited gate semantics, release-gate verification
evidence, negative fixtures, blocked claims, and required verification
commands, and preserves disabled workflow mutation, disabled artifact upload
execution, disabled CI gate enforcement, disabled required status checks,
disabled live telemetry, disabled network send, disabled collector endpoint
configuration, disabled OTLP serialization, disabled runtime pipeline
execution, disabled durable writes, disabled NenDB writes, NenDB-only durable
direction, and SolidJS `zig-webui` workbench direction.

Production telemetry CI gate application boundary is documented in
[production-telemetry-ci-gate-application-boundary.md](production-telemetry-ci-gate-application-boundary.md).
It emits
`zigeffect.causal.production-telemetry-ci-gate-application-boundary.v1`
through `zig build causal-production-telemetry-ci-gate-application-boundary`,
consumes ready CI gate readiness artifacts, records planned or blocked
application boundary evidence, and only records `applied=true` when reviewed
workflow-change evidence, before evidence, after evidence, after-workflow
content, safe after-workflow checks, and all post-application verification
commands exist. It preserves disabled CI gate enforcement, disabled required
status checks, disabled workflow mutation by the tool, disabled artifact upload
execution, disabled live telemetry, disabled durable writes, disabled NenDB
writes, NenDB-only durable direction, and SolidJS `zig-webui` workbench
direction.

The dry-run policy branch uses planned or applied CI gate application boundary
artifacts to define advisory policy rules before any CI telemetry gate
enforcement, required status checks, live telemetry, durable production writes,
capacity claims, production cluster claims, or mutation authority are
considered.

Production telemetry CI gate dry-run policy is documented in
[production-telemetry-ci-gate-dry-run-policy.md](production-telemetry-ci-gate-dry-run-policy.md).
It emits
`zigeffect.causal.production-telemetry-ci-gate-dry-run-policy.v1` through
`zig build causal-production-telemetry-ci-gate-dry-run-policy`, consumes
planned or applied CI gate application boundary artifacts, records advisory
candidate signal policies, bounded evidence requirements, negative fixtures,
and ready or blocked dry-run policy evidence, and hands off to the evaluator
branch. It preserves disabled CI gate enforcement, disabled required status
checks, disabled workflow mutation by the tool, disabled artifact upload
execution, disabled live telemetry, disabled durable writes, disabled NenDB
writes, NenDB-only durable direction, and SolidJS `zig-webui` workbench
direction.

Production telemetry CI gate dry-run evaluator is documented in
[production-telemetry-ci-gate-dry-run-evaluator.md](production-telemetry-ci-gate-dry-run-evaluator.md).
It emits
`zigeffect.causal.production-telemetry-ci-gate-dry-run-evaluator.v1` through
`zig build causal-production-telemetry-ci-gate-dry-run-evaluator`, consumes
ready dry-run policy artifacts and explicit bounded local or CI evidence,
records ready, advisory, or blocked evaluator findings, and hands off to the
advisory CI report branch. It preserves disabled CI gate enforcement, disabled
required status checks, disabled workflow mutation by the tool, disabled
artifact upload execution, disabled live telemetry, disabled durable writes,
disabled NenDB writes, NenDB-only durable direction, and SolidJS `zig-webui`
workbench direction.

Production telemetry CI gate advisory CI report is documented in
[production-telemetry-ci-gate-advisory-ci-report.md](production-telemetry-ci-gate-advisory-ci-report.md).
It emits
`zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report.v1` through
`zig build causal-production-telemetry-ci-gate-advisory-ci-report`, consumes
ready or advisory evaluator artifacts, records local JSON/text reviewer
guidance and publication channels, and hands off to the advisory CI report
application boundary. It preserves disabled CI gate enforcement, disabled
required status checks, disabled workflow mutation by the tool, disabled
artifact upload execution, disabled GitHub step summary writes, disabled pull
request comments, disabled live telemetry, disabled durable writes, disabled
NenDB writes, NenDB-only durable direction, and SolidJS `zig-webui` workbench
direction.

Production telemetry CI gate advisory CI report application boundary is
documented in
[production-telemetry-ci-gate-advisory-ci-report-application-boundary.md](production-telemetry-ci-gate-advisory-ci-report-application-boundary.md).
It emits
`zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report-application-boundary.v1`
through
`zig build causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary`,
consumes ready or advisory CI report artifacts, records planned, applied, or
blocked publication boundary evidence, and hands off to publication policy
work. It preserves disabled report publication by the tool, disabled CI
uploads, disabled GitHub step summary writes, disabled pull request comments,
disabled required checks, disabled workflow mutation by the tool, disabled
live telemetry, disabled durable writes, disabled NenDB writes, NenDB-only
durable direction, and SolidJS `zig-webui` workbench direction.

Production telemetry CI gate advisory CI report publication policy is
documented in
[production-telemetry-ci-gate-advisory-ci-report-publication-policy.md](production-telemetry-ci-gate-advisory-ci-report-publication-policy.md).
It emits
`zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report-publication-policy.v1`
through
`zig build causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy`,
consumes applied advisory CI report application-boundary artifacts, records
allowed and denied interpretations for externally published advisory reports,
and hands off to required-status-check readiness work. It preserves
non-blocking advisory semantics, disabled report publication by the tool,
disabled CI uploads, disabled GitHub step summary writes, disabled pull
request comments, disabled required checks, disabled workflow mutation by the
tool, disabled live telemetry, disabled durable writes, disabled NenDB writes,
NenDB-only durable direction, and SolidJS `zig-webui` workbench direction.

Production telemetry CI gate required status check readiness is documented in
[production-telemetry-ci-gate-required-status-check-readiness.md](production-telemetry-ci-gate-required-status-check-readiness.md).
It emits
`zigeffect.causal.production-telemetry-ci-gate-required-status-check-readiness.v1`
through
`zig build causal-production-telemetry-ci-gate-required-status-check-readiness`,
consumes ready advisory CI report publication-policy artifacts, records
candidate required-check profiles with activation disabled, records activation
guardrails, and hands off to required-status-check policy work after the
application-boundary milestone.
It preserves disabled required checks, disabled branch-protection mutation,
disabled GitHub API mutation, disabled workflow mutation by the tool, disabled
CI uploads, disabled live telemetry, disabled durable writes, disabled NenDB
writes, NenDB-only durable direction, and SolidJS `zig-webui` workbench
direction.

Production telemetry CI gate required status check application boundary is
documented in
[production-telemetry-ci-gate-required-status-check-application-boundary.md](production-telemetry-ci-gate-required-status-check-application-boundary.md).
It emits
`zigeffect.causal.production-telemetry-ci-gate-required-status-check-application-boundary.v1`
through
`zig build causal-production-telemetry-ci-gate-required-status-check-application-boundary`,
consumes ready required-status-check readiness artifacts, records planned,
applied, or blocked required-status-check boundary evidence, and hands off to
required-status-check policy work. It preserves disabled GitHub API mutation
by the tool, disabled branch-protection mutation by the tool, disabled
workflow mutation by the tool, disabled check-run creation by the tool,
disabled CI uploads, disabled live telemetry, disabled durable writes,
disabled NenDB writes, NenDB-only durable direction, and SolidJS `zig-webui`
workbench direction.

Production telemetry CI gate required status check policy is documented in
[production-telemetry-ci-gate-required-status-check-policy.md](production-telemetry-ci-gate-required-status-check-policy.md).
It emits
`zigeffect.causal.production-telemetry-ci-gate-required-status-check-policy.v1`
through
`zig build causal-production-telemetry-ci-gate-required-status-check-policy`,
consumes planned or externally applied required-status-check application
boundary artifacts, records planned versus applied source interpretation,
keeps `merge_blocker_claim_allowed=false`, and hands off to enforcement
readiness. It preserves disabled GitHub API mutation by the tool, disabled
branch-protection mutation by the tool, disabled workflow mutation by the tool,
disabled check-run creation by the tool, disabled CI uploads, disabled live
telemetry, disabled durable writes, disabled NenDB writes, NenDB-only durable
direction, and SolidJS `zig-webui` workbench direction.

Production telemetry CI gate required status check enforcement readiness is
documented in
[production-telemetry-ci-gate-required-status-check-enforcement-readiness.md](production-telemetry-ci-gate-required-status-check-enforcement-readiness.md).
It emits
`zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-readiness.v1`
through
`zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness`,
requires applied source policy plus explicit enforcement evidence, keeps
`active_enforcement_claim_allowed=false`,
`merge_blocker_claim_allowed=false`, and hands off to the enforcement
application-boundary branch. It preserves disabled GitHub API mutation by the
tool, disabled branch-protection mutation by the tool, disabled workflow
mutation by the tool, disabled check-run creation by the tool, disabled CI
uploads, disabled live telemetry, disabled durable writes, disabled NenDB
writes, NenDB-only durable direction, and SolidJS `zig-webui` workbench
direction.

Production telemetry CI gate required status check enforcement application
boundary is documented in
[production-telemetry-ci-gate-required-status-check-enforcement-application-boundary.md](production-telemetry-ci-gate-required-status-check-enforcement-application-boundary.md).
It emits
`zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-application-boundary.v1`
through
`zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary`,
records planned or externally applied active required-check enforcement
evidence, allows `merge_blocker_claim_allowed=true` only with explicit
merge-blocking evidence, and hands off to enforcement policy work. It
preserves disabled GitHub API mutation by the tool, disabled branch-protection
mutation by the tool, disabled workflow mutation by the tool, disabled
check-run creation by the tool, disabled CI uploads, disabled live telemetry,
disabled durable writes, disabled NenDB writes, NenDB-only durable direction,
and SolidJS `zig-webui` workbench direction.

The next branch should define enforcement interpretation policy for externally
applied required-status-check enforcement before any CI telemetry gate
enforcement, active required status checks, branch protection mutation, live
telemetry, durable production writes, capacity claims, production cluster
claims, or mutation authority are considered.

Mutation authority remains `none`. Backlog items can describe review gates and
future evidence records, but this report does not grant source, config,
deployment, rollout, app, registry, or production mutation authority.

## Verification Suite

Run the backlog report with the operating-model suite before using it to choose
the next branch:

```sh
cd packages/zigeffect
zig build causal-artifact-access-control
zig build causal-artifact-access-control -- --format json
zig build causal-unified-spine-contract
zig build causal-unified-spine-contract -- --format json
zig build causal-production-deployment-runbooks
zig build causal-production-deployment-runbooks -- --format json
zig build causal-durable-production-retention
zig build causal-durable-production-retention -- --format json
zig build causal-production-artifact-aggregation
zig build causal-production-artifact-aggregation -- --format json
zig build causal-encryption-at-rest-policy
zig build causal-encryption-at-rest-policy -- --format json
zig build causal-alerting-integrations
zig build causal-alerting-integrations -- --format json
zig build causal-live-dashboard-streaming-workbench
zig build causal-live-dashboard-streaming-workbench -- --format json
zig build causal-human-agent-feedback-loop
zig build causal-human-agent-feedback-loop -- --format json
zig build causal-rollout-automation-guardrails
zig build causal-rollout-automation-guardrails -- --format json
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
zig build causal-production-telemetry-readiness-review -- \
  --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json \
  reject \
  --reason "negative readiness path"
zig build causal-production-telemetry-implementation-proposal -- \
  --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review.json \
  approve \
  --reason "ready evidence reviewed for exporter boundary planning" \
  --verified-command "zig build causal-production-telemetry-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json approve --reason \"fixtures reviewed for implementation proposal\" --verified-command \"zig build causal-production-telemetry-capture-fixtures -- validate --format json\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
zig build causal-production-telemetry-implementation-proposal -- \
  --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review.json \
  reject \
  --reason "negative proposal path"
zig build causal-production-telemetry-exporter-boundary -- \
  --from-proposal ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal.json \
  approve \
  --reason "proposal evidence reviewed for local pipeline fixtures" \
  --verified-command "zig build causal-production-telemetry-implementation-proposal -- --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review.json approve --reason \"ready evidence reviewed for exporter boundary planning\" --verified-command \"zig build causal-production-telemetry-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json approve --reason \\\"fixtures reviewed for implementation proposal\\\" --verified-command \\\"zig build causal-production-telemetry-capture-fixtures -- validate --format json\\\" --verified-command \\\"zig build causal-schema-governance -- --format json\\\" --verified-command \\\"zig build causal-production-hardening-backlog -- --format json\\\" --verified-command \\\"zig build examples\\\" --verified-command \\\"zig build test\\\"\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
zig build causal-production-telemetry-exporter-boundary -- \
  --from-proposal ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal.json \
  reject \
  --reason "negative boundary path"
zig build causal-production-telemetry-local-pipeline-fixtures -- \
  --from-boundary ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary.json \
  approve \
  --reason "approved boundary reviewed for local pipeline fixtures" \
  --verified-command "zig build causal-production-telemetry-exporter-boundary -- --from-proposal ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal.json approve --reason \"proposal evidence reviewed for local pipeline fixtures\" --verified-command \"zig build causal-production-telemetry-implementation-proposal -- --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review.json approve --reason \\\"ready evidence reviewed for exporter boundary planning\\\" --verified-command \\\"zig build causal-production-telemetry-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json approve --reason \\\\\\\"fixtures reviewed for implementation proposal\\\\\\\" --verified-command \\\\\\\"zig build causal-production-telemetry-capture-fixtures -- validate --format json\\\\\\\" --verified-command \\\\\\\"zig build causal-schema-governance -- --format json\\\\\\\" --verified-command \\\\\\\"zig build causal-production-hardening-backlog -- --format json\\\\\\\" --verified-command \\\\\\\"zig build examples\\\\\\\" --verified-command \\\\\\\"zig build test\\\\\\\"\\\" --verified-command \\\"zig build causal-schema-governance -- --format json\\\" --verified-command \\\"zig build causal-production-hardening-backlog -- --format json\\\" --verified-command \\\"zig build examples\\\" --verified-command \\\"zig build test\\\"\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
zig build causal-production-telemetry-local-pipeline-fixtures -- \
  --from-boundary ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary.json \
  reject \
  --reason "negative local pipeline fixture path"
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
zig build causal-production-telemetry-nendb-retention-fixtures -- \
  --from-local-pipeline ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures.json \
  reject \
  --reason "negative NenDB retention fixture path"
bun run zigeffect:workbench:typecheck
bun run zigeffect:workbench:test
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
zig build causal-production-telemetry-workbench-readonly-preview -- \
  --from-retention ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures.json \
  reject \
  --reason "negative workbench preview path"
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
zig build causal-production-telemetry-ci-artifact-preview -- \
  --from-workbench ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview.json \
  reject \
  --reason "negative CI artifact preview path"
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
zig build causal-production-telemetry-ci-harness-boundary -- \
  --from-ci-preview ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview.json \
  --workflow ../../.github/workflows/zigeffect-causal.yml \
  reject \
  --reason "negative CI harness boundary path"
zig build causal-production-telemetry-ci-archive-application -- \
  --from-harness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary.json \
  plan \
  --reason "CI archive application planned from reviewed harness boundary"
zig build causal-production-telemetry-ci-archive-application -- \
  --from-harness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary.json \
  record-applied \
  --reason "negative archive application path" \
  --workflow-after ../../.github/workflows/zigeffect-causal.yml \
  --workflow-change ".github/workflows/zigeffect-causal.yml" \
  --before "source harness workflow digest" \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-archive-application-negative
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
zig build causal-production-telemetry-ci-archive-evidence-policy -- \
  --from-archive-application ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-archive-application.json \
  reject \
  --reason "negative CI archive evidence policy path" \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-archive-evidence-policy-negative
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
zig build causal-production-telemetry-ci-gate-readiness -- \
  --from-archive-evidence-policy ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-archive-evidence-policy.json \
  reject \
  --reason "negative CI gate readiness path" \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-readiness-negative
zig build causal-production-telemetry-ci-gate-application-boundary -- \
  --from-gate-readiness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-gate-readiness.json \
  plan \
  --reason "CI gate application boundary planned"
zig build causal-production-telemetry-ci-gate-application-boundary -- \
  --from-gate-readiness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-gate-readiness.json \
  record-applied \
  --reason "negative CI gate application boundary path" \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-application-boundary-negative
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
zig build causal-production-telemetry-ci-gate-dry-run-policy -- \
  --from-gate-application-boundary ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-gate-application-boundary.json \
  reject \
  --reason "negative CI gate dry-run policy path" \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-dry-run-policy-negative
zig build causal-production-telemetry-ci-gate-dry-run-evaluator -- \
  --from-dry-run-policy ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-gate-dry-run-policy.json \
  evaluate \
  --reason "CI gate dry-run evidence evaluated" \
  --evidence .zig-cache/release-gate/zigeffect-release-gate.json \
  --evidence .zig-cache/causal-artifacts/zigeffect-causal-causal-scoped-fiber.json
zig build causal-production-telemetry-ci-gate-dry-run-evaluator -- \
  --from-dry-run-policy ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-dry-run-policy-negative.json \
  evaluate \
  --reason "negative CI gate dry-run evaluator path" \
  --evidence .zig-cache/release-gate/zigeffect-release-gate.json \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-dry-run-evaluator-negative
zig build causal-production-telemetry-ci-gate-advisory-ci-report -- \
  --from-evaluator ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-gate-dry-run-evaluator.json \
  summarize \
  --reason "CI advisory report reviewed"
zig build causal-production-telemetry-ci-gate-advisory-ci-report -- \
  --from-evaluator ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-dry-run-evaluator-negative.json \
  summarize \
  --reason "negative CI advisory report path" \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-advisory-ci-report-negative
zig build causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary -- \
  --from-report ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-gate-advisory-ci-report.json \
  plan \
  --reason "CI advisory report application boundary planned"
zig build causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary -- \
  --from-report ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-advisory-ci-report-negative.json \
  record-applied \
  --reason "negative CI advisory report application boundary path" \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-advisory-ci-report-application-boundary-negative
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary -- \
  --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-readiness.json \
  plan \
  --reason "required status check enforcement application boundary planned"
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary -- \
  --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-readiness-negative.json \
  record-applied \
  --reason "negative required status check enforcement application boundary path" \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-application-boundary-negative
zig build causal-production-hardening-backlog
zig build causal-production-hardening-backlog -- --format json
zig build causal-schema-governance
zig build causal-m9-completion-audit
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```
