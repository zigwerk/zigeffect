# ZigEffect gRPC Marketing Page Design

Date: 2026-07-13
Status: Approved by user request and constrained by checked-in qualification evidence

## Objective

Add a dedicated `/grpc` chapter to the ZigEffect marketing site that presents
`zigeffect-grpc` as a flagship, end-to-end backend capability: one Protobuf
contract generates typed Zig clients and servers plus SolidJS Connect clients,
while ZigEffect supplies effects, layers, scoped resources, causal evidence,
deterministic fault exploration, Testing v2 receipts, and Cloud Run lifecycle
integration.

The page must make a positive case against a conventional Go backend without
claiming that Go lacks an ecosystem or that ZigEffect wins every benchmark. It
must distinguish features integrated into ZigEffect from features that can be
assembled separately around `grpc-go`.

## Claim Contract

The page may claim:

- a Zig-native gRPC client/server implementation without the gRPC C core;
- all four RPC shapes, persistent multiplexed channels, bounded incremental
  streaming, Connect, generated Solid Query clients, auth, health, reflection,
  Channelz, OTLP, and Cloud Run-ready h2c hosting;
- 120/120 stable Connect server conformance cases and the recorded official gRPC
  interoperability role/mode matrix;
- the exact ARM64 Docker-loopback benchmark observations recorded in
  `packages/zigeffect-grpc/conformance/benchmarks-linux-arm64.v1.json`;
- the 15-minute mixed-shape container qualification observation of 1,541,632
  completed calls, zero failures, and memory growth within its declared budget.

The page must not claim:

- pure Zig, because nghttp2 and OpenSSL provide HTTP/2 and TLS primitives;
- fastest gRPC implementation, because grpc-go, Tonic, and gRPC C++ lead some
  throughput lanes in the same receipt;
- an apples-to-apples win over Go REST frameworks, because the repository does
  not yet contain that benchmark;
- production-verified or deployed Cloud Run qualification before native Linux
  amd64, the 24-hour soak, and deployed GCP receipts exist on committed source.

## Go Comparison

The primary comparison uses the 1 KiB unary lane at 32 workers in the checked-in
four-runtime receipt:

| Runtime | RPC/s | p50 | p95 | p99 | server CPU/RPC |
| --- | ---: | ---: | ---: | ---: | ---: |
| ZigEffect | 4,094 | 3.27 ms | 5.84 ms | 7.06 ms | 71.5 us |
| grpc-go | 7,402 | 3.55 ms | 7.38 ms | 8.91 ms | 141.7 us |

The narrative is: ZigEffect recorded lower latency percentiles and lower server
CPU per RPC in this lane, while grpc-go recorded higher aggregate throughput.
The larger product advantage is integration: contract generation, browser
Connect clients, typed effects and errors, resource scopes, causal facts,
deterministic network/schedule testing, and evidence-backed maturity are one
coherent system rather than a separately assembled toolchain.

## Page Narrative

1. **Hero — one contract, every boundary.** Present the route from `.proto` to
   Zig service, Cloud Run, and SolidJS client. Lead with product value rather
   than a benchmark.
2. **Architecture — native where ownership matters.** Explain that Zig owns the
   gRPC semantics and operational runtime while nghttp2/OpenSSL supply mature
   standards primitives. Explicitly state “without the gRPC C core,” not “pure
   Zig.”
3. **Performance — receipts, not folklore.** Show the 1 KiB and 64 KiB unary
   observations plus the 15-minute mixed-shape qualification. Include the exact
   ARM64 Docker-loopback methodology adjacent to the numbers.
4. **Go comparison — optimize the whole development system.** Show the measured
   latency/CPU win and throughput loss honestly, then explain the integrated
   ZigEffect advantages that `grpc-go` alone does not provide.
5. **Cloud Run — from browser to global ingress.** Show SolidJS/Connect and
   native gRPC entering a Cloud Run h2c service through Google-managed TLS,
   readiness, identity, and graceful drain.
6. **Qualification — production candidate with visible gates.** Present passed
   conformance/adversarial/load evidence and the three remaining promotion
   gates.
7. **FAQ.** Answer speed versus Go, REST replacement, pure-Zig status,
   streaming, browser clients, global load balancing, and production maturity.

## Visual Direction

Reuse the ZigEffect site's white, slate, orange, thin-rule, editorial system.
The page uses code-native diagrams and data tables rather than a new raster
asset. The hero visual is an HTTP/2 channel console: one Protobuf contract feeds
typed Zig and Solid outputs, with four live RPC-shape lanes. Performance is
shown as a restrained receipt/table, not a triumphant chart that obscures the
grpc-go throughput result.

## Discovery And Accessibility

- Add `grpc` to the shared route type, desktop/mobile navigation, footer, static
  prerender list, sitemap, and standard-library handoff.
- Give `/grpc` independent title, description, canonical, Open Graph, Twitter,
  and JSON-LD metadata. JSON-LD includes `SoftwareSourceCode` and `FAQPage`.
- FAQ disclosure controls use native `details`/`summary` semantics.
- Tables remain horizontally scrollable on narrow screens and preserve headers.
- New diagrams collapse into a single column below 760 px.
- Motion remains governed by the site's existing reduced-motion contract.

## Acceptance

- A source-contract test fails before implementation and protects route,
  discovery, performance numbers, claim boundaries, FAQ, and responsive styles.
- Existing site tests continue to pass with the site expanded from ten to eleven
  chapters.
- `bun run zigeffect-site:typecheck`, `bun run zigeffect-site:test`, and
  `bun run zigeffect-site:build` pass.
- The production build prerenders `/grpc` and all existing routes.
