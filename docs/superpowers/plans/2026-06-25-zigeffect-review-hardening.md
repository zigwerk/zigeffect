# zigeffect Review Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the latest zigeffect review findings around workbench command secrecy, socket transport lifecycle accounting, loopback thread cleanup, and selective ops alert retries.

**Architecture:** Keep changes surgical: tests live next to the affected subsystem, runtime fixes preserve existing APIs except for an additive retry predicate on the alert delivery policy. Socket sends use local defer ordering for cleanup rather than a new abstraction.

**Tech Stack:** Zig std library tests, Bun workbench collector tests, zigeffect cluster transport and causal ops alert services.

---

### Task 1: Workbench Command Redaction

**Files:**
- Modify: `packages/zigeffect/workbench/src/collector/collector.test.ts`
- Modify: `packages/zigeffect/workbench/src/collector/collector.ts`

- [x] Add a collector test that posts `kind: "rotate_database_root_password token=sentinel-secret"` and asserts neither the HTTP response nor WebSocket command contains `sentinel-secret`.
- [x] Run `bun test --timeout 30000 packages/zigeffect/workbench/src/collector/collector.test.ts`; expected first result is failure because `command_kind` currently echoes `kind`.
- [x] Change `ingestCommand` to pass `record.kind` through `redactCommandText`.
- [x] Re-run the collector test; expected result is pass.

### Task 2: Alert Retry Selectivity

**Files:**
- Modify: `packages/zigeffect/test/causal_ops_alert_test.zig`
- Modify: `packages/zigeffect/src/services/causal_ops_alert.zig`

- [x] Add a test with a resolver returning `error.PermanentSecretStoreFailure` and `max_attempts = 3`, expecting one attempt, one failure, no sink send, and the permanent error returned.
- [x] Run `cd packages/zigeffect && zig build test-raw`; expected first result is failure because the current loop retries every error.
- [x] Add `CausalOpsAlertProviderRetryableErrorFn` and a default predicate to `CausalOpsAlertProviderDeliveryPolicy`.
- [x] In `deliverCausalOpsAlertProviderWithSecretRetrying`, continue only when the predicate returns true and attempts remain.
- [x] Re-run `cd packages/zigeffect && zig build test-raw`; expected result is pass.

### Task 3: Socket Lifecycle Accounting

**Files:**
- Modify: `packages/zigeffect/test/cluster_transport_test.zig`
- Modify: `packages/zigeffect/src/cluster/transport.zig`

- [x] Add socket transport tests that assert successful loopback and remote sends finish with `metrics.in_flight == 0`, and max-in-flight rejection still prevents durable submission.
- [x] Run `cd packages/zigeffect && zig build test-raw`; expected first result may pass for the zero-after-send assertion but still documents the regression boundary before code changes.
- [x] Increment `lifecycle.in_flight` after preflight in loopback socket send and remote socket send.
- [x] Decrement with `defer` on every post-preflight return path.
- [x] Re-run `cd packages/zigeffect && zig build test-raw`; expected result is pass.

### Task 4: Loopback Thread Cleanup

**Files:**
- Modify: `packages/zigeffect/src/cluster/transport.zig`

- [x] Move loopback client `connect` before `Thread.spawn` so a connection failure cannot leave an accept thread running.
- [x] After spawning, order defers so the client stream closes before fallback `thread.join()` on errors.
- [x] Remove the manual read-error join branch so every post-spawn error uses one cleanup path.
- [x] Re-run `cd packages/zigeffect && zig build test-raw`; expected result is pass with no leaked-thread hang.

### Task 5: Final Verification

**Files:**
- Verify all modified files.

- [x] Run `bun test --timeout 30000 packages/zigeffect/workbench/src/collector/collector.test.ts`.
- [x] Run `cd packages/zigeffect && zig build test-raw`.
- [x] Run `bun run zigeffect:workbench:typecheck`.
- [x] Run `bun run zigeffect:workbench:test`.
- [x] Run `bun run zigeffect:test`.
- [x] Run `git diff --check`.
- [x] Review `git diff --stat` and the focused diff before reporting completion.
