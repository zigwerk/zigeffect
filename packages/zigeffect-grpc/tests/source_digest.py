#!/usr/bin/env python3
"""Print the normalized SHA-256 for the gRPC implementation source set."""

from __future__ import annotations

import hashlib
import re
import sys
from pathlib import Path


EXCLUDED_PARTS = {
    ".zig-cache",
    ".zigeffect",
    "__pycache__",
    "node_modules",
    "target",
    "zig-out",
    "zig-pkg",
}
CONFORMANCE_DIGEST = re.compile(
    rb'\.content_sha256\s*=\s*"sha256:[0-9a-f]{64}"'
)


def included(path: Path, repository: Path) -> bool:
    relative = path.relative_to(repository)
    if any(part in EXCLUDED_PARTS for part in relative.parts):
        return False
    if path.suffix == ".pyc":
        return False
    return "conformance" not in relative.parts


def source_digest(repository: Path) -> str:
    roots = (
        repository / "packages/zigeffect-grpc",
        repository / "packages/zigeffect-grpc-web",
        repository / "packages/zigeffect-std/src/grpc",
        repository / "packages/zigeffect-otel/src",
    )
    files = sorted(
        path
        for root in roots
        for path in root.rglob("*")
        if path.is_file() and included(path, repository)
    )
    if not files:
        raise RuntimeError("gRPC source set is empty")
    digest = hashlib.sha256()
    for path in files:
        relative = path.relative_to(repository).as_posix().encode()
        content = path.read_bytes()
        if path.name == "root.zig" and path.parent.name == "src" and path.parent.parent.name == "zigeffect-grpc":
            content = CONFORMANCE_DIGEST.sub(
                b'.content_sha256 = "sha256:' + (b"0" * 64) + b'"',
                content,
            )
        digest.update(len(relative).to_bytes(8, "big"))
        digest.update(relative)
        digest.update(len(content).to_bytes(8, "big"))
        digest.update(content)
    return digest.hexdigest()


if __name__ == "__main__":
    repo = Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).parents[3]).resolve()
    print(source_digest(repo))
