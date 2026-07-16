# ZigEffect local compatibility

This contract covers local development with the checked-in packages. It does
not require a hosted service.

| Surface | Supported contract |
|---|---|
| Zig | `>= 0.16.0`, `< 0.17.0` |
| zigeffect CLI | `0.7.0` |
| project manifest | `zigeffect.project.v1` |
| scaffold template | `zigeffect.scaffold-template.v1`, version `10` |
| core API | `0.1.x` |
| zigeffect-std API | `0.1.x` |
| local causal graph | `zigeffect.causal.local-graph-record.v1` under the manifest-owned graph path |
| local adapters | zio `0.14.0`; checked-in Postgres and QUIC package locks |
| workbench protocol | checked-in TypeScript schemas and collector tests |

## Inspect

```sh
zigeffect --version
zigeffect compatibility --json
```

Every new scaffold commits `.zigeffect/compatibility.json` and
`.zigeffect/scaffold-state.json`. The first states the Zig, CLI, project-schema,
template, core, and stdlib ranges. The second stores SHA-256 hashes only for
CLI-owned compatibility and agent-skill files. Application source, tests,
README files, build files, and project requirements remain user-owned.

## Upgrade

```sh
zigeffect upgrade --dry-run --json
zigeffect upgrade --apply --json
```

Dry-run is the default. A pristine older scaffold without state can be adopted,
and `zigeffect.project.v0` is migrated to `zigeffect.project.v1`. Apply preserves
all user-owned files. If a CLI-owned file differs from its recorded hash, the
entire apply is refused with exit code `3`; the conflict must be reconciled
explicitly. There is no recursive deletion and no arbitrary rewrite boundary.
An older CLI also fails closed when state declares a newer CLI or scaffold
template version; install the required CLI before planning that upgrade.

The five generated project kinds are pinned by
`packages/zigeffect-cli/src/snapshots/scaffold-contracts.v1.json`. Template
changes must intentionally update the versioned SHA-256 snapshot and continue
to pass real Debug and ReleaseSafe generated-project builds.

Template version `2` added `causal_graph` to executable component capabilities
and `.zigeffect/graph` to manifest artifact paths. Existing version-1 manifests
remain parseable because the artifact field has a default. System graph
inspection requires a manifest component id:

```sh
zigeffect graph status --root ./system --component api-service --json
```

Template version `10` makes `zstd.ManagedRuntime` the canonical application and
service root. It automatically owns the memory recorder, an embedded Zig 0.16
port of NenDB's data-oriented topology, the crash-safe property WAL, agent map,
and checked shutdown. Generated libraries export effects and default layers
instead of creating hidden runtimes. `zigeffect graph since <id> --limit <n>
--json` provides bounded before/after evidence. NenDB requires no daemon or
Docker image; exact upstream provenance is reported in runtime health.

Template version `11` makes the generated acceptance scenario execute the real
root layer through that managed runtime using the `TestContext` causal store.
Its receipt maps assertion references to durable graph IDs, fresh graph
status/since queries return a read-only zero baseline, and application-map v2
joins live topology to validated manifest intent and exact agent commands.

Template version `5` makes Testing v2 the default compiler-test harness. Every
generated test artifact obtains `zigeffect_test_runner` transitively from
`zigeffect_std` and writes a complete suite receipt under
`.zigeffect/tests/suites/`; no extra application dependency is required.

Template version `9` moved local application, service, library, and generated
service/layer modules to canonical service tags, fluent effects and layers, one
named root program, one managed runtime, and runtime-owned application
inspection. The production profile retains a documented HTTP/Postgres/OTLP
compatibility bridge until those adapters publish canonical kernel layers.

## Install

```sh
cd packages/zigeffect-cli
zig build test
zig build install --prefix "$HOME/.local"
"$HOME/.local/bin/zigeffect" --version
```

Generate shell completions from the installed binary:

```sh
zigeffect completions zsh > "$HOME/.zfunc/_zigeffect"
zigeffect completions bash > "$HOME/.local/share/bash-completion/completions/zigeffect"
zigeffect completions fish > "$HOME/.config/fish/completions/zigeffect.fish"
```

Run the complete local release proof from the repository root:

```sh
bun run zigeffect:local-release
```

That command stage-installs the CLI, checks completion output and the 14-case
provider matrix, builds every generated scaffold, and runs stdlib, core Debug
and ReleaseSafe, public API, core release, Postgres, QUIC, zio, Workbench,
redaction, documentation-honesty, and tool-hygiene gates.
