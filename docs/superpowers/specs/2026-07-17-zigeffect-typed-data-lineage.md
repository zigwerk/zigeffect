# ZigEffect Typed Data Lineage Design

## Purpose

ZigEffect applications need to mark a small number of meaningful domain values
such as product IDs, order IDs, tenant IDs, or user references once and then
let the runtime preserve their causal lineage automatically. Agents must be
able to query every effect, fiber, service, and supported transport boundary
that observed a value without application code manually recording lifecycle
events.

This capability is called **typed data lineage**. It is causal context, not a
logging field and not arbitrary memory tracing.

## Developer experience

Applications declare a typed key and scope an effect with it:

```zig
const ProductId = zstd.Lineage.Key([]const u8, .{
    .name = "commerce.product.id",
    .privacy = .internal,
    .propagation = .distributed,
    .export_policy = .otel,
});

const program = createOrder(input)
    .track(ProductId, input.product_id)
    .named("orders.create");
```

The application does not construct a store, emit causal events, manage
baggage, add OTEL attributes, or pass a recorder through services. Multiple
nested `track` calls form a bounded lineage set. When product and order
references coexist on an effect, their association is visible in the graph.

Generated Schema, HTTP, gRPC, SQL, and workflow adapters may later bind declared
keys automatically, but they must use the same runtime primitive.

## Identity and privacy

Every key has a stable 64-bit identity derived from its canonical dotted name.
Every value becomes a 128-bit SHA-256 projection over a domain separator, the
key, the privacy scope, and a canonical representation of the typed value.
Only the projection enters causal events, NenDB, OTEL, or transport baggage.

Supported first-class values are byte strings, byte arrays, integers, booleans,
and enums. Unsupported value types fail at compile time and must be converted
to an explicit canonical identifier.

Privacy policies are:

- `public`: globally stable non-secret identifiers;
- `internal`: project-scoped identifiers, requiring project identity; and
- `personal`: project-scoped pseudonymous identifiers that are graph-only.

Secret values are never valid lineage keys. A fingerprint is correlation, not
an authorization claim, encryption or anonymization, and it does not make a
secret safe to record. Low-entropy personal values remain guessable to a graph
reader; applications should track a protected stable subject ID instead of a
username or email address.

## Bounds and propagation

Each causal context carries at most eight references in an allocation-free
fixed set. Child keys replace the same parent key and otherwise extend the set.
Child context has priority. Overflow is deterministic and sets `truncated`;
queries and agents must treat truncated lineage as incomplete evidence.

`fiber` propagation remains inside the runtime process. `distributed`
propagation may cross explicitly trusted service boundaries as opaque bounded
W3C baggage. Incoming baggage is validated, never interpreted as authority,
and never contains source values.

Scoped effect attachment copies the runtime context before interpreting the
child. It cannot leak a request's identifiers into another request or sibling
run. Handles and fibers derived inside the scope inherit the copied set.

## Runtime and graph semantics

The runtime adds lineage context to structural `RuntimeEvent` values before the
causal aspect records them. Consequently effect, fiber, scope, service, layer,
resource, and semantic events all use the same lineage set.

Attaching a key produces one unsampled `lineage_bound` structural event. Its
label contains the canonical key name, never the value. This maps the stable
key ID to a human-readable declaration without repeating names on every event.

The bounded recorder offers an in-memory lineage slice for deterministic tests.
The durable managed runtime exposes a paginated NenDB lineage query keyed by an
opaque reference. Matching records preserve their ordinary parent edges, so an
agent receives the real causal flow rather than a detached list of log fields.
The agent application map advertises this query.

## OTEL projection

OTEL export uses fixed indexed attribute names to prevent unbounded attribute
key cardinality:

- `zigeffect.lineage.count` and `zigeffect.lineage.truncated`;
- `zigeffect.lineage.<n>.key_id`;
- `zigeffect.lineage.<n>.value_id_high` and `value_id_low`; and
- bounded privacy and propagation tags.

Only keys explicitly configured with `.export_policy = .otel` are projected. Personal
keys cannot select OTEL export. Source values and dynamically generated
attribute names are forbidden.

## Supported transport slice

The first distributed adapter is generated native gRPC. The standard gRPC
client adds one bounded ZigEffect member to existing W3C baggage. Generated
server routes parse it into the handler runtime context before the handler
effect starts, so handler effects and nested fibers inherit the references.
Malformed lineage baggage is omitted and remains observable as transport
validation evidence; it never becomes authority.

## Acceptance

- typed keys produce deterministic opaque references and never serialize raw
  values;
- internal/personal keys require project identity and personal keys reject OTEL
  export at compile time;
- nested tracking is scoped, bounded, and inherited by child runtime handles;
- structural and semantic causal events contain the same lineage references;
- NenDB JSON and OTEL projections preserve permitted references;
- a bounded durable graph query returns matching causal records with explicit
  pagination/truncation state;
- generated gRPC calls propagate only distributed references; and
- Testing v2 receipts report complete passing suites with no pending tests,
  leaks, or logged errors.

## Non-goals

This work does not instrument arbitrary Zig variable assignments, retain raw
payloads, infer domain identifiers heuristically, trust public inbound baggage,
or change zgraph. Schema-driven automatic binding and indexed NenDB lookup are
future optimizations over the same public contract.
