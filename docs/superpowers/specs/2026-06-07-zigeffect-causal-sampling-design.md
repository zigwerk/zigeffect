# zigeffect Causal Sampling Design

Date: 2026-06-07

## Problem

The causal runtime is now useful enough to leave enabled during local
development, dogfood scenarios, and future CI runs. Bounded retention caps
retained memory, but it does not reduce the volume of high-frequency events
entering the store or attached backends. Logs, metrics, and spans can become
noisy enough to obscure the structural runtime evidence that agents need most:
runs, effects, scopes, resources, fibers, schedules, services, exits, and
assertions.

The first sampling policy must make long-running probes practical without
weakening the core promise: agent-readable runtime causality remains
trustworthy.

## Goals

- Add an explicit opt-in sampling policy to `CausalStoreOptions`.
- Sample only high-volume observability event kinds in this first slice:
  `log_recorded`, `metric_recorded`, and `span_recorded`.
- Keep all structural and finding-bearing runtime events unsampled.
- Preserve deterministic behavior so before/after causal comparisons remain
  stable.
- Disclose sampling policy and sampled-out event counts in text, CI, and JSON
  artifacts.
- Keep the default store behavior unchanged and unsampled.
- Keep the existing `record` API shape stable.

## Non-Goals

- No probabilistic sampling.
- No adaptive sampling.
- No per-label, per-run, or per-trace selectors yet.
- No schema version bump unless the artifact reader requires one. Version 1 can
  tolerate additive root metadata.
- No durable backend sampling controls beyond deciding which events are emitted
  from this in-memory store.
- No attempt to sample events that can produce causal findings.

## Policy

Sampling is deterministic `every_n` sampling per high-volume kind:

```zig
pub const CausalSamplingPolicy = struct {
    log_every_n: ?usize = null,
    metric_every_n: ?usize = null,
    span_every_n: ?usize = null,
};

pub const CausalStoreOptions = struct {
    max_events: ?usize = null,
    sampling: CausalSamplingPolicy = .{},
};
```

For a configured kind, the store increments a per-kind seen counter and retains
only events whose counter is divisible by `every_n`. `null` and `0` mean
"sampling disabled" for that kind. This keeps options forgiving while avoiding
division by zero.

All other event kinds bypass sampling. In particular, the following classes are
always retained before retention trimming:

- run, effect, layer, service, scope, resource, fiber, schedule, exit, and
  assertion events;
- any future event kind that is not explicitly wired into the sampling policy.

This default-to-retain posture is important: newly added runtime evidence should
not disappear silently until the taxonomy intentionally classifies it as
sampleable.

## Event IDs

Sampled-out events still consume event IDs and `record` still returns the
allocated ID. This keeps the public API stable and makes trace gaps visible to
agents. A stored sequence such as `1, 3, 6, 7` means events existed between
retained citations; the artifact sampling metadata explains why those gaps
exist.

Sampled-out events are not cloned, retained, exported, or forwarded to attached
backends. This makes sampling useful for memory and backend-volume reduction.

## Artifact Contract

Text reports and CI reports include a sampling summary after retention:

```text
sampling: log_every_n=off metric_every_n=off span_every_n=2 sampled_events=1
```

JSON artifacts include root sampling metadata beside retention:

```json
{
  "schema": "zigeffect.causal.v1",
  "schema_version": 1,
  "retention": {
    "max_events": null,
    "dropped_events": 0,
    "oldest_retained_event_id": null
  },
  "sampling": {
    "log_every_n": null,
    "metric_every_n": null,
    "span_every_n": 2,
    "sampled_events": 1
  },
  "events": []
}
```

Agents should treat `sampled_events > 0` differently from
`dropped_events > 0`:

- `sampled_events` means high-volume observability evidence may be incomplete,
  but structural runtime evidence should still be present.
- `dropped_events` means the retained in-memory trace window is truncated and
  parent chains or finding context may be missing.

## Development-Agent Use Cases

- Keep causal capture enabled during `zig build causal-dev-loop` without
  flooding artifacts with repetitive log, metric, or span events.
- Let an agent compare before/after traces and distinguish intentional
  observability sampling from runtime regressions.
- Allow future CI jobs to use bounded memory and reduced artifact volume while
  still keeping resource, fiber, service, schedule, and assertion evidence.
- Make gaps explicit enough that agents can avoid overclaiming evidence.

## Acceptance Criteria

- `CausalStore.init` remains unsampled.
- `CausalStore.initWithOptions(... .sampling = ...)` can sample logs, metrics,
  and spans independently.
- Structural events are retained even when observability sampling is enabled.
- Sampled-out events increment `sampledEventCount()`.
- Sampled-out events consume IDs, but do not appear in snapshots, reports, JSON,
  DOT, or attached backends.
- JSON, text report, and CI report disclose sampling policy and sampled counts.
- Existing retention behavior and redaction behavior continue to pass.

## Future Directions

- Add named presets such as `observabilityEvery(10)` once more call sites exist.
- Add event taxonomy compatibility docs that define which new event kinds are
  sampleable, structural, or finding-bearing.
- Add adaptive sampling controlled by artifact size budgets.
- Add per-run or per-trace selectors for app-level debugging.
- Add backend-specific policy hooks for durable stores that want to retain raw
  streams independently from local memory.
