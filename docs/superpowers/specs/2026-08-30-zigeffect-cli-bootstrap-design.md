# ZigEffect CLI Bootstrap Design

**Status:** Accepted for implementation

## Problem

ZigEffect has a capable scaffold engine, but the public repository presents it
as a source package. A developer cannot discover one installation command and
then create or adopt a project using only released artifacts. The existing
`new` command also generates monorepo-relative dependency paths, so a globally
installed CLI cannot produce a portable standalone project by default.

The extraction additionally omitted `zgraphy`, `zgdb`, and `zgroach` even
though generated acceptance tests import `zgraphy`. A clean public release must
own every first-party package required by its generated output.

The same rule applies to adapter families. The ignored Yachdee
`packages/zigeffect-http-tls-zigtls` directory contained only an upstream Zig
package cache, not adapter source. The standalone monorepo therefore owns a
real `zigeffect-http-tls-zigtls` package that implements the public HTTP TLS
provider contract against an immutable upstream ZigTLS release. See
`2026-08-30-zigeffect-extraction-completeness-design.md`.

## Product Contract

### Installation

The supported Unix bootstrap is:

```sh
curl -fsSL https://raw.githubusercontent.com/zigwerk/zigeffect/main/install.sh | sh
```

The installer:

- supports macOS and Linux without `sudo`;
- requires a compatible Zig toolchain and reports the required range;
- resolves the latest release unless `ZIGEFFECT_VERSION` is set;
- downloads `manifest.tsv` and the versioned CLI source archive;
- verifies the archive SHA-256 before extraction;
- builds the CLI in `ReleaseSafe` and installs it under
  `${ZIGEFFECT_INSTALL_DIR:-$HOME/.local}`;
- never executes an unverified downloaded binary;
- prints the PATH and completion commands needed by the active shell.

Building the verified source archive is the initial portability boundary. A
later release may add signed native binaries without changing the command.

### `zigeffect create`

`zigeffect create <name>` creates an application by default. `--kind` selects
`application`, `service`, `library`, `package`, or `system`; the existing
profile, target, dry-run, JSON, and force controls remain available.

Unlike `new`, `create` uses the release catalog embedded in the released CLI.
Generated `build.zig.zon` files contain immutable GitHub release URLs and Zig
package hashes. The matching package provenance is persisted in
`zigeffect.project.json`, allowing `add`, `upgrade`, and agent tooling to retain
the same dependency source.

`new` remains the contributor and advanced command. It continues to accept
explicit local `--zigeffect-path` and `--zigeffect-std-path` values.

### `zigeffect init`

`zigeffect init [name] [--root <path>]` adopts an existing repository. It does
not generate application source or replace root build files. It writes only:

- `zigeffect.workspace.json`, a versioned workspace manifest;
- `.zigeffect/workspace.json`, deterministic local tooling metadata;
- ZigEffect development skills for Codex, Claude Code, and Gemini;
- `.zigeffect/.gitignore` for runtime evidence and caches.

The workspace manifest discovers `zigeffect.project.json` recursively while
excluding VCS, dependency, cache, and build-output directories. A monorepo may
therefore contain one project or many independently deployable projects. A
future project can be added with `create --target <subdirectory>` or adopted
independently.

Initialization refuses conflicting managed files. Re-running the same version
is idempotent. `--dry-run`, `--json`, and `--force` follow the scaffold writer's
existing bounded semantics.

### Monorepo Ownership

The ZigEffect source monorepo owns core, stdlib, CLI, adapters, `zgdb`,
`zgroach`, and `zgraphy`. Release packaging emits each Zig package as an
immutable package-scoped archive while preserving one source and compatibility
matrix.

## Release Catalog

The development checkout carries a catalog placeholder that deliberately
cannot service `create`. During release packaging, the staged CLI package is
given a generated catalog containing:

- release version;
- package name;
- immutable release URL;
- Zig package hash;
- archive SHA-256.

The CLI archive is packaged after all runtime and scaffold dependencies, so the
catalog is complete before its own archive is hashed. The catalog is also
represented in `manifest.tsv` for installer verification.

Project dependency metadata remains backward compatible. Existing path-based
manifests parse as before; release-backed manifests add an explicit mode and
package pins. Validation rejects mixed, incomplete, mutable, or non-Zigwerk
release references.

## Safety And Failure Semantics

- Installation fails closed on missing tools, unsupported Zig versions,
  download errors, checksum mismatches, or compilation failure.
- `create` fails clearly when run from an unreleased development CLI without
  explicit local paths.
- `init` never infers authority to rewrite application files.
- Generated dependency URLs and hashes are data from the release process, not
  user-provided executable command text.
- Shell tests use local fixture archives and a fake Zig executable; they do not
  depend on GitHub availability.

## Verification

1. CLI parser and writer tests cover `create`, `init`, aliases, conflicts,
   idempotence, JSON receipts, and completions.
2. Generated release-backed application and system projects build from an
   isolated directory with no sibling source checkout.
3. Package release tests assert all first-party package archives and a fully
   populated staged CLI catalog.
4. Installer tests verify checksum success, mismatch refusal, version
   selection, prefix selection, and a fake source build.
5. A clean-clone E2E installs the CLI, runs `init`, runs `create`, and builds the
   generated application.
