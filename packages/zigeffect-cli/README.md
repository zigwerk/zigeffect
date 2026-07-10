# zigeffect CLI

Local-first project generation and development orchestration for zigeffect.
The CLI writes deterministic plans produced by `zstd.Project`; it does not add
another tool under the core engine's `tools/` directory.

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
Debug, and ReleaseSafe gates. Dependency paths are explicit relative paths so
the generated project stays portable and does not persist machine-specific
absolute locations.
