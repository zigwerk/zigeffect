# zigeffect-http

Real bounded HTTP server and client lifecycle adapters for `zigeffect-std`.

The HTTP/1.1 server capability is `production_candidate` on the checked-in,
content-bound live conformance receipt. It is not `production_verified`, and
HTTP/2 is not implemented. The built-in TLS 1.3 provider remains
`local_development`. The separate
[`zigeffect-http-tls-openssl`](../zigeffect-http-tls-openssl/README.md) adapter
is the current `production_candidate` direct-TLS provider; the built-in provider
must pass its own live conformance gate before promotion.

```sh
zig build test
```

`ServerLayerConfig`, `Handler`, and `serverLayer()` are the current lifecycle
bridge for existing consumers. They own listener lifetime and
`serveOneEffect`, `drainServerEffect`, and `shutdownServerEffect` emit causal
operation facts, but the bridge still uses the legacy environment-shaped layer
kernel. It is not the wiring pattern for new application roots.

The canonical migration will publish stable handler/server tags and a scoped
`fx.kernel.Layer` consumed by one managed runtime. Direct `Server.init` remains
the imperative driver API for adapter tests and low-level integrations.

## Guarded application map

`ApplicationMapHandler` exposes the canonical managed runtime's versioned
application snapshot without rebuilding layers or reconstructing a graph from
logs. A guard is required at construction time, and both the retained event
tail and response bytes are bounded:

```zig
var map = try http.ApplicationMapHandler(@TypeOf(runtime)).init(
    &runtime,
    "/_zigeffect/application",
    http.Guard.from(AgentAccess, &agent_access),
    .{ .max_recent_events = 128, .max_response_bytes = 1024 * 1024 },
);

const handler = map.asHandler();
```

The response is `zigeffect.application_snapshot.v1`: services, layers,
dependency edges, memoization, causal health, findings, fiber state, and a
bounded recent event tail in one JSON document. Deployments still decide the
network exposure and authorization policy.
