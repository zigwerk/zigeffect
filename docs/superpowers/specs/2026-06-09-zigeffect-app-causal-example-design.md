# zigeffect App Causal Example Design

Date: 2026-06-09

## Purpose

This M7 slice proves the app-facing causal runtime adapter in a small
Worker-shaped example. The example should show how an application request path
can record causal events, return a normal response, and hand the exported
`zigeffect.causal.v1` JSON to a caller-owned sink without using Bun-only,
filesystem, process, socket, or platform-specific APIs.

The example is not a TypeScript Cloudflare Worker integration. The current
Yachdee Worker lives in TypeScript and cannot honestly import the Zig
`zigeffect` package yet. This branch keeps the example inside the Zig package
so the adapter can be tested directly and copied into future Zig or native app
surfaces.

## Location

Create:

- `packages/zigeffect/examples/causal_app_request.zig`

Wire it into:

- `packages/zigeffect/build.zig`
- `packages/zigeffect/README.md`
- `packages/zigeffect/docs/agent-guide.md`
- `packages/zigeffect/docs/agent-observable-runtime.md`
- `packages/zigeffect/docs/roadmap.md`
- `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

## Example Shape

The request path is a pure function:

```zig
pub fn handleRequest(
    allocator: std.mem.Allocator,
    request: AppRequest,
    env: AppEnv,
) !AppIncident
```

It returns an `AppIncident` that owns:

- `response: AppResponse`
- `causal_json: []const u8`

The caller owns deinitialization and decides where to persist the JSON. The
request function must not write files or print.

The executable `main` can call the pure function with sample input and print
the response plus causal JSON. This keeps demo output outside the request path.

## Behaviors

Successful health request:

- starts `CausalAppTrace` with method `GET`, route `/health`, runtime `worker`;
- records service resolution for `HealthService`;
- records layer construction for `HealthLayer`;
- opens and closes a request scope;
- records the response status as a semantic app event;
- completes the trace with success;
- returns response status `200` and body `ok`.

Missing environment request:

- starts the same request trace;
- records config failure for `YACHDEE_ENV`;
- records requirement failure for `HealthService`;
- completes the trace with failure;
- returns response status `500` and body `missing_environment`;
- exported JSON includes assertion failure evidence and can produce causal
  findings.

Redaction guard:

- if the caller provides a secret-looking environment string, exported causal
  JSON must not contain the raw value;
- the store redaction marker should be present instead.

Workbench compatibility:

- exported artifacts must keep schema `zigeffect.causal.v1`;
- docs should direct users to:

```bash
zig build causal-workbench -- .zig-cache/causal-artifacts/<app-incident>.json
```

This branch does not write that artifact automatically. Worker-compatible
request code should hand JSON to R2, Durable Objects, D1, logs, or another
caller-owned sink in later app integrations.

## Testing

Add the example as both an executable and a test target:

```bash
cd packages/zigeffect && zig build causal-app-request-example
cd packages/zigeffect && zig build examples
```

The example tests must prove:

- success response and success causal events;
- missing environment response and assertion findings;
- redaction of accidental sensitive values;
- exported JSON is standard causal JSON.

Run final verification with:

```bash
cd packages/zigeffect && zig build causal-app-request-example
cd packages/zigeffect && zig build examples
cd packages/zigeffect && zig build test
bun run zigeffect:workbench:test
bun run zigeffect:workbench:typecheck
```

## Self-Review

- Scope is one example branch, not a platform instrumentation branch.
- Worker compatibility is preserved by keeping the request path pure and
  caller-owned.
- The existing SolidJS plus `zig-webui` workbench remains the viewer.
- The example uses the already delivered `CausalAppTrace` adapter rather than
  creating a second app artifact vocabulary.
