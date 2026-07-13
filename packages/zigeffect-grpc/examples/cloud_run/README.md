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

The example registers the standard Health Check/Watch, reflection v1/v1alpha,
and Channelz services. Channelz exposes bounded live server/listener snapshots
without application payloads or credentials.

For browser Connect clients, set `CORS_ALLOWED_ORIGINS` to a comma-separated
allowlist of exact origins. Set `CORS_ALLOW_CREDENTIALS=true` only when browser
credentials are required; undeclared origins fail closed.
