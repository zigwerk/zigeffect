# zigeffect Bidirectional PTY Sessions Design

## Goal

Deliver M87 as a real local interactive-process path: an approved tool runs in a
native pseudo-terminal, the workbench renders its bounded redacted output,
keyboard input and resize travel back through authenticated control routes, and
stop/restart behavior never leaves false ownership behind.

## Runtime Choice

Bun 1.3.14 provides native `Bun.Terminal` support on POSIX and ConPTY on
Windows. It supplies output callbacks, input writes, resize, raw mode, terminal
close, and a separate subprocess exit promise. M87 uses that API directly; no
native PTY add-on is needed. The browser uses the maintained scoped xterm.js
packages (`@xterm/xterm` and `@xterm/addon-fit`) rather than implementing VT
parsing or cursor behavior.

References:

- https://bun.sh/docs/runtime/child-process#terminal-pty-support
- https://github.com/xtermjs/xterm.js

## Tool Contract

`LocalAgentControlTool` gains `mode: "batch" | "pty"`, defaulting to `batch`.
The safe tools response exposes the mode. HTTP still selects only a fixed tool
ID and schema-described prompt; argv, executable, cwd, environment, and terminal
mode remain caller-owned.

The supported host retains the batch Codex/Claude tools and adds:

- `codex-interactive`: `codex --no-alt-screen <prompt>`
- `claude-code-interactive`: `claude <prompt>`

No approval, permission, or sandbox bypass flags are added.

## PTY Supervisor

`localAgentPtySupervisor.ts` is fakeable at the terminal boundary. The native
runner wraps `Bun.spawn({ terminal })`; tests use deterministic handles.

For each session it:

- begins and persists the durable registry record before spawn;
- waits for real spawn before marking running and accepting ownership;
- emits one running status and one terminal check/status pair;
- stores terminal output in a per-session sequence ring;
- accepts bounded input without logging, persisting, or echoing the submitted
  bytes itself;
- validates and applies bounded rows/columns;
- kills exactly once on explicit abort, idle timeout, runtime timeout, output
  limit, stream error, or collector delivery failure;
- distinguishes process exit code from PTY stream lifecycle status;
- closes the terminal after process settlement; and
- persists done, failed, or interrupted terminal state on every path.

## Bounds And Redaction

Defaults are conservative and configurable for tests:

- input message: 16 KiB;
- output callback: 64 KiB;
- retained output: 2,048 frames and 2 MiB per session;
- total output before termination: 64 MiB;
- dimensions: 20-500 columns and 5-200 rows;
- idle timeout: 30 minutes;
- runtime timeout: 4 hours; and
- retained PTY histories: 32, evicting terminal sessions only.

Output is decoded incrementally, coalesced, passed through the shared local
redactor, and scrubbed against explicit secret literals. Literal matching is
stream-aware so values split across callbacks are not emitted. The host removes
its control token from child environments and supplies secret-looking inherited
environment values to the sanitizer. Input payloads never appear in receipts.

When the ring evicts output, reads report a gap and cumulative dropped frame and
byte counts. The browser shows that gap instead of pretending its terminal
history is complete.

## Authenticated Control Protocol

All routes require the existing bearer token:

- `GET /agent-control/sessions/:id/terminal?after=<sequence>` returns ordered
  output frames, next cursor, gap/drop counters, dimensions, and terminal state.
- `POST /agent-control/sessions/:id/input` accepts `{ "data": "..." }`.
- `POST /agent-control/sessions/:id/resize` accepts `{ "cols": n, "rows": n }`.

Polling avoids placing bearer credentials in a WebSocket URL. Reads are
single-flight and cursor-based; active terminals use a short interval and
terminal sessions stop polling after their final frame. Input and resize routes
return policy decisions but do not create per-keystroke causal receipts.

Batch sessions reject terminal routes. Unknown, terminal, or unowned sessions
cannot receive input/resize. Output remains available for retained terminal PTY
sessions after process completion.

## Browser Terminal

`LocalAgentTerminalPanel` is lazy client-only code. It creates xterm.js on mount,
loads the fit addon, writes ordered frames, serializes input requests, and sends
dimension changes through a debounced `ResizeObserver`. It cancels polling and
disposes terminal/addon/input resources on session change or unmount.

The operator shows a Terminal mode only for PTY sessions. Desktop places it in
the session detail surface; mobile adds a Terminal tab alongside Run, Sessions,
and Detail. A read-only closed terminal remains inspectable. Gap, disconnected,
loading, and failure states are explicit.

## Recovery And Honesty

The durable registry remains the cross-restart source of truth. Restored
starting/running records become interrupted and are persisted before the host
serves. PTY output itself is bounded in memory and is not claimed durable.
Workbench copy says `retained` for output and `durable` only for registry state.

## Acceptance Criteria

- Deterministic supervisor tests cover spawn failure, I/O, resize, explicit
  abort, process failure, idle/runtime/output limits, collector failure,
  redaction across callback boundaries, ring gaps, terminal close, and no double
  kill/finalization.
- Control tests cover mode metadata, output cursors, input/resize validation,
  batch rejection, ownership, terminal output retention, and no input leakage.
- A real Bun smoke test proves TTY detection, input, output, resize, and exit.
- Client/controller tests cover terminal response validation, cursor polling,
  serialized input, resize, cancellation, and terminal settlement.
- Browser proof uses an inert interactive tool to launch, type, observe output,
  resize, exit/stop, and inspect the terminal on desktop/mobile with no console
  errors or layout overflow.
- The full local agent gate passes.

## Non-Goals

- No hosted terminal relay or remote bearer-token transport.
- No arbitrary shell/argv endpoint.
- No durable full terminal transcript.
- No bypass of Codex or Claude approval/sandbox policy.
- No attempt to derive structured provider turns from interactive VT output.
