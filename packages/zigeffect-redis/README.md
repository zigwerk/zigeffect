# zigeffect-redis

Real Redis RESP2 adapter for the `zstd.Cache` contract. Values and versions are
stored atomically with Lua; TTL, CAS, token-checked locks, and bounded replies
are covered by live local conformance. The current slice uses one TCP connection
per operation and does not yet provide TLS or cluster redirection.
