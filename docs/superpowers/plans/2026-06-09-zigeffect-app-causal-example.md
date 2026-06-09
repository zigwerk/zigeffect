# zigeffect App Causal Example Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Worker-shaped zigeffect app request example that emits bounded, redacted, workbench-compatible causal JSON through `CausalAppTrace`.

**Architecture:** Implement a pure request handler in `packages/zigeffect/examples/causal_app_request.zig` that returns a response plus owned causal JSON. The executable wrapper may print the sample output, but the request path itself uses only allocator-owned data, `CausalStore`, and `CausalAppTrace`.

**Tech Stack:** Zig standard library, zigeffect `CausalAppTrace`, existing causal JSON and workbench tooling.

---

## File Structure

- Create `packages/zigeffect/examples/causal_app_request.zig`
  - Owns `AppRequest`, `AppEnv`, `AppResponse`, `AppIncident`,
    `handleRequest`, tests, and demo `main`.
- Modify `packages/zigeffect/build.zig`
  - Add executable/test target and `causal-app-request-example` step.
  - Add executable/test to `examples` step.
- Modify `packages/zigeffect/README.md`
  - Add example link and command.
- Modify `packages/zigeffect/docs/agent-guide.md`
  - Point agents to the example for app-facing request traces.
- Modify `packages/zigeffect/docs/agent-observable-runtime.md`
  - Update app-level diagnostics section.
- Modify `packages/zigeffect/docs/roadmap.md`
  - Mark app causal example progress.
- Modify `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
  - Update M7 evidence and next queue.

## Task 1: RED Example And Build Wiring

**Files:**
- Create: `packages/zigeffect/examples/causal_app_request.zig`
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Write failing example tests**

Create `packages/zigeffect/examples/causal_app_request.zig` with the public
API and tests first:

```zig
const std = @import("std");
const fx = @import("zigeffect");

pub const AppRequest = struct {
    method: []const u8,
    route: []const u8,
};

pub const AppEnv = struct {
    environment: ?[]const u8 = null,
};

pub const AppResponse = struct {
    status: u16,
    body: []const u8,
};

pub const AppIncident = struct {
    allocator: std.mem.Allocator,
    response: AppResponse,
    causal_json: []const u8,

    pub fn deinit(self: *AppIncident) void {
        self.allocator.free(self.causal_json);
    }
};

pub fn handleRequest(
    allocator: std.mem.Allocator,
    request: AppRequest,
    env: AppEnv,
) !AppIncident {
    _ = allocator;
    _ = request;
    _ = env;
    return error.NotImplemented;
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var incident = try handleRequest(allocator, .{
        .method = "GET",
        .route = "/health",
    }, .{
        .environment = "local",
    });
    defer incident.deinit();
    std.debug.print("status={d} body={s}\n{s}", .{
        incident.response.status,
        incident.response.body,
        incident.causal_json,
    });
}

fn jsonContains(json: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, json, needle) != null;
}

test "causal app request example returns health response and standard causal JSON" {
    var incident = try handleRequest(std.testing.allocator, .{
        .method = "GET",
        .route = "/health",
    }, .{
        .environment = "test",
    });
    defer incident.deinit();

    try std.testing.expectEqual(@as(u16, 200), incident.response.status);
    try std.testing.expectEqualStrings("ok", incident.response.body);
    try std.testing.expect(jsonContains(incident.causal_json, "\"schema\": \"zigeffect.causal.v1\""));
    try std.testing.expect(jsonContains(incident.causal_json, "app.request GET /health"));
    try std.testing.expect(jsonContains(incident.causal_json, "HealthService"));
    try std.testing.expect(jsonContains(incident.causal_json, "\"kind\": \"run_completed\""));
    try std.testing.expect(jsonContains(incident.causal_json, "\"status\": \"success\""));
}

test "causal app request example records missing environment as app incident finding" {
    var incident = try handleRequest(std.testing.allocator, .{
        .method = "GET",
        .route = "/health",
    }, .{});
    defer incident.deinit();

    try std.testing.expectEqual(@as(u16, 500), incident.response.status);
    try std.testing.expectEqualStrings("missing_environment", incident.response.body);
    try std.testing.expect(jsonContains(incident.causal_json, "YACHDEE_ENV"));
    try std.testing.expect(jsonContains(incident.causal_json, "MissingConfig"));
    try std.testing.expect(jsonContains(incident.causal_json, "HealthService"));
    try std.testing.expect(jsonContains(incident.causal_json, "\"kind\": \"assertion_recorded\""));
    try std.testing.expect(jsonContains(incident.causal_json, "\"status\": \"failure\""));
}

test "causal app request example redacts accidental sensitive environment values" {
    var incident = try handleRequest(std.testing.allocator, .{
        .method = "GET",
        .route = "/health",
    }, .{
        .environment = "token=raw-secret",
    });
    defer incident.deinit();

    try std.testing.expect(std.mem.indexOf(u8, incident.causal_json, "raw-secret") == null);
    try std.testing.expect(jsonContains(incident.causal_json, fx.causal_redaction_marker));
}
```

- [ ] **Step 2: Add build wiring**

In `packages/zigeffect/build.zig`, add a module, executable, test target, and
step following the `causal_readiness_example` pattern:

```zig
const causal_app_request_example_module = b.createModule(.{
    .root_source_file = b.path("examples/causal_app_request.zig"),
    .target = target,
    .optimize = optimize,
});
causal_app_request_example_module.addImport("zigeffect", zigeffect);

const causal_app_request_example = b.addExecutable(.{
    .name = "zigeffect-causal-app-request",
    .root_module = causal_app_request_example_module,
});

const causal_app_request_example_tests = b.addTest(.{
    .name = "zigeffect-causal-app-request-tests",
    .root_module = causal_app_request_example_module,
});
const run_causal_app_request_example_tests = b.addRunArtifact(causal_app_request_example_tests);
const causal_app_request_example_step = b.step("causal-app-request-example", "Compile and test the causal app request example");
causal_app_request_example_step.dependOn(&causal_app_request_example.step);
causal_app_request_example_step.dependOn(&run_causal_app_request_example_tests.step);
```

Add both executable and tests to `examples_step`.

- [ ] **Step 3: Verify RED**

Run:

```bash
cd packages/zigeffect && zig build causal-app-request-example
```

Expected: FAIL with `NotImplemented` from the example tests.

## Task 2: GREEN Worker-Shaped Example

**Files:**
- Modify: `packages/zigeffect/examples/causal_app_request.zig`

- [ ] **Step 1: Implement `handleRequest`**

Use `fx.CausalStore.initWithOptions(allocator, fx.defaultRequestCausalStoreOptions())`,
`fx.CausalAppTrace.startRequest`, semantic app events, and
`fx.formatCausalJson`.

Successful request should record `HealthService`, `HealthLayer`, a request
scope, and complete success. Missing env should record config and requirement
failures and complete failure. Environment should only be recorded in
`redacted_detail` so the existing store redactor can remove secret-shaped
values.

- [ ] **Step 2: Verify GREEN**

Run:

```bash
cd packages/zigeffect && zig build causal-app-request-example
```

Expected: PASS.

## Task 3: Docs And Roadmap

**Files:**
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Document the example**

Add:

```bash
cd packages/zigeffect
zig build causal-app-request-example
```

Mention `examples/causal_app_request.zig`, Worker-compatible request-path
constraints, caller-owned persistence, and SolidJS/`zig-webui` workbench
compatibility.

- [ ] **Step 2: Update roadmap status**

Mark `codex/zigeffect-app-causal-example` as the current/delivered example
branch and leave `codex/zigeffect-app-incident-mapping` next.

- [ ] **Step 3: Verify docs do not introduce placeholders**

Run:

```bash
rg -n "TBD|TODO|fill in|implement later" docs/superpowers/specs/2026-06-09-zigeffect-app-causal-example-design.md docs/superpowers/plans/2026-06-09-zigeffect-app-causal-example.md packages/zigeffect/README.md packages/zigeffect/docs/agent-guide.md packages/zigeffect/docs/agent-observable-runtime.md packages/zigeffect/docs/roadmap.md
```

Expected: no matches.

## Task 4: Verification And Commit

**Files:**
- All changed files from this plan.

- [ ] **Step 1: Run final verification**

Run:

```bash
cd packages/zigeffect && zig build causal-app-request-example
cd packages/zigeffect && zig build examples
cd packages/zigeffect && zig build test
bun run zigeffect:workbench:test
bun run zigeffect:workbench:typecheck
git diff --check
```

Expected: all commands exit 0.

- [ ] **Step 2: Commit**

Run:

```bash
git add docs/superpowers/specs/2026-06-09-zigeffect-app-causal-example-design.md docs/superpowers/plans/2026-06-09-zigeffect-app-causal-example.md packages/zigeffect/examples/causal_app_request.zig packages/zigeffect/build.zig packages/zigeffect/README.md packages/zigeffect/docs/agent-guide.md packages/zigeffect/docs/agent-observable-runtime.md packages/zigeffect/docs/roadmap.md docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
git commit -m "feat(zigeffect): add causal app request example"
```

## Plan Self-Review

- Spec coverage: location, Worker-compatible constraints, request success,
  failure, redaction, workbench compatibility, docs, and verification are
  covered.
- Placeholder scan: no placeholders are intentionally present.
- Type consistency: the plan uses `AppRequest`, `AppEnv`, `AppIncident`, and
  `handleRequest` consistently.
