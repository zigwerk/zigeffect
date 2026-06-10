# zigeffect Causal Production Telemetry Readiness Review

`causal-production-telemetry-readiness-review` consumes production telemetry
capture fixture JSON and emits a reviewer-owned readiness artifact. It is a
gate between fixture examples and any future implementation proposal.

The report uses schema
`zigeffect.causal.production-telemetry-readiness-review.v1`.

## Command

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

Use `reject --reason <reason>` to produce a blocked readiness artifact.

## Boundary

The readiness artifact keeps these authority fields fixed:

- `applied=false`
- `mutation_authority="none"`
- `production_telemetry_ingestion=false`
- `live_exporter_enabled=false`
- `durable_write_enabled=false`
- `ci_gate_enabled=false`

Readiness does not enable live ingestion, exporters, OTLP sends, collector
endpoints, durable production writes, CI telemetry gates, production capacity
claims, non-NenDB adapter work, alternate renderers, or mutation authority.

## Status

- `ready`: the reviewer approved, fixture evidence passed every readiness
  check, and every required verification command was recorded.
- `blocked`: the reviewer rejected, fixture evidence failed a check, or
  required verification command evidence was missing.

`ready_for_implementation_proposal=true` means a later proposal branch may be
started. It does not mean telemetry has been implemented, deployed, or approved
for live production use.

## Checks

The readiness report evaluates:

- fixture schema and `fixtures-only` status;
- reviewer decision and reason;
- authority boundary fields;
- required source contracts;
- positive fixture coverage;
- negative fixture coverage;
- fixture validation checks;
- NenDB-only durable direction;
- SolidJS `webui-dev/zig-webui` direction;
- required verification command evidence.

## Output Paths

For this input:

```text
.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json
```

default output paths are:

```text
.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review.json
.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review.txt
```

Use `--out-prefix <path-prefix>` to choose a custom artifact prefix.

## Agent Guidance

Agents may use a `ready` report as input to
`causal-production-telemetry-implementation-proposal`. They must cite the
readiness artifact, source fixture path, check names, and verified commands.

Agents must treat `blocked` reports as stop signs. Blocked readiness can guide
fixture or design repairs, but it cannot justify implementation work.

## Verification

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_readiness_review.zig
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
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```
