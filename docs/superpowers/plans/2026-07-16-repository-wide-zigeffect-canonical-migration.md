# Repository-wide canonical ZigEffect migration plan

**Design:** `docs/superpowers/specs/2026-07-16-repository-wide-zigeffect-canonical-migration.md`

## 1. Establish failing contracts

- Replace the architecture policy's numeric legacy ratchets with discovered
  package classifications and zero-debt public-source rules.
- Make the Testing v2 guard scan every tracked `build.zig` and embedded build
  template.
- Add contracts for service/effect/layer exports, one-runtime application
  roots, no manual causal wiring, and generated production composition.
- Prove the new gates fail on the current production template, imperative
  reference system, omitted test artifact, and broken Zgroach build.

## 2. Canonicalize the standard-library surface

- Delete or replace environment-parameterized application APIs in defaults,
  console, config, random, filesystem, process, HTTP, SQL, queue, pubsub,
  workspace, secrets, IDs, sink, observability, lifecycle, CLI, and agent
  modules.
- Preserve pure data APIs and move live/deterministic behavior behind stable
  tags and kernel layers.
- Update standard examples and tests to use one `zstd.ManagedRuntime`.

## 3. Canonicalize adapter packages

- HTTP and OTEL: stable tags, operation effects, scoped server/exporter layers.
- Postgres and libpq: stable session/pool tags and scoped layers.
- Redis and S3: stable client layers supplying Cache/Broker/ObjectStorage.
- Transport and PostgreSQL storage: stable client/server/store tags and scoped
  layers.
- TLS, QUIC, and ZIO: canonical provider/backend layers without selecting the
  legacy environment runtime.
- Retain direct drivers only as explicit low-level APIs below the layers.

## 4. Regenerate application architecture

- Rewrite CLI production templates with canonical layers and one managed
  runtime; align local, real, and production profiles.
- Regenerate or hand-migrate the checked-in reference system without losing
  its domain, live-conformance, statechart, or load contracts.
- Add application-map and causal-path acceptance scenarios.

## 5. Finish Ziac and Zgraphy

- Move Ziac state/provider acquisition into scoped layers and route all command
  adapters through shared effects/runtime handles.
- Replace Zgraphy's empty root layer and imperative dispatch wrapper with
  explicit command services/effects while preserving current uncommitted
  semantic, operational, and security work.
- Update manifests before marking any new requirement satisfied.

## 6. Complete Testing v2 and documentation

- Repair Zgroach and migrate the Ziac sample test artifact.
- Use exported test-runner modules in every build.
- Synchronize generated templates, contract snapshots, repository-owned agent
  skills, architecture docs, roadmaps, and package READMEs.

## 7. Verify and harden

- Run format checks and affected tests after each package slice.
- Run all package-native Debug and ReleaseSafe gates and inspect suite receipts.
- Run generated-project integration matrices and architecture/testing guards.
- Run controlled Ziac, Zgraphy, and reference-system scenarios; inspect stable
  process receipts and graph paths.
- Run root Bun checks for non-Zig boundaries.
- Review the final diff for hidden runtimes, manual causal wiring, secrets,
  stale claims, incomplete receipts, and unrelated changes.
- Commit the complete result to `master` only after the worktree is stable and
  clean.
