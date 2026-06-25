# zigeffect-std Effect-Native Boundaries Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert `Env`, `Config`, `Secrets`, `Json`, and `Jsonl` from plain helpers into effect-native std services using `zstd.Service`.

**Architecture:** Keep existing helper APIs intact and add effect-like values that carry runtime inputs, declare `requiredServices`, resolve services through `ctx.service`, and record service-operation causal facts through `zstd.Service.recordOperation`. Tests use `zstd.Service.Provider` and `fx.Runtime` to prove dependency validation and effect execution.

**Tech Stack:** Zig 0.16, `zstd.Service`, existing std modules, existing `fx.Runtime` validation, `bun run zigeffect:std:test`.

---

## File Structure

- Modify `packages/zigeffect-std/src/env/root.zig`: add `requireEffect`.
- Modify `packages/zigeffect-std/src/config/root.zig`: add `requireEffect` and `displayEffect`.
- Modify `packages/zigeffect-std/src/secrets/root.zig`: add `Redactor` service and `redactEffect`.
- Modify `packages/zigeffect-std/src/json/root.zig`: add `Codec` service and `objectEffect`.
- Modify `packages/zigeffect-std/src/jsonl/root.zig`: add `Codec` service and `appendEffect`.
- Modify `packages/zigeffect-std/README.md`: describe effect-native boundary service APIs.

## Task 1: Env and Config Effects

- [ ] **Step 1: Write failing tests**

Add tests:

```zig
test "Env requireEffect resolves through runtime services and records causal fact" {}
test "Config requireEffect and displayEffect resolve through runtime services" {}
```

Run:

```sh
cd packages/zigeffect-std && zig build test
```

Expected: fail because effect APIs are missing.

- [ ] **Step 2: Implement Env/Config effect APIs**

Implement:

```zig
pub fn requireEffect(comptime EffectEnv: type, name: []const u8) RequireEffect(EffectEnv);
pub fn displayEffect(comptime EffectEnv: type, key: []const u8) DisplayEffect(EffectEnv);
```

Each effect must declare `requiredServices` and call `Service.recordOperation`.

- [ ] **Step 3: Verify**

Run:

```sh
cd packages/zigeffect-std && zig build test
```

Expected: tests pass.

## Task 2: Secrets, Json, and Jsonl Effects

- [ ] **Step 1: Write failing tests**

Add tests:

```zig
test "Secrets redactEffect uses Redactor service and records causal fact" {}
test "Json objectEffect uses Codec service and records causal fact" {}
test "Jsonl appendEffect uses Codec service and records causal fact" {}
```

Run:

```sh
cd packages/zigeffect-std && zig build test
```

Expected: fail because effect APIs are missing.

- [ ] **Step 2: Implement effects**

Implement:

```zig
pub const Redactor = struct { ... };
pub fn redactEffect(comptime EffectEnv: type, input: []const u8) RedactEffect(EffectEnv);

pub const Codec = struct { ... };
pub fn objectEffect(comptime EffectEnv: type, fields: []const Field) ObjectEffect(EffectEnv);
pub fn appendEffect(comptime EffectEnv: type, existing: []const u8, record_json: []const u8) AppendEffect(EffectEnv);
```

Each effect must declare `requiredServices` and call `Service.recordOperation`.

- [ ] **Step 3: Verify**

Run:

```sh
cd packages/zigeffect-std && zig build test
```

Expected: tests pass.

## Task 3: Docs and Gate

- [ ] **Step 1: Update README**

Mention that `Env`, `Config`, `Secrets`, `Json`, and `Jsonl` now expose
effect-native service APIs.

- [ ] **Step 2: Mark checkboxes complete**

Replace completed `- [ ]` with `- [x]`.

- [ ] **Step 3: Final verification**

Run:

```sh
bun run zigeffect:std:test
bun run zigeffect:local-agent-gate
git diff --check
```

Expected: all commands exit 0.

