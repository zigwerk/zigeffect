import Bug from "lucide-solid/icons/bug";
import CheckCircle2 from "lucide-solid/icons/circle-check-big";
import FlaskConical from "lucide-solid/icons/flask-conical";
import RotateCcw from "lucide-solid/icons/rotate-ccw";
import ShieldCheck from "lucide-solid/icons/shield-check";
import { CodeWindow, DeepPage, SectionHeading } from "./DeepPage";

export function TestingPage() {
  return (
    <DeepPage
      current="testing"
      eyebrow="TESTING V2"
      title={<>A green exit code <span>is not enough.</span></>}
      lede="Testing v2 proves that the declared scenario ran, the semantic assertions passed, resources were cleaned up, no work escaped, and the exact failure can be replayed."
      facts={["Requirement-linked scenarios", "Deterministic providers", "Semantic assertions", "Exact replay receipts"]}
      visual={<div class="test-receipt-mini"><div><CheckCircle2 size={32} /><strong>complete pass</strong></div><span>discovered 1 · executed 1</span><span>assertions 6/6 · leaks 0</span><span>pending fibers 0 · errors 0</span><code>replay seed 42 · http fault 2</code></div>}
      next={{ eyebrow: "NEXT / THE AGENT LOOP", title: "Give an agent a closed feedback loop.", copy: "The project contract, causal graph, deterministic tests, and safety receipts become one repeatable way of working.", href: "/agents", label: "See how agents build" }}
    >
      <section class="deep-section"><SectionHeading eyebrow="01 / SCENARIOS, NOT JUST TEST NAMES" title="A test belongs to a requirement." copy="The manifest registers the scenario, acceptance check, component, command, source roots, seed, and required status. The CLI writes the control document before execution and accepts only a matching native receipt." /><div class="two-column-example" data-reveal><CodeWindow label="scenario" badge="payment-timeout">{`requirement: checkout-retry
acceptance: one-charge-only
component: checkout
command: test
seed: 42
required_status: passed`}</CodeWindow><div class="plain-card"><ShieldCheck size={24} /><h3>Why the handshake matters</h3><p>A process exiting zero cannot pretend the scenario ran. Missing, mismatched, truncated, or unsupported required evidence is incomplete is not a pass.</p></div></div></section>
      <section class="deep-band deep-band-dark"><div class="deep-band-inner"><SectionHeading eyebrow="02 / CONTROL THE WORLD" title="Hard failures become repeatable inputs." copy="The test environment replaces time, files, config, ids, HTTP, SQL, logging, and other boundaries with deterministic providers. VirtualWorld adds bounded delay, drop, duplication, reordering, partition, crash, and recovery." /><div class="fault-grid" data-reveal><article><FlaskConical size={21} /><h3>HTTP fault 2</h3><p>Timeout after the provider accepted the charge.</p></article><article><Bug size={21} /><h3>Schedule 17</h3><p>Cancellation races the database finalizer.</p></article><article><RotateCcw size={21} /><h3>Recovery 3</h3><p>Restart after the journal commit but before dispatch.</p></article></div></div></section>
      <section class="deep-section"><SectionHeading eyebrow="03 / ASSERT MEANING" title="Test the contract the product cares about." copy="AssertionRecorder records stable ids, labels, source references, and repair hints. It can compare values and semantic JSON, inspect Exit and Cause, verify event sequences, reject findings, and prove no fibers or resources remain pending." /><CodeWindow label="checkout_test.zig" badge="AssertionRecorder">{`const assertions = zstd.Testing.AssertionRecorder.init(&context);
try assertions.boolean(.{
  .id = "one-charge-only",
  .label = "timeout never duplicates the charge",
  .repair_hint = "preserve the idempotency key across retry",
}, provider.charge_count == 1);
try assertions.noPendingFibers(.{ .id = "fibers-clean" });
try assertions.noFindings(.{ .id = "causal-clean" });`}</CodeWindow></section>
      <section class="deep-section deep-section-warm"><SectionHeading eyebrow="04 / RECEIPT AND REPLAY" title="A failure arrives with directions back to itself." copy="The receipt preserves the Zig version, target, optimization mode, seed, fault, bounds, assertion ids, causal ids, errors, and exact replay command. An agent starts from the first failed assertion and its causal event—not from raw scrollback." /><div class="receipt-card" data-reveal><div><CheckCircle2 size={27} /><div><small>TESTING V2 / NATIVE RECEIPT</small><h3>Payment timeout repaired</h3></div></div><dl><div><dt>Status</dt><dd>passed</dd></div><div><dt>Executed</dt><dd>1 / 1</dd></div><div><dt>Leaks</dt><dd>0</dd></div><div><dt>Logged errors</dt><dd>0</dd></div></dl><code>zigeffect test replay payment-timeout --seed 42 --fault http:2</code></div></section>
    </DeepPage>
  );
}

