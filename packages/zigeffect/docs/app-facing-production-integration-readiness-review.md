# App-Facing Production Integration Readiness Review

`causal-app-facing-production-integration-readiness-review` emits
`zigeffect.causal.app-facing-production-integration-readiness-review.v1` as a
record-only review artifact over app-facing production integration fixture
JSON.

It is the gate between deterministic fixtures and implementation-proposal work.
`readiness_status=ready` means a future proposal branch may start. It does not
mean app changes were applied, production telemetry was enabled, durable writes
exist, CI gates are active, or production app health was proven.

## Command

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-fixtures -- --format json 2> ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures.json
zig build causal-app-facing-production-integration-readiness-review -- \
  --from-fixtures ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures.json \
  approve \
  --reason "fixtures reviewed for implementation proposal" \
  --verified-command "zig build causal-app-facing-production-integration-fixtures -- validate --format json" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

The command writes:

- `<fixtures-base>-readiness-review.json`;
- `<fixtures-base>-readiness-review.txt`.

Use `--out-prefix <path-prefix>` to choose a different output path. A reject
review is also useful:

```sh
zig build causal-app-facing-production-integration-readiness-review -- \
  --from-fixtures ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures.json \
  reject \
  --reason "negative readiness path" \
  --out-prefix ../../.zig-cache/causal-artifacts/app-facing-production-integration-readiness-review-negative
```

## Required Evidence

Ready reviews require these exact verification commands to be recorded:

```sh
zig build causal-app-facing-production-integration-fixtures -- validate --format json
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
```

The review tool records evidence that a reviewer ran them. It does not run the
commands itself.

## Readiness Checks

The report evaluates:

- fixture schema and `fixtures-only` status;
- reviewer decision and reason;
- `applied=false` and `mutation_authority=none`;
- disabled live telemetry, exporter, durable write, app mutation, and CI flags;
- required source contracts;
- required positive fixture ids and integration surfaces;
- required negative fixture ids;
- all fixture validation checks;
- NenDB-only durable direction and Cockroach exclusion;
- app mutation state disabled for every positive fixture;
- telemetry transport and durable write state disabled for every positive
  fixture;
- SolidJS inside `webui-dev/zig-webui` by blocking React or alternate renderer
  work;
- exact required verification command evidence.

## Boundaries

Every readiness-review artifact keeps:

- `applied=false`;
- `mutation_authority="none"`;
- `production_telemetry_ingestion=false`;
- `live_exporter_enabled=false`;
- `durable_write_enabled=false`;
- `app_mutation_enabled=false`;
- `ci_gate_enabled=false`.

Durable direction remains NenDB adapter only. Cockroach adapter work is out of
scope for this milestone.

## Ready And Blocked

`ready_for_implementation_proposal=true` means the next branch may be:

`codex/zigeffect-causal-app-facing-production-integration-implementation-proposal`

`blocked` means agents should cite the failed checks and repair fixture,
verification, or boundary evidence first.

Neither status grants app mutation, live telemetry ingestion, exporter setup,
durable production writes, CI enforcement, production workbench hosting,
Cockroach adapter work, or alternate renderer work.
