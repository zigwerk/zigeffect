---
name: zigeffect-development
description: Build, change, debug, test, or review this ZigEffect application through zigeffect.project.json, public zigeffect_std APIs, zstd.Testing scenarios, causal evidence, deterministic replay, semantic snapshots, and evidence-backed agent handoffs.
---

# ZigEffect Development

Treat the manifest and structured evidence as the source of truth. Terminal
text is a bounded diagnostic artifact, not proof that a requirement passed.

## Run the proof-carrying causal loop

1. Orient with `zigeffect agent context --task <id-or-summary> --budget
   65536 --json`. Retain its source identity, manifest digest, graph cursor,
   authority, omissions, affected scenarios, and proof references.
2. Bind the request to a requirement, acceptance check, component, fixed
   command, and scenario. State the expected before/action/after causal path
   and the slice that must remain unchanged.
3. If a coordinator supplies a work packet, obey its baseline, allowed and
   excluded paths, dependencies, verification commands, graph cursor,
   lease, and fencing token. Never invent missing coordination or authority.
4. Add the failing deterministic native scenario, then make the smallest
   typed service/layer change through the one managed runtime.
5. Run the affected scenario. Treat
   `.zigeffect/tests/process-receipts/<scenario>.json` and
   `.zigeffect/handoffs/tests/<scenario>.json` as authoritative only when
   source, manifest, command, toolchain, and completeness identities match.
   `.zigeffect/tests/raw-receipts/` and terminal output are diagnostic only.
6. Compare `zigeffect graph since <cursor> --limit 256 --json` with the
   counterfactual and use `zigeffect graph path <from> <to> --limit 128
   --json` for exact relationships.
7. Re-query `agent context` after the change. Reject stale proof,
   undeclared or overlapping paths, expired fencing tokens, missing
   dependency proof, and required gaps before integration.
8. Run project gates and hand off exact receipt/proof paths, replay
   commands, causal IDs, limitations, and remaining authority requirements.

## Establish intent

1. Run `zigeffect compatibility --json`, read `zigeffect.project.json`, and
   inspect migrations with `zigeffect upgrade --dry-run --json`. Never work
   around a conflict or unsupported manifest.
2. Run:

       zigeffect project validate --json
       zigeffect agent status --json
       zigeffect agent next --json
       zigeffect test list --json

3. Map the request to a requirement, acceptance check, component,
   manifest-owned command, and one or more `test_scenarios`. Declare missing
   intent before implementing behavior.
4. Read the component's public facade, layers, schemas, tests, and causal
   helpers. Use public `zigeffect_std` APIs; never import another component's
   internals.

## Implement inspectable behavior

- Model fallible boundaries with typed effects, service layers, Schema,
  typed errors, scoped resources, and deterministic providers for config,
  clock, filesystem, process, HTTP, SQL, IDs, logging, and tracing.
- Define stable tags with `zstd.fx.kernel.Service`, operations with
  `zstd.fx.kernel.Effect`, and implementations with canonical layers.
  Compose one named root program and interpret it through one
  `zstd.ManagedRuntime`. It automatically owns the in-memory recorder,
  embedded NenDB topology, durable property WAL, and checked shutdown.
  Application code never calls `runIn`, `ctx.runEffect`, `layerGraph`,
  manually attaches a causal backend, or uses environment-parameterized
  effects.
- Application acceptance tests pass `context.causalStore()` only to the
  one root `zstd.ManagedRuntime`, assert the real execution, call
  `context.mapCausalEventIds(&runtime)` while it is live, then shut down
  and publish. Mount the runtime at the owning project or component root and
  query at least one mapped ID through the project-mounted graph before
  publishing. Do not create a synthetic receipt beside a detached graph.
- Use `zigeffect add` and `zigeffect generate` before hand-writing framework
  structure.
- Emit semantic facts at external, workflow, statechart, artifact, and
  acceptance boundaries. Use typed statecharts for inspectable long-lived
  control flow and durable statecharts for replayable workflows.
- Never put credentials, personal data, or raw terminal scrollback in
  manifests, facts, receipts, fixtures, snapshots, or Workbench payloads.

## Test requirements with `zstd.Testing`

Add a failing deterministic test before changing behavior. Register its
scenario in `test_scenarios` with a requirement, acceptance check, component,
command, source roots, stable seed, fault profile, and required status.

    const std = @import("std");
    const zstd = @import("zigeffect_std");

    var context = try zstd.Testing.TestContext.initFromProject(std.testing.allocator, std.testing.io, std.Io.Dir.cwd(), .{
        .project = "app",
        .suite = "acceptance",
        .scenario = scenario,
        .seed = 42,
    });
    defer context.deinit();
    const assertions = zstd.Testing.AssertionRecorder.init(&context);
    try assertions.equal(.{
        .id = "stable-acceptance-id",
        .label = "user-visible behavior holds",
        .repair_hint = "repair the responsible typed boundary",
    }, expected, actual);
    try assertions.noPendingFibers(.{ .id = "fibers-clean", .label = "no work escaped its scope" });
    try assertions.noFindings(.{ .id = "causal-clean", .label = "runtime invariants remain clean" });
    try context.publish(std.testing.io, std.Io.Dir.cwd(), 1);

Use `AssertionRecorder` for values, semantic JSON, `Exit`, `Cause`, events,
findings, fibers, and secret scans. Use `FaultMatrix` for bounded hostile
runtime cases, `Generators.runProperty` for structural shrinking,
`Models.StatechartExplorer` and `Schedules` for bounded exploration,
`Differential` for cross-executor comparison, `VirtualWorld` for
distributed faults, `Mutation` for requirement-linked mutant evidence,
`Budgets` for deterministic performance contracts, `Sandbox.Firewall` for
side-effect authority, and semantic snapshots for durable artifacts.
Unsupported cases, exhausted bounds, dropped evidence, or truncation are not
passes.

## Iterate from evidence

1. Before editing, run `zigeffect agent context --task <id> --budget 65536
   --json`. Retain its exact source/manifest identity, proof references,
   authority, omissions, and `newest_durable_event_id` as the causal
   baseline. Use the current graph,
   requirement, contracts, and scopes to state the expected counterfactual:
   which services, boundaries, and facts should change, and which should not.
2. Select the smallest declared set with `zigeffect test affected --changed
   <path> --json`, then run a scenario or `zigeffect test run --requirement
   <id> --json`.
3. Read `.zigeffect/tests/latest.json`, then the stable native receipt and
   proof handoff under `.zigeffect/tests/process-receipts/` and
   `.zigeffect/handoffs/tests/`; require their source, manifest, command,
   native toolchain, selection, and status identities to agree.
   Run `zigeffect test coverage --json` and `zigeffect test gaps --json`;
   required semantic gaps are unpassed evidence.
4. Query `zigeffect graph since <baseline-event-id> --limit 256 --json` and
   compare the actual causal delta with the stated counterfactual and test
   contract. An empty, truncated, dropped, or unexpectedly broad delta is
   evidence to investigate, not a pass.
5. On failure, inspect the first assertion's source, repair hint, causal
   event IDs, and `causal_event_id_space`. Query `zigeffect graph event
   <id> --json` and `zigeffect graph children <id> --json` only for
   `graph_durable` IDs; `runtime_local` IDs are not graph cursors.
   Use `zigeffect graph path <from> <to> --limit 128 --json` when two
   events bound the suspected causal behavior.
6. Copy the receipt's exact replay command, preserving its seed, fault,
   root, and bounds. Use `zigeffect safety explain <finding-id>` for a
   source-linked safety repair.
7. Compare with `zigeffect test snapshot <scenario> --json`. Apply only an
   inspected intentional change with `--apply --json`; never bless an
   unexplained diff.

## Verify and hand off

    zigeffect project validate --json
    zigeffect test run --requirement <id> --json
    zigeffect test coverage --requirement <id> --json
    zigeffect test gaps --requirement <id> --json
    zigeffect test stress --requirement <id> --runs 32 --json
    zigeffect test history --json
    zigeffect project test --json
    zigeffect project check --agent --json
    zigeffect agent handoff --provider <harness> --session <id> --json

Attach changed requirements, acceptance status, bounded redacted receipts,
replay commands, and relevant causal IDs. State failed or unrun gates. Never
claim safety or completeness beyond the compiler mode, platform, cases, and
bounds recorded in the evidence.

For multi-agent work, integrate proof rather than prose. Each implementer
owns one non-overlapping work packet and returns a proof bundle bound to the
source baseline, lease fencing token, changed paths, verification digests,
receipts, and causal IDs. Independent qualifiers never repair candidates.
Repair memory is advice, not current proof or authority.
