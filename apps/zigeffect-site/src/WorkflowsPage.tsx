import GitMerge from "lucide-solid/icons/git-merge";
import History from "lucide-solid/icons/history";
import LockKeyhole from "lucide-solid/icons/lock-keyhole";
import Network from "lucide-solid/icons/network";
import ShieldCheck from "lucide-solid/icons/shield-check";
import Workflow from "lucide-solid/icons/workflow";
import { BellRing, Boxes, CircleGauge, GitFork, TimerReset } from "lucide-solid";
import { CodeWindow, DeepPage, SectionHeading } from "./DeepPage";

export function WorkflowsPage() {
  return (
    <DeepPage
      current="workflows"
      eyebrow="DURABLE WORKFLOWS"
      title={<>Business logic you can <span>see and replay.</span></>}
      lede="Typed statecharts make long-lived work explicit: states, events, decisions, commands, recovery, supervision, and human authority all have a visible place."
      facts={["Typed states and events", "Pure decisions", "Journal-backed recovery", "Governed control"]}
      visual={<div class="statechart-mini"><span>received</span><span>payment_pending</span><span>inventory_reserved</span><span>dispatching</span><strong>completed</strong><i>failure → compensate</i></div>}
      next={{ eyebrow: "NEXT / REAL PRESSURE", title: "See where ZigEffect is being exercised.", copy: "Ziac and Yachdee push the runtime across infrastructure, backend, data, storage, workflows, and cloud operations.", href: "/built-with", label: "Built with ZigEffect" }}
    >
      <section class="deep-section"><SectionHeading eyebrow="01 / A VISIBLE PROCESS" title="A workflow is more than a background function." copy="An order may wait for payment, reserve stock, request human review, time out, compensate, restart on another node, and continue days later. A statechart names those states and legal transitions instead of scattering them across callbacks and queues." /><div class="workflow-path" data-reveal><span>Order received</span><span>Payment accepted</span><span>Stock reserved</span><span>Dispatch requested</span><strong>Complete</strong></div></section>
      <section class="deep-band deep-band-dark"><div class="deep-band-inner"><SectionHeading eyebrow="02 / THE TRUST BOUNDARY" title="Decisions are pure. Commands do the outside work." copy="Reducers receive owned value data and a typed event. They choose the next state and emit typed command descriptions. Database writes, messages, timers, and child workflows happen outside the transaction through adapters." /><div class="decision-grid" data-reveal><article><Workflow size={22} /><span>Inside</span><h3>Deterministic decision</h3><p>State + event → next state + commands.</p></article><article><Network size={22} /><span>Outside</span><h3>Effectful adapter</h3><p>Execute payment, SQL, queue, timer, or child work.</p></article><article><GitMerge size={22} /><span>Return</span><h3>Typed outcome event</h3><p>Success or failure re-enters the same machine.</p></article></div></div></section>
      <section class="deep-section"><SectionHeading eyebrow="03 / DURABILITY" title="The journal is the source of truth." copy="Every accepted transition records the definition fingerprint, event identity, resulting snapshot, chosen transition ids, commands, and fence epoch. Recovery folds saved records without re-running decisions." /><div class="journal-list" data-reveal><span><History size={17} /> 184 · payment.accepted · payment_pending → inventory_reserved</span><span><History size={17} /> 185 · command.reserve_stock · dispatched</span><span><History size={17} /> 186 · worker.crashed · journal durable</span><span><History size={17} /> 187 · owner.epoch.12 · recovery resumed</span></div><p class="boundary-note"><ShieldCheck size={18} /> ZigEffect guarantees exactly-once decision acceptance plus idempotent command receipt and recovery. External systems must still honor the supplied idempotency key.</p></section>
      <section class="deep-section deep-section-warm" id="durable-primitives">
        <SectionHeading eyebrow="04 / DURABLE PRIMITIVES" title="Waiting is part of the program, not a hole in it." copy="Activities, timers, signals, queues and deferred values give a workflow durable ways to call services, sleep, receive outside input, distribute work and await results. Compensation records the repair path when completed work must be undone." />
        <div class="durable-primitives" data-reveal>
          <article><Boxes size={21} /><strong>Activity</strong><p>Run typed outside work with identity, attempts, outcomes, and compensation.</p></article>
          <article><TimerReset size={21} /><strong>Timer</strong><p>Sleep across process restarts using journaled durable time.</p></article>
          <article><BellRing size={21} /><strong>Signal</strong><p>Pause until a named external event arrives, without polling.</p></article>
          <article><Network size={21} /><strong>Queue</strong><p>Offer and claim durable work with visible ownership and redelivery.</p></article>
          <article><GitMerge size={21} /><strong>Deferred</strong><p>Join a result that may be completed by another durable execution.</p></article>
        </div>
      </section>
      <section class="deep-band deep-band-dark" id="statecharts"><div class="deep-band-inner">
        <SectionHeading eyebrow="05 / STATECHARTS AND ACTORS" title="State machines grow with the system." copy="Hierarchical and parallel states model real business processes without flattening every concern into one enum. History states remember where a branch was. Typed commands keep decisions pure while actors add mailboxes, supervision, and process identity." />
        <div class="two-column-example">
          <div class="statechart-detail" data-reveal>
            <span>order</span>
            <div><i>payment</i><i>inventory</i></div>
            <div><b>waiting_review</b><b>dispatching</b></div>
            <strong>complete</strong>
            <small>parallel branches · deep history · typed events</small>
          </div>
          <div class="actor-story" data-reveal>
            <CircleGauge size={25} />
            <h3>Actors turn a statechart into a supervised process.</h3>
            <p>Each instance receives a mailbox, inspection state, overflow policy and command executor. Actor systems add supervised trees and checkpointable recovery without changing the machine's pure transition logic.</p>
            <ul><li>Typed mailbox</li><li>Supervision policy</li><li>Tree checkpoint</li><li>Inspectable status</li></ul>
          </div>
        </div>
      </div></section>
      <section class="deep-section" id="verification">
        <SectionHeading eyebrow="06 / PROVE THE MACHINE" title="Explore behavior before production does." copy="Simulation, coverage and determinism audits turn control flow into testable structure. The analyzer finds invalid and unreachable definitions; bounded model exploration searches state and event paths; mutation checks whether the acceptance suite can detect meaningful mistakes." />
        <div class="decision-grid" data-reveal>
          <article><GitFork size={22} /><span>Explore</span><h3>Reachable behavior</h3><p>Walk hierarchical configurations and event sequences with shortest replayable failures.</p></article>
          <article><CircleGauge size={22} /><span>Measure</span><h3>Statechart coverage</h3><p>Track states, transitions, guards, actions, commands, and declared coverage gaps.</p></article>
          <article><ShieldCheck size={22} /><span>Audit</span><h3>Deterministic decisions</h3><p>Run the same owned inputs again and require the same snapshot and command plan.</p></article>
        </div>
      </section>
      <section class="deep-section deep-section-warm"><SectionHeading eyebrow="07 / AGENT AUTHORING" title="Agents propose logic as a governed artifact." copy="An agent can assemble a portable workflow plan, compile it into normal typed Zig, verify and review the immutable definition, then request approval. Generated guards fail closed until implemented." /><CodeWindow label="workflow lifecycle" badge="dry-run first">{`zigeffect statechart compile workflows/order.json
zigeffect statechart verify proof-input.json --apply
zigeffect statechart review review-input.json --apply
zigeffect statechart approve approval-input.json --apply
zigeffect statechart studio commerce.order --json`}</CodeWindow></section>
      <section class="deep-section" id="versioning"><SectionHeading eyebrow="08 / CHANGE OVER TIME" title="Versioning and migration are runtime concerns." copy="Definitions carry fingerprints and version artifacts. Compatibility analysis classifies changes, migration registries translate durable state, and deployment strategies make rolling, canary, or blue-green change explicit instead of hoping an old journal matches new code." /><div class="version-flow" data-reveal><span>v3 definition</span><span>compatibility diff</span><span>dry-run migration</span><span>canary fleet</span><strong>v4 active</strong></div></section>
      <section class="deep-section deep-section-warm"><SectionHeading eyebrow="09 / CONTROL" title="Approval is not mutation authority." copy="A separately authorized control request must match policy, the live definition fingerprint, and the current lease or fence epoch. Suspend, resume, cancel, migrate, and apply operations are default-deny, idempotent, and dry-run capable." /><div class="honesty-card" data-reveal><LockKeyhole size={26} /><div><h3>Review and control stay distinct.</h3><p>A reviewed workflow cannot apply itself. A stale owner cannot append history. Unsupported operations fail closed instead of guessing.</p></div></div><p class="boundary-note"><ShieldCheck size={18} /> Local memory and file journals support development and bounded deployments. Clustered production durability requires an appropriate storage adapter, fencing strategy, idempotent external boundaries, and operational ownership.</p></section>
    </DeepPage>
  );
}
