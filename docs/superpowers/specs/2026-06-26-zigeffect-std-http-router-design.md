# zigeffect-std HTTP Router Design

Date: 2026-06-26

Status: delivered on 2026-06-26.

## Decision

Add M16 as a Schema-coded local HTTP router in `zstd.Http`.

The current HTTP module has request/response contracts, fake/live clients, and a
static memory server. M16 adds the application boundary: route matching, Schema
request decode, typed handler execution, Schema response encode, route receipts,
and workbench-ready trace JSON.

## Goals

- Add typed JSON endpoints backed by `zstd.Schema`.
- Add a tuple-backed local router that can hold heterogeneous endpoint types.
- Return owned responses plus route receipts and trace JSON.
- Return typed failures as deterministic 404/400/500 responses.
- Redact request details and validation issues.
- Add an effect-native route handler that records causal service facts.
- Add a copyable `examples/http_router.zig`.

## Non-Goals

- No production network listener in this milestone.
- No middleware stack.
- No streaming request bodies.
- No path parameters yet.
- No method-specific CORS handling.

## API Shape

```zig
const endpoint = zstd.Http.jsonEndpoint(
    "POST",
    "/projects",
    request_schema,
    response_schema,
    createProject,
);

var router = zstd.Http.router(.{endpoint});
var result = try router.handleAlloc(allocator, request);
defer result.deinit(allocator);
```

The result owns:

- `response`
- `receipt_json`
- `trace_json`

## Testing

- valid JSON route returns a Schema-encoded response, receipt, and trace.
- invalid JSON/schema input returns a redacted 400 body.
- unknown route returns a deterministic 404 body.
- effect-native router records causal facts.
- `examples/http_router.zig` compiles and has a behavior test.
