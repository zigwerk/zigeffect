# zigeffect Durable Queue Design

Date: 2026-06-09

## Purpose

Milestone 16 adds a local durable queue on top of the workflow journal. It lets
workflows enqueue durable work and wait for completion, while workers can claim,
complete, fail, retry expired claims, and ack items through append-only events.

## Design

Add `workflow/queue.zig`:

- `Queue(name, Payload, Success, Failure)`;
- queue metadata with claim timeout and max concurrency;
- stable `queueItemId(queue_name, idempotency_key)`;
- `DurableQueue`;
- `QueueClaim(Payload)`;
- `QueueAwaitResult(Success, Failure)`.

Add one journal event kind:

```text
queue_retry_scheduled
```

Existing queue rows remain stable:

- `queue_offered`: payload detail encoded through `Codec(Payload)`;
- `queue_claimed`: claim/worker metadata in redacted detail;
- `queue_completed`: success detail encoded through `Codec(Success)`;
- `queue_failed`: failure detail using existing `Exit`/`Cause` formatting;
- `queue_retry_scheduled`: expired claim is ready to be claimed again;
- `queue_acked`: workflow or caller has observed terminal completion/failure.

`DurableQueue.offer(QueueType, payload_codec, payload)` appends
`queue_offered` once per queue item id. Queue items require a typed
idempotency-key callback, mirroring workflow/activity definitions.

`DurableQueue.claim(QueueType, payload_codec, worker_id)` scans journal state,
respects `QueueType.max_concurrency`, finds the oldest offered or retry-ready
item, appends `queue_claimed`, and returns the decoded payload. Active claims
are queue items whose latest state is claimed.

`DurableQueue.retryExpiredClaims(QueueType)` scans claimed rows whose
`claim_deadline_ms` is due and appends `queue_retry_scheduled`. This is local
and deterministic; distributed ownership arrives in the cluster milestones.

`WorkflowContext.queue(QueueType, payload_codec, result_codec, payload)` offers
the item if absent, returns completed results on replay, appends `queue_acked`
after observing completion/failure, or suspends with `SuspensionKind.queue`
while the item is pending. `DurableQueue.complete` and `fail` wake suspended
workflows with `workflow_resumed`.

## Acceptance

- Queue definitions expose metadata, idempotency requirement, claim timeout,
  max concurrency, and stable item ids.
- Offer is idempotent by typed payload key.
- Claim respects max concurrency.
- Complete, fail, retry, and ack are durable events.
- Claim timeout schedules retry and makes the item claimable again.
- Queue items survive `FileJournalStore` reopen.
- Workflow queue await suspends, resumes after completion, returns decoded
  success, and replays without duplicate ack rows.
- `bun run zigeffect:test` passes.
- `cd packages/zigeffect && zig build examples` passes.
- `bun run zig:test` passes.
- Milestone 16 is marked complete in the roadmap.
