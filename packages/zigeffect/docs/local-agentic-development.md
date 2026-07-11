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
13. M84 - Durable local agent session registry.
14. M85 - Local agent control API.
15. M86 - Workbench local operator controls and supported loopback host.
16. M87 - Bidirectional native PTY sessions and workbench terminal.

M72 through M87 are implemented. The registry records redacted session
lifecycle and counters, writes starting/running/terminal snapshots through a
caller-owned store, restores snapshots all-or-nothing, and marks stale active
ownership interrupted. The authenticated control API exposes only caller-owned
tool IDs, bounded input, durable session reads, explicit stop ownership, and
redacted audit receipts; HTTP callers cannot provide argv. M86 provides a
runtime-validated loopback browser client, ephemeral token bootstrap,
single-flight polling, responsive Solid controls, and the supported Bun host
that combines the collector with prompt-only Codex/Claude allowlists. M87 adds
native interactive Codex and Claude tools, a bounded Bun PTY supervisor,
authenticated terminal cursor/input/resize routes, and a lazy xterm.js panel.
Input is never copied into receipts, inherited control authority is removed from
all child environments, and retained terminal output is redacted and explicitly
memory-only. No hosted control plane is required.

## Interactive local agents

The supported host exposes both batch and interactive tools. Start it and the
workbench in separate local terminals:

```sh
export ZIGEFFECT_CONTROL_TOKEN="$(openssl rand -hex 32)"
bun run zigeffect:local-agent-host
```

```sh
bun run zigeffect:workbench:dev
```

Open the host's printed workbench query, connect with the token, and select
`Codex interactive` or `Claude Code interactive`. The browser receives only
redacted bounded output frames. Session lifecycle/counters survive host restart;
terminal scrollback does not, and the UI reports retention gaps if old frames
expire.

## Boundaries

- Causal graph inspection remains read-only; local command execution is owned by
  explicit runner code and policy-gated command intents.
- Generated applications and services persist redacted causal facts in their
  local `.zigeffect/graph` WAL. `zigeffect graph` resolves only validated project
  and component paths; it never accepts an arbitrary database path.
- zigeffect causal tools write evidence, not source patches.
- Human approval is required before any source mutation path is treated as
  applied.
- Secrets must be redacted before they reach causal artifacts, workbench payloads,
  or local adapter files.
