<p align="center">
  <img src="docs/assets/zigwerk-mark.png" width="96" alt="Zigwerk">
</p>

# ZigEffect

ZigEffect is an effectful application runtime, standard library and agent
development platform for Zig. It combines typed effects and layers with scoped
resources, deterministic testing, durable workflows, causal evidence and
production transport adapters.

ZigEffect is developed as a monorepo so its core, standard library, adapters,
CLI, reference system and documentation can evolve against one compatibility
matrix.

## Monorepo Contract

All first-party ZigEffect packages remain in this repository. That includes the
runtime, standard library, CLI, testing infrastructure, native and browser
transports, persistence adapters, observability integrations, reference system,
Workbench and project website. New first-party sister packages join this
monorepo rather than creating separate source repositories.

Source packages use local workspace dependencies and are tested together. A
release tag produces package-scoped, immutable archives with public dependency
URLs so downstream projects can install only what they need. Those archives are
distribution boundaries, not separately maintained source trees.

Consumers such as Ziac pin released ZigEffect packages and the released CLI.
They must not copy ZigEffect source or depend on a sibling checkout.

## Install The CLI

ZigEffect requires Zig `>= 0.16.0` and `< 0.17.0`. Install the latest verified
CLI source release without cloning the monorepo:

```sh
curl -fsSL https://raw.githubusercontent.com/zigwerk/zigeffect/main/install.sh | sh
```

The installer verifies the release checksum, builds the CLI in `ReleaseSafe`,
and writes `zigeffect` to `$HOME/.local/bin`. Override the version or prefix
without `sudo`:

```sh
curl -fsSL https://raw.githubusercontent.com/zigwerk/zigeffect/main/install.sh | \
  ZIGEFFECT_VERSION=0.1.5 ZIGEFFECT_INSTALL_DIR="$HOME/bin" sh
```

Create a standalone application pinned to immutable ZigEffect release
packages:

```sh
zigeffect create hello-effects
cd hello-effects
zig build test
zig build run
```

Use `--kind service`, `library`, `package`, or `system` for other project
shapes. A system starts as an independently buildable service monorepo.

Adopt an existing repository or monorepo without replacing application files:

```sh
cd my-existing-repo
zigeffect init my-workspace
```

`init` installs the shared workspace manifest and ZigEffect skills for Codex,
Claude Code, and Gemini. It discovers any nested `zigeffect.project.json`, so a
monorepo can begin with one project and split into independently checked
projects later.

## Repository

- [`packages/zigeffect`](packages/zigeffect): runtime kernel, workflows,
  statecharts, testing and causal engine
- [`packages/zigeffect-std`](packages/zigeffect-std): application-facing
  standard library
- [`packages/zigeffect-cli`](packages/zigeffect-cli): project and agent CLI
- [`packages/zigeffect-grpc`](packages/zigeffect-grpc): native gRPC and Cloud Run
  transport
- [`packages/zigeffect-http`](packages/zigeffect-http): HTTP runtime
- [`packages/zigeffect-postgres`](packages/zigeffect-postgres): Postgres effects
- [`packages/zigeffect-reference-system`](packages/zigeffect-reference-system):
  complete reference application
- [`packages/zgdb`](packages/zgdb), [`packages/zgroach`](packages/zgroach), and
  [`packages/zgraphy`](packages/zgraphy): embedded graph storage, query planning,
  and agent-facing repository intelligence
- [`apps/zigeffect-site`](apps/zigeffect-site): project website

Additional packages provide OpenTelemetry, Redis, S3, QUIC, parser, storage and
transport integrations.

## Develop The Monorepo

ZigEffect currently targets Zig 0.16.0.

```sh
bun install
bun run test:core
bun run check:frontend
```

Package-native tests produce Testing v2 receipts under each package's
`.zigeffect/tests/suites/` directory. A successful command without a complete
receipt is not release evidence.

Read the [core documentation](packages/zigeffect/README.md), the
[standard-library guide](packages/zigeffect-std/README.md), and
[`CONTRIBUTING.md`](CONTRIBUTING.md) before making broad changes.

## Performance Evidence

The current working baseline is the schema-v2 ARM64 Docker optimization
diagnostic: 11,792 RPC/s for 1 KiB unary, 96.6% of grpc-go in the same receipt,
and 13.4% higher throughput than Tonic. This is candidate engineering evidence,
not a release or Cloud Run performance promise.

Read [`packages/zigeffect-grpc/benchmarks/PERFORMANCE.md`](packages/zigeffect-grpc/benchmarks/PERFORMANCE.md)
before repeating or changing the claim. Production promotion requires a
schema-v2 receipt from committed source with native Linux amd64 evidence, the
complete 24-hour mixed-shape bounded-memory campaign, and deployed GCP
service-to-service qualification.

## Status

ZigEffect is pre-1.0. Public contracts may change with documented migration
guidance. Production claims require the qualification evidence named by the
affected package; local or credential-gated tests are reported explicitly.

## Licence

Apache-2.0. ZigEffect is a [Zigwerk](https://github.com/zigwerk) project and is
independent of the Zig Software Foundation.
