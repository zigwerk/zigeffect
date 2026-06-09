# zigeffect Workflow Inspector CLI Design

Date: 2026-06-09

## Purpose

Milestone 18 makes local durable workflow state understandable to humans and
agents. It adds reusable inspection logic plus three build-run CLI steps:
`workflow-journal-inspect`, `workflow-replay`, and `workflow-list`.

The tools read either fixture JSON Lines files or real `FileJournalStore`
directories. They produce deterministic text for humans and JSON reports for
agent consumption.

## Design

Add `workflow/inspect.zig` as the reusable module. It owns:

- journal event grouping by `(workflow_id, execution_id)`;
- execution summaries for list output;
- replay-state reports for a selected execution;
- pending timer, deferred, queue, and activity summaries;
- last failure or terminal-cause extraction from workflow, activity, step,
  queue, deferred, timer, and lifecycle rows;
- text and JSON report formatting.

The module accepts event batches, not concrete stores. Tools can therefore load
events from:

- an in-memory fixture file made of the existing workflow journal JSON row
  format; or
- a real append-only journal directory through `FileJournalStore.open`.

The default selection behavior is conservative:

- `workflow-list` always lists all execution summaries found in the event
  stream.
- `workflow-replay` and `workflow-journal-inspect` select the only execution
  when exactly one execution is present.
- when multiple executions are present, those commands require both
  `--workflow-id` and `--execution-id`.

## CLI Shape

All three commands use the existing Zig build-tool argument forwarding pattern:

```bash
cd packages/zigeffect && zig build workflow-list -- --fixture path/to/events.jsonl
cd packages/zigeffect && zig build workflow-replay -- --journal-dir path/to/journal --format json
cd packages/zigeffect && zig build workflow-journal-inspect -- --fixture path/to/events.jsonl --format text
```

Accepted input flags:

- `--fixture <path>` reads newline-delimited workflow event JSON rows into an
  in-memory event batch.
- `--journal-dir <path>` opens a `FileJournalStore` directory and reads its
  recovered events.

Accepted output flags:

- `--format text` emits stable human-readable reports.
- `--format json` emits schema-versioned JSON reports.

## Report Shape

The JSON schema names are:

- `zigeffect.workflow.inspect.v1`
- `zigeffect.workflow.replay.v1`
- `zigeffect.workflow.list.v1`

Reports include:

- schema and schema version;
- event count and sequence range;
- execution summaries;
- selected workflow id and execution id when a single execution is replayed;
- workflow status, last sequence, and workflow name;
- pending timers, deferreds, queues, and activities;
- last failure detail when a failure, defect, interruption, cancellation, or
  failed durable work row exists.

Text output mirrors the same data with stable labels so shell tests can assert
specific lines.

## Error Behavior

CLI errors are deterministic:

- missing input returns `error.MissingWorkflowJournalInput`;
- both `--fixture` and `--journal-dir` return `error.ConflictingWorkflowJournalInput`;
- unknown format returns `error.InvalidWorkflowReportFormat`;
- multiple executions without explicit selection return
  `error.AmbiguousWorkflowExecution`;
- selecting an absent execution returns `error.UnknownWorkflowExecution`.

Malformed fixture rows reuse `parseWorkflowEventJson` errors. Real journal
corruption reuses `FileJournalStore` recovery errors.

## Acceptance

- `workflow/inspect.zig` formats text and JSON reports for fixture events.
- Reports include formatted state, pending timers, pending deferreds, pending
  queues, pending activities, and last failure detail.
- `workflow-list` lists fixture and file-journal executions.
- `workflow-replay` replays fixture and file-journal state.
- `workflow-journal-inspect` prints selected execution events and report
  metadata.
- Build steps accept forwarded args.
- CLI tests cover fixture files and real file journals.
- Milestone 18 is marked complete in the roadmap after the full gate passes.
