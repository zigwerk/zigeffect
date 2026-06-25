# zigeffect-std Service Kernel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement `zstd.Service`, the effect-native service kernel that all EffectTS-grade `zigeffect-std` modules will use.

**Architecture:** Add `packages/zigeffect-std/src/service/root.zig` as a thin std-layer facade over existing core engine APIs: `fx.ServiceEnv`, `fx.Layer`, `fx.Effect`, `fx.Context`, `fx.ServiceSet`, and `Context.recordCausal`. The kernel provides typed provider/env helpers, service access effects with dependency metadata, and causal service fact helpers. It does not create a second runtime or dependency system.

**Tech Stack:** Zig 0.16, existing `packages/zigeffect` effect/layer/runtime APIs, existing `packages/zigeffect-std` package and Bun verification scripts.

---

## File Structure

- Create `packages/zigeffect-std/src/service/root.zig`: service provider/env/access/causal helpers plus tests.
- Modify `packages/zigeffect-std/src/root.zig`: export `Service`.
- Modify `packages/zigeffect-std/README.md`: document the service kernel.

## Task 1: Public Service Module and Provider

**Files:**
- Create: `packages/zigeffect-std/src/service/root.zig`
- Modify: `packages/zigeffect-std/src/root.zig`

- [ ] **Step 1: Write failing provider tests**

Add these tests in `packages/zigeffect-std/src/service/root.zig`:

```zig
test "Service.Provider resolves multiple services and exposes metadata" {}
test "Service.layerFromEnv provides services through fx.Layer" {}
```

The tests must prove:

- a provider containing `Console.CapturedConsole` and `Env.EnvMap` resolves both
  services through `provider.service(Service)`;
- `providedServices` contains both service type names;
- `layerFromEnv` runs an effect through an `fx.Layer` and resolves a service.

Run:

```sh
cd packages/zigeffect-std && zig build test
```

Expected: fail because `zstd.Service` is not exported and provider APIs are
missing.

- [ ] **Step 2: Implement provider/env helpers**

Implement:

```zig
pub fn Env(comptime services: anytype) type;
pub fn Provider(comptime services: anytype) type;
pub fn layerFromEnv(comptime ProviderEnv: type, env: *ProviderEnv, comptime services: anytype) @TypeOf(fx.layer.Layer(ProviderEnv).fromEnv(env).provides(services));
```

`Provider(.{ A, B })` must:

- store typed service pointers;
- implement `service(self, Requested)`;
- implement `providedServices(self, allocator)`;
- expose `layer(self)` that returns a provided layer.

- [ ] **Step 3: Verify provider tests**

Run:

```sh
cd packages/zigeffect-std && zig build test
```

Expected: provider tests pass.

## Task 2: Service Access Effects

**Files:**
- Modify: `packages/zigeffect-std/src/service/root.zig`

- [ ] **Step 1: Write failing access-effect tests**

Add tests:

```zig
test "Service.access returns an effect that requires and resolves the service" {}
test "Service.access participates in runtime dependency validation" {}
```

The tests must prove:

- `access(Service, Env)` returns `*Service`;
- `requiredServices` includes the service type;
- runtime execution succeeds when the provider supplies the service;
- runtime execution fails with `MissingServiceRequirement` when metadata says
  the service is absent.

Run:

```sh
cd packages/zigeffect-std && zig build test
```

Expected: fail because `access` is missing.

- [ ] **Step 2: Implement `access`**

Implement:

```zig
pub fn access(comptime Service: type, comptime EffectEnv: type) fx.effect.Effect(*Service, error{}, EffectEnv);
```

The returned effect must call `ctx.service(Service)` and declare
`.requires(.{Service})`.

- [ ] **Step 3: Verify access-effect tests**

Run:

```sh
cd packages/zigeffect-std && zig build test
```

Expected: tests pass.

## Task 3: Causal Service Facts

**Files:**
- Modify: `packages/zigeffect-std/src/service/root.zig`

- [ ] **Step 1: Write failing causal tests**

Add tests:

```zig
test "Service records required provided and operation causal facts" {}
test "Service operation details are redacted by the causal store" {}
```

The tests must prove:

- `recordRequired` records a `service_required` event with `service_key`;
- `recordProvided` records a `service_provided` event with `service_key`;
- `recordOperation` records a `span_recorded` event with `service_key`,
  operation label, status, and detail;
- secret-shaped detail is redacted in a store snapshot.

Run:

```sh
cd packages/zigeffect-std && zig build test
```

Expected: fail because causal helper APIs are missing.

- [ ] **Step 2: Implement causal helpers**

Implement:

```zig
pub fn serviceKey(comptime Service: type) []const u8;
pub fn recordRequired(ctx: anytype, comptime Service: type, detail: []const u8) ?u64;
pub fn recordProvided(ctx: anytype, comptime Service: type, detail: []const u8) ?u64;
pub fn recordOperation(ctx: anytype, comptime Service: type, operation: []const u8, status: []const u8, detail: []const u8) ?u64;
```

These helpers must call `ctx.recordCausal` and rely on the core `CausalStore` to
clone and redact event strings.

- [ ] **Step 3: Verify causal tests**

Run:

```sh
cd packages/zigeffect-std && zig build test
```

Expected: tests pass.

## Task 4: Docs and Gate

**Files:**
- Modify: `packages/zigeffect-std/README.md`
- Modify: `docs/superpowers/plans/2026-06-25-zigeffect-std-service-kernel.md`

- [ ] **Step 1: Update README**

Add `Service` to the module list and describe it as the effect-native service
kernel for providers, access effects, layers, and causal service facts.

- [ ] **Step 2: Mark plan checkboxes complete**

Replace every completed `- [ ]` in this plan with `- [x]`.

- [ ] **Step 3: Run final verification**

Run:

```sh
bun run zigeffect:std:test
bun run zigeffect:local-agent-gate
git diff --check
```

Expected: all commands exit 0.

