# Third-Party Notices

## ziglana/gRPC-zig

`zstd.Grpc` was derived from concepts and public-domain source material in
[`ziglana/gRPC-zig`](https://github.com/ziglana/gRPC-zig) at revision
`ab34a7778193a309fc61117230643d2cbb5c2aaf`.

The ZigEffect implementation is repository-owned and has been substantially
rewritten for Zig 0.16, the published gRPC-over-HTTP/2 protocol, Effect service
integration, deterministic testing, bounded ownership, and redacted causal
evidence. It does not preserve the upstream package API.

The upstream license is the Unlicense:

> This is free and unencumbered software released into the public domain.
>
> Anyone is free to copy, modify, publish, use, compile, sell, or distribute
> this software, either in source code form or as a compiled binary, for any
> purpose, commercial or non-commercial, and by any means.
>
> In jurisdictions that recognize copyright laws, the author or authors of
> this software dedicate any and all copyright interest in the software to the
> public domain. We make this dedication for the benefit of the public at large
> and to the detriment of our heirs and successors. We intend this dedication
> to be an overt act of relinquishment in perpetuity of all present and future
> rights to this software under copyright law.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
> IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
> FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
> AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
> ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
> WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
>
> For more information, please refer to <https://unlicense.org>.

## Arwalk/zig-protobuf

`zigeffect-grpc` uses the Zig 0.16-compatible `Arwalk/zig-protobuf` proto3
runtime and generator at revision `2b7103e1f71a02cb19bb464820ab6fa7376e5a17`.
The package is licensed under the MIT License. Its copyright and permission
notice are retained by the pinned package source distributed through Zig's
package manager.

## NenDB

The embedded causal graph includes a Zig 0.16 port of the data-oriented graph
layout from [Nen-Co/nen-db](https://github.com/Nen-Co/nen-db), commit
`c990ef87d74e4dd7e77d3d8d1aafea2d57d12af7`. NenDB is licensed under the
Apache License 2.0. The complete license is included at
`src/vendor/nendb/LICENSE` and port details are recorded in
`src/vendor/nendb/UPSTREAM.md`.
