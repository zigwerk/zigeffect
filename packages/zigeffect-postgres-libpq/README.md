# zigeffect-postgres-libpq

Persistent native PostgreSQL adapter for ZigEffect using the reviewed system
`libpq` protocol implementation. It never interpolates bind values into SQL.
The capability remains `local_development` until M135 live PostgreSQL and
CockroachDB conformance receipts are complete.
