# zigeffect Local Agent Artifact Capture Design

## Goal

Turn local agent command output into redacted, linkable evidence for the
workbench Dev Session tab.

## Decision

Extend the Bun-local agent runtime with an optional artifact sink. When a tool
produces stdout, stderr, or a runner exception, the runtime writes redacted text
artifacts through the sink, emits `artifact_link` events, and attaches the first
artifact path to the related `check_result`.

The sink is an interface, not hard-coded file IO:

- Tests use an in-memory sink.
- Local usage can use a Bun-backed sink that writes text files to a caller-owned
  artifact directory.

## Architecture

`LocalAgentRuntimeArtifactSink` receives a sanitized artifact descriptor with a
safe filename, key, stream type, tool id, and redacted content. It returns the
artifact path that should be advertised to the workbench.

`runLocalAgentRuntime` remains the orchestration point:

1. Emit `agent_status:running`.
2. Run the configured command through the selected runner.
3. Write stdout/stderr/error artifacts when a sink exists.
4. Emit `artifact_link` events for written artifacts.
5. Emit the final `check_result` with `artifact_path`.
6. Emit `agent_status:done` or `agent_status:failed`.

The runtime redacts content before the sink sees it, so even a naive sink cannot
persist sentinel secrets.

## Non-Goals

- Do not build interactive terminal transcript capture yet.
- Do not tail long-running processes yet.
- Do not introduce hosting or durable storage.

## Acceptance Criteria

- Tests prove stdout/stderr artifacts are redacted before sink writes.
- Tests prove artifact links are emitted before the related check result.
- Tests prove runner exceptions can produce redacted error artifacts.
- Tests prove the Bun artifact sink writes redacted files with safe filenames.
