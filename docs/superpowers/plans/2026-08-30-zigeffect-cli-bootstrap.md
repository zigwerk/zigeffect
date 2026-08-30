# ZigEffect CLI Bootstrap Implementation Plan

**Design:** `docs/superpowers/specs/2026-08-30-zigeffect-cli-bootstrap-design.md`

**Status:** Shipped in `v0.1.5` on 2026-08-30. The release workflow proved the
public installer, standalone scaffold, hosted dependency fetch, and generated
application test build on cold Linux.

## 1. Complete The Source Monorepo

- [x] Import the history and current source for `zgdb`, `zgroach`, and
  `zgraphy` from Yachdee.
- [x] Add the packages to release ordering after their dependencies.
- [x] Update repository documentation and package-boundary tests.

## 2. Define Release-Backed Project Dependencies

- [x] Add backward-compatible path/release dependency metadata to
  `zigeffect_std.Project` with validation tests first.
- [x] Add the generated CLI release catalog placeholder and package lookup.
- [x] Teach scaffold rendering to emit either local `.path` dependencies or
  immutable `.url` and `.hash` dependencies.
- [x] Preserve dependency mode through `add` and `upgrade`.

## 3. Add Friendly CLI Commands

- [x] Add failing parser tests for `create` and `init`.
- [x] Implement `create <name>` as the released-package experience while
  preserving `new` as the local-path command.
- [x] Implement non-destructive workspace initialization and idempotence.
- [x] Add `create` and `init` to Bash, Zsh, and Fish completions and help.

## 4. Ship The Installer

- [x] Add shell tests using local release fixtures and a fake Zig executable.
- [x] Implement `install.sh` with release selection, SHA-256 verification,
  temporary-directory cleanup, and prefix support.
- [x] Extend release packaging to embed the generated catalog in the staged CLI
  archive.
- [x] Extend release CI with installer and clean-create qualification.

## 5. Document And Qualify

- [x] Put installation, `init`, `create`, and monorepo examples at the top of
  the public README.
- [x] Update the CLI README with the low-level `new` distinction.
- [x] Run CLI Testing v2 tests, generated-project integration tests, release
  package tests, installer tests, tool hygiene, and migration checks.
- [x] Qualify from a clean clone without Yachdee or sibling ZigEffect paths.
- [x] Publish a new immutable ZigEffect release and verify the public curl
  journey.
