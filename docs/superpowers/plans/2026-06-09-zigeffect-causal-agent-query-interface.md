# zigeffect Causal Agent Query Interface Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a bounded JSON agent-query mode to `causal-query` over the unified runtime spine.

**Architecture:** Extend the existing `causal_query.zig` tool rather than adding a parallel command. Keep text output as the default compatibility surface and add an `--agent` JSON formatter with explicit relationships, policy metadata, limitations, and next-query hints.

**Tech Stack:** Zig 0.16, `std.json.parseFromSlice`, existing `causal_artifact` compatibility helpers, existing zigeffect build step.

---

## Scope

This branch implements the runtime-only first version of the agent query
interface. App semantic `trace_data` and cross-artifact `compare_runs` remain
future branches.

## Files

- Modify `packages/zigeffect/tools/causal_query.zig`
- Update `packages/zigeffect/docs/agent-observable-runtime.md`
- Update `packages/zigeffect/docs/agent-guide.md`
- Update `packages/zigeffect/docs/schema-governance.md`
- Update `packages/zigeffect/tools/causal_schema_governance.zig`
- Update `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Add this plan and companion spec under `docs/superpowers/`

### Task 1: Add Agent Query Parsing And Red Tests

**Files:**
- Modify `packages/zigeffect/tools/causal_query.zig`

- [ ] **Step 1: Add deep runtime fixture fields**

Extend the existing `Event` parser with:

```zig
layer_id: ?u64 = null,
service_key: []const u8 = "",
resource_id: ?u64 = null,
cause_event_id: ?u64 = null,
schedule_id: ?u64 = null,
```

- [ ] **Step 2: Add failing tests for agent JSON**

Add tests proving:

```zig
test "agent explain_event returns bounded schema relationships and next queries" {
    const output = try runQuery(std.testing.allocator, deep_runtime_sample_json, &.{ "--agent", "explain_event", "4" });
    defer std.testing.allocator.free(output);

    try std.testing.expect(std.mem.indexOf(u8, output, "\"schema\":\"zigeffect.causal.agent-query.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"query\":\"explain_event\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"id\":4") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"relationship\":\"requires\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"next_queries\"") != null);
}
```

Also add tests for:

```zig
test "agent summarize_run is bounded by explicit limit" { ... }
test "agent find_failures reports failure evidence and policy metadata" { ... }
test "agent next_queries returns commands for selected event" { ... }
test "invalid agent options return typed usage errors" { ... }
```

- [ ] **Step 3: Run tests to verify RED**

Run:

```sh
cd packages/zigeffect && zig build test
```

Expected: compile/test failure because `--agent`, `explain_event`, and agent
JSON formatting do not exist yet.

### Task 2: Implement Agent Mode

**Files:**
- Modify `packages/zigeffect/tools/causal_query.zig`

- [ ] **Step 1: Add options parsing**

Introduce:

```zig
const OutputMode = enum { text, agent_json };

const ParsedArgs = struct {
    file_path: []const u8,
    query_args: []const []const u8,
    mode: OutputMode,
    limit: usize,
};
```

Parse `--agent`, `--limit <n>`, and `--file <path>` before query args. Default
limit is 32; maximum accepted limit is 256.

- [ ] **Step 2: Add runtime query selection**

Support agent query names:

```zig
summarize_run <run_id>
find_failures <run_id>
explain_event <event_id>
trace_cause <event_id>
list_findings <run_id>
next_queries <event_id>
```

Reuse the existing selection helpers where possible. Keep text query names
working.

- [ ] **Step 3: Add relationship derivation**

Derive relationships from returned events:

```zig
parent_id -> parent_of
cause_event_id -> caused_by
service_required -> requires
service_provided/service_replaced -> provides
resource_acquired -> owns
resource_finalized -> finalizes
fiber_forked/fiber_started/fiber_joined/fiber_interrupted with scope_id -> owns
```

- [ ] **Step 4: Add agent JSON formatter**

Emit deterministic JSON with compact event and relationship records. Preserve
all new runtime identity fields.

- [ ] **Step 5: Run focused tests to verify GREEN**

Run:

```sh
cd packages/zigeffect && zig build test
```

Expected: all `causal_query.zig` tests and package tests pass.

### Task 3: Governance And Docs

**Files:**
- Update `packages/zigeffect/tools/causal_schema_governance.zig`
- Update `packages/zigeffect/docs/schema-governance.md`
- Update `packages/zigeffect/docs/agent-observable-runtime.md`
- Update `packages/zigeffect/docs/agent-guide.md`
- Update `packages/zigeffect/tools/causal_production_hardening_backlog.zig`

- [ ] **Step 1: Register schema governance**

Add `zigeffect.causal.agent-query.v1` as a strict/read-only agent-query schema
emitted by `causal-query --agent`.

- [ ] **Step 2: Advance backlog status for runtime query boundary**

Mark `agent-query-interface` as `in_progress` or `partial` rather than
`delivered`, because app semantic `trace_data` and `compare_runs` still need
future branches.

- [ ] **Step 3: Document CLI usage**

Document examples:

```sh
zig build causal-query -- --agent --file <artifact.json> explain_event 3
zig build causal-query -- --agent --limit 16 --file <artifact.json> summarize_run 1
zig build causal-query -- --agent --file <artifact.json> find_failures 1
```

Explain that this is a compact agent surface, not the human workbench.

### Task 4: Verification And Commit

**Files:**
- All modified files from Tasks 1-3.

- [ ] **Step 1: Run verification**

Run:

```sh
cd packages/zigeffect
zig build causal-query -- --agent snapshot
zig build causal-query -- --agent --limit 8 summarize_run 1
zig build causal-schema-governance
zig build causal-production-hardening-backlog
zig build examples
zig build test
cd ../..
bun run zig:test
bun run check
git diff --check
git diff --cached --check
```

- [ ] **Step 2: Commit**

Stage only this branch's files. Do not stage unrelated dirty files already
present in the worktree.

Commit:

```sh
git commit -m "feat(zigeffect): add bounded causal agent queries"
```

## Follow-On Branch

The next branch should implement the app semantic trace API so `trace_data` and
app-facing agent understanding can be backed by real app events instead of a
future placeholder.
