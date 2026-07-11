# zigeffect-otel

Bounded OTLP/HTTP JSON export and W3C Trace Context propagation for ZigEffect.
The first adapter supports plain HTTP endpoints (normally a same-node collector);
direct HTTPS and OTLP/gRPC are explicitly outside this release slice.

The exporter owns queued payloads, applies bounded backpressure, retries only
retryable failures, bounds each request and shutdown, and retains local counters
when the collector is unavailable. Payloads are secret-scanned before enqueue.
