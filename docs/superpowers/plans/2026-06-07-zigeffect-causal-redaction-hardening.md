# zigeffect Causal Redaction Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make zigeffect causal store events defensively redact common secret-shaped text before snapshots, reports, JSON artifacts, and backends can observe it.

**Architecture:** Add a deterministic redaction helper in `services/causal.zig`, call it from event cloning for all event string fields, and document the policy. Keep the existing artifact schema version because this is a value-safety improvement, not a structural schema change.

**Tech Stack:** Zig 0.16, `std.ArrayList`, existing zigeffect causal runtime tests and Bun-managed verification commands.

---

## File Structure

- Modify `packages/zigeffect/src/services/causal.zig` to add redaction helpers and sanitize event strings during `cloneEvent`.
- Modify `packages/zigeffect/test/services_test.zig` to add RED/GREEN redaction tests for JSON, text reports, snapshots, findings, and backends.
- Modify `packages/zigeffect/README.md`, `packages/zigeffect/docs/agent-guide.md`, `packages/zigeffect/docs/agent-observable-runtime.md`, and `docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md` to document the hardening slice.

### Task 1: RED Redaction Tests

**Files:**
- Modify: `packages/zigeffect/test/services_test.zig`

- [ ] **Step 1: Add store-time redaction test**

Add this test near the causal JSON/report tests:

```zig
test "causal store redacts secret-shaped event strings before storage and export" {
    var backend_state = FakeCausalBackendState{};
    var store = fx.CausalStore.init(std.testing.allocator);
    store.attachBackend(fakeCausalBackend(&backend_state));
    defer store.deinit();

    _ = try store.record(.{
        .kind = .log_recorded,
        .label = "Authorization: Bearer raw-bearer-token",
        .type_name = "postgresql://root:db-password@localhost/yachdee",
        .status = "api_key=sk-proj-raw-key",
        .redacted_detail = "database.password=hunter2 token: raw-token safe=kept",
    });

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();

    const event = snapshot.events[0];
    try std.testing.expect(std.mem.indexOf(u8, event.label, "raw-bearer-token") == null);
    try std.testing.expect(std.mem.indexOf(u8, event.type_name, "db-password") == null);
    try std.testing.expect(std.mem.indexOf(u8, event.status, "sk-proj-raw-key") == null);
    try std.testing.expect(std.mem.indexOf(u8, event.redacted_detail, "hunter2") == null);
    try std.testing.expect(std.mem.indexOf(u8, event.redacted_detail, "raw-token") == null);
    try std.testing.expect(std.mem.indexOf(u8, event.redacted_detail, "safe=kept") != null);
    try std.testing.expect(std.mem.indexOf(u8, event.redacted_detail, "database.password=<redacted>") != null);

    try std.testing.expect(std.mem.indexOf(u8, backend_state.labels[0], "raw-bearer-token") == null);

    const report = try fx.formatCausalReport(std.testing.allocator, "redaction", &store);
    defer std.testing.allocator.free(report);
    try std.testing.expect(std.mem.indexOf(u8, report, "hunter2") == null);
    try std.testing.expect(std.mem.indexOf(u8, report, "raw-token") == null);
    try std.testing.expect(std.mem.indexOf(u8, report, "db-password") == null);
    try std.testing.expect(std.mem.indexOf(u8, report, "<redacted>") != null);

    const json = try fx.formatCausalJson(std.testing.allocator, &store);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "hunter2") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "raw-token") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "db-password") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "<redacted>") != null);
}
```

- [ ] **Step 2: Add safe diagnostic preservation test**

Add:

```zig
test "causal redaction preserves safe retry diagnostics" {
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    _ = try store.record(.{
        .kind = .schedule_decision,
        .label = "retry",
        .status = "exhausted",
        .redacted_detail = "attempt=2 delay_ms=null decision=exhausted",
    });

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();

    try std.testing.expectEqualStrings(
        "attempt=2 delay_ms=null decision=exhausted",
        snapshot.events[0].redacted_detail,
    );
}
```

- [ ] **Step 3: Run tests and verify RED**

Run:

```bash
cd packages/zigeffect && zig build test --summary none
```

Expected: FAIL because stored causal strings still contain the raw secret-shaped values.

### Task 2: GREEN Redaction Helper

**Files:**
- Modify: `packages/zigeffect/src/services/causal.zig`

- [ ] **Step 1: Add public marker constant**

Add near the schema constants:

```zig
pub const causal_redaction_marker = "<redacted>";
```

- [ ] **Step 2: Add sensitive key matching**

Add helper functions for ASCII-insensitive key checks:

```zig
fn asciiLower(byte: u8) u8 {
    if (byte >= 'A' and byte <= 'Z') return byte + 32;
    return byte;
}

fn eqlAsciiIgnoreCase(left: []const u8, right: []const u8) bool {
    if (left.len != right.len) return false;
    for (left, right) |a, b| {
        if (asciiLower(a) != asciiLower(b)) return false;
    }
    return true;
}
```

Use sensitive keys:

```zig
const sensitive_detail_keys = [_][]const u8{
    "password",
    "passwd",
    "pwd",
    "secret",
    "token",
    "api_key",
    "apikey",
    "access_token",
    "refresh_token",
    "authorization",
};
```

- [ ] **Step 3: Add deterministic redaction scanner**

Implement `redactCausalText(allocator, value)` that:

- returns `""` for empty input;
- scans for URL credentials and writes `://<redacted>@`;
- scans key tokens followed by optional spaces, then `=` or `:`;
- writes the original key and separator, then `<redacted>`;
- skips the value until whitespace, `&`, `;`, `,`, newline, or carriage return;
- treats `Authorization: Bearer value` as one redacted value;
- otherwise copies bytes unchanged.

- [ ] **Step 4: Sanitize cloned events**

Change `cloneEvent` string cloning to use `redactCausalText` for `label`,
`type_name`, `status`, and `redacted_detail`.

- [ ] **Step 5: Run tests and verify GREEN**

Run:

```bash
cd packages/zigeffect && zig build test --summary none
```

Expected: PASS.

### Task 3: Documentation

**Files:**
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
- Modify: `docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md`

- [ ] **Step 1: Document the defensive policy**

Document that causal store redacts common secret-shaped key/value details,
Bearer token values, and URL credentials before events are retained or sent to
backends.

- [ ] **Step 2: Document caller responsibility**

Document that callers should still avoid putting secrets in labels, statuses,
type names, and details; the defensive policy is a backstop, not a full PII
classifier.

- [ ] **Step 3: Update hardening roadmap**

Mark stronger secret redaction tests as delivered for this first policy slice,
while leaving sampling, event taxonomy compatibility, and artifact retention
planned.

### Task 4: Verification And Commit

**Files:**
- Stage all files modified in Tasks 1-3.

- [ ] **Step 1: Run verification**

Run:

```bash
cd packages/zigeffect && zig build test --summary none
cd packages/zigeffect && zig build examples
bun run zig:test
zig build causal-dev-loop -- baseline
zig build causal-dev-loop -- after
git diff --check
```

Expected: all commands PASS.

- [ ] **Step 2: Commit implementation**

Run:

```bash
git add docs/superpowers/specs/2026-06-07-zigeffect-causal-redaction-hardening-design.md docs/superpowers/plans/2026-06-07-zigeffect-causal-redaction-hardening.md docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md packages/zigeffect/README.md packages/zigeffect/docs/agent-guide.md packages/zigeffect/docs/agent-observable-runtime.md packages/zigeffect/src/services/causal.zig packages/zigeffect/test/services_test.zig
git commit -m "feat(zigeffect): harden causal event redaction"
```

## Self-Review

- Spec coverage: acceptance criteria map to Tasks 1-4.
- Placeholder scan: no deferred implementation language remains.
- Type consistency: redaction marker is a string constant; redaction helper returns owned `[]const u8` just like `cloneSlice`.
