import Cpu from "lucide-solid/icons/cpu";
import Eye from "lucide-solid/icons/eye";
import Gauge from "lucide-solid/icons/gauge";
import Repeat2 from "lucide-solid/icons/repeat-2";
import ShieldAlert from "lucide-solid/icons/shield-alert";
import { CodeWindow, DeepPage, SectionHeading } from "./DeepPage";

export function WhyZig() {
  return (
    <DeepPage
      current="why-zig"
      eyebrow="WHY ZIG"
      title={<>Humans made the foundation. <span>Agents absorb the repetition.</span></>}
      lede="Zig is small, explicit, fast, and sometimes repetitive. That used to be a productivity tax. Agents change the cost of explicit code—and let us keep the control."
      facts={["Explicit memory", "Explicit errors", "Small language surface", "Portable native output"]}
      visual={<div class="explicit-stack"><span>Allocator</span><span>Error set</span><span>Service environment</span><span>Resource scope</span><strong>Nothing important is hidden</strong></div>}
      next={{ eyebrow: "NEXT / THE ENGINE", title: "What the runtime adds.", copy: "Zig gives us honest machine-level constraints. ZigEffect makes whole-program behavior composable, observable, and replayable.", href: "/runtime", label: "Explore the runtime" }}
    >
      <section class="deep-section">
        <SectionHeading eyebrow="01 / THE ECONOMICS CHANGED" title="Agents change the cost of explicit code." copy="Boilerplate is expensive when a person must type and maintain every line. For an agent, repetition is cheap—provided the compiler, runtime, tests, and evidence make mistakes easy to locate and hard to hide." />
        <div class="editorial-split" data-reveal><div><Repeat2 size={28} /><h3>Let the agent write the repetition.</h3><p>Adapters, error cases, explicit dependency wiring, cleanup paths, schemas, and focused tests are precisely the kind of regular work language models can generate well.</p></div><div><Eye size={28} /><h3>Keep the system inspectable.</h3><p>The output is ordinary Zig. There is no opaque generated service graph or hidden runtime contract standing between the engineer and the machine.</p></div></div>
      </section>
      <section class="deep-band deep-band-dark"><div class="deep-band-inner"><SectionHeading eyebrow="02 / THE TRUSTED CORE" title="A small language gives the agent fewer places to hide." copy="Allocators, error sets, imports, service requirements, and resource cleanup remain visible in source and compiler diagnostics." /><div class="mechanism-grid" data-reveal><article><Cpu size={22} /><span>Control</span><h3>Direct machine model</h3><p>Memory and execution costs stay legible.</p></article><article><Gauge size={22} /><span>Output</span><h3>Small native artifacts</h3><p>No server-side JavaScript runtime is required.</p></article><article><Eye size={22} /><span>Review</span><h3>Readable source</h3><p>Generated code is still code a human can audit.</p></article></div></div></section>
      <section class="deep-section deep-section-warm"><SectionHeading eyebrow="03 / AN HONEST BOUNDARY" title="Explicit does not mean magically safe." copy="Zig does not make arbitrary programs safe, and ZigEffect does not claim Rust-equivalent language soundness. The agent safety profile combines compiler checks, source policy, ownership evidence, deterministic fault exploration, and human-reviewed audited roots." /><div class="honesty-card" data-reveal><ShieldAlert size={26} /><div><h3>What a passed receipt actually means</h3><p>The declared gates passed for the recorded source revision, toolchain, roots, and bounds. Missing, stale, truncated, or unsupported required evidence stays incomplete—it never becomes a green claim.</p></div></div></section>
      <section class="deep-section"><SectionHeading eyebrow="04 / NORMAL ZIG" title="The framework never replaces the language." copy="A service remains a struct, a failure remains an error set, and the useful unit of work remains a direct-style function." /><CodeWindow label="checkout.zig" badge="ordinary Zig">{`fn charge(ctx: *fx.Context(AppEnv), order: Order) CheckoutError!Receipt {
    const payments = ctx.service(PaymentClient);
    return try payments.charge(order.id, order.total);
}`}</CodeWindow></section>
    </DeepPage>
  );
}

