import Bot from "lucide-solid/icons/bot";
import Braces from "lucide-solid/icons/braces";
import Check from "lucide-solid/icons/check";
import GitBranch from "lucide-solid/icons/git-branch";
import Play from "lucide-solid/icons/play";
import RotateCcw from "lucide-solid/icons/rotate-ccw";
import ShieldCheck from "lucide-solid/icons/shield-check";
import SquareTerminal from "lucide-solid/icons/square-terminal";
import { CodeWindow, DeepPage, SectionHeading } from "./DeepPage";

export function HowItWorks() {
  return (
    <DeepPage
      current="how-it-works"
      eyebrow="HOW ZIGEFFECT WORKS"
      title={<>One change. <span>Seven visible steps.</span></>}
      lede="Take a real request—“Make checkout retry safely.” ZigEffect turns it into declared intent, explicit Zig, observable execution, a replayable failure, and proof an agent can hand back to you. No framework vocabulary required."
      facts={["Normal Zig at the center", "Every boundary stays visible", "Failures replay exactly", "Proof closes the loop"]}
      primary={{ href: "#first-project", label: "Follow one change" }}
      visual={
        <ol class="hero-journey" aria-label="The ZigEffect development loop">
          <li><span><SquareTerminal size={18} /></span><div><small>Requirement</small><strong>Make checkout retry safely</strong></div></li>
          <li><span><Braces size={18} /></span><div><small>Typed change</small><strong>HTTP + SQL capabilities</strong></div></li>
          <li><span><GitBranch size={18} /></span><div><small>Runtime evidence</small><strong>Failure isolated to one edge</strong></div></li>
          <li><span><ShieldCheck size={18} /></span><div><small>Verified replay</small><strong>Ready to hand off</strong></div></li>
        </ol>
      }
      next={{ eyebrow: "NEXT / THE FOUNDATION", title: "Why start with Zig?", copy: "The runtime can only be as trustworthy as the language and machine model underneath it.", href: "/why-zig", label: "Why Zig" }}
    >
      <section class="deep-section" id="first-project">
        <SectionHeading eyebrow="01 / DECLARE WHAT DONE MEANS" title="The agent starts with a contract, not a blank prompt." copy="A small project manifest connects the requirement to the component, command, safety posture, and deterministic scenario that must pass. It makes intent executable and keeps an agent inside the authority you gave it." />
        <div class="two-column-example" data-reveal>
          <CodeWindow label="zigeffect.project.json" badge="executable intent">
            {`{
  "requirement": "checkout-retry",
  "acceptance": "one charge, even after timeout",
  "component": "checkout",
  "scenario": "payment-timeout",
  "authority": ["source", "tests"]
}`}
          </CodeWindow>
          <div class="plain-card"><Bot size={24} /><h3>What the agent learns</h3><p>What to change, what it may touch, which command is authoritative, which failure matters, and what evidence must exist before it can say “done.”</p><strong>Prompting starts the conversation. The contract governs the work.</strong></div>
        </div>
      </section>

      <section class="deep-band deep-band-dark">
        <div class="deep-band-inner">
          <SectionHeading eyebrow="02 / WRITE NORMAL ZIG" title="The useful code stays boring." copy="The agent writes a direct-style function with explicit inputs, errors, services, and memory. ZigEffect wraps it only where composition, retries, ownership, or test environments add value." />
          <div class="mechanism-grid" data-reveal>
            <article><Braces size={21} /><span>Input</span><h3>A typed request</h3><p>No unstructured bag of framework state.</p></article>
            <article><Play size={21} /><span>Program</span><h3>A normal function</h3><p>Readable Zig remains the center of the API.</p></article>
            <article><ShieldCheck size={21} /><span>Output</span><h3>A typed result</h3><p>Success and every expected failure stay named.</p></article>
          </div>
        </div>
      </section>

      <section class="deep-section">
        <SectionHeading eyebrow="03–05 / RUN, BREAK, EXPLAIN" title="Run it with evidence. Break it on purpose." copy="The runtime opens a request scope, resolves services, forks work, acquires resources, records retry decisions, and closes everything. The test world can then inject a timeout at the exact payment boundary without sleeping or calling a real provider." />
        <div class="trace-example" data-reveal>
          <div class="trace-line is-ok"><span>01</span><strong>request scope opened</strong><small>checkout-184</small><Check size={15} /></div>
          <div class="trace-line is-ok"><span>02</span><strong>PaymentClient resolved</strong><small>test layer</small><Check size={15} /></div>
          <div class="trace-line is-fault"><span>03</span><strong>POST /charges timed out</strong><small>fault index 2</small><GitBranch size={15} /></div>
          <div class="trace-line"><span>04</span><strong>retry decision</strong><small>idempotency key preserved</small><RotateCcw size={15} /></div>
          <div class="trace-line is-ok"><span>05</span><strong>scope closed</strong><small>pending fibers 0</small><Check size={15} /></div>
        </div>
      </section>

      <section class="deep-section deep-section-warm">
        <SectionHeading eyebrow="06–07 / REPAIR AND PROVE" title="Replay the exact failure. Keep the receipt." copy="The agent applies the smallest repair, copies the receipt's exact replay command, and runs the same seed, fault, and bounds. The result is not a claim about the terminal—it is structured evidence another agent or human can inspect." />
        <div class="receipt-card" data-reveal>
          <div><ShieldCheck size={27} /><div><small>CHECKOUT-RETRY / PAYMENT-TIMEOUT</small><h3>Complete pass</h3></div></div>
          <dl><div><dt>Assertions</dt><dd>6 / 6</dd></div><div><dt>Leaks</dt><dd>0</dd></div><div><dt>Pending fibers</dt><dd>0</dd></div><div><dt>Replay</dt><dd>seed 42 · fault 2</dd></div></dl>
          <code>zigeffect test replay payment-timeout --seed 42 --fault http:2</code>
        </div>
      </section>

      <section class="chapter-grid-section">
        <SectionHeading eyebrow="THE COMPLETE SYSTEM" title="Go as deep as you need." copy="The overview is one path through a larger system. Each chapter explains one mechanism in plain language, then shows the exact runtime contract underneath it." />
        <div class="chapter-grid" data-reveal>
          <a href="/why-zig"><span>01</span><h3>Why Zig</h3><p>Why explicit code becomes an advantage when agents write it.</p></a>
          <a href="/runtime"><span>02</span><h3>Runtime</h3><p>Effects, layers, scopes, fibers, and ownership.</p></a>
          <a href="/causal-graph"><span>03</span><h3>Causal graph</h3><p>How execution becomes queryable evidence.</p></a>
          <a href="/testing"><span>04</span><h3>Testing v2</h3><p>Deterministic failures, receipts, and replay.</p></a>
          <a href="/agents"><span>05</span><h3>Agent loop</h3><p>How an agent builds, diagnoses, and hands off.</p></a>
          <a href="/workflows"><span>06</span><h3>Workflows</h3><p>Visible control logic for long-lived systems.</p></a>
        </div>
      </section>
    </DeepPage>
  );
}
