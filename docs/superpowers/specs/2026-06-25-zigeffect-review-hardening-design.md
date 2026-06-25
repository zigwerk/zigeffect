# zigeffect Review Hardening Design

## Goal

Close the latest review findings without widening zigeffect's public runtime surface: command frames must stay secret-safe, socket transports must keep lifecycle accounting honest, loopback socket sends must not leave spawned threads using stack state on error paths, and ops alert retries must be limited to transient delivery failures.

## Scope

- Workbench collector command ingestion redacts every free-text command field, including `kind`, before broadcasting or returning a `LiveCommandFrame`.
- Loopback socket transport moves client connection setup before thread spawn where possible, then guarantees client close happens before any fallback thread join on send/read errors.
- Loopback and remote socket transports increment `lifecycle.in_flight` only after preflight succeeds, decrement it on every return path, and keep max-in-flight rejection unchanged.
- Alert provider delivery policy gains an explicit retryability predicate with a conservative default. The default retries transport/transient sink failures and does not retry resolver, formatting, auth, validation, or allocation failures.

## Non-Goals

- No new zigeffect tools.
- No public command-kind enum in the workbench; existing unknown-command flows continue to work, just with redacted text.
- No broad retry taxonomy for every possible application sink error. Callers can opt in by supplying a retryability predicate.

## Verification

- `bun test --timeout 30000 packages/zigeffect/workbench/src/collector/collector.test.ts`
- `cd packages/zigeffect && zig build test-raw`
- `bun run zigeffect:workbench:typecheck`
- `bun run zigeffect:workbench:test`
- `bun run zigeffect:test`
- `git diff --check`
- Failing-first checks were captured for collector command-kind redaction and permanent alert resolver retry suppression before implementation.
