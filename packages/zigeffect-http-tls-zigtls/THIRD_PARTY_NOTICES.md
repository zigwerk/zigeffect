# Third-Party Notices

## ZigTLS

- Project: `Geun-Oh/zigtls`
- Version: `v0.1.3`
- Release: `https://github.com/Geun-Oh/zigtls/releases/tag/v0.1.3`
- Asset: `zigtls-v0.1.3.tar.gz`
- Asset SHA-256: `46b53db9a931d093e964289bff31401058d0c65448b5839110bfa8104c4c0300`
- Zig content hash: `zigtls-0.0.0-RqrH2HbHBwCsKIOzdZzuEFA4I8X9ZRPQeAczX-HwjjxG`
- Included paths: `src/`, `LICENSE`, and upstream `README.md`

The vendored source carries a bounded Zig `0.16` compatibility layer:

- `cert_reload.zig` adds a `std.Io` credential-loading entry point;
- removed standard-library enum, clock, random, trimming, bundle, and base64
  APIs are mapped to their Zig `0.16` equivalents; and
- an ALPN allowlist validates offered protocols without implicitly requiring
  clients to send the optional extension; and
- connected TLS 1.3 shutdown encrypts `close_notify` with application traffic
  keys, as required by the protocol and proved against the OpenSSL client.

Cipher-suite selection, key schedule, certificate signing, record encryption,
and handshake state transitions otherwise remain the upstream implementation.
Refresh the snapshot only from an immutable release asset after verifying both
the published SHA-256 and Zig content hash, then reapply and independently
review these patches. ZigTLS is distributed under the MIT License reproduced
at `vendor/zigtls/LICENSE`.
