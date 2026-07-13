# zigeffect-otel

Bounded OTLP/HTTP JSON export and W3C Trace Context propagation for ZigEffect.
The exporter accepts typed metric, span, and log records and serializes the
OTLP/HTTP JSON envelope internally. It supports either an explicitly trusted
plaintext same-node collector or direct TLS 1.2/1.3 with certificate-chain and
hostname verification, platform/private-CA trust, bounded custom headers, and
bearer authentication. OTLP/gRPC is not implemented.

The exporter owns queued payloads, applies bounded backpressure, retries only
retryable failures, bounds each request and shutdown, and retains local counters
when the collector is unavailable. Payloads are secret-scanned before enqueue.
The checked-in external receipt currently qualifies plaintext collector mode;
the direct-TLS path has a local live collector test and remains
`local_development` until an external secure-collector receipt is checked in.
