# zigeffect Causal PII Redaction Policy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expand causal store redaction to cover deterministic header, cookie, query-parameter, JSON-ish, config-ish, SQL-ish, and key-bound personal-data payloads before app-facing causal traces arrive.

**Architecture:** Keep the store-time redaction boundary in `services/causal.zig`. Extend the existing scanner with a broader key catalog, full-header-value redaction for cookie and authorization headers, quoted key/value handling, and whitespace-plus-quote value forms. Verify behavior through focused `bun:test`-free Zig tests in `services_test.zig` and document the policy in the agent-facing docs.

**Tech Stack:** Zig stdlib, `zig build test-raw`, `zig build test`, Bun repo verification commands.

---

## File Structure

- Modify `packages/zigeffect/src/services/causal.zig`
  - Expand the sensitive key catalog.
  - Add full-value header key classification.
  - Add quoted key and quoted value scanning helpers.
  - Extend `appendSensitiveKeyRedaction` without adding downstream formatter redaction.
- Modify `packages/zigeffect/test/services_test.zig`
  - Add focused store-time redaction tests beside the existing causal redaction tests.
  - Reuse `FakeCausalBackendState` for label/backend assertions.
- Modify `packages/zigeffect/docs/agent-guide.md`
  - Update the causal redaction guidance for agents.
- Modify `packages/zigeffect/README.md`
  - Update public README redaction language.
- Modify `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
  - Mark the immediate M3 redaction branch as in progress or delivered once implementation is verified.

---

### Task 1: Add RED Coverage For Headers, Cookies, And Query Parameters

**Files:**
- Modify: `packages/zigeffect/test/services_test.zig`

- [ ] **Step 1: Add the failing test**

Insert this test after `causal store redacts secret-shaped event strings before storage and export`:

```zig
test "causal redaction removes sensitive headers cookies and query params" {
    var backend_state = FakeCausalBackendState{};
    var store = fx.CausalStore.init(std.testing.allocator);
    store.attachBackend(fakeCausalBackend(&backend_state));
    defer store.deinit();

    _ = try store.record(.{
        .kind = .log_recorded,
        .label = "Cookie: sid=raw-cookie; theme=dark",
        .type_name = "Proxy-Authorization: Basic raw-proxy",
        .status = "GET /v1?vessel=demo&x-api-key=raw-query-key",
        .redacted_detail = "Set-Cookie: session_id=raw-session; HttpOnly",
    });

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();

    const event = snapshot.events[0];
    try std.testing.expect(std.mem.indexOf(u8, event.label, "raw-cookie") == null);
    try std.testing.expect(std.mem.indexOf(u8, event.label, "theme=dark") == null);
    try std.testing.expect(std.mem.indexOf(u8, event.label, "Cookie: <redacted>") != null);
    try std.testing.expect(std.mem.indexOf(u8, event.type_name, "raw-proxy") == null);
    try std.testing.expect(std.mem.indexOf(u8, event.status, "raw-query-key") == null);
    try std.testing.expect(std.mem.indexOf(u8, event.status, "vessel=demo") != null);
    try std.testing.expect(std.mem.indexOf(u8, event.status, "x-api-key=<redacted>") != null);
    try std.testing.expect(std.mem.indexOf(u8, event.redacted_detail, "raw-session") == null);
    try std.testing.expect(std.mem.indexOf(u8, event.redacted_detail, "HttpOnly") == null);

    try std.testing.expect(std.mem.indexOf(u8, backend_state.labels[0], "raw-cookie") == null);
    try std.testing.expect(std.mem.indexOf(u8, backend_state.labels[0], "Cookie: <redacted>") != null);

    const json = try fx.formatCausalJson(std.testing.allocator, &store);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "raw-cookie") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "raw-proxy") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "raw-query-key") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "raw-session") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "vessel=demo") != null);
}
```

- [ ] **Step 2: Run the focused package tests and verify RED**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary none
```

Expected: FAIL. At least one new assertion should fail because `Cookie`, `Set-Cookie`, `Proxy-Authorization`, or `x-api-key` values are still visible.

---

### Task 2: Implement Header, Cookie, And Query-Parameter Redaction

**Files:**
- Modify: `packages/zigeffect/src/services/causal.zig`

- [ ] **Step 1: Expand the sensitive key catalog**

Replace the existing `sensitive_detail_keys` array with this version:

```zig
const sensitive_detail_keys = [_][]const u8{
    "authorization",
    "proxy-authorization",
    "cookie",
    "set-cookie",
    "x-api-key",
    "x-auth-token",
    "api_key",
    "api-key",
    "apikey",
    "token",
    "access_token",
    "access-token",
    "refresh_token",
    "refresh-token",
    "id_token",
    "id-token",
    "session",
    "session_id",
    "session-id",
    "sessionid",
    "csrf",
    "xsrf",
    "password",
    "passwd",
    "pwd",
    "secret",
    "client_secret",
    "client-secret",
    "private_key",
    "private-key",
    "connection_string",
    "connection-string",
    "database_url",
    "database-url",
    "email",
    "user_email",
    "user-email",
    "phone",
    "phone_number",
    "phone-number",
    "ssn",
    "social_security_number",
    "social-security-number",
    "address",
    "street_address",
    "street-address",
    "ip",
    "ip_address",
    "ip-address",
    "user_ip",
    "user-ip",
    "date_of_birth",
    "date-of-birth",
    "dob",
};
```

- [ ] **Step 2: Add full-value header classification**

Replace `isAuthorizationKey` with these helpers:

```zig
fn isQuote(byte: u8) bool {
    return byte == '"' or byte == '\'';
}

fn isFullValueRedactionKey(key: []const u8) bool {
    return eqlAsciiIgnoreCase(key, "authorization") or
        eqlAsciiIgnoreCase(key, "proxy-authorization") or
        eqlAsciiIgnoreCase(key, "cookie") or
        eqlAsciiIgnoreCase(key, "set-cookie");
}
```

- [ ] **Step 3: Allow underscore suffix matching**

Change the suffix separator lookup in `isSensitiveKey` to:

```zig
if (std.mem.lastIndexOfAny(u8, key, "._-")) |separator_index| {
    const suffix = key[separator_index + 1 ..];
    for (sensitive_detail_keys) |candidate| {
        if (eqlAsciiIgnoreCase(suffix, candidate)) return true;
    }
}
```

- [ ] **Step 4: Replace the header value skipper**

Replace `isHardValueDelimiter` and `skipAuthorizationValue` with:

```zig
fn isFullValueDelimiter(byte: u8) bool {
    return byte == '\n' or byte == '\r';
}

fn skipFullSensitiveValue(value: []const u8, start: usize) usize {
    var index = start;
    while (index < value.len and !isFullValueDelimiter(value[index])) {
        index += 1;
    }
    return index;
}
```

- [ ] **Step 5: Update unquoted sensitive value skipping**

In `appendSensitiveKeyRedaction`, replace:

```zig
index.* = if (isAuthorizationKey(key))
    skipAuthorizationValue(value, value_start)
else
    skipValue(value, value_start);
```

with:

```zig
index.* = if (isFullValueRedactionKey(key) and value[separator_index] == ':')
    skipFullSensitiveValue(value, value_start)
else
    skipValue(value, value_start);
```

- [ ] **Step 6: Verify GREEN for Task 1**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary none
```

Expected: PASS for the new header/query test and all existing package tests.

- [ ] **Step 7: Commit the first implementation slice**

Run:

```bash
git add packages/zigeffect/src/services/causal.zig packages/zigeffect/test/services_test.zig
git commit -m "test(zigeffect): cover causal header redaction"
```

---

### Task 3: Add RED Coverage For Quoted JSON-ish And Personal-Data Payloads

**Files:**
- Modify: `packages/zigeffect/test/services_test.zig`

- [ ] **Step 1: Add the failing test**

Insert this test after the header/query test:

```zig
test "causal redaction handles quoted json-ish keys and key-bound personal data" {
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    _ = try store.record(.{
        .kind = .log_recorded,
        .label = "headers.authorization: \"Bearer raw-json-bearer\"",
        .type_name = "ip_address=\"203.0.113.42\" user=jane",
        .status = "'phone_number': 'raw-phone'",
        .redacted_detail = "{\"email\":\"owner@example.com\",\"safe\":\"kept\",\"auth\":{\"token\":\"raw-json-token\"}}",
    });

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();

    const event = snapshot.events[0];
    try std.testing.expect(std.mem.indexOf(u8, event.label, "raw-json-bearer") == null);
    try std.testing.expect(std.mem.indexOf(u8, event.label, "headers.authorization: \"<redacted>\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, event.type_name, "203.0.113.42") == null);
    try std.testing.expect(std.mem.indexOf(u8, event.type_name, "user=jane") != null);
    try std.testing.expect(std.mem.indexOf(u8, event.status, "raw-phone") == null);
    try std.testing.expect(std.mem.indexOf(u8, event.status, "'phone_number': '<redacted>'") != null);
    try std.testing.expect(std.mem.indexOf(u8, event.redacted_detail, "owner@example.com") == null);
    try std.testing.expect(std.mem.indexOf(u8, event.redacted_detail, "raw-json-token") == null);
    try std.testing.expect(std.mem.indexOf(u8, event.redacted_detail, "\"safe\":\"kept\"") != null);

    const report = try fx.formatCausalReport(std.testing.allocator, "quoted-redaction", &store);
    defer std.testing.allocator.free(report);
    try std.testing.expect(std.mem.indexOf(u8, report, "owner@example.com") == null);
    try std.testing.expect(std.mem.indexOf(u8, report, "raw-json-token") == null);
    try std.testing.expect(std.mem.indexOf(u8, report, "safe") != null);
}
```

- [ ] **Step 2: Run package tests and verify RED**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary none
```

Expected: FAIL because quoted keys such as `"email"` and quoted values such as `'raw-phone'` are not fully redacted yet.

---

### Task 4: Implement Quoted Key And Quoted Value Redaction

**Files:**
- Modify: `packages/zigeffect/src/services/causal.zig`

- [ ] **Step 1: Add a quoted value skipper**

Add this helper near the other skip helpers:

```zig
fn skipQuotedValue(value: []const u8, start: usize, quote: u8) usize {
    var index = start;
    while (index < value.len) {
        if (value[index] == quote) return index;
        index += 1;
    }
    return index;
}
```

- [ ] **Step 2: Replace `appendSensitiveKeyRedaction` with quoted-aware parsing**

Replace the full body of `appendSensitiveKeyRedaction` with this implementation:

```zig
fn appendSensitiveKeyRedaction(
    output: *std.ArrayList(u8),
    allocator: Allocator,
    value: []const u8,
    index: *usize,
) Allocator.Error!bool {
    var key_start = index.*;
    var key_quote: ?u8 = null;
    if (isQuote(value[key_start])) {
        key_quote = value[key_start];
        key_start += 1;
    }

    if (key_start >= value.len or !isSensitiveKeyChar(value[key_start])) return false;

    var key_end = key_start;
    while (key_end < value.len and isSensitiveKeyChar(value[key_end])) {
        key_end += 1;
    }

    var after_key = key_end;
    if (key_quote) |quote| {
        if (after_key >= value.len or value[after_key] != quote) return false;
        after_key += 1;
    }

    var separator_index = after_key;
    while (separator_index < value.len and std.ascii.isWhitespace(value[separator_index])) {
        separator_index += 1;
    }
    if (separator_index >= value.len) return false;

    var separator: ?u8 = null;
    if (value[separator_index] == '=' or value[separator_index] == ':') {
        separator = value[separator_index];
        separator_index += 1;
    } else if (!isQuote(value[separator_index])) {
        return false;
    }

    const key = value[key_start..key_end];
    if (!isSensitiveKey(key)) return false;

    var value_start = separator_index;
    while (value_start < value.len and std.ascii.isWhitespace(value[value_start])) {
        value_start += 1;
    }

    var value_quote: ?u8 = null;
    if (value_start < value.len and isQuote(value[value_start])) {
        value_quote = value[value_start];
        value_start += 1;
    }

    try output.appendSlice(allocator, value[index.*..value_start]);
    try output.appendSlice(allocator, causal_redaction_marker);

    if (value_quote) |quote| {
        const value_end = skipQuotedValue(value, value_start, quote);
        if (value_end < value.len) {
            try output.append(allocator, quote);
            index.* = value_end + 1;
        } else {
            index.* = value_end;
        }
        return true;
    }

    index.* = if (separator != null and separator.? == ':' and isFullValueRedactionKey(key))
        skipFullSensitiveValue(value, value_start)
    else
        skipValue(value, value_start);
    return true;
}
```

- [ ] **Step 3: Verify GREEN for Task 3**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary none
```

Expected: PASS for the quoted JSON-ish test and all package tests.

- [ ] **Step 4: Commit the quoted scanner slice**

Run:

```bash
git add packages/zigeffect/src/services/causal.zig packages/zigeffect/test/services_test.zig
git commit -m "feat(zigeffect): redact quoted causal payload values"
```

---

### Task 5: Add RED Coverage For SQL-ish/Config Payloads And Key-Bound PII Semantics

**Files:**
- Modify: `packages/zigeffect/test/services_test.zig`

- [ ] **Step 1: Add the failing test**

Insert this test after the quoted JSON-ish test:

```zig
test "causal redaction covers sql-ish config payloads without free-text pii scanning" {
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    _ = try store.record(.{
        .kind = .log_recorded,
        .label = "owner email 'owner@example.com' contact plain@example.com",
        .type_name = "audit phone_number \"raw-phone\" contact plain@example.com",
        .status = "config={database_url:\"postgresql://root:raw-db@db/app\", retry_count:2}",
        .redacted_detail = "select user_ip '198.51.100.42' attempt=2 delay_ms=null decision=exhausted",
    });

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();

    const event = snapshot.events[0];
    try std.testing.expect(std.mem.indexOf(u8, event.label, "owner@example.com") == null);
    try std.testing.expect(std.mem.indexOf(u8, event.label, "email '<redacted>'") != null);
    try std.testing.expect(std.mem.indexOf(u8, event.label, "plain@example.com") != null);
    try std.testing.expect(std.mem.indexOf(u8, event.type_name, "raw-phone") == null);
    try std.testing.expect(std.mem.indexOf(u8, event.type_name, "plain@example.com") != null);
    try std.testing.expect(std.mem.indexOf(u8, event.status, "raw-db") == null);
    try std.testing.expect(std.mem.indexOf(u8, event.status, "retry_count:2") != null);
    try std.testing.expect(std.mem.indexOf(u8, event.redacted_detail, "198.51.100.42") == null);
    try std.testing.expect(std.mem.indexOf(u8, event.redacted_detail, "attempt=2 delay_ms=null decision=exhausted") != null);

    const json = try fx.formatCausalJson(std.testing.allocator, &store);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "owner@example.com") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "raw-phone") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "raw-db") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "198.51.100.42") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "plain@example.com") != null);
}
```

- [ ] **Step 2: Run package tests and verify RED**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary none
```

Expected: FAIL if `key 'value'`, `key "value"`, or nested config values are not redacted correctly. If it passes because Task 4 already covered the full shape, keep the test as regression coverage and proceed.

- [ ] **Step 3: Adjust scanner only if the RED test exposes a gap**

If the test fails, update `appendSensitiveKeyRedaction` so the no-separator quoted value path keeps the prefix through the opening quote and redacts until the closing quote. The Task 4 implementation already has this shape:

```zig
} else if (!isQuote(value[separator_index])) {
    return false;
}
```

and:

```zig
if (value_start < value.len and isQuote(value[value_start])) {
    value_quote = value[value_start];
    value_start += 1;
}
```

- [ ] **Step 4: Verify GREEN**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary none
```

Expected: PASS.

- [ ] **Step 5: Commit the SQL/config regression coverage**

Run:

```bash
git add packages/zigeffect/src/services/causal.zig packages/zigeffect/test/services_test.zig
git commit -m "test(zigeffect): cover causal pii redaction fixtures"
```

---

### Task 6: Update Agent-Facing Redaction Documentation

**Files:**
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/README.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Update `agent-guide.md` redaction paragraph**

Replace the paragraph at the causal artifact guidance section with:

```markdown
Causal events also redact common secret and key-bound personal-data text before
storage: password-like fields, API keys, token keys, authorization and proxy
authorization headers, cookies, URL credentials, secret query parameters,
JSON-ish quoted keys, config-ish maps, SQL-ish key/value diagnostics, and
personal-data keys such as email, phone, IP address, SSN, address, and date of
birth become `<redacted>`. Treat this as a deterministic safety backstop. Do not
intentionally put secrets, prompts, request bodies, credentials, or personal
data into labels, statuses, type names, or details; app-facing adapters should
emit compact semantic diagnostics instead of raw payloads.
```

- [ ] **Step 2: Update `README.md` redaction paragraph**

Replace the README paragraph with:

```markdown
Causal event strings are defensively redacted before storage and backend
emission for common secret, header, cookie, URL credential, query-parameter,
JSON-ish, config-ish, SQL-ish, and key-bound personal-data forms. Callers
should still avoid putting secrets, prompts, request bodies, credentials, or
personal data in labels, statuses, type names, or details; the redactor is a
deterministic safety backstop, not a full PII classifier.
```

- [ ] **Step 3: Update the master roadmap progress ledger**

Change the M3 row from:

```markdown
| M3 Production hardening | planned | bounded store, redaction, sampling, taxonomy delivered | broaden PII/schema/taxonomy fixtures |
```

to:

```markdown
| M3 Production hardening | in progress | bounded store, basic redaction, sampling, taxonomy, and broader PII redaction fixtures delivered | continue with schema/taxonomy compatibility fixtures |
```

Then remove the completed branch from the top of the immediate queue so it begins with `codex/zigeffect-causal-schema-taxonomy-fixtures`.

- [ ] **Step 4: Run docs whitespace check**

Run:

```bash
git diff --check HEAD
```

Expected: no output and exit code 0.

- [ ] **Step 5: Commit docs**

Run:

```bash
git add packages/zigeffect/docs/agent-guide.md packages/zigeffect/README.md docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
git commit -m "docs(zigeffect): document broader causal redaction policy"
```

---

### Task 7: Full Verification And Merge

**Files:**
- Verify all touched files.

- [ ] **Step 1: Run package verification**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary none
cd packages/zigeffect && zig build test --summary none
cd packages/zigeffect && zig build causal-test-matrix
cd packages/zigeffect && zig build examples
```

Expected: all commands pass.

- [ ] **Step 2: Run repo verification**

Run:

```bash
bun run check
bun run zig:test
```

Expected: all commands pass.

- [ ] **Step 3: Check final diff and status**

Run:

```bash
git diff --check HEAD
git status --short --branch
```

Expected: no whitespace errors. Status should show only the known unrelated untracked durable-workflows roadmap file outside this branch's committed work.

- [ ] **Step 4: Fast-forward merge to master**

Run:

```bash
git switch master
git merge --ff-only codex/zigeffect-causal-pii-redaction-policy
git branch -d codex/zigeffect-causal-pii-redaction-policy
```

Expected: merge succeeds, branch deletes cleanly, and the unrelated untracked durable-workflows roadmap remains untracked.

- [ ] **Step 5: Post-merge verification**

Run:

```bash
git diff --check HEAD
cd packages/zigeffect && zig build test --summary none
bun run check
bun run zig:test
```

Expected: all commands pass on `master`.

## Self-Review

- Spec coverage: The tasks cover broader keys, quoted payloads, header/cookie full-value redaction, URL query parameters, SQL/config-like forms, key-bound personal-data semantics, docs, verification, and roadmap ledger updates.
- Placeholder scan: This plan contains no placeholder implementation steps; every code-changing step includes the exact intended snippets or test bodies.
- Type consistency: The plan consistently uses existing `fx.CausalStore`, `FakeCausalBackendState`, `appendSensitiveKeyRedaction`, `causal_redaction_marker`, and Zig stdlib test APIs.
