# zigeffect Roadmap M60-M63 Design

Date: 2026-06-24

## Context

M56-M59 turned several local substrates into host/provider seams: host apply
request handling, remediation decision eval artifacts, file-backed discovery
snapshots, and provider-shaped ops alert requests. The next slice keeps the same
discipline: harden real deployment edges without embedding process supervision,
network clients, or secret stores in the deterministic Zig core.

## M60: Live Engine Host Runner Bundle

Add a TypeScript host bundle that groups the tested apply request adapter with
the existing collector command daemon bridge. A real host process can construct
the bundle around its engine bridge, expose `handleApplyRequest(request)`, and
run `runCommandDaemon(...)` against a collector inbox.

This does not start an HTTP server. It gives the host process the two pieces it
needs to wire one: apply endpoint handling and collector command polling.

## M61: HTTP-Shaped Discovery Snapshot Provider

Add request/response helpers for network-backed service discovery without
performing network IO in core:

- `formatClusterTransportServiceDiscoveryHttpRequest(url)` returns a fixed
  `GET` request shape.
- `parseClusterTransportServiceDiscoveryHttpResponse(...)` rejects non-200
  responses and parses governed snapshot JSON through the existing owned parser.

Host code can own the real HTTP client, feed the body to the parser, and refresh
the registry.

## M62: Patch-Proposal Eval Artifact Persistence

Extend the approved patch-proposal tool path so it can write linked eval diff
artifacts beside patch proposal artifacts. This broadens remediation-specific
eval persistence beyond the decision step while keeping the first implementation
bounded to the same smoke eval used by dev-loop and decision artifacts.

Draft proposals stay record-only. Approved proposals write:

- `...-patch-proposal-eval-diff.json`
- `...-patch-proposal-eval-link.json`
- `...-patch-proposal-eval-manifest.json`

## M63: Provider Alert Secret Injection

M59 formatted provider request bodies with secret references. M63 adds a
caller-owned secret injection seam for the send step. The core still does not
store, fetch, or log secrets. A caller passes a secret resolver sink that maps a
secret reference to a transient secret value; the provider delivery helper uses
it only while constructing the outbound request passed to the caller-owned HTTP
sink.

The test uses a non-sentinel fake routing key and separately proves sentinel
alert evidence remains redacted from the provider request body.

## Verification

Use focused red-green tests for each milestone, then the same package gates as
previous slices:

- Bun live attach tests for the host bundle.
- Zig cluster transport tests for HTTP-shaped discovery responses.
- Zig patch-proposal tool tests through `zig build examples`.
- Zig ops alert tests for provider secret injection.
- Full workbench, zigeffect, zio, hygiene, diff, and release gates before commit.
