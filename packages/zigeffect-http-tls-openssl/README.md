# zigeffect-http-tls-openssl

OpenSSL 3 TLS 1.2/1.3 provider for `zigeffect-http`. The normal package test
performs a live, certificate-verified encrypted HTTP exchange through the public
TLS provider contract.

The capability is `production_candidate` on its checked-in content-bound live
loopback receipt. It is not `production_verified` and requires a compatible
system OpenSSL 3 installation.
