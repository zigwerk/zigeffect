# zigeffect CLI

Local-first project generation and development orchestration for zigeffect.
The CLI writes deterministic plans produced by `zstd.Project`; it does not add
another tool under the core engine's `tools/` directory.

## Install And Completions

The supported local toolchain is Zig `>= 0.16.0` and `< 0.17.0`:

```sh
zig build test
zig build install --prefix "$HOME/.local"
"$HOME/.local/bin/zigeffect" --version
zigeffect completions zsh > "$HOME/.zfunc/_zigeffect"
```

`completions` also supports `bash` and `fish`. The generated scripts are
deterministic and include every top-level command.

## Build And Test

```sh
zig build
zig build test
zig build integration-test
```

The integration gate generates application, service, library, package, and
system projects in isolated directories. Every root runs in Debug and
ReleaseSafe. A generated system's API service, worker service, and shared
package are also tested independently.

## Generate

```sh
zig build run -- new application my-app \
  --target ../../my-app \
  --zigeffect-path ../zigeffect \
  --zigeffect-std-path ../zigeffect-std
```

Supported kinds are `application`, `service`, `library`, `package`, and
`system`. Use `--dry-run` to inspect the complete sorted file plan and `--json`
for a stable receipt. Existing non-empty targets are refused by default.
`--force` replaces only paths declared by the plan and preserves unrelated
files. Files are written through sibling temporary files and renamed into
place.

Generated applications and services include typed Config/Schema and CLI
boundaries, local HTTP and SQL fakes, an effect-native service and layer, causal
evidence, workbench attachment metadata, deterministic tests, the project
manifest, and matching Codex/Claude skills. Libraries and packages expose a
tested effect-native public facade. Systems contain two independently buildable
services and a shared package.

Every generated manifest defaults to `agent_safe_v1` and declares source-policy,
Debug, ReleaseSafe, allocation/leak, causal, schedule, and executor-equivalence
gates plus explicit optional sanitizer/stack-protection/fuzz capabilities. Dependency paths are explicit relative paths so
the generated project stays portable and does not persist machine-specific
absolute locations.

Every scaffold also commits `.zigeffect/compatibility.json` and a SHA-256
`.zigeffect/scaffold-state.json`. Inspect or upgrade the local contract with:

```sh
zigeffect compatibility --root ./my-app --json
zigeffect upgrade --root ./my-app --dry-run --json
zigeffect upgrade --root ./my-app --apply --json
```

Upgrade is dry-run by default. It preserves source, tests, READMEs, build files,
requirements, and unrelated files. Only CLI-owned compatibility and agent-skill
files are eligible for replacement, and an edited managed file refuses the
entire apply with exit code `3`. Legacy `zigeffect.project.v0` manifests migrate
to v1 through the same preflight. State written by a newer CLI or template is
rejected rather than silently downgraded.

## Manage A Project

```sh
zigeffect add service payments --root ./my-system
zigeffect add package shared-events --root ./my-system
zigeffect generate schema invoice --component api-service --root ./my-system
zigeffect project validate --root ./my-system --json
zigeffect project doctor --root ./my-system --json
zigeffect project check --root ./my-system --json
zigeffect project check --agent --root ./my-system --json
zigeffect safety explain <finding-id> --root ./my-system
zigeffect safety baseline --root ./my-system
```

`add` atomically updates a validated system manifest and writes an independently
buildable child. `generate` accepts only the seven declared module kinds and a
manifest component id. Project execution selects fixed command ids from the
manifest; there is no arbitrary command or passthrough argv option. Check, test,
and dev output is bounded and redacted, with receipts persisted under
`.zigeffect/receipts`. Dev also writes `.zigeffect/workbench.json` for local
attachment.

The agent check joins AST-based governed-construct policy with bounded raw Zig
compiler artifacts and writes a source-revision/toolchain-linked safety receipt.
Required unsupported or truncated evidence is incomplete, never passed.

Score a provider/language fixture without provider credentials or network use:

```sh
zigeffect benchmark score benchmarks/fixture.json --root ./my-system --json
```

Scores are limited to the supplied bounded fixture and explicitly do not prove
general language or provider superiority.

Gate the complete offline Codex/Claude lifecycle matrix:

```sh
zigeffect benchmark conformance \
  packages/zigeffect/benchmarks/fixtures/provider-conformance.v1.json \
  --root . --json
```

The gate covers success, repair, failure, cancellation, approval, bounded large
output, and recovery. It exits non-zero when the provider/scenario matrix is
incomplete or any lifecycle fails. It remains fixture evidence, not a model
quality claim.

Real-provider runs are opt-in: configure a fixed manifest command, create
`.zigeffect/provider-benchmarks.enabled`, and invoke `benchmark run --provider
<id> --command <manifest-id>`. No provider command or network access runs in CI.
Executed output is bounded, redacted, and persisted as a provider receipt; an
uninstalled provider executable yields an explicit unavailable result.

## Agent Protocol

```sh
zigeffect agent status --root ./my-system --json
zigeffect agent requirements --root ./my-system --jsonl
zigeffect agent checks --root ./my-system --jsonl
zigeffect agent evidence --root ./my-system --jsonl
zigeffect agent next --root ./my-system --json
zigeffect agent handoff --provider codex --session local-42 --root ./my-system
```

The versioned provider-neutral protocol maps requirements to tasks, acceptance
state, bounded artifact/causal evidence, and next actions. Handoffs reject
secret-shaped values and persist to `.zigeffect/handoffs/latest.json`. Codex,
Claude Code, local tools, and the workbench consume the same contract.

Generated applications and services emit `zstd.Application` facts for config,
Schema, CLI, HTTP, SQL, external calls, artifacts, component dependencies, and
acceptance evaluation. These facts use stable labels and references so agents
and the workbench can compare application intent across executor-specific event
ids and ordering.

The version matrix, ownership rules, snapshot contract, and complete release
gate are documented in `packages/zigeffect/docs/compatibility.md`.
