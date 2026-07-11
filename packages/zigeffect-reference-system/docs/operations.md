# Reference Orders Operations

This runbook operates the production-candidate reference topology: API, worker,
Postgres or CockroachDB, Redis Streams, S3-compatible storage, authenticated TLS
transport, and an OTLP collector. The immutable regression budgets are in
`operations/budgets.v1.json`; alert and dashboard contracts sit beside it.

## Release and health contract

`GET /health/live` proves that the API process can serve. `GET /health/ready`
is eligible for traffic only after configuration, secret resolution, database
migrations, external clients, telemetry, and lifecycle startup complete. During
drain readiness must become false before accepted work is forced closed.

Run `bash test/check_release_evidence.sh` for the local evidence gate. Run
`bash test/run_process_stack.sh` for the independent-process topology,
`bash test/run_load_conformance.sh` for the bounded load gate, and
`bash test/run_soak_conformance.sh` for the scheduled soak lane. No skipped,
unsupported, incomplete, or truncated required receipt is a pass.

## API or worker not ready

1. Read lifecycle facts and the first classified external failure, never raw
   secret values or terminal dumps.
2. Verify Postgres, Redis, S3, transport certificate files, and the collector.
3. Compare the running capability profile to `zigeffect.project.json`.
4. If startup cannot complete inside 60 seconds, keep the instance out of
   service and roll back to the last receipt-backed artifact.

## Order processing failures

Query the order, custom outbox row, workflow journal stream, Redis pending entry,
and object checksum by the same idempotency key. A committed order may be safely
redispatched; Redis publication and workflow journal appends are idempotent.
Never delete an order to clear an incident. Preserve the normalized trace and
Testing v2 replay command in the incident record.

## Outbox or broker backlog

Confirm database connectivity and Redis authentication. Inspect pending outbox
rows and Redis consumer-group ownership. Replay the dispatcher; do not mark an
outbox row dispatched without observing the broker acknowledgement. A delayed
nack is Redis-scheduled and must not block the worker thread.

## Lease loss

Stop writes from the stale epoch immediately. Confirm the database clock,
current owner, expiry, and epoch in `reference_runner_leases`. Restart the stale
worker only after its old process is gone. The journal rejects stale fences; do
not manually lower an epoch.

## Telemetry outage

The exporter retains the failed head item in its bounded queue and retries after
collector recovery. At 80% queue utilization reduce optional telemetry volume;
at capacity preserve application availability and record dropped counts. Never
claim complete traces while drops, truncation, or export failures are present.

## Backup and restore drill

1. Quiesce API writes and drain workers.
2. Take a provider-native consistent Postgres/Cockroach backup and record its
   restore timestamp, database version, migration checksum set, and object-store
   version/retention posture.
3. Restore into an isolated database, run migrations in status-only mode, start
   a fresh worker identity, and execute duplicate create/read plus journal replay.
4. Verify object checksums and Redis can be rebuilt from pending outbox records.
5. Publish a Testing v2 recovery receipt before promoting the restore.

Redis is delivery infrastructure, not canonical order storage. S3 data requires
provider versioning or backup policy outside this library. Backup credentials
are secret references and must be rotated after every real incident exercise.

## Migration and rollback drill

Apply only checksum-pinned migrations under the adapter migration lock. Test on
a restored backup first. Schema changes must be expand-compatible before service
deployment and contract only after all old binaries drain. Rollback means deploy
the previous compatible binary and, when explicitly authored, run its reviewed
down migration; the framework does not invent destructive rollback SQL.

## Credential and certificate rotation

Install the next secret or certificate, advance its epoch, reload transport
contexts, prove new connections, then revoke the old material. Keep overlap
bounded. Run the hostile auth/replay suite and scan logs/receipts after rotation.
Environment secrets use process epoch one, so rotate them through a new process;
managed stores should implement the `Secrets.Provider` contract.

## Retention and incident evidence

Keep release receipts and capability manifests immutably for the deployed
artifact lifetime plus the organization audit window. Retain causal and OTLP
data according to data classification, while preserving run id, adapter id,
failure class, source references, and replay command. Incident evidence must be
redacted before persistence and must state all drops and limitations.

## Incomplete release evidence

Stop promotion. Re-run the exact recorded command and inspect the first failed
assertion causal id. Do not refresh a snapshot or receipt merely to turn the
status green. A digest mismatch means the referenced evidence has changed and
the capability is unresolved until conformance is rerun and reviewed.
