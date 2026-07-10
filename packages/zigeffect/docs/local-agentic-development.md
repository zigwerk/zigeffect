# Local Agentic Development

Date: 2026-07-10

`zigeffect` is being hardened as a local-first agentic development engine. The
goal is to let Codex, Claude Code, and zigeffect's own causal tools collaborate
against the same structured evidence while developing local projects.

This mode does not require hosting.

## Inner loop

1. Capture a baseline:

   ```sh
   bun run zigeffect:self-improve:start
   ```

2. Make source changes with a local agent or by hand.

3. Assess the change:

   ```sh
   bun run zigeffect:self-improve:assess
   ```

4. Open the emitted session or causal artifacts in the workbench:

   ```sh
   cd packages/zigeffect
   zig build causal-workbench -- .zig-cache/causal-artifacts/zigeffect-causal-dev-session.json
   ```

For frontend-only inspection, run the Vite workbench and open the local sample:

```sh
bun run zigeffect:workbench:dev -- --port 5178
```

Then visit `http://127.0.0.1:5178/?sample=dev-session`.

Codex, Claude Code, and local scripts can append activity through the JSONL
contract in `local-agent-adapters.md`. The Bun-local process supervisor can also
own a command from start to exit, normalize native Codex/Claude stream events,
drain bounded stderr, stop the child on abort, and send lifecycle receipts to
the collector's `/agent-events` endpoint.

Before handing a session to another local agent, run:

```sh
bun run zigeffect:local-agent-gate
```

## What the local cockpit should show

- session goal, target, phase, and status;
- local agents participating in the run;
- commands and checks with pass/fail/running status;
- before, after, verdict, diagnosis, audit, and diff artifact paths;
- guardrails and next actions;
- causal timeline, findings, graph, semantic diff, chain, queries, and metadata.

## Milestones

The ordered local-first roadmap is:

1. M72 - Local development session protocol.
2. M73 - Workbench agent cockpit view.
3. M74 - Dogfood session receipt enrichment.
4. M75 - Live agent runtime feed.
5. M76 - Local Codex and Claude Code adapters.
6. M77 - Local reliability gate.
7. M78 - Local agent runtime.
8. M79 - Local agent artifact capture.
9. M80 - Local agent turn receipts.
10. M81 - Local agent transcript tail.
11. M82 - Local agent process supervisor.
12. M83 - Native Codex and Claude transcript adapters.

M72 through M83 are implemented. The remaining local maturity frontier is
interactive PTY control, resumable process/session recovery, and deeper
workbench operator controls; none requires a hosted control plane.

## Boundaries

- Causal graph inspection remains read-only; local command execution is owned by
  explicit runner code and policy-gated command intents.
- zigeffect causal tools write evidence, not source patches.
- Human approval is required before any source mutation path is treated as
  applied.
- Secrets must be redacted before they reach causal artifacts, workbench payloads,
  or local adapter files.
