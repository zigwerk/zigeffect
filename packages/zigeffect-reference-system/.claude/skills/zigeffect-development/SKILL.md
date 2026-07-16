---
name: zigeffect-development
description: Build, change, debug, test, or review this ZigEffect application through zigeffect.project.json, public zigeffect_std APIs, zstd.Testing scenarios, causal evidence, deterministic replay, semantic snapshots, and evidence-backed agent handoffs.
---

# ZigEffect Development

Treat the manifest and structured evidence as the source of truth. Terminal
text is a bounded diagnostic artifact, not proof that a requirement passed.

## Proof-carrying causal loop

1. Start with `zigeffect agent context --task <id-or-summary> --budget 65536
   --json`; retain source/manifest identity, graph cursor, authority, omissions,
   affected scenarios, and proof references.
2. Bind work to a requirement, check, component, fixed command, and scenario.
   State the expected before/action/after causal path and unchanged slice.
3. Respect any supplied work packet, allowed/excluded paths, dependencies,
   verification commands, lease, and fencing token.
4. Add the failing deterministic native scenario first, then make the smallest
   service/layer change through the one managed runtime.
5. Require the current stable process receipt and test proof handoff. Raw
   package receipts and terminal output are diagnostic only.
6. Compare the graph delta and query exact graph paths. Re-query context before
   integration and reject stale or conflicting proof.

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
- Compose services and default layers into one process-level
  `zstd.ManagedRuntime`. It owns the recorder, embedded NenDB graph, durable
  property WAL, agent map, and checked shutdown. Libraries never hide an
  independent runtime or manually attach a causal backend.
- Controlled acceptance runtimes use the owning project or component root.
  After mapping assertion IDs, query the project-mounted graph before
  publishing; a temporary graph cannot support CLI proof.
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

1. Query `zigeffect agent context --task <id> --budget 65536 --json` and capture
   its content-addressed source identity, proof references, authority,
   omissions, and `newest_durable_event_id`. Query the guarded application map
   when available, then state which services,
   boundaries, and semantic facts should and should not change.
2. Select the smallest declared set with `zigeffect test affected --changed
   <path> --json`, then run a scenario or `zigeffect test run --requirement
   <id> --json`.
3. Read `.zigeffect/tests/latest.json`, the stable
   `.zigeffect/tests/process-receipts/<scenario>.json`, and
   `.zigeffect/handoffs/tests/<scenario>.json`; require matching source,
   manifest, command, native toolchain, selection, and status identities.
   `.zigeffect/tests/raw-receipts/` never replaces this controlled evidence.
   Run `zigeffect test coverage --json` and `zigeffect test gaps --json`;
   required semantic gaps are unpassed evidence.
4. Query `zigeffect graph since <baseline-event-id> --limit 256 --json` and
   compare the bounded causal delta with the expected counterfactual. Continue
   from `next_event_id` if truncated; missing or unread evidence is not a pass.
5. On failure, inspect the first assertion's source, repair hint, and causal
   event IDs. Query `zigeffect graph event <id> --json` and `zigeffect graph
   children <id> --json` before reconstructing the failure from text. Use
   `zigeffect graph path <from> <to> --limit 128 --json` for a bounded path
   proof between known events.
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

For multi-agent work, return a proof bundle bound to the work packet, source
baseline, fencing token, changed paths, verification digests, receipts, and
causal IDs. Independent qualifiers do not repair candidates; repair memory is
advice rather than proof.
