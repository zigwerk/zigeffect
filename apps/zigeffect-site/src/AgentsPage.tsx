import Bot from "lucide-solid/icons/bot";
import FileCheck2 from "lucide-solid/icons/file-check-2";
import GitBranch from "lucide-solid/icons/git-branch";
import Search from "lucide-solid/icons/search";
import ShieldCheck from "lucide-solid/icons/shield-check";
import Wrench from "lucide-solid/icons/wrench";
import { CodeWindow, DeepPage, SectionHeading } from "./DeepPage";

const agentLoop = [
  ["01", "Orient", "Validate compatibility, project intent, current status, and declared scenarios."],
  ["02", "Specify", "Add the missing requirement, acceptance check, and failing deterministic scenario."],
  ["03", "Implement", "Change the smallest public boundary using typed effects, layers, and schemas."],
  ["04", "Diagnose", "Read the receipt, failed assertion, causal ids, and exact replay command."],
  ["05", "Verify", "Run affected scenarios, coverage, gaps, project tests, and the agent safety gate."],
  ["06", "Handoff", "Publish bounded evidence another agent or human can continue from."],
] as const;

export function AgentsPage() {
  return (
    <DeepPage
      current="agents"
      eyebrow="AGENTIC DEVELOPMENT"
      title={<>Agents need a runtime, <span>not more guesswork.</span></>}
      lede="ZigEffect gives coding agents an executable project contract, public capability boundaries, deterministic scenarios, causal diagnosis, safety checks, and evidence-backed handoff."
      facts={["Manifest-first intent", "Public boundaries", "Causal diagnosis", "Evidence-backed handoff"]}
      visual={<ol class="agent-loop-mini">{agentLoop.map(([number, title]) => <li><span>{number}</span><strong>{title}</strong></li>)}</ol>}
      next={{ eyebrow: "NEXT / LONG-LIVED WORK", title: "Make workflow logic visible too.", copy: "Typed statecharts give agents a bounded, reviewable way to author and operate processes that outlive a request.", href: "/workflows", label: "Explore workflows" }}
    >
      <section class="deep-section"><SectionHeading eyebrow="01 / EXECUTABLE INTENT" title="The manifest is executable intent." copy="A requirement is linked to acceptance, a component, a command, source roots, scenarios, and authority. The agent asks what is next instead of inventing a roadmap from filenames." /><div class="command-stack" data-reveal><code>zigeffect compatibility --json</code><code>zigeffect project validate --json</code><code>zigeffect agent status --json</code><code>zigeffect agent next --json</code><code>zigeffect test list --json</code></div></section>
      <section class="deep-band deep-band-dark"><div class="deep-band-inner"><SectionHeading eyebrow="02 / ONE CLOSED LOOP" title="Every step leaves the next step easier." copy="The system narrows an agent's context before it asks the model to reason. A failed test points to an assertion; the assertion points to causal ids; the graph points to an owner and source boundary; replay preserves the world." /><ol class="agent-loop" data-reveal>{agentLoop.map(([number, title, copy]) => <li><span>{number}</span><div><strong>{title}</strong><p>{copy}</p></div></li>)}</ol></div></section>
      <section class="deep-section"><SectionHeading eyebrow="03 / DIAGNOSE FROM EVIDENCE" title="The first question is bounded." copy="After test affected selects the relevant scenarios, the agent reads the latest receipt before raw terminal output. It starts from the first failed assertion, its repair hint and source reference, then queries the causal event and children." /><div class="diagnosis-path" data-reveal><span><FileCheck2 size={18} /> failed assertion</span><span><Search size={18} /> causal event 43</span><span><GitBranch size={18} /> resource owner scope-12</span><span><Wrench size={18} /> smallest repair</span><span><ShieldCheck size={18} /> exact replay</span></div></section>
      <section class="deep-section deep-section-warm"><SectionHeading eyebrow="04 / SAFETY AND HANDOFF" title="Fast generation still has a hard edge." copy="The governed agent profile combines compiler evidence, source policy, leak and allocation-failure checks, bounded schedule exploration, and causal source references. project check --agent writes receipts tied to the source revision and toolchain." /><CodeWindow label="handoff" badge="provider-neutral">{`zigeffect test affected --changed src/checkout.zig --json
zigeffect test replay payment-timeout --seed 42 --fault http:2
zigeffect project check --agent --json
zigeffect agent handoff --provider codex --session checkout-retry --json`}</CodeWindow></section>
      <section class="deep-section"><SectionHeading eyebrow="05 / THE HUMAN ROLE" title="Autonomy does not erase authority." copy="Agents may inspect, implement inside declared roots, run deterministic scenarios, propose repairs, and publish evidence. Broader mutations, unsafe roots, production control, and workflow application remain separately authorized and reviewable." /><div class="honesty-card" data-reveal><Bot size={26} /><div><h3>The goal is not fewer humans.</h3><p>The goal is to move human attention from typing repetitive boundary code and reconstructing failures toward requirements, architecture, review, policy, and product judgment.</p></div></div></section>
    </DeepPage>
  );
}

