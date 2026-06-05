# zigeffect Test Assertion Reports Design

Date: 2026-06-05

## Goal

Make deterministic test failures easier for agents and humans to diagnose by
adding readable assertion report formatters to the test toolkit.

## Design

Add focused report formatters in `packages/zigeffect/src/testing/test_env.zig`
instead of changing core runtime behavior:

- `TestEnv.formatLogAssertionReport(expected)`
- `fx.testing.formatScheduleDelayAssertionReport(allocator, attempt, expected, actual)`
- `fx.testing.formatFiberStatusAssertionReport(allocator, expected, actual)`
- `fx.testing.formatQueueStateAssertionReport(allocator, expected_len, actual_len, expected_shutdown, actual_shutdown)`

Reports use one stable shape:

```text
zigeffect test assertion failed
assertion: ...
expected: ...
actual: ...
details:
...
```

Existing `expect*` helpers stay available. This slice adds report generation
that callers can print, snapshot, or include in higher-level harness failures
without changing current helper signatures.

## Non-Goals

- Do not replace `std.testing` assertions globally.
- Do not add a custom test runner.
- Do not make assertions allocate unless the caller explicitly asks for a
  formatted report.

## Tests

Add focused tests in `packages/zigeffect/test/dependency_test.zig` that assert
the generated reports include the assertion name, expected value, actual value,
and relevant context.
