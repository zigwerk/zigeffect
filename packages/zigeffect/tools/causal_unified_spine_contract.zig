const std = @import("std");

pub const unified_spine_contract_schema = "zigeffect.causal.unified-spine-contract.v1";
pub const unified_spine_contract_schema_version: u32 = 1;
pub const core_runtime_contract_schema = "zigeffect.causal.v1";
pub const app_runtime_contract_schema = "zigeffect.causal.app-runtime.v1";
pub const artifact_access_control_contract_schema = "zigeffect.causal.artifact-access-control.v1";
pub const nendb_node_contract_schema = "zigeffect.causal.nendb_node.v1";
pub const nendb_edge_contract_schema = "zigeffect.causal.nendb_edge.v1";
pub const recommendation = "start-deep-runtime-internals";
pub const recommended_next_branch = "codex/zigeffect-causal-deep-runtime-internals";

const OutputFormat = enum { text, json };

const generated_by = "causal-unified-spine-contract";

const CanonicalField = struct {
    name: []const u8,
    maps_from: []const u8,
    description: []const u8,
};

const RelationshipType = struct {
    id: []const u8,
    description: []const u8,
    primary_index: []const u8,
};

const PolicyStage = struct {
    id: []const u8,
    order: u32,
    description: []const u8,
    invariant: []const u8,
};

const DerivedIndex = struct {
    id: []const u8,
    relationships: []const []const u8,
    consumed_by: []const []const u8,
    limitation: []const u8,
};

const ConsumerContract = struct {
    id: []const u8,
    surface: []const u8,
    contract: []const u8,
};

const FixtureMapping = struct {
    id: []const u8,
    source_field: []const u8,
    unified_field: []const u8,
    example_value: []const u8,
    relationship: []const u8,
};

const source_contracts: []const []const u8 = &.{
    core_runtime_contract_schema,
    app_runtime_contract_schema,
    artifact_access_control_contract_schema,
    nendb_node_contract_schema,
    nendb_edge_contract_schema,
};

const runtime_ids: []const CanonicalField = &.{
    .{
        .name = "run_id",
        .maps_from = "CausalEvent.run_id",
        .description = "Stable execution or artifact run scope.",
    },
    .{
        .name = "event_id",
        .maps_from = "CausalEvent.id",
        .description = "Stable append-only event id; current artifacts serialize this as id.",
    },
    .{
        .name = "parent_event_id",
        .maps_from = "CausalEvent.parent_id",
        .description = "Direct structural parent event id; current artifacts serialize this as parent_id.",
    },
    .{
        .name = "cause_id",
        .maps_from = "finding.event_id or derived cause node",
        .description = "Typed cause, finding, or cause-tree node derived from event evidence.",
    },
    .{
        .name = "fiber_id",
        .maps_from = "CausalEvent.fiber_id",
        .description = "Runtime fiber identifier for fork, start, join, interrupt, and pending-lane analysis.",
    },
    .{
        .name = "scope_id",
        .maps_from = "CausalEvent.scope_id",
        .description = "Resource lifetime scope identifier.",
    },
    .{
        .name = "layer_id",
        .maps_from = "future layer graph event metadata",
        .description = "Stable layer graph node id for deep runtime internals.",
    },
    .{
        .name = "service_key",
        .maps_from = "future service requirement/provider metadata",
        .description = "Stable service key for requirement, provider, and replacement graphs.",
    },
    .{
        .name = "resource_id",
        .maps_from = "future resource acquisition/finalizer metadata",
        .description = "Stable resource identity spanning acquire, ownership, and finalizer events.",
    },
};

const app_semantic_ids: []const CanonicalField = &.{
    .{
        .name = "artifact_id",
        .maps_from = "artifact manifest, app response, bundle, or emitted report id",
        .description = "Generated report, response, file, bundle, or app artifact reference.",
    },
    .{
        .name = "domain_entity_ref",
        .maps_from = "redacted app domain reference",
        .description = "Stable redacted reference to an app domain entity.",
    },
    .{
        .name = "data_subject_ref",
        .maps_from = "redacted user, tenant, account, or regulated subject reference",
        .description = "Stable redacted reference to a data subject without raw PII.",
    },
    .{
        .name = "schema_ref",
        .maps_from = "application schema or data contract version",
        .description = "Stable schema/version reference for app reads, writes, and transforms.",
    },
};

const relationship_types: []const RelationshipType = &.{
    .{
        .id = "caused_by",
        .description = "Event, finding, or app incident was caused by another event or cause node.",
        .primary_index = "cause_index",
    },
    .{
        .id = "parent_of",
        .description = "Structural parent/child relationship from parent_event_id to event_id.",
        .primary_index = "parent_index",
    },
    .{
        .id = "requires",
        .description = "Effect, layer, app operation, or policy gate requires a service, config, resource, schema, or precondition.",
        .primary_index = "layer_service_index",
    },
    .{
        .id = "provides",
        .description = "Layer, service, resource, or app operation provides a dependency or capability.",
        .primary_index = "layer_service_index",
    },
    .{
        .id = "reads",
        .description = "Runtime or app event reads a redacted domain entity, data subject, resource, or schema.",
        .primary_index = "data_lineage_index",
    },
    .{
        .id = "writes",
        .description = "Runtime or app event writes a redacted domain entity, data subject, resource, or schema.",
        .primary_index = "data_lineage_index",
    },
    .{
        .id = "transforms",
        .description = "Event transforms data from one redacted schema/entity reference to another.",
        .primary_index = "data_lineage_index",
    },
    .{
        .id = "emits",
        .description = "Event emits an artifact, metric, log, response, report, or app semantic artifact.",
        .primary_index = "artifact_index",
    },
    .{
        .id = "owns",
        .description = "Scope, fiber, layer, or app operation owns a resource or subgraph.",
        .primary_index = "scope_index",
    },
    .{
        .id = "finalizes",
        .description = "Finalizer or close event releases a resource, scope, or app-owned artifact.",
        .primary_index = "scope_index",
    },
};

const policy_stages: []const PolicyStage = &.{
    .{
        .id = "append-only-source-events",
        .order = 1,
        .description = "Runtime internals and app semantic APIs emit source facts without mutating historical events.",
        .invariant = "CausalStore source events remain append-only",
    },
    .{
        .id = "spine-normalization",
        .order = 2,
        .description = "Existing runtime fields and app semantic refs are normalized into canonical ids and relationship records.",
        .invariant = "normalization maps fields but does not rename existing v1 artifacts",
    },
    .{
        .id = "redaction-sampling-retention-policy",
        .order = 3,
        .description = "Redaction, sampling, truncation, access-control, and retention policy are applied before any external projection.",
        .invariant = "no raw payload, secret, credential, prompt, request body, header, or PII crosses this boundary",
    },
    .{
        .id = "derived-index-projection",
        .order = 4,
        .description = "Rebuildable indexes are derived for cause, parent, fiber, scope, layer/service, data lineage, artifact, and findings.",
        .invariant = "indexes are disposable projections and expose limitation metadata",
    },
    .{
        .id = "human-agent-backend-projection",
        .order = 5,
        .description = "Workbench, agent queries, backend export, and NenDB adapter records consume bounded read-only projections.",
        .invariant = "downstream projections do not gain source mutation authority",
    },
};

const derived_indexes: []const DerivedIndex = &.{
    .{
        .id = "cause_index",
        .relationships = &.{"caused_by"},
        .consumed_by = &.{ "agent explain_event", "workbench cause chain", "findings" },
        .limitation = "may be partial when parent events were retained but detailed sampled events were dropped",
    },
    .{
        .id = "parent_index",
        .relationships = &.{"parent_of"},
        .consumed_by = &.{ "lineage query", "workbench event tree", "NenDB edges" },
        .limitation = "parent links preserve v1 parent_id semantics",
    },
    .{
        .id = "fiber_index",
        .relationships = &.{ "parent_of", "owns" },
        .consumed_by = &.{ "fiber lane query", "pending fiber findings", "runtime topology view" },
        .limitation = "fiber details deepen in the next runtime internals branch",
    },
    .{
        .id = "scope_index",
        .relationships = &.{ "owns", "finalizes" },
        .consumed_by = &.{ "resource query", "resource leak findings", "scope tree view" },
        .limitation = "resource_id is introduced as future metadata and not retrofitted into v1 events here",
    },
    .{
        .id = "layer_service_index",
        .relationships = &.{ "requires", "provides" },
        .consumed_by = &.{ "missing service findings", "layer graph", "startup diagnostics" },
        .limitation = "layer_id and service_key are contract fields until deep runtime internals emits them",
    },
    .{
        .id = "data_lineage_index",
        .relationships = &.{ "reads", "writes", "transforms" },
        .consumed_by = &.{ "agent trace_data", "app incident analysis", "workbench data lineage graph" },
        .limitation = "stores references only and never raw app payloads",
    },
    .{
        .id = "artifact_index",
        .relationships = &.{"emits"},
        .consumed_by = &.{ "artifact access control", "workbench artifacts", "production aggregation" },
        .limitation = "artifact visibility is governed by access-control policy before sharing",
    },
    .{
        .id = "finding_index",
        .relationships = &.{ "caused_by", "requires", "finalizes" },
        .consumed_by = &.{ "agent find_failures", "CI handoff", "remediation chain" },
        .limitation = "findings include confidence and limitation notes instead of claiming completeness",
    },
};

const consumer_contracts: []const ConsumerContract = &.{
    .{
        .id = "deep-runtime-internals",
        .surface = "zigeffect runtime",
        .contract = "Emit typed layer, service, scope, fiber, resource, finalizer, retry, interruption, defect, and cause-chain facts using canonical runtime ids.",
    },
    .{
        .id = "app-semantic-trace-api",
        .surface = "apps built with zigeffect",
        .contract = "Emit semantic boundaries, service calls, domain actions, data reads/writes/transforms, policy decisions, artifacts, and responses using redacted refs.",
    },
    .{
        .id = "agent-query-interface",
        .surface = "agent tools",
        .contract = "Return bounded graph slices with event ids, relationship ids, policy state, limitation notes, confidence, verification commands, and next-query hints.",
    },
    .{
        .id = "solidjs-zig-webui-workbench",
        .surface = "SolidJS inside webui-dev/zig-webui",
        .contract = "Render read-only graph, timeline, findings, artifact, and remediation views that cite the same ids exposed to agents.",
    },
    .{
        .id = "nendb-adapter-projection",
        .surface = "NenDB adapter",
        .contract = "Persist post-policy nodes and edges as durable projections without becoming the source event store.",
    },
};

const fixture_mappings: []const FixtureMapping = &.{
    .{
        .id = "runtime-event-id",
        .source_field = "id",
        .unified_field = "event_id",
        .example_value = "event:0002",
        .relationship = "parent_of",
    },
    .{
        .id = "runtime-parent-id",
        .source_field = "parent_id",
        .unified_field = "parent_event_id",
        .example_value = "event:0001",
        .relationship = "parent_of",
    },
    .{
        .id = "runtime-service-requirement",
        .source_field = "type_name",
        .unified_field = "service_key",
        .example_value = "services.config.Config",
        .relationship = "requires",
    },
    .{
        .id = "runtime-scope-resource",
        .source_field = "scope_id",
        .unified_field = "scope_id",
        .example_value = "scope:0009",
        .relationship = "owns",
    },
    .{
        .id = "app-artifact",
        .source_field = "app emitted artifact",
        .unified_field = "artifact_id",
        .example_value = "artifact:response:health-check",
        .relationship = "emits",
    },
    .{
        .id = "app-domain-entity-read",
        .source_field = "redacted domain reference",
        .unified_field = "domain_entity_ref",
        .example_value = "entity:deck:redacted",
        .relationship = "reads",
    },
    .{
        .id = "app-data-subject-write",
        .source_field = "redacted data subject reference",
        .unified_field = "data_subject_ref",
        .example_value = "subject:user:redacted",
        .relationship = "writes",
    },
    .{
        .id = "app-schema-transform",
        .source_field = "schema version reference",
        .unified_field = "schema_ref",
        .example_value = "schema:yachdee.deck.v1",
        .relationship = "transforms",
    },
};

const authority_boundaries: []const []const u8 = &.{
    "CausalStore source events remain append-only",
    "policy is applied before every human agent backend or durable projection",
    "derived indexes are rebuildable and disposable",
    "agent responses are bounded redacted and loss-aware",
    "SolidJS zig-webui workbench remains read-only",
    "NenDB records are durable projections not source-of-truth events",
    "mutation authority remains none",
};

const non_goals: []const []const u8 = &.{
    "live runtime emission changes",
    "new app semantic API implementation",
    "workbench UI changes",
    "agent query implementation",
    "direct upstream NenDB dependency changes",
    "Cockroach adapter work",
    "React workbench support",
    "production mutation authority",
    "live telemetry ingestion",
    "RBAC enforcement",
};

const verification_commands: []const []const u8 = &.{
    "cd packages/zigeffect",
    "zig build causal-unified-spine-contract",
    "zig build causal-unified-spine-contract -- --format json",
    "zig build causal-artifact-access-control",
    "zig build causal-production-hardening-backlog",
    "zig build causal-production-hardening-backlog -- --format json",
    "zig build causal-schema-governance",
    "zig build examples",
    "zig build test",
    "cd ../..",
    "bun run check",
    "bun run zig:test",
    "git diff --check",
};

fn usage() []const u8 {
    return
    \\usage:
    \\  zig build causal-unified-spine-contract
    \\  zig build causal-unified-spine-contract -- --format text
    \\  zig build causal-unified-spine-contract -- --format json
    \\
    \\formats:
    \\  --format text|json
    \\
    ;
}

fn parseOptions(args: []const []const u8) !OutputFormat {
    if (args.len == 1) return .text;
    if (args.len == 3 and std.mem.eql(u8, args[1], "--format")) {
        if (std.mem.eql(u8, args[2], "text")) return .text;
        if (std.mem.eql(u8, args[2], "json")) return .json;
        return error.UnknownFormat;
    }
    if (args.len == 2 and std.mem.eql(u8, args[1], "--format")) return error.MissingFormat;
    return error.UnknownFlag;
}

pub fn formatUnifiedSpineContractText(allocator: std.mem.Allocator) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect causal unified spine contract\n");
    try output.print(allocator, "schema: {s}\n", .{unified_spine_contract_schema});
    try output.print(allocator, "schema_version: {d}\n", .{unified_spine_contract_schema_version});
    try output.appendSlice(allocator, "status: current\n");
    try output.print(allocator, "generated by: {s}\n", .{generated_by});
    try output.print(allocator, "recommendation: {s}\n", .{recommendation});
    try output.print(allocator, "recommended next branch: {s}\n", .{recommended_next_branch});

    try output.appendSlice(allocator, "\nsource contracts:\n");
    for (source_contracts) |schema| try output.print(allocator, "- {s}\n", .{schema});

    try output.appendSlice(allocator, "\nruntime ids:\n");
    for (runtime_ids) |field| {
        try output.print(allocator, "- {s}\n", .{field.name});
        try output.print(allocator, "  maps from: {s}\n", .{field.maps_from});
        try output.print(allocator, "  description: {s}\n", .{field.description});
    }

    try output.appendSlice(allocator, "\napp semantic ids:\n");
    for (app_semantic_ids) |field| {
        try output.print(allocator, "- {s}\n", .{field.name});
        try output.print(allocator, "  maps from: {s}\n", .{field.maps_from});
        try output.print(allocator, "  description: {s}\n", .{field.description});
    }

    try output.appendSlice(allocator, "\nrelationship types:\n");
    for (relationship_types) |relationship| {
        try output.print(allocator, "- {s}\n", .{relationship.id});
        try output.print(allocator, "  primary index: {s}\n", .{relationship.primary_index});
        try output.print(allocator, "  description: {s}\n", .{relationship.description});
    }

    try output.appendSlice(allocator, "\npolicy stages:\n");
    for (policy_stages) |stage| {
        try output.print(allocator, "{d}. {s}\n", .{ stage.order, stage.id });
        try output.print(allocator, "   description: {s}\n", .{stage.description});
        try output.print(allocator, "   invariant: {s}\n", .{stage.invariant});
    }

    try output.appendSlice(allocator, "\nderived indexes:\n");
    for (derived_indexes) |index| {
        try output.print(allocator, "- {s}\n", .{index.id});
        try output.appendSlice(allocator, "  relationships:");
        for (index.relationships) |relationship| try output.print(allocator, " {s}", .{relationship});
        try output.append(allocator, '\n');
        try output.appendSlice(allocator, "  consumed by:");
        for (index.consumed_by) |consumer| try output.print(allocator, " {s};", .{consumer});
        try output.append(allocator, '\n');
        try output.print(allocator, "  limitation: {s}\n", .{index.limitation});
    }

    try output.appendSlice(allocator, "\nconsumer contracts:\n");
    for (consumer_contracts) |consumer| {
        try output.print(allocator, "- {s}\n", .{consumer.id});
        try output.print(allocator, "  surface: {s}\n", .{consumer.surface});
        try output.print(allocator, "  contract: {s}\n", .{consumer.contract});
    }

    try output.appendSlice(allocator, "\nfixture mappings:\n");
    for (fixture_mappings) |mapping| {
        try output.print(allocator, "- {s}\n", .{mapping.id});
        try output.print(allocator, "  source field: {s}\n", .{mapping.source_field});
        try output.print(allocator, "  unified field: {s}\n", .{mapping.unified_field});
        try output.print(allocator, "  example value: {s}\n", .{mapping.example_value});
        try output.print(allocator, "  relationship: {s}\n", .{mapping.relationship});
    }

    try output.appendSlice(allocator, "\nauthority boundaries:\n");
    for (authority_boundaries) |boundary| try output.print(allocator, "- {s}\n", .{boundary});

    try output.appendSlice(allocator, "\nnon-goals:\n");
    for (non_goals) |goal| try output.print(allocator, "- {s}\n", .{goal});

    try output.appendSlice(allocator, "\nverification commands:\n");
    for (verification_commands) |command| try output.print(allocator, "- {s}\n", .{command});

    return output.toOwnedSlice(allocator);
}

pub fn formatUnifiedSpineContractJson(allocator: std.mem.Allocator) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try appendJsonStringProperty(allocator, &output, "schema", unified_spine_contract_schema, true);
    try appendJsonU32Property(allocator, &output, "schema_version", unified_spine_contract_schema_version, true);
    try appendJsonStringProperty(allocator, &output, "status", "current", true);
    try appendJsonStringProperty(allocator, &output, "generated_by", generated_by, true);
    try appendJsonStringArrayProperty(allocator, &output, "source_contracts", source_contracts, true);
    try appendJsonStringProperty(allocator, &output, "recommendation", recommendation, true);
    try appendJsonStringProperty(allocator, &output, "recommended_next_branch", recommended_next_branch, true);

    try output.appendSlice(allocator, "  \"runtime_ids\": [\n");
    for (runtime_ids, 0..) |field, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringPropertyIndented(allocator, &output, "name", field.name, true, "      ");
        try appendJsonStringPropertyIndented(allocator, &output, "maps_from", field.maps_from, true, "      ");
        try appendJsonStringPropertyIndented(allocator, &output, "description", field.description, false, "      ");
        try output.appendSlice(allocator, if (index + 1 == runtime_ids.len) "    }\n" else "    },\n");
    }
    try output.appendSlice(allocator, "  ],\n");

    try output.appendSlice(allocator, "  \"app_semantic_ids\": [\n");
    for (app_semantic_ids, 0..) |field, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringPropertyIndented(allocator, &output, "name", field.name, true, "      ");
        try appendJsonStringPropertyIndented(allocator, &output, "maps_from", field.maps_from, true, "      ");
        try appendJsonStringPropertyIndented(allocator, &output, "description", field.description, false, "      ");
        try output.appendSlice(allocator, if (index + 1 == app_semantic_ids.len) "    }\n" else "    },\n");
    }
    try output.appendSlice(allocator, "  ],\n");

    try output.appendSlice(allocator, "  \"relationship_types\": [\n");
    for (relationship_types, 0..) |relationship, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringPropertyIndented(allocator, &output, "id", relationship.id, true, "      ");
        try appendJsonStringPropertyIndented(allocator, &output, "description", relationship.description, true, "      ");
        try appendJsonStringPropertyIndented(allocator, &output, "primary_index", relationship.primary_index, false, "      ");
        try output.appendSlice(allocator, if (index + 1 == relationship_types.len) "    }\n" else "    },\n");
    }
    try output.appendSlice(allocator, "  ],\n");

    try output.appendSlice(allocator, "  \"policy_stages\": [\n");
    for (policy_stages, 0..) |stage, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringPropertyIndented(allocator, &output, "id", stage.id, true, "      ");
        try appendJsonU32PropertyIndented(allocator, &output, "order", stage.order, true, "      ");
        try appendJsonStringPropertyIndented(allocator, &output, "description", stage.description, true, "      ");
        try appendJsonStringPropertyIndented(allocator, &output, "invariant", stage.invariant, false, "      ");
        try output.appendSlice(allocator, if (index + 1 == policy_stages.len) "    }\n" else "    },\n");
    }
    try output.appendSlice(allocator, "  ],\n");

    try output.appendSlice(allocator, "  \"derived_indexes\": [\n");
    for (derived_indexes, 0..) |index_item, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringPropertyIndented(allocator, &output, "id", index_item.id, true, "      ");
        try output.appendSlice(allocator, "      \"relationships\": ");
        try appendJsonStringArray(allocator, &output, index_item.relationships);
        try output.appendSlice(allocator, ",\n");
        try output.appendSlice(allocator, "      \"consumed_by\": ");
        try appendJsonStringArray(allocator, &output, index_item.consumed_by);
        try output.appendSlice(allocator, ",\n");
        try appendJsonStringPropertyIndented(allocator, &output, "limitation", index_item.limitation, false, "      ");
        try output.appendSlice(allocator, if (index + 1 == derived_indexes.len) "    }\n" else "    },\n");
    }
    try output.appendSlice(allocator, "  ],\n");

    try output.appendSlice(allocator, "  \"consumer_contracts\": [\n");
    for (consumer_contracts, 0..) |consumer, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringPropertyIndented(allocator, &output, "id", consumer.id, true, "      ");
        try appendJsonStringPropertyIndented(allocator, &output, "surface", consumer.surface, true, "      ");
        try appendJsonStringPropertyIndented(allocator, &output, "contract", consumer.contract, false, "      ");
        try output.appendSlice(allocator, if (index + 1 == consumer_contracts.len) "    }\n" else "    },\n");
    }
    try output.appendSlice(allocator, "  ],\n");

    try output.appendSlice(allocator, "  \"fixture_mappings\": [\n");
    for (fixture_mappings, 0..) |mapping, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringPropertyIndented(allocator, &output, "id", mapping.id, true, "      ");
        try appendJsonStringPropertyIndented(allocator, &output, "source_field", mapping.source_field, true, "      ");
        try appendJsonStringPropertyIndented(allocator, &output, "unified_field", mapping.unified_field, true, "      ");
        try appendJsonStringPropertyIndented(allocator, &output, "example_value", mapping.example_value, true, "      ");
        try appendJsonStringPropertyIndented(allocator, &output, "relationship", mapping.relationship, false, "      ");
        try output.appendSlice(allocator, if (index + 1 == fixture_mappings.len) "    }\n" else "    },\n");
    }
    try output.appendSlice(allocator, "  ],\n");

    try appendJsonStringArrayProperty(allocator, &output, "authority_boundaries", authority_boundaries, true);
    try appendJsonStringArrayProperty(allocator, &output, "non_goals", non_goals, true);
    try appendJsonStringArrayProperty(allocator, &output, "verification_commands", verification_commands, false);
    try output.appendSlice(allocator, "}\n");

    return output.toOwnedSlice(allocator);
}

fn appendJsonStringProperty(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    name: []const u8,
    value: []const u8,
    trailing: bool,
) std.mem.Allocator.Error!void {
    try appendJsonStringPropertyIndented(allocator, output, name, value, trailing, "  ");
}

fn appendJsonStringPropertyIndented(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    name: []const u8,
    value: []const u8,
    trailing: bool,
    indent: []const u8,
) std.mem.Allocator.Error!void {
    try output.appendSlice(allocator, indent);
    try output.append(allocator, '"');
    try output.appendSlice(allocator, name);
    try output.appendSlice(allocator, "\": ");
    try appendJsonString(allocator, output, value);
    try output.appendSlice(allocator, if (trailing) ",\n" else "\n");
}

fn appendJsonU32Property(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    name: []const u8,
    value: u32,
    trailing: bool,
) std.mem.Allocator.Error!void {
    try appendJsonU32PropertyIndented(allocator, output, name, value, trailing, "  ");
}

fn appendJsonU32PropertyIndented(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    name: []const u8,
    value: u32,
    trailing: bool,
    indent: []const u8,
) std.mem.Allocator.Error!void {
    try output.print(allocator, "{s}\"{s}\": {d}", .{ indent, name, value });
    try output.appendSlice(allocator, if (trailing) ",\n" else "\n");
}

fn appendJsonStringArrayProperty(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    name: []const u8,
    values: []const []const u8,
    trailing: bool,
) std.mem.Allocator.Error!void {
    try output.print(allocator, "  \"{s}\": ", .{name});
    try appendJsonStringArray(allocator, output, values);
    try output.appendSlice(allocator, if (trailing) ",\n" else "\n");
}

fn appendJsonStringArray(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    values: []const []const u8,
) std.mem.Allocator.Error!void {
    try output.append(allocator, '[');
    for (values, 0..) |value, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try appendJsonString(allocator, output, value);
    }
    try output.append(allocator, ']');
}

fn appendJsonString(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    value: []const u8,
) std.mem.Allocator.Error!void {
    try output.append(allocator, '"');
    for (value) |byte| {
        switch (byte) {
            '"' => try output.appendSlice(allocator, "\\\""),
            '\\' => try output.appendSlice(allocator, "\\\\"),
            '\n' => try output.appendSlice(allocator, "\\n"),
            '\r' => try output.appendSlice(allocator, "\\r"),
            '\t' => try output.appendSlice(allocator, "\\t"),
            else => try output.append(allocator, byte),
        }
    }
    try output.append(allocator, '"');
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-unified-spine-contract error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(1);
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const format = parseOptions(args) catch |err| failUsage(err);
    const report = switch (format) {
        .text => try formatUnifiedSpineContractText(init.gpa),
        .json => try formatUnifiedSpineContractJson(init.gpa),
    };
    defer init.gpa.free(report);

    std.debug.print("{s}", .{report});
}

fn expectRuntimeId(name: []const u8) !void {
    for (runtime_ids) |field| {
        if (std.mem.eql(u8, field.name, name)) return;
    }
    return error.MissingRuntimeId;
}

fn expectAppSemanticId(name: []const u8) !void {
    for (app_semantic_ids) |field| {
        if (std.mem.eql(u8, field.name, name)) return;
    }
    return error.MissingAppSemanticId;
}

fn expectRelationship(id: []const u8) !void {
    for (relationship_types) |relationship| {
        if (std.mem.eql(u8, relationship.id, id)) return;
    }
    return error.MissingRelationship;
}

fn expectPolicyStage(id: []const u8) !void {
    for (policy_stages) |stage| {
        if (std.mem.eql(u8, stage.id, id)) return;
    }
    return error.MissingPolicyStage;
}

fn expectDerivedIndex(id: []const u8) !void {
    for (derived_indexes) |index| {
        if (std.mem.eql(u8, index.id, id)) return;
    }
    return error.MissingDerivedIndex;
}

fn expectConsumer(id: []const u8) !void {
    for (consumer_contracts) |consumer| {
        if (std.mem.eql(u8, consumer.id, id)) return;
    }
    return error.MissingConsumer;
}

fn expectMapping(id: []const u8) !void {
    for (fixture_mappings) |mapping| {
        if (std.mem.eql(u8, mapping.id, id)) return;
    }
    return error.MissingFixtureMapping;
}

fn expectString(values: []const []const u8, expected: []const u8) !void {
    for (values) |value| {
        if (std.mem.eql(u8, value, expected)) return;
    }
    return error.MissingExpectedString;
}

test "unified spine metadata names schema sources and next branch" {
    try std.testing.expectEqualStrings("zigeffect.causal.unified-spine-contract.v1", unified_spine_contract_schema);
    try std.testing.expectEqual(@as(u32, 1), unified_spine_contract_schema_version);
    try std.testing.expectEqualStrings("zigeffect.causal.v1", core_runtime_contract_schema);
    try std.testing.expectEqualStrings("zigeffect.causal.app-runtime.v1", app_runtime_contract_schema);
    try std.testing.expectEqualStrings("zigeffect.causal.artifact-access-control.v1", artifact_access_control_contract_schema);
    try std.testing.expectEqualStrings("start-deep-runtime-internals", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-deep-runtime-internals", recommended_next_branch);
}

test "unified spine preserves canonical ids relationships indexes and non goals" {
    try expectRuntimeId("run_id");
    try expectRuntimeId("event_id");
    try expectRuntimeId("parent_event_id");
    try expectRuntimeId("cause_id");
    try expectRuntimeId("fiber_id");
    try expectRuntimeId("scope_id");
    try expectRuntimeId("layer_id");
    try expectRuntimeId("service_key");
    try expectRuntimeId("resource_id");

    try expectAppSemanticId("artifact_id");
    try expectAppSemanticId("domain_entity_ref");
    try expectAppSemanticId("data_subject_ref");
    try expectAppSemanticId("schema_ref");

    try expectRelationship("caused_by");
    try expectRelationship("parent_of");
    try expectRelationship("requires");
    try expectRelationship("provides");
    try expectRelationship("reads");
    try expectRelationship("writes");
    try expectRelationship("transforms");
    try expectRelationship("emits");
    try expectRelationship("owns");
    try expectRelationship("finalizes");

    try expectPolicyStage("append-only-source-events");
    try expectPolicyStage("redaction-sampling-retention-policy");
    try expectPolicyStage("derived-index-projection");

    try expectDerivedIndex("cause_index");
    try expectDerivedIndex("parent_index");
    try expectDerivedIndex("fiber_index");
    try expectDerivedIndex("scope_index");
    try expectDerivedIndex("layer_service_index");
    try expectDerivedIndex("data_lineage_index");
    try expectDerivedIndex("artifact_index");
    try expectDerivedIndex("finding_index");

    try expectString(non_goals, "Cockroach adapter work");
    try expectString(non_goals, "React workbench support");
    try expectString(non_goals, "production mutation authority");
    try expectString(non_goals, "direct upstream NenDB dependency changes");
}

test "unified spine exposes consumer contracts and fixture mappings" {
    try expectConsumer("deep-runtime-internals");
    try expectConsumer("app-semantic-trace-api");
    try expectConsumer("agent-query-interface");
    try expectConsumer("solidjs-zig-webui-workbench");
    try expectConsumer("nendb-adapter-projection");

    try expectMapping("runtime-event-id");
    try expectMapping("runtime-parent-id");
    try expectMapping("runtime-service-requirement");
    try expectMapping("app-artifact");
    try expectMapping("app-domain-entity-read");
    try expectMapping("app-data-subject-write");
    try expectMapping("app-schema-transform");

    try expectString(authority_boundaries, "CausalStore source events remain append-only");
    try expectString(authority_boundaries, "policy is applied before every human agent backend or durable projection");
    try expectString(authority_boundaries, "NenDB records are durable projections not source-of-truth events");
}

test "unified spine text and json expose core contract sections" {
    const text = try formatUnifiedSpineContractText(std.testing.allocator);
    defer std.testing.allocator.free(text);
    const json = try formatUnifiedSpineContractJson(std.testing.allocator);
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, text, "runtime ids:") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "app semantic ids:") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "relationship types:") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "policy stages:") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "derived indexes:") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "consumer contracts:") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "fixture mappings:") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "recommended next branch: codex/zigeffect-causal-deep-runtime-internals") != null);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"runtime_ids\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"app_semantic_ids\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"relationship_types\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"policy_stages\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"derived_indexes\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"consumer_contracts\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"fixture_mappings\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"recommended_next_branch\": \"codex/zigeffect-causal-deep-runtime-internals\"") != null);
}

test "unified spine parses text json and errors" {
    try std.testing.expectEqual(OutputFormat.text, try parseOptions(&.{"zigeffect-causal-unified-spine-contract"}));
    try std.testing.expectEqual(OutputFormat.text, try parseOptions(&.{ "zigeffect-causal-unified-spine-contract", "--format", "text" }));
    try std.testing.expectEqual(OutputFormat.json, try parseOptions(&.{ "zigeffect-causal-unified-spine-contract", "--format", "json" }));
    try std.testing.expectError(error.UnknownFormat, parseOptions(&.{ "zigeffect-causal-unified-spine-contract", "--format", "yaml" }));
    try std.testing.expectError(error.MissingFormat, parseOptions(&.{ "zigeffect-causal-unified-spine-contract", "--format" }));
    try std.testing.expectError(error.UnknownFlag, parseOptions(&.{ "zigeffect-causal-unified-spine-contract", "--json" }));
}
