# zigeffect Tool Roadmap

This is the **human-maintained registry of approved `tools/` entries**. It is the
gate referenced by the Tool Hygiene Policy in `AGENTS.md` / `CLAUDE.md` and
enforced by `tools/check_tool_hygiene.sh`.

A `causal_*` tool may exist only if it appears below. To add a new tool:

1. Open a PR that adds a line item to the relevant section here with a one-line
   justification and an `approved:` marker.
2. A human reviewer (not an agent) adds/confirms the `approved:` marker.
3. The tool must import from or exercise `src/` — it must add runtime capability,
   not paperwork. Text-only "describe another tool's output" tools are rejected.
   The hygiene checker enforces this for new `.zig` tools unless a human adds a
   narrow `//hygiene:allow-no-runtime-import reason=<...>` marker.

There are currently **46 tools**. The cap is 60 (`check_tool_hygiene.sh`). If you
are near the cap, the answer is almost always to extend an existing tool or to
add capability under `src/`, not to add a file here.

## History

In June 2026 an autonomous "self-improving engine loop" generated ~120
near-duplicate tools (`*_level_*` counter tiers and
`*_evaluation_report_evaluation_report_*` recursion chains), each a ~1,800-line
record-only printer. `tools/` grew ~178,000 lines while runtime `src/` grew ~95.
All 120 were removed; this registry and the hygiene check exist so it cannot
recur. See [roadmap.md](roadmap.md) for the forward plan.

## Approved tools

### Core runtime harness
- `causal_run` — run a named scenario from the catalog. approved
- `causal_test` — failure-gated package-test causal harness. approved
- `causal_test_matrix` — coverage matrix across causal domains. approved
- `causal_report` — sample causal CI report. approved
- `causal_artifact` / `causal_artifacts` — artifact helpers + retention manifest. approved
- `causal_verdict` — structured dev-loop verdict JSON. approved
- `scaffold_module` — agent-friendly module scaffold generator. approved

### Agent-observable query interface
- `causal_query` — cause / lineage / resources / fibers / requirements / retries / `--agent`. approved
- `causal_compare` — before/after causal event diff. approved
- `causal_advice` — rule-based next-action advice (non-mutating). approved
- `causal_snapshot` — snapshot manifest, fork-proposal, replay-feasibility, compare. approved
- `causal_handoff` — compact CI failure handoff report. approved
- `causal_schema_governance` — registry of the official causal artifact schemas. approved
- `causal_performance_budget` — deterministic retention/sampling/truncation budgets. approved

### Causal dev loop (the self-improvement harness)
- `causal_dev_loop` — two-phase baseline→after compare/advice/verdict loop. approved
- `causal_dev_session` — coordinated local self-improvement session. approved
- `causal_dev_agent` — agent inspection-order handoff. approved
- `causal_loop` — watch-mode loop over test/compare/query/advice. approved
- `causal_diagnosis` — `*-diagnosis.txt` from a verdict. approved

### Guarded remediation chain (record-only, `mutation_authority=none`)
- `causal_remediation_plan` / `causal_remediation_audit` / `causal_remediation_decision`. approved
- `causal_patch_proposal` — non-mutating patch proposal draft. approved
- `causal_audit_chain` — deterministic before/after assessment of a proposal. approved
- `causal_policy_decision` — local self-improvement policy verdict. approved

### Scenario registry chain
- `causal_scenario_proposal` — propose scenario/invariant coverage. approved
- `causal_scenario_registry_patch` — review-draft registry patch. approved
- `causal_registry_application_readiness` / `causal_registry_apply` — guarded apply. approved

### App-facing causal trace + remediation
- `causal_app_remediation_audit` / `causal_app_policy_decision` / `causal_app_human_review`. approved
- `causal_app_patch_proposal` / `causal_app_application_readiness` / `causal_app_apply`. approved

### Workbench
- `causal_workbench` / `causal_workbench_session` — read-only SolidJS / zig-webui workbench. approved

### Workflow + cluster inspection (back real `src/workflow`, `src/cluster`)
- `workflow_list` / `workflow_replay` / `workflow_journal_inspect` / `workflow_tool_support`. approved
- `cluster_runner` / `cluster_inspect`. approved
- `storage_migrate` — SQL storage migration plan (postgresql/cockroachdb). approved
- `performance_bench` — performance benchmark runner. approved
- `release_gate_report` — release-gate pipeline report. approved

## Not approved (explicitly out of scope)

These were removed and must not return as record-only printers. If any becomes
real, it requires a `src/` implementation and a new approved entry here:

- Production-telemetry CI-gate / required-status-check contract printers.
- App-facing production-integration "evaluation report of an evaluation report" chains.
- `*_level_` numbered tier clones (eight … fourteen).
- Record-only production-hardening contracts: artifact aggregation, durable
  retention, deployment runbooks, artifact access control, unified spine,
  encryption-at-rest policy, alerting integrations, M9 completion audit, rollout
  automation guardrails, capacity planning, load-test observation, wall-clock
  benchmark baselines, human-agent feedback loop, live-dashboard streaming.
