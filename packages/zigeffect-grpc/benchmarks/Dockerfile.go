# syntax=docker/dockerfile:1.7
FROM golang:1.25.6-bookworm AS build
RUN apt-get update \
    && apt-get install -y --no-install-recommends protobuf-compiler \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /src
COPY packages/zigeffect-grpc/benchmarks/go/go.mod ./go.mod
RUN go mod download
RUN go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.36.11 \
    && go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@v1.5.1
COPY packages/zigeffect-grpc/benchmarks/proto ./proto
RUN protoc -I proto --go_out=. --go_opt=module=zigeffect-grpc-bench \
    --go-grpc_out=. --go-grpc_opt=module=zigeffect-grpc-bench \
    proto/conformance.proto proto/stats.proto
COPY packages/zigeffect-grpc/benchmarks/go/main.go ./main.go
RUN go mod tidy && CGO_ENABLED=0 go build -trimpath -ldflags='-s -w' -o /server .

FROM debian:bookworm-slim
RUN useradd --system --uid 65532 --home /nonexistent --shell /usr/sbin/nologin nonroot
COPY --from=build --chown=65532:65532 /server /server
USER 65532:65532
ENV PORT=8080
ENTRYPOINT ["/server"]
