import Activity from "lucide-solid/icons/activity";
import Braces from "lucide-solid/icons/braces";
import CloudCog from "lucide-solid/icons/cloud-cog";
import Cpu from "lucide-solid/icons/cpu";
import Gauge from "lucide-solid/icons/gauge";
import GitBranch from "lucide-solid/icons/git-branch";
import Globe from "lucide-solid/icons/globe";
import Network from "lucide-solid/icons/network";
import Server from "lucide-solid/icons/server";
import ShieldCheck from "lucide-solid/icons/shield-check";
import Waypoints from "lucide-solid/icons/waypoints";
import Waves from "lucide-solid/icons/waves";
import { For } from "solid-js";
import { CodeWindow, DeepPage, SectionHeading } from "./DeepPage";

const integratedAdvantages = [
  {
    icon: Braces,
    eyebrow: "One contract",
    title: "Zig and Solid stay typed together.",
    copy: "One checked-in Protobuf schema generates Zig messages, client stubs, server bindings, and Connect clients with TanStack Solid Query helpers.",
  },
  {
    icon: GitBranch,
    eyebrow: "One effect model",
    title: "RPC failures become program values.",
    copy: "Handlers enter typed effects, layers, errors, deadlines, cancellation, and resource scopes instead of escaping into an unrelated networking framework.",
  },
  {
    icon: Activity,
    eyebrow: "One evidence model",
    title: "The transport explains what happened.",
    copy: "Resolve, connect, pick, attempt, stream, handler, and drain emit redacted causal facts linked to traces, metrics, and replayable test evidence.",
  },
  {
    icon: ShieldCheck,
    eyebrow: "One test system",
    title: "Network failure is explored before deploy.",
    copy: "VirtualWorld, FaultMatrix, Schedules, fuzzing, malformed peers, and certificate rotation exercise behavior that ordinary happy-path integration tests miss.",
  },
] as const;

const faqItems = [
  {
    question: "Are we faster than Go?",
    answer: <>In the latest schema-v2 optimization diagnostic, ZigEffect reached the same performance class as grpc-go: 11,792 versus 12,206 RPC/s, so grpc-go led this run by 3.4%. ZigEffect led Tonic by 13.4%, with 2.42 ms p50, 6.06 ms p99, and 7.0 allocations per RPC. That is a strong same-receipt result, not a claim that ZigEffect wins every machine or workload. The larger advantage is the complete ZigEffect development system around the transport.</>,
  },
  {
    question: "Is it faster than a Go REST API?",
    answer: <>Binary Protobuf over persistent HTTP/2 avoids much of the JSON parsing, repeated connection, and schema-drift overhead common in REST stacks. We have not yet published an apples-to-apples Go REST benchmark, so we market the measured gRPC results rather than inventing a universal REST comparison.</>,
  },
  {
    question: "Why not just use grpc-go?",
    answer: <>grpc-go is mature and extremely fast. ZigEffect is selling a different unit: typed effects and errors, scoped resources, generated Solid Query clients, causal diagnostics, deterministic schedule and network testing, evidence-backed capability maturity, and Cloud Run lifecycle integration. Those are not provided by grpc-go alone; a Go team can assemble equivalents from separate projects, while ZigEffect makes them one coherent contract.</>,
  },
  {
    question: "Is this pure Zig?",
    answer: <>No—and that is intentional. It is a Zig-native gRPC implementation without the gRPC C core, but not pure Zig: nghttp2 supplies standards-grade HTTP/2 and HPACK, OpenSSL 3 supplies TLS, and the Protobuf runtime is written for Zig. ZigEffect owns the gRPC semantics, channels, server, streaming, Connect, middleware, operations, and evidence.</>,
  },
  {
    question: "Can browsers call the same services?",
    answer: <>Yes. SolidJS uses generated Connect/Protobuf clients and TanStack Solid Query against the same service contract. Native Zig services use gRPC, while browser code never receives native service credentials.</>,
  },
  {
    question: "Does streaming have real backpressure?",
    answer: <>Yes. Unary, client-streaming, server-streaming, and bidirectional RPCs are supported. Incremental handlers use fixed-capacity queues and HTTP/2 pause/resume so a slow consumer propagates pressure instead of forcing the server to buffer an unbounded stream.</>,
  },
  {
    question: "Can it serve a global public API on Cloud Run?",
    answer: <>Yes. Put a global external Application Load Balancer and regional serverless NEG in front of Cloud Run v2. Google terminates public TLS, Cloud Run forwards h2c, and the ZigEffect server listens on 0.0.0.0:$PORT with readiness, identity, resource limits, and graceful SIGTERM drain.</>,
  },
  {
    question: "Is it production ready today?",
    answer: <>It is a Production candidate, ready for application development and qualification. Promotion to production-verified still requires native Linux amd64 evidence, the 24-hour mixed-shape soak, and deployed GCP service-to-service qualification on committed source.</>,
  },
] as const;

export function GrpcPage() {
  return (
    <DeepPage
      current="grpc"
      eyebrow="ZIGEFFECT GRPC"
      title={<>Native gRPC + Connect, <span>from service to browser.</span></>}
      lede="One Protobuf contract becomes typed Zig clients and servers, SolidJS query clients, persistent HTTP/2 channels, bounded streams, operational evidence, and a Cloud Run-ready backend."
      facts={["96.6% of grpc-go", "7 allocs / unary RPC", "1.54M mixed calls", "One contract to Solid"]}
      visual={
        <div class="grpc-channel-visual" aria-label="Protobuf contract flowing through ZigEffect gRPC to Cloud Run and SolidJS">
          <div class="grpc-channel-topline"><span>zigeffect-grpc</span><strong><i /> production candidate</strong></div>
          <div class="grpc-contract-node"><Braces size={22} /><span>contract/orders.v1.proto</span><small>the single source of truth</small></div>
          <div class="grpc-path">
            <span><Cpu size={19} /><strong>Zig bindings</strong><small>typed effects</small></span>
            <span><Network size={19} /><strong>HTTP/2</strong><small>persistent + bounded</small></span>
            <span><CloudCog size={19} /><strong>Cloud Run</strong><small>h2c + drain</small></span>
            <span><Globe size={19} /><strong>Solid client</strong><small>Connect + Query</small></span>
          </div>
          <div class="grpc-shape-rail"><span>unary</span><span>client stream</span><span>server stream</span><span>bidi</span></div>
        </div>
      }
      primary={{ href: "#performance", label: "See measured performance" }}
      next={{ eyebrow: "NEXT / BUILD THE SYSTEM", title: "Now use the rest of the backend vocabulary.", copy: "gRPC is one production boundary inside a broader standard library for data, reliability, storage, workflows, testing, and agent-readable operations.", href: "/standard-library", label: "Explore the standard library" }}
    >
      <section class="deep-section">
        <SectionHeading
          eyebrow="01 / ONE CONTRACT"
          title="The backend boundary stops drifting."
          copy="The checked-in .proto is the contract. ZigEffect generates both sides of the native service boundary and the browser boundary, then keeps compatibility, reflection, tests, and documentation tied to that source."
        />
        <div class="grpc-contract-flow" data-reveal>
          <article><span>01</span><Braces size={24} /><h3>Define once</h3><p>Messages, maps, oneofs, optional fields, well-known types, and every RPC shape live in Protobuf.</p></article>
          <article><span>02</span><Cpu size={24} /><h3>Generate Zig</h3><p>Typed messages, clients, handlers, service declarations, ownership, and status contracts compile with the backend.</p></article>
          <article><span>03</span><Globe size={24} /><h3>Generate Solid</h3><p>Connect-Web transport and TanStack Solid Query options give the UI the same message and method vocabulary.</p></article>
        </div>
        <div class="two-column-example grpc-native-explainer">
          <CodeWindow label="orders.proto → both boundaries" badge="contract first">{`service Orders {
  rpc Place(PlaceOrderRequest) returns (Order);
  rpc Watch(WatchOrdersRequest) returns (stream OrderEvent);
}

zig build gen-proto
bunx @bufbuild/buf generate
zig build schema-compatibility-test`}</CodeWindow>
          <div class="plain-card">
            <Waypoints size={25} />
            <h3>Zig-native, without the gRPC C core.</h3>
            <p>ZigEffect owns the gRPC semantics, typed API, server supervision, channels, streaming, Connect adapter, middleware, standard services, and telemetry.</p>
            <strong>It is not pure Zig: nghttp2 handles HTTP/2 and HPACK, while OpenSSL 3 provides peer-verified TLS.</strong>
          </div>
        </div>
      </section>

      <section class="deep-section deep-section-warm" id="performance" aria-label="gRPC performance evidence">
        <SectionHeading
          eyebrow="02 / MEASURED PERFORMANCE"
          title="Receipts, not benchmark folklore."
          copy="The latest optimization diagnostic holds architecture, containers, driver, payload, and concurrency constant across ZigEffect, grpc-go, Tonic, and gRPC C++. It records throughput, latency, and allocations rather than selecting one flattering number."
        />
        <div class="grpc-metric-strip" data-reveal>
          <article><span>1 KiB unary</span><strong>11,792</strong><small>RPC/s · 32 client workers</small></article>
          <article><span>Against grpc-go</span><strong>96.6%</strong><small>of best same-receipt throughput</small></article>
          <article><span>Unary latency</span><strong>2.42 ms</strong><small>p99 · 6.06 ms</small></article>
          <article><span>Server allocation</span><strong>7.0 allocations</strong><small>per 1 KiB unary RPC</small></article>
        </div>
        <div class="grpc-data-scroll">
          <table class="grpc-benchmark-table">
            <caption>Schema-v2 ARM64 optimization diagnostic · one receipt</caption>
            <thead><tr><th scope="col">Runtime</th><th scope="col">RPC/s</th><th scope="col">p50</th><th scope="col">p99</th><th scope="col">vs grpc-go</th></tr></thead>
            <tbody>
              <tr><th scope="row">grpc-go</th><td>12,206</td><td>2.35 ms</td><td>5.67 ms</td><td>100%</td></tr>
              <tr><th scope="row">ZigEffect</th><td>11,792</td><td>2.42 ms</td><td>6.06 ms</td><td>96.6%</td></tr>
              <tr><th scope="row">Tonic</th><td>10,403</td><td>2.69 ms</td><td>8.54 ms</td><td>85.2%</td></tr>
              <tr><th scope="row">gRPC C++</th><td>10,394</td><td>2.82 ms</td><td>6.33 ms</td><td>85.2%</td></tr>
            </tbody>
          </table>
        </div>
        <div class="grpc-soak-note"><Waves size={22} /><p><strong>Fifteen minutes under mixed traffic.</strong> The separate Cloud Run-compatible candidate receipt completed 1,541,632 unary, client-streaming, server-streaming, and bidirectional calls at 64 workers with zero failures and 10.9 MiB memory growth inside a 64 MiB budget.</p></div>
        <p class="grpc-method-note">Schema-v2 optimization diagnostic · ARM64 Docker loopback · plaintext HTTP/2 · 32 client workers · one persistent connection · 50,000 measured calls after warm-up. These are observations, not universal deployment guarantees, and this diagnostic is not the checked-in release receipt or deployed Cloud Run latency.</p>
      </section>

      <section class="deep-band deep-band-dark">
        <div class="deep-band-inner">
          <SectionHeading
            eyebrow="03 / THE GO QUESTION"
            title="Optimize the whole development system."
            copy="Raw transport speed matters. So do contract drift, cancellation, resource ownership, browser integration, incident diagnosis, test determinism, and knowing exactly what a green build proved."
          />
          <div class="grpc-go-comparison" data-reveal>
            <article class="grpc-go-score">
              <Gauge size={28} />
              <span>THE SCHEMA-V2 1 KiB LANE</span>
              <h3>ZigEffect reached 96.6% of grpc-go—and led Tonic.</h3>
              <dl>
                <div><dt>grpc-go gap</dt><dd>3.4%</dd></div>
                <div><dt>p50 gap</dt><dd>+0.07 ms</dd></div>
                <div><dt>p99 ratio</dt><dd>1.07x Go</dd></div>
                <div><dt>vs Tonic</dt><dd>+13.4%</dd></div>
              </dl>
              <p>ZigEffect delivered 13.4% higher throughput than Tonic in this run. That is a useful engineering result, not permission to write “fastest.” Different payloads, hosts, and streaming shapes produce different leaders.</p>
            </article>
            <article class="grpc-system-score">
              <Network size={28} />
              <span>THE PRODUCT ADVANTAGE</span>
              <h3>grpc-go is a transport. ZigEffect is the operating model around it.</h3>
              <p>Go teams can assemble excellent libraries for these concerns. ZigEffect makes typed effects, scopes, generated browser clients, causal facts, deterministic fault exploration, OTLP, and qualification receipts one maintained system—not provided by grpc-go alone.</p>
              <ul><li>One public facade</li><li>One error and scope model</li><li>One causal graph</li><li>One evidence contract</li></ul>
            </article>
          </div>
        </div>
      </section>

      <section class="deep-section">
        <SectionHeading
          eyebrow="04 / BEYOND THE TRANSPORT"
          title="The features that change how the backend is built."
          copy="The strongest differentiation is not a single hot-loop result. It is giving application code, operations, tests, and coding agents the same explicit model of failure and ownership."
        />
        <div class="grpc-advantage-grid" data-reveal>
          <For each={integratedAdvantages}>
            {(advantage) => (
              <article>
                <advantage.icon size={23} />
                <span>{advantage.eyebrow}</span>
                <h3>{advantage.title}</h3>
                <p>{advantage.copy}</p>
              </article>
            )}
          </For>
        </div>
      </section>

      <section class="deep-section deep-section-warm">
        <SectionHeading
          eyebrow="05 / CLOUD RUN"
          title="One main API, globally reachable."
          copy="The same ZigEffect host can serve browser Connect traffic and native gRPC traffic behind Google's global ingress. Platform TLS terminates before the container; the server receives HTTP/2 cleartext over Cloud Run's encrypted h2c path."
        />
        <div class="grpc-cloud-path" data-reveal>
          <span><Globe size={22} /><strong>SolidJS + native clients</strong><small>Connect or gRPC over HTTPS</small></span>
          <span><Network size={22} /><strong>Global load balancer</strong><small>certificate + Cloud Armor</small></span>
          <span><Waypoints size={22} /><strong>Regional serverless NEG</strong><small>route to Cloud Run v2</small></span>
          <span><Server size={22} /><strong>ZigEffect host</strong><small>0.0.0.0:$PORT · h2c</small></span>
        </div>
        <div class="grpc-cloud-details">
          <article><ShieldCheck size={21} /><h3>Fail closed at ingress</h3><p>Explicit CORS, bounded metadata and messages, JWT/IAP middleware, deadlines, rate policy, and sensitive-header redaction.</p></article>
          <article><Activity size={21} /><h3>Ready before traffic</h3><p>Health Watch, reflection, Channelz, listeners, and interceptors install before readiness turns true.</p></article>
          <article><Waves size={21} /><h3>Drain without guessing</h3><p>SIGTERM stops accepts, sends GOAWAY, waits for bounded in-flight work, then closes remaining resources with causal evidence.</p></article>
        </div>
      </section>

      <section class="deep-section">
        <SectionHeading
          eyebrow="06 / QUALIFICATION"
          title="Production candidate means the boundary stays visible."
          copy="The package has serious interoperability, parser, adversarial, load, and downstream evidence. ZigEffect still refuses to translate a workflow definition or unsupported environment into a production pass."
        />
        <div class="grpc-evidence-grid" data-reveal>
          <article><strong>120 / 120</strong><span>stable Connect server cases</span><small>zero unsupported server cases</small></article>
          <article><strong>56 runs</strong><span>official gRPC role/mode matrix</span><small>both roles · plaintext + TLS</small></article>
          <article><strong>1,000 iterations</strong><span>malformed frames + TLS rotation</span><small>one bounded defensive campaign</small></article>
          <article><strong>94 / 94</strong><span>ReleaseSafe Testing v2</span><small>zero pending · leaks · log errors</small></article>
        </div>
        <div class="grpc-promotion-gates">
          <span><i>01</i> native Linux amd64 committed-source receipt</span>
          <span><i>02</i> complete 24-hour mixed-shape soak</span>
          <span><i>03</i> deployed GCP service-to-service qualification</span>
        </div>
      </section>

      <section class="deep-section deep-section-warm" id="faq">
        <SectionHeading
          eyebrow="07 / FAQ"
          title="The questions a skeptical backend team should ask."
          copy="Short answers, measured claims, and the boundaries we expect engineers to inspect before choosing a primary API stack."
        />
        <div class="grpc-faq">
          <For each={faqItems}>
            {(item, index) => (
              <details open={index() === 0}>
                <summary><span>{String(index() + 1).padStart(2, "0")}</span>{item.question}</summary>
                <p>{item.answer}</p>
              </details>
            )}
          </For>
        </div>
      </section>
    </DeepPage>
  );
}
