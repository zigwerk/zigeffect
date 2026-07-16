# ZigEffect gRPC on Cloud Run

Build from the repository root so the local ZigEffect packages are available:

```sh
docker build \
  -f packages/zigeffect-grpc/examples/cloud_run/Dockerfile \
  -t zigeffect-grpc-cloud-run .
```

The container listens without TLS on `0.0.0.0:$PORT`. Cloud Run terminates TLS
and forwards HTTP/2 to the container; deploy the service with end-to-end HTTP/2
enabled (`--use-http2`). SIGTERM starts a bounded graceful drain.

The example composes policy, implementation, generated routes, standard Health
Check/Watch, reflection v1/v1alpha, Channelz, registries, middleware, and the
native server as one root layer. One `zstd.ManagedRuntime` owns the process and its
embedded NenDB graph. Generated handlers run through requirements-limited
runtime handles with a fresh child scope per RPC or complete stream lifetime.

The native server layer installs its causal boundary recorder automatically.
Transport lifecycle and handler facts therefore join the same application
graph; request IDs and W3C trace context are correlated without retaining raw
headers, credentials, metadata, or payloads.

For browser Connect clients, set `CORS_ALLOWED_ORIGINS` to a comma-separated
allowlist of exact origins. Set `CORS_ALLOW_CREDENTIALS=true` only when browser
credentials are required; undeclared origins fail closed.
