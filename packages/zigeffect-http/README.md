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

`ServerConfigService`, `HandlerService`, and `serverLayer()` are the canonical
scoped adapter surface. They own listener lifetime and
`serveOneEffect`, `drainServerEffect`, and `shutdownServerEffect` emit causal
operation facts. Direct `Server.init` remains the imperative driver API for
adapter tests and low-level integrations.

## Guarded application map

`RuntimeApplicationMapHandler` exposes the owning managed runtime's versioned
application snapshot without rebuilding layers or reconstructing a graph from
logs. Its layered handler is constructed before the runtime, then an
`ApplicationMapSlot` borrows that exact runtime from startup until drain. A
guard is required, and both the retained event tail and response bytes are
bounded:

```zig
var slot = http.ApplicationMapSlot{};
var map = try http.RuntimeApplicationMapHandler.init(
    &slot,
    "/.well-known/zigeffect/application-map",
    http.Guard.from(AgentAccess, &agent_access),
    .{ .max_recent_events = 128, .max_response_bytes = 1024 * 1024 },
);
// After ManagedRuntime.make and before serving:
try slot.install(@TypeOf(runtime), &runtime);
defer slot.clear();
```

For durable runtimes the response is the versioned agent map: services, layers,
dependency edges, memoization, manifest intent, causal health, NenDB summary,
findings, fiber state, and a bounded recent event tail in one JSON document.
Deployments still decide the network exposure and authorization policy.
