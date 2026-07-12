import Boxes from "lucide-solid/icons/boxes";
import GitFork from "lucide-solid/icons/git-fork";
import Layers3 from "lucide-solid/icons/layers-3";
import PlugZap from "lucide-solid/icons/plug-zap";
import Recycle from "lucide-solid/icons/recycle";
import { CodeWindow, DeepPage, SectionHeading } from "./DeepPage";

export function RuntimePage() {
  return (
    <DeepPage
      current="runtime"
      eyebrow="THE ZIGEFFECT RUNTIME"
      title={<>Normal Zig in. <span>Visible execution out.</span></>}
      lede="ZigEffect does not replace your functions. It gives them typed composition, dependency environments, automatic ownership, structured concurrency, and an execution record an agent can interrogate."
      facts={["Typed success and failure", "Scoped ownership", "Structured concurrency", "Replaceable executors"]}
      visual={<div class="runtime-stack"><span>HTTP request</span><strong>Effect&lt;Receipt, CheckoutError, AppEnv&gt;</strong><div><i>scope</i><i>fiber</i><i>services</i></div><span>Exit + causal evidence</span></div>}
      next={{ eyebrow: "NEXT / THE EVIDENCE", title: "See what the runtime remembers.", copy: "Execution is recorded as relationships—so an agent can ask why instead of scanning what was printed.", href: "/causal-graph", label: "Explore the causal graph" }}
    >
      <section class="deep-section"><SectionHeading eyebrow="01 / EFFECTS" title="A normal Zig function is still the center." copy="An Effect is a typed description around a function: the value it can produce, the errors it can return, and the services it needs. Wrap only when you want composition, retry, cleanup, concurrency, or a deterministic environment." /><div class="two-column-example" data-reveal><CodeWindow label="checkout.zig" badge="direct style">{`fn run(ctx: *fx.Context(AppEnv)) CheckoutError!Receipt {
    const db = ctx.service(Database);
    return try db.commitCheckout();
}

const Checkout = fx.Effect(Receipt, CheckoutError, AppEnv).fromFn(run);`}</CodeWindow><div class="plain-card"><PlugZap size={24} /><h3>The type is the operating contract.</h3><p>An agent can see that checkout returns a Receipt, may fail with CheckoutError, and cannot run without AppEnv. Missing services become compiler diagnostics rather than runtime surprises.</p></div></div></section>
      <section class="deep-band deep-band-dark"><div class="deep-band-inner"><SectionHeading eyebrow="02 / LAYERS" title="Wiring is a graph the runtime can validate." copy="Layers build services in dependency order, memoize shared providers, own startup resources, and produce readable diagnostics when a requirement has no provider." /><div class="layer-sequence" data-reveal><span><Boxes size={20} /> Config</span><span><Layers3 size={20} /> Database</span><span><PlugZap size={20} /> Checkout</span><strong>AppEnv ready</strong></div></div></section>
      <section class="deep-section"><SectionHeading eyebrow="03 / SCOPES" title="Cleanup has an owner, not a convention." copy="The scope that registers cleanup owns the resource. A request connection closes with the request; a fiber resource closes when the fiber completes, fails, or is interrupted; an application service stays alive until its startup scope closes." /><div class="ownership-table" data-reveal><article><span>Request</span><h3>Database transaction</h3><p>Closes on success or typed failure.</p></article><article><span>Fiber</span><h3>Concurrent child work</h3><p>Interrupted when its parent scope closes.</p></article><article><span>Application</span><h3>Connection pool</h3><p>Lives across runs in an explicit shared scope.</p></article></div><p class="boundary-note"><Recycle size={18} /> The scope that registers cleanup owns the resource. Shared scopes are never silently closed for you.</p></section>
      <section class="deep-section deep-section-warm"><SectionHeading eyebrow="04 / FIBERS AND EXECUTORS" title="One program. More than one way to run it." copy="Structured fibers fork, join, race, interrupt, and clean up inside visible scopes. The same effect program can use a deterministic, coroutine, or OS-thread executor while preserving the structural ownership facts agents rely on." /><div class="executor-grid" data-reveal><article><GitFork size={21} /><strong>Deterministic</strong><p>Stable tests and bounded schedule exploration.</p></article><article><GitFork size={21} /><strong>Zio coroutines</strong><p>Real suspension and wake-up without changing program types.</p></article><article><GitFork size={21} /><strong>OS thread pool</strong><p>Native parallel execution behind the same executor contract.</p></article></div></section>
    </DeepPage>
  );
}

