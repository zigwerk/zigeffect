# zigeffect Causal Sampling Implementation Plan

Date: 2026-06-07

## Goal

Add explicit opt-in sampling for high-volume causal observability events so the
development-agent harness can stay enabled during longer zigeffect work without
burying causal runtime evidence.

## Architecture

Extend `CausalStoreOptions` with `CausalSamplingPolicy`. The store tracks
per-kind observability counters and a total sampled-out count. `record` allocates
an event ID first, applies deterministic sampling for log, metric, and span
events, and returns the ID even when the event is skipped. Skipped events are not
cloned, retained, emitted to backends, or included in artifacts.

Reports and JSON disclose sampling state beside retention metadata.

## Files

- `packages/zigeffect/src/services/causal.zig`
- `packages/zigeffect/src/zigeffect.zig`
- `packages/zigeffect/test/services_test.zig`
- `packages/zigeffect/README.md`
- `packages/zigeffect/docs/agent-observable-runtime.md`
- `packages/zigeffect/docs/agent-guide.md`
- `packages/zigeffect/docs/roadmap.md`

## TDD Steps

### 1. Add RED tests for sampling behavior

Add tests that prove:

- `log_recorded` every 2 and `metric_recorded` every 3 retain only the expected
  events;
- structural events are still retained;
- sampled-out events consume IDs;
- attached backends receive only retained sampled-in events;
- `sampledEventCount()` reports the sampled-out total.

Expected result: compile failure because the sampling option and method do not
exist yet.

### 2. Add RED tests for artifact metadata

Add tests that prove:

- JSON artifacts include a root `sampling` object;
- sampled-out event labels are absent from JSON;
- retained sampled-in event labels remain present;
- CI reports disclose `log_every_n`, `metric_every_n`, `span_every_n`, and
  `sampled_events`.

Expected result: compile failure and/or assertion failure until formatting is
implemented.

## Implementation Steps

### 1. Add sampling types

Add:

```zig
pub const CausalSamplingPolicy = struct {
    log_every_n: ?usize = null,
    metric_every_n: ?usize = null,
    span_every_n: ?usize = null,
};
```

Extend `CausalStoreOptions`:

```zig
pub const CausalStoreOptions = struct {
    max_events: ?usize = null,
    sampling: CausalSamplingPolicy = .{},
};
```

Re-export `CausalSamplingPolicy` from `zigeffect.zig`.

### 2. Add store state and accessors

Add to `CausalStore`:

```zig
sampling: CausalSamplingPolicy = .{},
sampled_event_count: u64 = 0,
log_seen_count: u64 = 0,
metric_seen_count: u64 = 0,
span_seen_count: u64 = 0,
```

Add:

```zig
pub fn sampledEventCount(self: *const CausalStore) u64 {
    return self.sampled_event_count;
}
```

### 3. Apply deterministic sampling in `record`

Change `record` so it:

1. allocates and increments `next_event_id`;
2. checks sampleability;
3. increments `sampled_event_count` and returns the allocated ID for skipped
   events;
4. clones, redacts, stores, emits to backend, and trims only retained events.

Sampling helper behavior:

- `null` or `0` means record every event of that kind;
- only `log_recorded`, `metric_recorded`, and `span_recorded` are sampled;
- every other kind records unconditionally.

### 4. Format sampling metadata

Add a text helper:

```text
sampling: log_every_n=off metric_every_n=off span_every_n=2 sampled_events=1
```

Call it from `formatCausalReport` and `formatCausalCiReport` immediately after
retention.

Add JSON root metadata:

```json
"sampling": {
  "log_every_n": null,
  "metric_every_n": null,
  "span_every_n": 2,
  "sampled_events": 1
}
```

### 5. Update docs

Document that sampling:

- is opt-in;
- applies only to logs, metrics, and spans;
- keeps structural causal evidence;
- causes event ID gaps;
- is separate from retention truncation.

Update roadmap delivered/future bullets.

## Verification

Run:

```bash
cd packages/zigeffect && zig build test --summary none
cd packages/zigeffect && zig build examples
bun run zig:test
cd packages/zigeffect && zig build causal-dev-loop -- baseline
cd packages/zigeffect && zig build causal-dev-loop -- after
git diff --check
```

## Commit Plan

1. Commit the design and plan:
   `docs(zigeffect): plan causal event sampling`
2. Commit implementation and docs:
   `feat(zigeffect): add causal event sampling policy`

## Risks

- Event ID gaps could surprise tools that assume dense IDs. The artifact
  metadata and tests make gaps intentional.
- Future event kinds could be high-volume but unsampled. Default retain is the
  safer compatibility posture until taxonomy rules are formalized.
- Sampling before cloning means skipped text is not redacted. This is acceptable
  because skipped events are not retained or emitted; callers still must avoid
  secrets.
