# zigeffect-s3

S3-compatible object-storage adapter using AWS Signature Version 4 and real
multipart upload. Live conformance runs against MinIO and covers put/get/head,
delete/list, checksums, permissions, and multipart assembly. The initial adapter
supports plain HTTP for local/private-sidecar endpoints; direct HTTPS, virtual
host bucket routing, and resumable multipart state are explicit limitations.
