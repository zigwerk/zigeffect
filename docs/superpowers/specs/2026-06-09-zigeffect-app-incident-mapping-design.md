# zigeffect App Incident Mapping Design

Date: 2026-06-09

## Purpose

This M7 slice turns app-facing causal traces into stable app incident
categories. The previous branches added `CausalAppTrace` and a Worker-shaped app
request example. Agents can now see app events, but advice and diagnosis still
treat app failures as generic assertion failures or generic missing services.

This branch adds a small app incident classifier and app-aware advice/diagnosis
mappings while preserving the existing `zigeffect.causal.v1` event taxonomy.

## Scope

In scope:

- classify app incidents from existing `CausalEvent` fields;
- expose classifier types from `zigeffect`;
- add tests for config, requirement, response, retry, resource, and fiber app
  incidents;
- teach `causal-advice` to emit app-specific actions where the event is clearly
  app-owned;
- teach `causal-diagnosis` to map those actions to app subsystems and patch
  prompts;
- document the app incident mapping path.

Out of scope:

- new `CausalEventKind` values;
- a new app artifact schema;
- workbench UI changes;
- app remediation artifacts or policy gates;
- Yachdee TypeScript Worker instrumentation.

## Incident Model

Add these types to `packages/zigeffect/src/services/causal_app_runtime.zig`:

```zig
pub const CausalAppIncidentKind = enum {
    missing_config,
    missing_requirement,
    failed_response,
    retry_exhausted,
    resource_leak,
    finalizer_failure,
    fiber_unresolved,
};

pub const CausalAppIncident = struct {
    kind: CausalAppIncidentKind,
    event_id: u64,
    run_id: ?u64 = null,
    scope_id: ?u64 = null,
    fiber_id: ?u64 = null,
    label: []const u8 = "",
    type_name: []const u8 = "",
    redacted_detail: []const u8 = "",
};

pub const CausalAppIncidents = struct {
    allocator: std.mem.Allocator,
    items: []CausalAppIncident,
    pub fn deinit(self: *CausalAppIncidents) void;
};

pub fn deriveCausalAppIncidents(
    allocator: std.mem.Allocator,
    store: *const causal.CausalStore,
) !CausalAppIncidents;
```

Classification rules:

- `assertion_recorded` with status `failure`, label `YACHDEE_ENV` or
  `redacted_detail` `app.config.required` -> `missing_config`;
- `assertion_recorded` with status `failure`, detail
  `app.requirement.required` -> `missing_requirement`;
- `span_recorded` with type `zigeffect.app.response` and status beginning with
  `5` -> `failed_response`;
- `schedule_decision` with type `zigeffect.app.retry` and status `exhausted`
  -> `retry_exhausted`;
- `resource_acquired` with no matching `resource_finalized` for same
  `scope_id` and `type_name` -> `resource_leak`;
- `resource_finalized` with status `failure` -> `finalizer_failure`;
- `fiber_forked` or `fiber_started` with status `pending` or `running` and no
  later `fiber_joined`/`fiber_interrupted` for same fiber -> `fiber_unresolved`.

The classifier only owns cloned strings in its result. It never mutates the
store and never depends on filesystem or process APIs.

## Advice And Diagnosis

Extend `causal-advice` with app-aware actions:

- `fix-app-config`
- `wire-app-requirement`
- `inspect-app-response-failure`
- `inspect-app-retry-exhaustion`
- `close-app-resource`
- `resolve-app-fiber`

The existing generic actions remain for core runtime artifacts. App-specific
actions should win only when type names or details clearly identify app events.

Extend `causal-diagnosis` mappings:

- app config -> `app_config`, `config-or-secret-binding`;
- app requirement -> `app_service_layer`, `service-provider-or-layer`;
- app response failure -> `app_request_path`, `response-or-handler-failure`;
- app retry exhaustion -> `app_dependency`, `retry-policy-or-upstream`;
- app resource leak -> `app_resource_scope`, `resource-finalizer`;
- app fiber unresolved -> `app_fiber_runtime`, `structured-concurrency`.

## Testing

Tests should prove:

- classifier derives incidents from `CausalAppTrace` events and the
  `causal_app_request` example;
- classifier result owns cloned strings and can be deinitialized;
- `causal-advice` emits app-specific actions for app artifacts while preserving
  generic actions for existing fixtures;
- `causal-diagnosis` maps app actions to app subsystems and fix categories;
- existing workbench tests remain green because artifacts are still standard
  causal JSON.

Verification commands:

```bash
cd packages/zigeffect && zig build causal-app-runtime
cd packages/zigeffect && zig build causal-advice
cd packages/zigeffect && zig build causal-diagnosis
cd packages/zigeffect && zig build test
bun run zigeffect:workbench:test
bun run zigeffect:workbench:typecheck
```

## Future Work

- Workbench app incident panel after the classifier proves stable.
- App remediation audit artifacts that cite incident kind, event ids, and
  required policy gates.
- Real Yachdee platform instrumentation after the Zig runtime has an honest app
  integration path.

## Self-Review

- Scope is one classifier/advice/diagnosis branch, not M8 remediation.
- Compatibility is preserved: no new event kinds and no new causal JSON schema.
- The example branch provides concrete app evidence for tests.
- The next branch should move to app remediation audit only after app incident
  mapping is verified.
