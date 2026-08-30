# ZigEffect CLI Bootstrap Implementation Plan

**Design:** `docs/superpowers/specs/2026-08-30-zigeffect-cli-bootstrap-design.md`

## 1. Complete The Source Monorepo

- [ ] Import the history and current source for `zgdb`, `zgroach`, and
  `zgraphy` from Yachdee.
- [ ] Add the packages to release ordering after their dependencies.
- [ ] Update repository documentation and package-boundary tests.

## 2. Define Release-Backed Project Dependencies

- [ ] Add backward-compatible path/release dependency metadata to
  `zigeffect_std.Project` with validation tests first.
- [ ] Add the generated CLI release catalog placeholder and package lookup.
- [ ] Teach scaffold rendering to emit either local `.path` dependencies or
  immutable `.url` and `.hash` dependencies.
- [ ] Preserve dependency mode through `add` and `upgrade`.

## 3. Add Friendly CLI Commands

- [ ] Add failing parser tests for `create` and `init`.
- [ ] Implement `create <name>` as the released-package experience while
  preserving `new` as the local-path command.
- [ ] Implement non-destructive workspace initialization and idempotence.
- [ ] Add `create` and `init` to Bash, Zsh, and Fish completions and help.

## 4. Ship The Installer

- [ ] Add shell tests using local release fixtures and a fake Zig executable.
- [ ] Implement `install.sh` with release selection, SHA-256 verification,
  temporary-directory cleanup, and prefix support.
- [ ] Extend release packaging to embed the generated catalog in the staged CLI
  archive.
- [ ] Extend release CI with installer and clean-create qualification.

## 5. Document And Qualify

- [ ] Put installation, `init`, `create`, and monorepo examples at the top of
  the public README.
- [ ] Update the CLI README with the low-level `new` distinction.
- [ ] Run CLI Testing v2 tests, generated-project integration tests, release
  package tests, installer tests, tool hygiene, and migration checks.
- [ ] Qualify from a clean clone without Yachdee or sibling ZigEffect paths.
- [ ] Publish a new immutable ZigEffect release and verify the public curl
  journey.

