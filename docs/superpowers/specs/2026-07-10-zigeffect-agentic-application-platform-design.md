# zigeffect Agentic Application Platform Design

Date: 2026-07-10

## Goal

Turn zigeffect into the application-development engine that Codex, Claude Code,
and human Zig developers can reliably build on. A requirements prompt should
lead to a conventional, compiling zigeffect project whose services, effects,
layers, schemas, commands, HTTP/SQL boundaries, tests, causal facts, and local
workbench attachment are already structured for agent inspection.

This is local-first productization. It does not require hosting, a remote
control plane, or a distributed deployment platform.

## Product Principle

The agent runner is infrastructure, not the product. The product is a Zig
framework that makes software development more legible and verifiable:

1. Requirements become a typed project contract and acceptance checks.
2. Agents create code through stable zigeffect conventions and generators.
3. Build, test, run, and tool activity emits structured causal evidence.
4. Agents query that evidence instead of reconstructing failures from logs.
5. Humans inspect the same session in the workbench.
6. Every iteration leaves a redacted, replayable handoff receipt.

## Existing Baseline

The repository already has the runtime, standard library, causal engine,
workbench, local agent supervisors, and an M72-M87 operator path. It also has a
text-only `scaffold_module` tool. That tool deliberately does not write files,
does not update a build graph, and does not generate compiling projects. The new
platform supersedes that limitation without adding another tool under
`packages/zigeffect/tools`.

## Package Boundaries

### `zstd.Project`

Add `Project` to `packages/zigeffect-std/src/root.zig`. It owns pure,
deterministic application-development contracts:

- `Manifest` and component kinds;
- requirement and acceptance-check records;
- feature/capability selection;
- validated Zig/package identifiers;
- deterministic generated-file plans;
- scaffold and verification receipts;
- manifest JSON encoding/decoding;
- path-safety and overwrite decisions; and
- template rendering for applications, services, libraries, shared packages,
  and multi-service systems.

It does not directly own the process environment or mutate the host filesystem.
Unit tests can therefore generate complete projects into memory.

### `packages/zigeffect-cli`

Create a dedicated Zig package and installable `zigeffect` executable. It
imports `zigeffect-std`, uses `zstd.Project`, and owns:

- argument parsing and help;
- local filesystem writes and directory creation;
- dry-run, JSON output, conflict, and force behavior;
- local dependency path discovery/overrides;
- project/component generation;
- project validation, doctor, build, test, and dev orchestration;
- agent/workbench launch handoff; and
- redacted causal development receipts.

This package is outside the core tool-count policy and still exercises runtime
and stdlib symbols through its normal build graph.

### Agent Skills

Commit matching repository skills for both agent families:

- `.agents/skills/zigeffect-development/SKILL.md` for Codex;
- `.claude/skills/zigeffect-development/SKILL.md` for Claude Code.

The CLI also installs project-local versions containing the generated project
manifest, commands, boundaries, and workflow. Skills teach agents to inspect
requirements first, use public imports, run project gates, query causal
artifacts, respect policy/approval boundaries, and update receipts before
handoff. They must not contain secrets or machine-specific absolute paths.

## Project Contract

Every generated root contains `zigeffect.project.json` with schema
`zigeffect.project.v1`. The manifest records:

- project name, kind, and version;
- component names, kinds, paths, and dependencies;
- selected capabilities (`cli`, `http`, `sql`, `config`, `observability`,
  `agent`, `workbench`);
- canonical build/test/dev/doctor commands;
- requirements and acceptance checks;
- causal artifact/session paths;
- local policy posture; and
- dependency mode and zigeffect package paths.

Unknown schema versions fail closed. Names and paths are validated before a
file plan exists. Components cannot escape the project root or collide after
normalization.

## Scaffold Kinds

### Application

A single executable application with:

- `build.zig` and `build.zig.zon`;
- `src/main.zig`, `src/app.zig`, and `src/services/`;
- typed Config and Schema boundary;
- typed CLI command;
- local HTTP health route;
- SQL contract/fake boundary;
- service/layer wiring;
- deterministic tests and fixtures;
- causal recorder/session output;
- workbench/local-agent commands; and
- agent guidance and project manifest.

### Service

An independently runnable microservice with application startup, typed config,
HTTP routes, service/layer/effect files, tests, causal health facts, and an
explicit public contract. It is independently buildable and does not assume a
network deployment platform.

### Library

A reusable Zig module with public facade, internal implementation, typed errors,
tests, fixtures, and no process entry point.

### Shared Package

A versioned package intended for multiple applications/services. It includes a
public module, package metadata, compatibility tests, changelog/API guidance,
and dependency rules that prevent importing application internals.

### System

A local multi-component workspace with two independently runnable services and
a shared package. The root manifest owns component dependencies and aggregate
commands. Each child remains independently buildable; the root does not hide
failures behind a monolithic script.

## Generator Safety

- Default behavior refuses a non-empty target.
- `--force` may replace only files declared by the generated plan; it never
  recursively deletes a directory.
- `--dry-run` performs validation and prints the complete plan without writing.
- `--json` emits a stable redacted receipt.
- Writes create parents and use sibling temporary files plus rename where the
  platform permits.
- Every path is relative, normalized, and checked against traversal.
- Generated manifests never persist bearer tokens, connection URLs with
  credentials, or arbitrary inherited environment values.
- CLI command execution is selected from manifest-owned command IDs, not HTTP
  or agent-supplied arbitrary argv.

## Improved M88-M95 Roadmap

### M88 - Agentic Project Contract And Skills

Deliver `zstd.Project` manifest/types/validation/JSON, deterministic file-plan
primitives, requirements and acceptance contracts, plus Codex/Claude skills.
Acceptance requires malformed versions/names/paths/dependencies to fail closed
and all manifest/receipt fields to pass sentinel-secret tests.

### M89 - Production Application Scaffold CLI

Deliver `packages/zigeffect-cli` and real `new application|service|library|
package|system` commands. All kinds support dry-run, JSON receipts, path
overrides, conflict refusal, and bounded force behavior. Integration tests write
every scaffold to a temporary workspace and compile/test it.

### M90 - Instrumented Project Manager

Deliver `add service|library|package`, `generate service|layer|schema|cli|http|
sql|test`, and `project show|validate|doctor|check|test|dev` commands. Commands
operate from the manifest, emit local dev-session/causal receipts, and never
accept hidden arbitrary command lines.

### M91 - Agent Development Protocol

Deliver machine-readable requirement/task/acceptance/handoff schemas and CLI
queries. Agents can ask what to build, what failed, which service/layer is
missing, what causal evidence supports a finding, and which acceptance checks
remain. JSON/JSONL contracts are stable and provider-neutral.

### M92 - Causal Application SDK

Add semantic application facts for request handling, schema decode, config
load, command execution, SQL transaction, external call, artifact production,
acceptance evaluation, and component dependency state. Generated projects use
these helpers by default so causal graphs describe application intent rather
than only low-level fibers/resources.

### M93 - Workbench Application Development UX

Render project requirements, components, dependencies, tasks, commands,
acceptance checks, artifacts, source-change receipts, agent activity, and
application causal facts as one development session. Add project/session
filtering, component graph focus, artifact inspection, comparison, recovery,
and explicit approval states.

### M94 - Provider Conformance And Benchmarks

Create deterministic Codex/Claude transcript fixtures plus opt-in real local
provider runs against the same application requirements. Score compile/test
success, acceptance coverage, repair iterations, causal-query use, secret
posture, and handoff completeness. CI stays network-free; real runs are local
and emit comparable receipts.

### M95 - Local Distribution And Compatibility

Deliver install artifacts, version output, shell completions, compatibility
matrix, upgrade/migration checks, scaffold snapshots, public API gates, and a
single local release gate. Generated projects state their Zig/zigeffect/std/CLI
compatibility and can be upgraded without silent rewrites.

## Verification Strategy

Each milestone follows red/green tests and lands independently. The final gate
must include:

- core, stdlib, CLI, Postgres, and workbench tests;
- generated-project compilation for every scaffold kind;
- deterministic snapshot and manifest compatibility tests;
- sentinel-secret and path-traversal property cases;
- real local filesystem and process smoke tests;
- browser proof for the M93 project-development flow;
- provider-neutral offline conformance fixtures;
- `git diff --check` and existing tool hygiene; and
- roadmap/docs contradiction scans.

## Non-Goals

- No hosted project service or remote control plane.
- No mandatory cloud, container, Kubernetes, or multi-node deployment.
- No arbitrary source mutation endpoint.
- No provider-specific private transcript scraping.
- No generated domain behavior that pretends to satisfy user requirements.
- No replacement of Zig's build system or package manager.
