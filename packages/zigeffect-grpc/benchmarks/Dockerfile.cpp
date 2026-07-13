# syntax=docker/dockerfile:1.7
FROM debian:bookworm-slim AS build
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       build-essential libgrpc++-dev libprotobuf-dev pkg-config protobuf-compiler protobuf-compiler-grpc \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /src
COPY packages/zigeffect-grpc/benchmarks/proto ./proto
COPY packages/zigeffect-grpc/benchmarks/cpp/main.cc ./main.cc
RUN mkdir generated \
    && protoc -I proto --cpp_out=generated --grpc_out=generated \
       --plugin=protoc-gen-grpc=/usr/bin/grpc_cpp_plugin \
       proto/conformance.proto proto/stats.proto \
    && c++ -std=c++17 -O3 -DNDEBUG -Igenerated main.cc \
       generated/conformance.pb.cc generated/conformance.grpc.pb.cc \
       generated/stats.pb.cc generated/stats.grpc.pb.cc \
       -o /server $(pkg-config --cflags --libs grpc++ protobuf)

FROM debian:bookworm-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends libgrpc++1.51 libprotobuf32 \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --uid 65532 --home /nonexistent --shell /usr/sbin/nologin nonroot
COPY --from=build --chown=65532:65532 /server /server
USER 65532:65532
ENV PORT=8080
ENTRYPOINT ["/server"]
