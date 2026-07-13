# syntax=docker/dockerfile:1.7
FROM debian:bookworm-slim AS build

ARG TARGETARCH
ARG ZIG_VERSION=0.16.0
ARG ZIG_AMD64_SHA256=70e49664a74374b48b51e6f3fdfbf437f6395d42509050588bd49abe52ba3d00
ARG ZIG_ARM64_SHA256=ea4b09bfb22ec6f6c6ceac57ab63efb6b46e17ab08d21f69f3a48b38e1534f17

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl xz-utils libnghttp2-dev libssl-dev \
    && rm -rf /var/lib/apt/lists/*

RUN case "$TARGETARCH" in \
      amd64) zig_arch=x86_64; zig_sha="$ZIG_AMD64_SHA256" ;; \
      arm64) zig_arch=aarch64; zig_sha="$ZIG_ARM64_SHA256" ;; \
      *) echo "unsupported TARGETARCH: $TARGETARCH" >&2; exit 1 ;; \
    esac \
    && archive="zig-${zig_arch}-linux-${ZIG_VERSION}.tar.xz" \
    && curl -fsSLO "https://ziglang.org/download/${ZIG_VERSION}/${archive}" \
    && echo "${zig_sha}  ${archive}" | sha256sum -c - \
    && tar -xJf "${archive}" -C /opt \
    && ln -s "/opt/zig-${zig_arch}-linux-${ZIG_VERSION}/zig" /usr/local/bin/zig \
    && rm "${archive}"

WORKDIR /src
COPY packages/zigeffect packages/zigeffect
COPY packages/zigeffect-std packages/zigeffect-std
COPY packages/zigeffect-otel packages/zigeffect-otel
COPY packages/zigeffect-grpc packages/zigeffect-grpc
RUN cd packages/zigeffect-grpc \
    && zig build install-cloud-run -Doptimize=ReleaseSafe --prefix /out

FROM debian:bookworm-slim AS runtime
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates libnghttp2-14 libssl3 \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --uid 65532 --home /nonexistent --shell /usr/sbin/nologin nonroot

COPY --from=build --chown=65532:65532 /out/bin/zigeffect-grpc-cloud-run /app/service
USER 65532:65532
ENV PORT=8080
EXPOSE 8080
ENTRYPOINT ["/app/service"]
