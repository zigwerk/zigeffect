# zigeffect Workbench Local Operator Design

## Goal

Turn the collaboration lens into a complete local operator surface for the M85
agent control API: connect, discover approved tools, launch a bounded task,
inspect durable session history, stop active ownership, and read the policy
decision that authorized or rejected each mutation.

## Local Authority Boundary

The browser client accepts only `http:` control endpoints on `localhost`, IPv4
loopback, or IPv6 loopback. It never sends a bearer token to a remote host. The
control URL may be prefilled with `?control=`, but the token lives only in
component memory. A launcher may provide a one-use `#control-token=` fragment;
the application consumes and removes it with `history.replaceState` before
starting any network work.

Tokens are never persisted, included in errors, copied into causal artifacts,
or rendered back into the DOM. Disconnecting drops the client and clears the
in-memory token.

## Tool Input Contract

M85 tools gain optional safe input metadata. The first supported input kind is
`prompt`, with a redacted label/placeholder, required flag, and bounded maximum
length. The workbench renders a textarea and sends `{ "prompt": "..." }` to
the caller-owned tool builder. Tools without input metadata launch without a
form payload. HTTP still cannot submit argv, cwd, executables, or environment.

## Typed Browser Client

`localAgentControlClient.ts` owns the browser protocol boundary. It:

- normalizes and validates loopback base URLs;
- adds bearer authentication only to protected routes;
- caps response bodies before parsing;
- validates health, tools, sessions, detail, receipts, start, and stop payloads;
- maps network, authorization, policy, not-found, and invalid-response failures
  to a bounded `LocalAgentControlClientError` without leaking credentials; and
- supports request cancellation through `AbortSignal`.

The health response reports active ownership and whether the server has a
durable session store (`durable` or `memory`). Older responses without this
field remain readable as `unknown` during local upgrades.

## Operator State

`createLocalAgentOperator` is a small Solid state controller shared by the UI
and tests. It owns connection state, validated tools, durable sessions, selected
session detail, receipts, pending action, and the latest bounded failure.

Refreshes load health, tools, sessions, and receipts as one generation. A stale
generation cannot overwrite a newer connection. Polling is single-flight and
uses an injected delay: active sessions refresh quickly, idle history refreshes
less often, and cleanup aborts in-flight requests. Start and stop actions are
serialized, preserve the server policy response, then refresh before becoming
idle.

Selection follows the selected session ID across refreshes and falls back to
the newest session when the selected record is evicted. Session detail is read
from the dedicated detail route so the operator proves that route end to end.

## SolidJS Surface

`LocalAgentOperator` is an unframed band at the top of `CollabBoard`, available
even when the loaded causal artifact has no development-session model.

Disconnected state contains loopback endpoint and password-token fields plus a
connect command. Connected state contains:

- runtime, active-count, and persistence status;
- approved-tool selection and schema-driven prompt input;
- icon controls for launch, stop, refresh, and disconnect;
- durable session history with status and updated time;
- selected-session lifecycle, task, counters, exit status, and redacted detail;
- an explicit recovery interruption state; and
- the latest accepted or rejected control receipt.

Controls remain disabled while their mutation is pending. Errors are concise
operational states, not instructions or raw server payload dumps. The layout
collapses to one column on narrow screens and all fixed controls have stable
dimensions.

## Supported Local Host

`localAgentControlHost.ts` provides the missing executable composition. It binds
only to loopback, combines the existing collector and WebSocket routes with the
M85 control routes, restores the durable registry, persists recovery
interruptions immediately, and exposes fixed Codex and Claude Code prompt tools
using the native public stream adapters.

The host requires `ZIGEFFECT_CONTROL_TOKEN`, accepts explicit loopback port,
workspace, and state-path configuration, and never prints the token. Graceful
shutdown aborts every owned child and waits for terminal persistence. Invalid
durable state fails startup instead of silently presenting empty history.

## Acceptance Criteria

- Client tests prove loopback-only URLs, auth placement, response validation,
  size bounds, typed failures, token-fragment parsing, and fragment scrubbing.
- Controller tests prove initial load, session detail, non-overlapping polling,
  stale-generation rejection, start/stop refresh, unauthorized state, and
  cleanup cancellation.
- Server tests prove safe prompt metadata, persistence health, and unchanged
  no-argv enforcement.
- Host tests prove collector/control composition, built-in Codex/Claude
  allowlists, durable recovery persistence, loopback-only binding inputs, and
  graceful no-orphan shutdown.
- UI source and browser tests prove connection, launch, history/detail, stop,
  recovery interruption, counters, receipt, loading, empty, and error states.
- Desktop and mobile screenshots show no overlap or clipped text.
- The full local agent gate passes.

## Non-Goals

- No arbitrary command editor or JSON input console.
- No token persistence or hosted authentication.
- No PTY stdin, terminal emulation, or resize protocol; those remain M87.
- No mutation of causal graph evidence from the browser.
