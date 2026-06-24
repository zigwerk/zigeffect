# zigeffect Roadmap M56-M59 Design

Date: 2026-06-24

## Context

M0-M55 established local command polling, HTTP command bridge clients, collector
frame ingest, service-discovery snapshot JSON parsing, dev-loop eval artifact
persistence, and endpoint-aware runbooks. The next frontier should make those
local substrates easier to run in real host processes while keeping the Zig core
deterministic and adapter-shaped.

The design keeps the boundary conservative:

- TypeScript workbench tooling may expose `Request`/`Response` helpers because
  it already owns Bun/browser HTTP edges.
- Zig core may format and parse bounded data shapes and caller-owned sinks, but
  it does not open network connections or send provider traffic directly.
- Tooling may write artifacts through existing local artifact paths, but it must
  reuse core eval writers instead of inventing new report layers.

## M56: Live Engine Apply Request Adapter

Add a host-side TypeScript request adapter that turns a `Request` into a
validated `LiveCommandInboxResponse`, calls a caller-owned
`LiveCommandEngineBridge`, and returns a JSON `LiveCommandEngineBatchResult`.
This is the missing half of the HTTP bridge introduced in M52: host processes can
now implement the apply endpoint with a small, tested adapter instead of
hand-rolling request parsing.

The adapter rejects non-POST requests, invalid JSON, invalid inbox payloads, and
invalid engine batch results. All responses use JSON, `cache-control: no-store`,
and `x-content-type-options: nosniff`.

## M57: Remediation Decision Eval Artifact Persistence

Extend the remediation decision tool so an approved remediation decision can
write linked eval diff artifacts beside the decision artifacts. This attaches
eval evidence to the actual remediation chain instead of only to the generic
dev-loop after phase.

The first implementation uses a bounded built-in suspended-fiber smoke eval, the
same core manifest writer as M54, and stable artifact paths derived from the
decision target:

- `...-remediation-eval-diff.json`
- `...-remediation-eval-link.json`
- `...-remediation-eval-manifest.json`

Rejected decisions remain record-only and do not write eval artifacts.

## M58: File-Backed Service Discovery Snapshot Loader

Add a concrete local discovery provider seam by loading the governed service
discovery JSON snapshot from a caller-provided directory/path and parsing it into
the existing owned snapshot type. This is deliberately a file provider, not a
cluster service: it proves provider ingestion through real file IO while reusing
the existing validation, registry refresh, and endpoint selection.

The loader owns memory through the existing
`ClusterTransportOwnedServiceDiscoverySnapshot` lifecycle and rejects missing or
corrupt files through the same parse errors.

## M59: Provider-Shaped Ops Alert Request Adapter

Add provider-shaped alert request formatting for external alert adapters. The
core still does not send network traffic; it formats request shapes for caller
sinks.

Initial providers:

- generic webhook: existing delivery-envelope body.
- Slack webhook: Slack-shaped text plus the redacted delivery envelope.
- PagerDuty Events v2: trigger event with redacted summary/details and a secret
  reference field rather than a raw routing key.

The provider request adapter preserves fixed JSON/no-store/nosniff headers and
keeps sentinel values redacted.

## Verification

This slice should be proven by focused red-green tests first, then the usual
package gates:

- Bun live attach tests for the request adapter.
- Zig cluster transport tests for file-backed snapshot loading.
- Zig causal ops alert tests for provider-shaped requests and redaction.
- Zig remediation-decision tool tests through `zig build examples`.
- Full zigeffect/workbench/typecheck/release gates before commit.
