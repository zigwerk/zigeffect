# ZigEffect HTTP ZigTLS Adapter

`zigeffect-http-tls-zigtls` implements the public `zigeffect-http` TLS provider
contract with a Zig-native TLS 1.3 engine.

The initial provider supports synchronous HTTP/1.1 servers using
TLS AES-128-GCM, X25519, and Ed25519 PKCS#8 credentials. It remains a
`local_development` capability until cross-implementation live conformance is
captured as durable release evidence.

```zig
const tls = @import("zigeffect_http_tls_zigtls");

var provider = try tls.Provider.init(allocator, io, .{
    .certificate_chain_path = "cert.pem",
    .private_key_path = "key.pem",
});
defer provider.deinit();

const http_provider = provider.asProvider();
```

The package vendors the runtime `src/` tree from ZigTLS `v0.1.3` because that
release's build DSL does not evaluate under Zig `0.16`. See
`THIRD_PARTY_NOTICES.md` for immutable provenance and update instructions.

## Adapter Selection

- `zigeffect-http-tls-openssl` is the production-candidate adapter when a
  compatible system OpenSSL 3 installation is available.
- `zigeffect-http-tls-zigtls` keeps the TLS implementation in Zig and removes
  that system-library dependency. It remains `local_development` until its
  live evidence is retained as a durable conformance receipt.

`zig build test` runs both the public adapter contract and all 309 vendored
ZigTLS tests. The adapter contract includes a certificate-verified HTTP/1.1
exchange with the OpenSSL command-line client.
