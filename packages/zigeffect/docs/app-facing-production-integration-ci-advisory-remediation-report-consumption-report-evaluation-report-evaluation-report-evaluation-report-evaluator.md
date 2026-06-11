# App-Facing CI Advisory Remediation Report Consumption Report Evaluation Report Evaluation Report Evaluation Report Evaluator

`causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator` consumes a ready triple evaluation-report policy artifact plus bounded local request and support evidence. It emits read-only evaluator artifacts for agents, reviewers, advisory CI readers, and the SolidJS `webui-dev/zig-webui` workbench.

## Command

```bash
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator -- \
  --from-policy <consumption-report-evaluation-report-evaluation-report-evaluation-report-policy.json> \
  evaluate \
  --reason <reason> \
  --request <path>... \
  [--evidence <path>]...
```

Use `--out-prefix <path-prefix>` to override the default local artifact path.

## Ready Conditions

Ready output requires:

- source schema `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy.v1`
- policy decision `approve`
- policy status `ready`
- `ready_for_next_branch=true`
- `mutation_authority=none`
- triple application-boundary source refs and digest evidence
- inherited source refs, checks, summaries, policy rules, consumption scopes, denied claims, negative fixtures, and verification evidence
- at least one safe request file under `.zig-cache/causal-artifacts`
- optional support evidence under `.zig-cache/causal-artifacts`
- bounded or redacted-bounded request and evidence posture

## Boundary

This tool is advisory and record-only. It does not create required status checks, mutate workflows, call GitHub APIs, write PR comments, upload public artifacts, mutate apps, integrate with app runtime, capture raw prompts or payloads, write to Durable Objects or NenDB, execute a NenDB adapter, do Cockroach work, deploy, prove production health, create hosted dashboards, auto-apply changes, or grant mutation authority.

## Handoff

Ready evaluator artifacts may feed only the next local report summarizer branch:

`codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report`
