# zigeffect Causal Artifact Size Limits Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add opt-in per-event-string size limits and explicit truncation metadata so causal artifacts can be bounded without invalidating JSON, text, CI, or DOT outputs.

**Architecture:** Extend `CausalStoreOptions` with `max_event_string_bytes`, apply redaction before truncation at store time, count truncated fields, and disclose that count through JSON/text/CI reports. Keep default behavior unchanged and avoid global post-format byte slicing.

**Tech Stack:** Zig stdlib, zigeffect causal runtime, `bun:test` repo gate, `zig build` package verification.

---

## File Structure

- Modify `packages/zigeffect/src/services/causal.zig`
  - Add `causal_truncation_marker`.
  - Add `max_event_string_bytes` to `CausalStoreOptions`.
  - Add `max_event_string_bytes` and `truncated_field_count` to `CausalStore`.
  - Add `truncatedFieldCount()`.
  - Add redaction-then-truncation helper functions.
  - Emit truncation summary in text, CI, and JSON artifacts.
- Modify `packages/zigeffect/test/services_test.zig`
  - Add RED tests for default metadata.
  - Add RED tests for opt-in truncation, backend forwarding, DOT labels, JSON/text/CI disclosure, and redaction-before-truncation safety.
- Modify `packages/zigeffect/README.md`
  - Document the new `truncation` root metadata.
  - Explain how to use `max_events` plus `max_event_string_bytes`.
- Modify `packages/zigeffect/docs/agent-guide.md`
  - Teach agents how to cite `truncated_fields`.
- Modify `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
  - Mark M3 artifact size limits as delivered after implementation.
  - Move the immediate branch queue to M4 backend conformance after this lands.

---

### Task 1: Add RED Tests For Default Truncation Metadata

**Files:**
- Modify: `packages/zigeffect/test/services_test.zig`

- [ ] **Step 1: Add a default behavior test near the existing retention and sampling artifact tests**

```zig
test "causal artifacts disclose truncation policy when string limits are disabled" {
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    _ = try store.record(.{
        .kind = .run_started,
        .label = "unbounded-label",
        .type_name = "UnboundedEffect",
        .status = "success",
        .redacted_detail = "detail remains complete",
    });

    try std.testing.expectEqual(@as(u64, 0), store.truncatedFieldCount());

    const json = try fx.formatCausalJson(std.testing.allocator, &store);
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"truncation\": {") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"max_event_string_bytes\": null") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"truncated_fields\": 0") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "detail remains complete") != null);

    const report = try fx.formatCausalReport(std.testing.allocator, "default truncation", &store);
    defer std.testing.allocator.free(report);
    try std.testing.expect(std.mem.indexOf(u8, report, "truncation: max_event_string_bytes=off truncated_fields=0") != null);

    const ci_report = try fx.formatCausalCiReport(std.testing.allocator, "default truncation", &store);
    defer std.testing.allocator.free(ci_report);
    try std.testing.expect(std.mem.indexOf(u8, ci_report, "truncation: max_event_string_bytes=off truncated_fields=0") != null);
}
```

- [ ] **Step 2: Run the package tests and verify RED**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary none
```

Expected: FAIL because `CausalStore.truncatedFieldCount` and truncation metadata do not exist yet.

---

### Task 2: Implement Default Truncation Metadata

**Files:**
- Modify: `packages/zigeffect/src/services/causal.zig`

- [ ] **Step 1: Add the option and store fields**

Update the top-level constants and options:

```zig
pub const causal_redaction_marker = "<redacted>";
pub const causal_truncation_marker = "<truncated>";

pub const CausalStoreOptions = struct {
    max_events: ?usize = null,
    sampling: CausalSamplingPolicy = .{},
    max_event_string_bytes: ?usize = null,
};
```

Update `CausalStore` fields and initializer:

```zig
max_events: ?usize = null,
dropped_event_count: u64 = 0,
sampling: CausalSamplingPolicy = .{},
sampled_event_count: u64 = 0,
max_event_string_bytes: ?usize = null,
truncated_field_count: u64 = 0,
```

```zig
pub fn initWithOptions(allocator: Allocator, options: CausalStoreOptions) CausalStore {
    return .{
        .allocator = allocator,
        .max_events = options.max_events,
        .sampling = options.sampling,
        .max_event_string_bytes = options.max_event_string_bytes,
    };
}
```

- [ ] **Step 2: Add the accessor**

```zig
pub fn truncatedFieldCount(self: *const CausalStore) u64 {
    return self.truncated_field_count;
}
```

- [ ] **Step 3: Add text summary helpers**

Place after `appendSamplingSummary`:

```zig
fn appendTruncationLimit(output: *std.ArrayList(u8), allocator: Allocator, value: ?usize) Allocator.Error!void {
    if (value) |number| {
        try output.print(allocator, "{d}", .{number});
    } else {
        try output.appendSlice(allocator, "off");
    }
}

fn appendTruncationSummary(output: *std.ArrayList(u8), allocator: Allocator, store: *const CausalStore) Allocator.Error!void {
    try output.appendSlice(allocator, "truncation: max_event_string_bytes=");
    try appendTruncationLimit(output, allocator, store.max_event_string_bytes);
    try output.print(allocator, " truncated_fields={d}\n", .{store.truncated_field_count});
}
```

- [ ] **Step 4: Emit text and CI truncation summaries**

In both `formatCausalReport` and `formatCausalCiReport`, call:

```zig
try appendTruncationSummary(&output, allocator, store);
```

immediately after `appendSamplingSummary`.

- [ ] **Step 5: Emit JSON truncation metadata**

In `formatCausalJson`, after the `sampling` object and before `events`, emit:

```zig
try output.appendSlice(allocator, "  },\n  \"truncation\": {\n    \"max_event_string_bytes\": ");
try appendOptionalJsonUsize(&output, allocator, store.max_event_string_bytes);
try output.print(allocator, ",\n    \"truncated_fields\": {d}\n", .{store.truncated_field_count});
try output.appendSlice(allocator, "  },\n  \"events\": [\n");
```

Replace the old direct transition from `sampling` to `events`.

- [ ] **Step 6: Run the RED test again and verify GREEN**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary none
```

Expected: PASS for the new default metadata test.

- [ ] **Step 7: Commit**

```bash
git add packages/zigeffect/src/services/causal.zig packages/zigeffect/test/services_test.zig
git commit -m "feat(zigeffect): disclose causal truncation metadata"
```

---

### Task 3: Add RED Tests For Opt-In String Truncation And Safety

**Files:**
- Modify: `packages/zigeffect/test/services_test.zig`

- [ ] **Step 1: Add truncation behavior tests**

Add near the default truncation metadata test:

```zig
test "causal store truncates event strings before snapshots reports json dot and backend emission" {
    var backend_state = FakeCausalBackendState{};
    var store = fx.CausalStore.initWithOptions(std.testing.allocator, .{
        .max_event_string_bytes = 24,
    });
    store.attachBackend(fakeCausalBackend(&backend_state));
    defer store.deinit();

    _ = try store.record(.{
        .kind = .run_started,
        .label = "label-prefix-that-is-too-long",
        .type_name = "TypeNamePrefixThatIsTooLong",
        .status = "status-prefix-that-is-too-long",
        .redacted_detail = "detail-prefix-that-is-too-long",
    });

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();

    const event = snapshot.events[0];
    try std.testing.expect(event.label.len <= 24);
    try std.testing.expect(event.type_name.len <= 24);
    try std.testing.expect(event.status.len <= 24);
    try std.testing.expect(event.redacted_detail.len <= 24);
    try std.testing.expect(std.mem.indexOf(u8, event.label, "<truncated>") != null);
    try std.testing.expect(std.mem.indexOf(u8, event.redacted_detail, "<truncated>") != null);
    try std.testing.expectEqual(@as(u64, 4), store.truncatedFieldCount());

    try std.testing.expectEqual(@as(usize, 1), backend_state.count);
    try std.testing.expect(backend_state.labels[0].len <= 24);
    try std.testing.expect(std.mem.indexOf(u8, backend_state.labels[0], "<truncated>") != null);
    try std.testing.expect(std.mem.indexOf(u8, backend_state.labels[0], "too-long") == null);

    const report = try fx.formatCausalReport(std.testing.allocator, "truncated", &store);
    defer std.testing.allocator.free(report);
    try std.testing.expect(std.mem.indexOf(u8, report, "truncation: max_event_string_bytes=24 truncated_fields=4") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "too-long") == null);

    const ci_report = try fx.formatCausalCiReport(std.testing.allocator, "truncated", &store);
    defer std.testing.allocator.free(ci_report);
    try std.testing.expect(std.mem.indexOf(u8, ci_report, "truncation: max_event_string_bytes=24 truncated_fields=4") != null);

    const json = try fx.formatCausalJson(std.testing.allocator, &store);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"max_event_string_bytes\": 24") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"truncated_fields\": 4") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "too-long") == null);

    const dot = try fx.formatCausalDot(std.testing.allocator, &store);
    defer std.testing.allocator.free(dot);
    try std.testing.expect(std.mem.indexOf(u8, dot, "<truncated>") != null);
    try std.testing.expect(std.mem.indexOf(u8, dot, "too-long") == null);
}
```

- [ ] **Step 2: Add the redaction-order safety test**

Add near the redaction tests:

```zig
test "causal string truncation happens after secret redaction" {
    var backend_state = FakeCausalBackendState{};
    var store = fx.CausalStore.initWithOptions(std.testing.allocator, .{
        .max_event_string_bytes = 40,
    });
    store.attachBackend(fakeCausalBackend(&backend_state));
    defer store.deinit();

    _ = try store.record(.{
        .kind = .log_recorded,
        .label = "authorization: Bearer raw-secret-token with trailing debug context that is very long",
        .type_name = "postgresql://root:raw-db-password@localhost/yachdee with trailing context",
        .status = "api_key=raw-api-key safe=kept with trailing context",
        .redacted_detail = "{\"email\":\"owner@example.com\",\"safe\":\"kept\",\"token\":\"raw-json-token\",\"note\":\"long\"}",
    });

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();

    const event = snapshot.events[0];
    try std.testing.expect(std.mem.indexOf(u8, event.label, "raw-secret-token") == null);
    try std.testing.expect(std.mem.indexOf(u8, event.type_name, "raw-db-password") == null);
    try std.testing.expect(std.mem.indexOf(u8, event.status, "raw-api-key") == null);
    try std.testing.expect(std.mem.indexOf(u8, event.redacted_detail, "owner@example.com") == null);
    try std.testing.expect(std.mem.indexOf(u8, event.redacted_detail, "raw-json-token") == null);
    try std.testing.expect(std.mem.indexOf(u8, event.label, "<redacted>") != null);
    try std.testing.expect(std.mem.indexOf(u8, event.label, "<truncated>") != null);
    try std.testing.expectEqual(@as(u64, 4), store.truncatedFieldCount());

    try std.testing.expect(std.mem.indexOf(u8, backend_state.labels[0], "raw-secret-token") == null);

    const json = try fx.formatCausalJson(std.testing.allocator, &store);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "raw-secret-token") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "raw-db-password") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "raw-api-key") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "owner@example.com") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "raw-json-token") == null);
}
```

- [ ] **Step 3: Run the package tests and verify RED**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary none
```

Expected: FAIL because `max_event_string_bytes` is recorded but no string truncation is applied.

---

### Task 4: Implement Redaction-Then-Truncation At Store Time

**Files:**
- Modify: `packages/zigeffect/src/services/causal.zig`

- [ ] **Step 1: Add the truncation helper**

Place after `redactCausalText`:

```zig
fn truncateCausalText(
    allocator: Allocator,
    value: []const u8,
    max_bytes: ?usize,
    truncated_field_count: *u64,
) Allocator.Error![]const u8 {
    const max = max_bytes orelse return value;
    if (value.len <= max) return value;

    truncated_field_count.* += 1;
    if (max == 0) return "";

    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    if (max <= causal_truncation_marker.len) {
        try output.appendSlice(allocator, causal_truncation_marker[0..max]);
        return output.toOwnedSlice(allocator);
    }

    const prefix_len = max - causal_truncation_marker.len;
    try output.appendSlice(allocator, value[0..prefix_len]);
    try output.appendSlice(allocator, causal_truncation_marker);
    return output.toOwnedSlice(allocator);
}
```

- [ ] **Step 2: Add a redaction-then-truncation field helper**

```zig
fn redactAndBoundCausalText(
    allocator: Allocator,
    value: []const u8,
    max_bytes: ?usize,
    truncated_field_count: *u64,
) Allocator.Error![]const u8 {
    const redacted = try redactCausalText(allocator, value);
    errdefer if (redacted.len > 0) allocator.free(redacted);

    const truncated = try truncateCausalText(allocator, redacted, max_bytes, truncated_field_count);
    if (truncated.ptr == redacted.ptr) return redacted;

    if (redacted.len > 0) allocator.free(redacted);
    return truncated;
}
```

- [ ] **Step 3: Add a store-specific event clone helper**

```zig
fn cloneEventForStore(
    allocator: Allocator,
    event: CausalEvent,
    max_event_string_bytes: ?usize,
    truncated_field_count: *u64,
) Allocator.Error!CausalEvent {
    var owned = event;
    owned.label = try redactAndBoundCausalText(allocator, event.label, max_event_string_bytes, truncated_field_count);
    errdefer if (owned.label.len > 0) allocator.free(owned.label);
    owned.type_name = try redactAndBoundCausalText(allocator, event.type_name, max_event_string_bytes, truncated_field_count);
    errdefer if (owned.type_name.len > 0) allocator.free(owned.type_name);
    owned.status = try redactAndBoundCausalText(allocator, event.status, max_event_string_bytes, truncated_field_count);
    errdefer if (owned.status.len > 0) allocator.free(owned.status);
    owned.redacted_detail = try redactAndBoundCausalText(allocator, event.redacted_detail, max_event_string_bytes, truncated_field_count);
    errdefer if (owned.redacted_detail.len > 0) allocator.free(owned.redacted_detail);
    return owned;
}
```

- [ ] **Step 4: Use the store-specific clone in `record`**

Replace:

```zig
var owned = try cloneEvent(self.allocator, event);
```

with:

```zig
var owned = try cloneEventForStore(
    self.allocator,
    event,
    self.max_event_string_bytes,
    &self.truncated_field_count,
);
```

Leave `snapshot`, `lineage`, `cause`, and `filterEvents` on `cloneEvent` so
they clone already-stored event strings without incrementing truncation counts.

- [ ] **Step 5: Run the truncation tests and verify GREEN**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary none
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add packages/zigeffect/src/services/causal.zig packages/zigeffect/test/services_test.zig
git commit -m "feat(zigeffect): bound causal event string payloads"
```

---

### Task 5: Update Documentation And Roadmap

**Files:**
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Update the JSON root examples**

In README and agent guide JSON examples, add:

```json
  "truncation": {
    "max_event_string_bytes": null,
    "truncated_fields": 0
  },
```

between `sampling` and `events`.

- [ ] **Step 2: Add agent guidance after sampling guidance**

Use this wording:

````markdown
For long-running probes with potentially large labels, statuses, type names, or
details, configure `max_event_string_bytes` as well as `max_events`:

```zig
var store = fx.CausalStore.initWithOptions(allocator, .{
    .max_events = 256,
    .max_event_string_bytes = 512,
});
defer store.deinit();
```

Truncation is opt-in. Redaction runs before truncation, and attached backends
receive the bounded strings. If `truncated_fields` is nonzero, cite the
truncation metadata and avoid claims that depend on complete event payload
text.
````

- [ ] **Step 3: Update the master roadmap ledger**

Change M3:

```markdown
| M3 Production hardening | delivered | bounded store, broader redaction, sampling, taxonomy, schema/taxonomy compatibility fixtures, and artifact string-size limits delivered | move to M4 backend conformance |
```

Change the immediate branch queue to:

```markdown
1. `codex/zigeffect-causal-backend-conformance`
   - Establish common adapter contract tests before durable backends.
```

Only do this after the implementation tests are passing.

- [ ] **Step 4: Run docs diff check**

Run:

```bash
git diff --check
```

Expected: no whitespace errors.

- [ ] **Step 5: Commit docs**

```bash
git add packages/zigeffect/README.md packages/zigeffect/docs/agent-guide.md docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
git commit -m "docs(zigeffect): document causal artifact truncation"
```

---

### Task 6: Final Verification And Merge

**Files:**
- Verify only; no edits unless a command exposes a real issue.

- [ ] **Step 1: Run focused package verification**

```bash
cd packages/zigeffect && zig build test-raw --summary none
cd packages/zigeffect && zig build test --summary none
cd packages/zigeffect && zig build causal-test-matrix
cd packages/zigeffect && zig build examples
```

Expected: all commands exit 0.

- [ ] **Step 2: Run repo verification**

```bash
bun run check
bun run zig:test
git diff --check HEAD
```

Expected:

- `bun run check` reports all tests passing;
- `bun run zig:test` exits 0;
- `git diff --check HEAD` exits 0.

- [ ] **Step 3: Confirm no unrelated files are staged**

```bash
git status --short
git diff --name-only master...HEAD
```

Expected:

- the unrelated untracked durable-workflows plan remains untracked;
- branch diff contains only artifact-size-limit design, plan, runtime, tests,
  docs, and roadmap files.

- [ ] **Step 4: Merge**

```bash
git switch master
git merge --ff-only codex/zigeffect-causal-artifact-size-limits
git branch -d codex/zigeffect-causal-artifact-size-limits
```

- [ ] **Step 5: Re-run post-merge verification**

```bash
cd packages/zigeffect && zig build test --summary none
bun run check
bun run zig:test
git diff --check HEAD
```

Expected: all commands exit 0.

---

## Self-Review Checklist

- The plan covers all requirements in `2026-06-08-zigeffect-causal-artifact-size-limits-design.md`.
- No post-format JSON slicing is introduced.
- Redaction remains before truncation.
- Default behavior stays unbounded for event strings.
- All new metadata is additive under `zigeffect.causal.v1`.
- The unrelated untracked durable-workflows plan is not staged.
