# zigeffect Causal Workbench Read-Only Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> `superpowers:executing-plans` or `superpowers:subagent-driven-development` to
> implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for
> tracking.

**Goal:** Add the first read-only local causal workbench as a SolidJS
application hosted by `zig-webui`.

**Architecture:** The SolidJS renderer lives under
`packages/zigeffect/workbench` and owns the UI/model. The Zig host lives under
`packages/zigeffect/tools`, reads exactly one selected artifact with a bounded
limit, exposes it to the renderer through read-only WebUI bindings, and opens
the built app with `zig build causal-workbench -- <artifact.json>`. The launcher
also supports `--server-only` for deterministic local browser inspection and
falls back to a local WebUI server URL if native window launch is unavailable.

**Tech Stack:** Bun, Vite, SolidJS, TypeScript, Zig 0.16, `webui-dev/zig-webui`,
existing zigeffect causal artifacts. No Cockroach work. Future durable indexing
targets a NenDB adapter.

---

## Files

- Modify: `package.json`
  - Add workbench build/typecheck/test scripts.
  - Add Solid/Vite dependencies.
- Modify: `bun.lock`
  - Updated by Bun dependency installation.
- Modify: `tsconfig.json`
  - Exclude the isolated Solid workbench from the Preact-flavored root
    typecheck if needed.
- Create: `packages/zigeffect/build.zig.zon`
  - Pin `zig_webui`.
- Modify: `packages/zigeffect/build.zig`
  - Add session tests, WebUI launcher executable, UI build step, and
    `causal-workbench`.
- Create: `packages/zigeffect/tools/causal_workbench_session.zig`
  - Pure session/usage/bounded-read helpers and tests.
- Create: `packages/zigeffect/tools/causal_workbench.zig`
  - WebUI launcher.
- Create: `packages/zigeffect/workbench/index.html`
- Create: `packages/zigeffect/workbench/vite.config.ts`
- Create: `packages/zigeffect/workbench/tsconfig.json`
- Create: `packages/zigeffect/workbench/src/main.tsx`
- Create: `packages/zigeffect/workbench/src/App.tsx`
- Create: `packages/zigeffect/workbench/src/causalArtifact.ts`
- Create: `packages/zigeffect/workbench/src/causalArtifact.test.ts`
- Create: `packages/zigeffect/workbench/src/styles.css`
- Create: `packages/zigeffect/workbench/public/sample-artifact.json`
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
- Modify: `packages/zigeffect/docs/causal-scenarios.md`
- Modify:
  `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

---

## Task 1: Add Solid Workbench Model Tests

**Files:**
- Create: `packages/zigeffect/workbench/src/causalArtifact.ts`
- Create: `packages/zigeffect/workbench/src/causalArtifact.test.ts`
- Create: `packages/zigeffect/workbench/tsconfig.json`

- [ ] **Step 1: Write failing Bun tests**

Add tests for:

- parsing a causal artifact JSON string;
- deriving schema/version/taxonomy metadata;
- sorting events by numeric id;
- deriving findings for missing service and failed cleanup examples;
- filtering by text/kind/status;
- generating `zig build causal-query -- --file <artifact> ...` commands;
- tolerating missing optional fields.

- [ ] **Step 2: Run tests and verify red**

Run:

```sh
bun test --timeout 30000 packages/zigeffect/workbench/src
```

Expected: FAIL because the model implementation is incomplete.

- [ ] **Step 3: Implement the model**

Implement:

- `parseArtifactJson`;
- `deriveWorkbenchModel`;
- `filterEvents`;
- `queryCommandsForEvent`;
- defensive coercion helpers for id/kind/status/run/scope/fiber/parent fields;
- small derived finding heuristics.

- [ ] **Step 4: Verify green**

Run:

```sh
bun test --timeout 30000 packages/zigeffect/workbench/src
```

Expected: PASS.

- [ ] **Step 5: Commit**

Commit message:

```sh
test(zigeffect): specify solid causal workbench model
```

---

## Task 2: Build The Solid UI Shell

**Files:**
- Create: `packages/zigeffect/workbench/index.html`
- Create: `packages/zigeffect/workbench/vite.config.ts`
- Create: `packages/zigeffect/workbench/src/main.tsx`
- Create: `packages/zigeffect/workbench/src/App.tsx`
- Create: `packages/zigeffect/workbench/src/styles.css`
- Create: `packages/zigeffect/workbench/public/sample-artifact.json`
- Modify: `package.json`
- Modify: `bun.lock`
- Modify: `tsconfig.json`

- [ ] **Step 1: Add scripts and dependencies**

Use Bun to add:

- `solid-js`;
- `vite`;
- `vite-plugin-solid`.

Add scripts:

```json
{
  "zigeffect:workbench:dev": "vite --config packages/zigeffect/workbench/vite.config.ts --host 127.0.0.1",
  "zigeffect:workbench:build": "vite build --config packages/zigeffect/workbench/vite.config.ts",
  "zigeffect:workbench:typecheck": "bunx tsc --noEmit -p packages/zigeffect/workbench/tsconfig.json",
  "zigeffect:workbench:test": "bun test --timeout 30000 packages/zigeffect/workbench/src"
}
```

Wire `bun run check` to include the workbench typecheck and test without
breaking the existing Preact/Astro marketing app.

- [ ] **Step 2: Implement the app shell**

Implement:

- WebUI bridge call for `zigeffect_load_artifact` and
  `zigeffect_load_session`;
- browser/Vite fallback using `public/sample-artifact.json`;
- top toolbar;
- left tab/filter rail;
- timeline;
- findings view;
- relationship graph/list view;
- query command view;
- metadata view;
- event inspector;
- read-only safety labels.

- [ ] **Step 3: Verify UI build**

Run:

```sh
bun run zigeffect:workbench:test
bun run zigeffect:workbench:typecheck
bun run zigeffect:workbench:build
```

Expected: PASS and `packages/zigeffect/workbench/dist/index.html` exists.

- [ ] **Step 4: Commit**

Commit message:

```sh
feat(zigeffect): add solid causal workbench renderer
```

---

## Task 3: Add Pure Zig Workbench Session Module

**Files:**
- Create: `packages/zigeffect/tools/causal_workbench_session.zig`
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Write failing Zig tests**

Tests should cover:

- `usage()` includes `zig build causal-workbench -- <artifact.json>`;
- `usage()` includes `zig build causal-workbench -- --server-only <artifact.json>`;
- launch argument parsing accepts normal window mode and explicit server-only
  mode;
- stable `default_workbench_root`;
- stable `default_index_path`;
- `workbench_schema = "zigeffect.causal.workbench-session.v1"`;
- session JSON includes `read_only: true`;
- session JSON includes selected artifact path and byte length;
- oversized artifact handling returns a typed error or warning.

- [ ] **Step 2: Run tests and verify red**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_workbench_session.zig
```

Expected: FAIL before implementation.

- [ ] **Step 3: Implement session helpers**

Implement:

- constants;
- `usage`;
- `formatSessionJson`;
- bounded artifact reader;
- typed errors for invalid arguments, missing artifact, and oversized artifact.

- [ ] **Step 4: Wire tests into `build.zig`**

Add a module and unit test run artifact, and depend on it from the existing
`test` and `examples` verification steps.

- [ ] **Step 5: Verify green**

Run:

```sh
cd packages/zigeffect
zig build test-raw --summary none
zig build test --summary none
```

Expected: PASS.

- [ ] **Step 6: Commit**

Commit message:

```sh
test(zigeffect): specify causal workbench session bridge
```

---

## Task 4: Add Zig WebUI Launcher

**Files:**
- Create: `packages/zigeffect/build.zig.zon`
- Create: `packages/zigeffect/tools/causal_workbench.zig`
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Pin `zig-webui`**

Create `packages/zigeffect/build.zig.zon` with a pinned `zig_webui` dependency.
Use the upstream package that supports Zig 0.16. Keep the dependency scoped to
the zigeffect package.

- [ ] **Step 2: Implement the launcher**

Implement:

- argument validation;
- bounded artifact read through `causal_workbench_session`;
- null-terminated WebUI response payloads;
- `zigeffect_load_artifact` binding;
- `zigeffect_load_session` binding;
- root folder set to `workbench/dist`;
- window size and title;
- `index.html` launch;
- local WebUI server fallback if native window launch fails;
- explicit `--server-only` mode for agent/browser smoke testing;
- no writeback operations.

- [ ] **Step 3: Wire build steps**

Add:

- `causal-workbench-ui`: runs `bun run zigeffect:workbench:build` from repo
  root;
- `causal-workbench`: depends on UI build, then runs the WebUI executable with
  forwarded args;
- optional executable compile dependency in `examples` without opening the UI.

- [ ] **Step 4: Verify launcher**

Run:

```sh
cd packages/zigeffect
zig build causal-test
zig build causal-workbench -- .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json
zig build causal-workbench -- --server-only .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json
```

Expected: the workbench opens in a WebUI browser/WebView window when available.
In environments where native launch is unavailable, the command prints a local
WebUI server URL. `--server-only` always starts the local read-only server and
prints the URL for deterministic agent/browser inspection.

- [ ] **Step 5: Commit**

Commit message:

```sh
feat(zigeffect): launch causal workbench with zig webui
```

---

## Task 5: Docs, Roadmap, And Agent Usage

**Files:**
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
- Modify: `packages/zigeffect/docs/causal-scenarios.md`
- Modify:
  `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Document commands**

Document:

```sh
cd packages/zigeffect
zig build causal-test
zig build causal-workbench -- .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json
zig build causal-workbench -- --server-only .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json
```

- [ ] **Step 2: Document safety boundary**

State that the workbench is local, read-only, bounded, and non-mutating. State
that copyable commands are advisory and must be run explicitly.

- [ ] **Step 3: Update roadmap**

Mark the first M6 workbench slice delivered. Advance the next recommended
branch to richer graph/remediation-chain visualization, then NenDB-backed
artifact indexing.

- [ ] **Step 4: Commit**

Commit message:

```sh
docs(zigeffect): document solid causal workbench
```

---

## Task 6: Final Verification

- [ ] Run frontend verification:

```sh
bun run zigeffect:workbench:test
bun run zigeffect:workbench:typecheck
bun run zigeffect:workbench:build
```

- [ ] Run Zig verification:

```sh
cd packages/zigeffect
zig build examples
zig build causal-snapshot
zig build test --summary none
zig build causal-test
zig build causal-workbench -- .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json
```

- [ ] Run repository verification:

```sh
bun run check
bun run zig:test
git diff --check HEAD
```

- [ ] Browser/UI check:
  - page is nonblank;
  - tabs render;
  - events appear;
  - search/filter works;
  - selecting an event updates the inspector;
  - no mutation controls are visible.

- [ ] Confirm no active Cockroach causal backend work was added:

```sh
rg -n "Cockroach|RoachGraph|cockroach_history" packages/zigeffect docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
```

Expected: no active M6/M7 workbench backend scope; future durable indexing names
NenDB first.
