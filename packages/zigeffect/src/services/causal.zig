const std = @import("std");
const causal_backend = @import("causal_backend.zig");
const sync = @import("../runtime/sync.zig");

pub const Allocator = std.mem.Allocator;
pub const CausalBackend = causal_backend.CausalBackend;
pub const causal_json_schema = "zigeffect.causal.v1";
pub const causal_json_schema_version: u32 = 1;
pub const causal_event_taxonomy_version: u32 = 1;
pub const causal_redaction_marker = "<redacted>";
pub const causal_truncation_marker = "<truncated>";

pub const CausalExtensionDomain = enum {
    workflow,
    cluster,
    statechart,
};

pub fn causalExtensionDomainName(domain: CausalExtensionDomain) []const u8 {
    return switch (domain) {
        .workflow => "workflow",
        .cluster => "cluster",
        .statechart => "statechart",
    };
}

pub const CausalSamplingPolicy = struct {
    log_every_n: ?usize = null,
    metric_every_n: ?usize = null,
    span_every_n: ?usize = null,
};

pub const CausalStoreOptions = struct {
    max_events: ?usize = null,
    sampling: CausalSamplingPolicy = .{},
    max_event_string_bytes: ?usize = null,
    // Default service identity stamped onto every recorded event whose own
    // `service_key` is empty. The slice is NOT cloned by the store; it must
    // outlive the store (a string literal is the normal case).
    service_key: []const u8 = "",
};

/// Narrow, copyable capability for boundary adapters that must emit semantic
/// facts after their layer has been acquired. It exposes recording only—not
/// store ownership, snapshots, retention controls, or backend lifecycle. The
/// captured lineage keeps later adapter events attached to the effect that
/// handed out the recorder without retaining a live ContextView.
pub const CausalRecorder = struct {
    pub const Lineage = struct {
        run_id: ?u64 = null,
        parent_id: ?u64 = null,
        fiber_id: ?u64 = null,
        scope_id: ?u64 = null,
        trace_id: ?u64 = null,
        span_id: ?u64 = null,
        context: CausalContextV2 = .{},
    };

    store: *CausalStore,
    lineage: Lineage = .{},

    pub fn fromStore(store: *CausalStore) CausalRecorder {
        return .{ .store = store };
    }

    pub fn withLineage(store: *CausalStore, lineage: Lineage) CausalRecorder {
        return .{ .store = store, .lineage = lineage };
    }

    pub fn record(self: CausalRecorder, event: CausalEvent) Allocator.Error!u64 {
        var enriched = event;
        enriched.run_id = enriched.run_id orelse self.lineage.run_id;
        enriched.parent_id = enriched.parent_id orelse self.lineage.parent_id;
        enriched.fiber_id = enriched.fiber_id orelse self.lineage.fiber_id;
        enriched.scope_id = enriched.scope_id orelse self.lineage.scope_id;
        enriched.trace_id = enriched.trace_id orelse self.lineage.trace_id;
        enriched.span_id = enriched.span_id orelse self.lineage.span_id;
        enriched.context = CausalContextV2.merge(self.lineage.context, enriched.context);
        enriched.context.trace_id_low = enriched.context.trace_id_low orelse enriched.trace_id;
        enriched.context.span_id = enriched.context.span_id orelse enriched.span_id;
        enriched.trace_id = enriched.trace_id orelse enriched.context.trace_id_low;
        enriched.span_id = enriched.span_id orelse enriched.context.span_id;
        return self.store.record(enriched);
    }
};

pub const CausalEventKind = enum {
    run_started,
    run_completed,
    effect_started,
    effect_completed,
    layer_started,
    layer_completed,
    service_required,
    service_provided,
    service_replaced,
    scope_opened,
    scope_closed,
    resource_acquired,
    resource_finalized,
    fiber_forked,
    fiber_started,
    fiber_joined,
    fiber_interrupted,
    fiber_suspended,
    fiber_resumed,
    timer_scheduled,
    timer_fired,
    io_wait_started,
    io_completed,
    deferred_completed,
    queue_item_available,
    signal_raised,
    activity_completed,
    external_signal_received,
    hub_published,
    hub_received,
    remediation_requested,
    remediation_decided,
    remediation_applied,
    schedule_decision,
    exit_recorded,
    log_recorded,
    metric_recorded,
    span_recorded,
    assertion_recorded,
    workflow_event_recorded,
    statechart_event_recorded,
    race_started,
    race_winner_selected,
    race_loser_interrupted,
    both_started,
    both_completed,
    stm_transaction_started,
    stm_conflict_detected,
    stm_retry_scheduled,
    stm_transaction_committed,
    alert_emitted,
    supervisor_child_started,
    supervisor_restart_decided,
    supervisor_escalated,
    supervisor_shutdown_ordered,
    cluster_shard_lease_acquired,
    cluster_shard_lease_refreshed,
    cluster_shard_lease_released,
    cluster_shard_lease_conflict,
    cluster_shard_handoff_started,
    cluster_shard_recovery_started,
    cluster_shard_recovery_completed,
    cluster_runner_registered,
    cluster_runner_heartbeat,
    cluster_message_submitted,
    cluster_message_claimed,
    cluster_message_acked,
    cluster_message_replied,
    cluster_entity_registered,
    cluster_entity_processed,
    cluster_entity_failed,
    cluster_trace_propagated,
};

pub const CausalEventTaxonomy = struct {
    structural: bool,
    finding_evidence: bool,
    sampleable: bool,
};

pub fn causalEventTaxonomy(kind: CausalEventKind) CausalEventTaxonomy {
    return switch (kind) {
        .log_recorded, .metric_recorded, .span_recorded => .{
            .structural = false,
            .finding_evidence = false,
            .sampleable = true,
        },
        .service_required,
        .scope_closed,
        .resource_acquired,
        .resource_finalized,
        .fiber_forked,
        .fiber_started,
        .fiber_joined,
        .fiber_interrupted,
        .fiber_suspended,
        .fiber_resumed,
        .timer_scheduled,
        .timer_fired,
        .io_wait_started,
        .io_completed,
        .deferred_completed,
        .queue_item_available,
        .signal_raised,
        .activity_completed,
        .external_signal_received,
        .hub_published,
        .hub_received,
        .remediation_requested,
        .remediation_decided,
        .remediation_applied,
        .schedule_decision,
        .assertion_recorded,
        .workflow_event_recorded,
        .statechart_event_recorded,
        .race_started,
        .race_winner_selected,
        .race_loser_interrupted,
        .both_started,
        .both_completed,
        .stm_transaction_started,
        .stm_conflict_detected,
        .stm_retry_scheduled,
        .stm_transaction_committed,
        .alert_emitted,
        .supervisor_child_started,
        .supervisor_restart_decided,
        .supervisor_escalated,
        .supervisor_shutdown_ordered,
        .cluster_shard_lease_acquired,
        .cluster_shard_lease_refreshed,
        .cluster_shard_lease_released,
        .cluster_shard_lease_conflict,
        .cluster_shard_handoff_started,
        .cluster_shard_recovery_started,
        .cluster_shard_recovery_completed,
        .cluster_runner_registered,
        .cluster_runner_heartbeat,
        .cluster_message_submitted,
        .cluster_message_claimed,
        .cluster_message_acked,
        .cluster_message_replied,
        .cluster_entity_registered,
        .cluster_entity_processed,
        .cluster_entity_failed,
        .cluster_trace_propagated,
        => .{
            .structural = true,
            .finding_evidence = true,
            .sampleable = false,
        },
        .run_started,
        .run_completed,
        .effect_started,
        .effect_completed,
        .layer_started,
        .layer_completed,
        .service_provided,
        .service_replaced,
        .scope_opened,
        .exit_recorded,
        => .{
            .structural = true,
            .finding_evidence = false,
            .sampleable = false,
        },
    };
}

pub fn isCausalStructuralEvent(kind: CausalEventKind) bool {
    return causalEventTaxonomy(kind).structural;
}

pub fn isCausalFindingEvidenceEvent(kind: CausalEventKind) bool {
    return causalEventTaxonomy(kind).finding_evidence;
}

pub fn isCausalSampleableEvent(kind: CausalEventKind) bool {
    return causalEventTaxonomy(kind).sampleable;
}

pub const causal_context_schema_version: u8 = 2;
pub const max_causal_links: usize = 4;

pub const TraceParent = struct {
    trace_id_high: u64,
    trace_id_low: u64,
    parent_id: u64,
    flags: u8,

    pub fn context(self: TraceParent) CausalContextV2 {
        return .{
            .trace_id_high = self.trace_id_high,
            .trace_id_low = self.trace_id_low,
            .span_id = self.parent_id,
        };
    }

    pub fn format(self: TraceParent) [55]u8 {
        var output: [55]u8 = undefined;
        _ = std.fmt.bufPrint(&output, "00-{x:0>16}{x:0>16}-{x:0>16}-{x:0>2}", .{ self.trace_id_high, self.trace_id_low, self.parent_id, self.flags }) catch unreachable;
        return output;
    }
};

pub fn parseTraceParent(value: []const u8) !TraceParent {
    if (value.len != 55 or value[2] != '-' or value[35] != '-' or value[52] != '-' or std.mem.eql(u8, value[0..2], "ff")) return error.InvalidTraceParent;
    for (value, 0..) |byte, index| {
        if (index == 2 or index == 35 or index == 52) continue;
        if (!std.ascii.isHex(byte)) return error.InvalidTraceParent;
    }
    const parsed = TraceParent{
        .trace_id_high = std.fmt.parseInt(u64, value[3..19], 16) catch return error.InvalidTraceParent,
        .trace_id_low = std.fmt.parseInt(u64, value[19..35], 16) catch return error.InvalidTraceParent,
        .parent_id = std.fmt.parseInt(u64, value[36..52], 16) catch return error.InvalidTraceParent,
        .flags = std.fmt.parseInt(u8, value[53..55], 16) catch return error.InvalidTraceParent,
    };
    if ((parsed.trace_id_high == 0 and parsed.trace_id_low == 0) or parsed.parent_id == 0) return error.InvalidTraceParent;
    return parsed;
}

/// Allocation-free correlation shared by runtime execution, development
/// coordination, embedded graph persistence, and telemetry projections. Zero
/// optionals mean "not supplied"; child contexts inherit missing values from
/// their parent/runtime context.
pub const CausalContextV2 = struct {
    schema_version: u8 = causal_context_schema_version,
    runtime_instance_id: ?u64 = null,
    graph_session_id: ?u64 = null,
    workspace_id: ?u64 = null,
    project_id: ?u64 = null,
    component_id: ?u64 = null,
    requirement_id: ?u64 = null,
    acceptance_check_id: ?u64 = null,
    scenario_id: ?u64 = null,
    agent_id: ?u64 = null,
    agent_attempt: ?u64 = null,
    development_task_id: ?u64 = null,
    work_packet_id: ?u64 = null,
    change_set_id: ?u64 = null,
    source_revision_id: ?u64 = null,
    /// The two halves of a W3C-compatible 128-bit trace identifier.
    trace_id_high: ?u64 = null,
    trace_id_low: ?u64 = null,
    span_id: ?u64 = null,

    pub fn merge(parent: CausalContextV2, child: CausalContextV2) CausalContextV2 {
        return .{
            .runtime_instance_id = child.runtime_instance_id orelse parent.runtime_instance_id,
            .graph_session_id = child.graph_session_id orelse parent.graph_session_id,
            .workspace_id = child.workspace_id orelse parent.workspace_id,
            .project_id = child.project_id orelse parent.project_id,
            .component_id = child.component_id orelse parent.component_id,
            .requirement_id = child.requirement_id orelse parent.requirement_id,
            .acceptance_check_id = child.acceptance_check_id orelse parent.acceptance_check_id,
            .scenario_id = child.scenario_id orelse parent.scenario_id,
            .agent_id = child.agent_id orelse parent.agent_id,
            .agent_attempt = child.agent_attempt orelse parent.agent_attempt,
            .development_task_id = child.development_task_id orelse parent.development_task_id,
            .work_packet_id = child.work_packet_id orelse parent.work_packet_id,
            .change_set_id = child.change_set_id orelse parent.change_set_id,
            .source_revision_id = child.source_revision_id orelse parent.source_revision_id,
            .trace_id_high = child.trace_id_high orelse parent.trace_id_high,
            .trace_id_low = child.trace_id_low orelse parent.trace_id_low,
            .span_id = child.span_id orelse parent.span_id,
        };
    }

    pub fn empty(self: CausalContextV2) bool {
        return self.runtime_instance_id == null and self.graph_session_id == null and
            self.workspace_id == null and self.project_id == null and self.component_id == null and
            self.requirement_id == null and self.acceptance_check_id == null and self.scenario_id == null and
            self.agent_id == null and self.agent_attempt == null and
            self.development_task_id == null and self.work_packet_id == null and
            self.change_set_id == null and self.source_revision_id == null and self.trace_id_high == null and
            self.trace_id_low == null and self.span_id == null;
    }
};

/// Stable non-secret identity projection for bounded causal context fields.
/// The original text remains in manifests/receipts; runtime events carry only
/// this deterministic identifier.
pub fn stableCausalContextId(value: []const u8) u64 {
    var hash: u64 = 14695981039346656037;
    for (value) |byte| {
        hash ^= byte;
        hash *%= 1099511628211;
    }
    return if (hash == 0) 1 else hash;
}

pub const CausalLinkKind = enum {
    parent,
    cause,
    proof,
    lease,
    change,
    federated,
};

pub const CausalLink = struct {
    kind: CausalLinkKind,
    event_id: u64,
    graph_session_id: ?u64 = null,
};

pub const CausalLinkError = error{
    InvalidCausalLink,
    DuplicateCausalLink,
    TooManyCausalLinks,
};

pub const CausalEvent = struct {
    id: u64 = 0,
    kind: CausalEventKind,
    run_id: ?u64 = null,
    parent_id: ?u64 = null,
    fiber_id: ?u64 = null,
    scope_id: ?u64 = null,
    layer_id: ?u64 = null,
    layer_name: []const u8 = "",
    service_key: []const u8 = "",
    resource_id: ?u64 = null,
    cause_event_id: ?u64 = null,
    schedule_id: ?u64 = null,
    source_ref_id: ?u64 = null,
    // Cross-service correlation: one id stamped on both sides of a service
    // boundary — the origin allocates it (nextBoundaryId) and records it on its
    // outbound event; the callee receives it over the transport and records it
    // on its inbound run/scope events.
    boundary_id: ?u64 = null,
    artifact_id: []const u8 = "",
    domain_entity_ref: []const u8 = "",
    data_subject_ref: []const u8 = "",
    schema_ref: []const u8 = "",
    trace_id: ?u64 = null,
    span_id: ?u64 = null,
    context: CausalContextV2 = .{},
    links: [max_causal_links]CausalLink = [_]CausalLink{.{ .kind = .parent, .event_id = 0 }} ** max_causal_links,
    link_count: u8 = 0,
    label: []const u8 = "",
    type_name: []const u8 = "",
    status: []const u8 = "",
    redacted_detail: []const u8 = "",
    /// Internal ownership backing for events retained or cloned by the core
    /// causal store. It is not part of the causal schema; public formatters
    /// serialize the named event fields above. Copies made by other backends
    /// must reset this field before taking independent ownership.
    _owned_text: []u8 = &.{},

    const Wire = struct {
        id: u64,
        kind: CausalEventKind,
        run_id: ?u64,
        parent_id: ?u64,
        fiber_id: ?u64,
        scope_id: ?u64,
        layer_id: ?u64,
        layer_name: []const u8,
        service_key: []const u8,
        resource_id: ?u64,
        cause_event_id: ?u64,
        schedule_id: ?u64,
        source_ref_id: ?u64,
        boundary_id: ?u64,
        artifact_id: []const u8,
        domain_entity_ref: []const u8,
        data_subject_ref: []const u8,
        schema_ref: []const u8,
        trace_id: ?u64,
        span_id: ?u64,
        context: CausalContextV2,
        links: []const CausalLink,
        label: []const u8,
        type_name: []const u8,
        status: []const u8,
        redacted_detail: []const u8,
    };

    /// Keep internal text ownership out of generic JSON serialization. The
    /// causal JSONL and artifact formatters remain the authoritative versioned
    /// wire schemas; this method makes ad-hoc diagnostics safe as well.
    pub fn jsonStringify(self: CausalEvent, writer: anytype) !void {
        try writer.write(Wire{
            .id = self.id,
            .kind = self.kind,
            .run_id = self.run_id,
            .parent_id = self.parent_id,
            .fiber_id = self.fiber_id,
            .scope_id = self.scope_id,
            .layer_id = self.layer_id,
            .layer_name = self.layer_name,
            .service_key = self.service_key,
            .resource_id = self.resource_id,
            .cause_event_id = self.cause_event_id,
            .schedule_id = self.schedule_id,
            .source_ref_id = self.source_ref_id,
            .boundary_id = self.boundary_id,
            .artifact_id = self.artifact_id,
            .domain_entity_ref = self.domain_entity_ref,
            .data_subject_ref = self.data_subject_ref,
            .schema_ref = self.schema_ref,
            .trace_id = self.trace_id,
            .span_id = self.span_id,
            .context = self.context,
            .links = self.activeLinks(),
            .label = self.label,
            .type_name = self.type_name,
            .status = self.status,
            .redacted_detail = self.redacted_detail,
        });
    }

    pub fn activeLinks(self: *const CausalEvent) []const CausalLink {
        const count = @min(@as(usize, self.link_count), max_causal_links);
        return self.links[0..count];
    }

    pub fn addLink(self: *CausalEvent, link: CausalLink) CausalLinkError!void {
        if (link.event_id == 0 or link.graph_session_id == 0) return error.InvalidCausalLink;
        for (self.activeLinks()) |existing| {
            if (existing.kind == link.kind and existing.event_id == link.event_id and
                existing.graph_session_id == link.graph_session_id)
            {
                return error.DuplicateCausalLink;
            }
        }
        if (self.link_count >= max_causal_links) return error.TooManyCausalLinks;
        self.links[self.link_count] = link;
        self.link_count += 1;
    }
};

const sensitive_detail_keys = [_][]const u8{
    "authorization",
    "proxy-authorization",
    "cookie",
    "set-cookie",
    "x-api-key",
    "x-auth-token",
    "api_key",
    "api-key",
    "apikey",
    "token",
    "access_token",
    "access-token",
    "refresh_token",
    "refresh-token",
    "id_token",
    "id-token",
    "session",
    "session_id",
    "session-id",
    "sessionid",
    "csrf",
    "xsrf",
    "password",
    "passwd",
    "pwd",
    "secret",
    "client_secret",
    "client-secret",
    "private_key",
    "private-key",
    "connection_string",
    "connection-string",
    "database_url",
    "database-url",
    "email",
    "user_email",
    "user-email",
    "phone",
    "phone_number",
    "phone-number",
    "ssn",
    "social_security_number",
    "social-security-number",
    "address",
    "street_address",
    "street-address",
    "ip",
    "ip_address",
    "ip-address",
    "user_ip",
    "user-ip",
    "date_of_birth",
    "date-of-birth",
    "dob",
};

fn asciiLower(byte: u8) u8 {
    if (byte >= 'A' and byte <= 'Z') return byte + 32;
    return byte;
}

fn eqlAsciiIgnoreCase(left: []const u8, right: []const u8) bool {
    if (left.len != right.len) return false;
    for (left, right) |a, b| {
        if (asciiLower(a) != asciiLower(b)) return false;
    }
    return true;
}

fn startsWithAsciiIgnoreCase(value: []const u8, index: usize, expected: []const u8) bool {
    if (index + expected.len > value.len) return false;
    return eqlAsciiIgnoreCase(value[index .. index + expected.len], expected);
}

fn isAsciiAlphaNumeric(byte: u8) bool {
    return (byte >= 'a' and byte <= 'z') or
        (byte >= 'A' and byte <= 'Z') or
        (byte >= '0' and byte <= '9');
}

fn isSensitiveKeyChar(byte: u8) bool {
    return isAsciiAlphaNumeric(byte) or byte == '_' or byte == '-' or byte == '.';
}

fn isQuote(byte: u8) bool {
    return byte == '"' or byte == '\'';
}

fn isSensitiveKeyWrapperClose(byte: u8) bool {
    return byte == ']';
}

fn isValueDelimiter(byte: u8) bool {
    return byte == ' ' or
        byte == '\t' or
        byte == '\n' or
        byte == '\r' or
        byte == '&' or
        byte == ';' or
        byte == ',';
}

fn skipValue(value: []const u8, start: usize) usize {
    var index = start;
    while (index < value.len and !isValueDelimiter(value[index])) {
        index += 1;
    }
    return index;
}

fn skipQuotedValue(value: []const u8, start: usize, quote: u8) usize {
    var index = start;
    while (index < value.len) {
        if (value[index] == quote) return index;
        index += 1;
    }
    return index;
}

fn isFullValueDelimiter(byte: u8) bool {
    return byte == '\n' or byte == '\r';
}

fn skipFullSensitiveValue(value: []const u8, start: usize) usize {
    var index = start;
    while (index < value.len and !isFullValueDelimiter(value[index])) {
        index += 1;
    }
    return index;
}

fn isFullValueRedactionKey(key: []const u8) bool {
    return eqlAsciiIgnoreCase(key, "authorization") or
        eqlAsciiIgnoreCase(key, "proxy-authorization") or
        eqlAsciiIgnoreCase(key, "cookie") or
        eqlAsciiIgnoreCase(key, "set-cookie");
}

fn isSensitiveKey(key: []const u8) bool {
    for (sensitive_detail_keys) |candidate| {
        if (eqlAsciiIgnoreCase(key, candidate)) return true;
    }

    if (std.mem.lastIndexOfAny(u8, key, "._-")) |separator_index| {
        const suffix = key[separator_index + 1 ..];
        for (sensitive_detail_keys) |candidate| {
            if (eqlAsciiIgnoreCase(suffix, candidate)) return true;
        }
    }

    return false;
}

fn appendUrlCredentialRedaction(
    output: *std.ArrayList(u8),
    allocator: Allocator,
    value: []const u8,
    index: *usize,
) Allocator.Error!bool {
    if (!std.mem.startsWith(u8, value[index.*..], "://")) return false;

    const authority_start = index.* + 3;
    const authority_end = skipValue(value, authority_start);
    const authority = value[authority_start..authority_end];
    const at_index = std.mem.indexOfScalar(u8, authority, '@') orelse return false;
    const credentials = authority[0..at_index];
    if (std.mem.indexOfScalar(u8, credentials, ':') == null) return false;

    try output.appendSlice(allocator, "://");
    try output.appendSlice(allocator, causal_redaction_marker);
    try output.append(allocator, '@');
    index.* = authority_start + at_index + 1;
    return true;
}

fn appendBearerRedaction(
    output: *std.ArrayList(u8),
    allocator: Allocator,
    value: []const u8,
    index: *usize,
) Allocator.Error!bool {
    if (!startsWithAsciiIgnoreCase(value, index.*, "bearer")) return false;
    const after_bearer = index.* + "bearer".len;
    if (after_bearer >= value.len or !std.ascii.isWhitespace(value[after_bearer])) return false;

    try output.appendSlice(allocator, value[index.*..after_bearer]);
    var value_start = after_bearer;
    while (value_start < value.len and std.ascii.isWhitespace(value[value_start])) {
        try output.append(allocator, value[value_start]);
        value_start += 1;
    }
    try output.appendSlice(allocator, causal_redaction_marker);
    index.* = skipValue(value, value_start);
    return true;
}

fn appendSensitiveKeyRedaction(
    output: *std.ArrayList(u8),
    allocator: Allocator,
    value: []const u8,
    index: *usize,
) Allocator.Error!bool {
    var key_start = index.*;
    var key_quote: ?u8 = null;
    if (isQuote(value[key_start])) {
        key_quote = value[key_start];
        key_start += 1;
    }

    if (key_start >= value.len or !isSensitiveKeyChar(value[key_start])) return false;

    var key_end = key_start;
    while (key_end < value.len and isSensitiveKeyChar(value[key_end])) {
        key_end += 1;
    }

    var after_key = key_end;
    if (key_quote) |quote| {
        if (after_key >= value.len or value[after_key] != quote) return false;
        after_key += 1;
    }
    if (after_key < value.len and isSensitiveKeyWrapperClose(value[after_key])) {
        after_key += 1;
    }

    var separator_index = after_key;
    while (separator_index < value.len and std.ascii.isWhitespace(value[separator_index])) {
        separator_index += 1;
    }
    if (separator_index >= value.len) return false;

    var separator: ?u8 = null;
    if (value[separator_index] == '=' or value[separator_index] == ':') {
        separator = value[separator_index];
        separator_index += 1;
    } else if (!isQuote(value[separator_index])) {
        return false;
    }

    const key = value[key_start..key_end];
    if (!isSensitiveKey(key)) return false;

    var value_start = separator_index;
    while (value_start < value.len and std.ascii.isWhitespace(value[value_start])) {
        value_start += 1;
    }

    var value_quote: ?u8 = null;
    if (value_start < value.len and isQuote(value[value_start])) {
        value_quote = value[value_start];
        value_start += 1;
    }

    try output.appendSlice(allocator, value[index.*..value_start]);
    try output.appendSlice(allocator, causal_redaction_marker);

    if (value_quote) |quote| {
        const value_end = skipQuotedValue(value, value_start, quote);
        if (value_end < value.len) {
            try output.append(allocator, quote);
            index.* = value_end + 1;
        } else {
            index.* = value_end;
        }
        return true;
    }

    index.* = if (separator != null and separator.? == ':' and isFullValueRedactionKey(key))
        skipFullSensitiveValue(value, value_start)
    else
        skipValue(value, value_start);
    return true;
}

fn redactCausalText(allocator: Allocator, value: []const u8) Allocator.Error![]const u8 {
    if (value.len == 0) return "";

    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    var index: usize = 0;
    while (index < value.len) {
        if (try appendUrlCredentialRedaction(&output, allocator, value, &index)) continue;
        if (try appendSensitiveKeyRedaction(&output, allocator, value, &index)) continue;
        if (try appendBearerRedaction(&output, allocator, value, &index)) continue;

        try output.append(allocator, value[index]);
        index += 1;
    }

    return output.toOwnedSlice(allocator);
}

fn truncateCausalText(
    allocator: Allocator,
    value: []const u8,
    max_bytes: ?usize,
    truncated_field_count: *u64,
) Allocator.Error![]const u8 {
    const max = max_bytes orelse return value;
    if (value.len <= max) return value;

    truncated_field_count.* += 1;
    if (max == 0) return "";

    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    if (max <= causal_truncation_marker.len) {
        try output.appendSlice(allocator, causal_truncation_marker[0..max]);
        return output.toOwnedSlice(allocator);
    }

    const prefix_len = max - causal_truncation_marker.len;
    try output.appendSlice(allocator, value[0..prefix_len]);
    try output.appendSlice(allocator, causal_truncation_marker);
    return output.toOwnedSlice(allocator);
}

fn redactAndBoundCausalText(
    allocator: Allocator,
    value: []const u8,
    max_bytes: ?usize,
    truncated_field_count: *u64,
) Allocator.Error![]const u8 {
    const redacted = try redactCausalText(allocator, value);
    errdefer if (redacted.len > 0) allocator.free(redacted);

    const truncated = try truncateCausalText(allocator, redacted, max_bytes, truncated_field_count);
    if (truncated.ptr == redacted.ptr) return redacted;

    if (redacted.len > 0) allocator.free(redacted);
    return truncated;
}

fn cloneSlice(allocator: Allocator, value: []const u8) Allocator.Error![]const u8 {
    if (value.len == 0) return "";
    return allocator.dupe(u8, value);
}

fn packEventText(allocator: Allocator, event: *CausalEvent) Allocator.Error!void {
    const fields = .{
        &event.label,
        &event.type_name,
        &event.layer_name,
        &event.service_key,
        &event.artifact_id,
        &event.domain_entity_ref,
        &event.data_subject_ref,
        &event.schema_ref,
        &event.status,
        &event.redacted_detail,
    };

    var total_bytes: usize = 0;
    inline for (fields) |field| total_bytes += field.*.len;
    if (total_bytes == 0) {
        event._owned_text = &.{};
        return;
    }

    const storage = try allocator.alloc(u8, total_bytes);
    var offset: usize = 0;
    inline for (fields) |field| {
        const previous = field.*;
        const next = storage[offset .. offset + previous.len];
        @memcpy(next, previous);
        field.* = next;
        offset += previous.len;
    }
    event._owned_text = storage;
}

fn cloneEventForStore(
    allocator: Allocator,
    event: CausalEvent,
    max_event_string_bytes: ?usize,
    truncated_field_count: *u64,
) Allocator.Error!CausalEvent {
    var scratch_arena = std.heap.ArenaAllocator.init(allocator);
    defer scratch_arena.deinit();
    const scratch = scratch_arena.allocator();

    var owned = event;
    owned._owned_text = &.{};
    owned.label = try redactAndBoundCausalText(scratch, event.label, max_event_string_bytes, truncated_field_count);
    owned.type_name = try redactAndBoundCausalText(scratch, event.type_name, max_event_string_bytes, truncated_field_count);
    owned.layer_name = try redactAndBoundCausalText(scratch, event.layer_name, max_event_string_bytes, truncated_field_count);
    owned.service_key = try redactAndBoundCausalText(scratch, event.service_key, max_event_string_bytes, truncated_field_count);
    owned.artifact_id = try redactAndBoundCausalText(scratch, event.artifact_id, max_event_string_bytes, truncated_field_count);
    owned.domain_entity_ref = try redactAndBoundCausalText(scratch, event.domain_entity_ref, max_event_string_bytes, truncated_field_count);
    owned.data_subject_ref = try redactAndBoundCausalText(scratch, event.data_subject_ref, max_event_string_bytes, truncated_field_count);
    owned.schema_ref = try redactAndBoundCausalText(scratch, event.schema_ref, max_event_string_bytes, truncated_field_count);
    owned.status = try redactAndBoundCausalText(scratch, event.status, max_event_string_bytes, truncated_field_count);
    owned.redacted_detail = try redactAndBoundCausalText(scratch, event.redacted_detail, max_event_string_bytes, truncated_field_count);
    try packEventText(allocator, &owned);
    return owned;
}

fn cloneEvent(allocator: Allocator, event: CausalEvent) Allocator.Error!CausalEvent {
    var scratch_arena = std.heap.ArenaAllocator.init(allocator);
    defer scratch_arena.deinit();
    const scratch = scratch_arena.allocator();

    var owned = event;
    owned._owned_text = &.{};
    owned.label = try redactCausalText(scratch, event.label);
    owned.type_name = try redactCausalText(scratch, event.type_name);
    owned.layer_name = try redactCausalText(scratch, event.layer_name);
    owned.service_key = try redactCausalText(scratch, event.service_key);
    owned.artifact_id = try redactCausalText(scratch, event.artifact_id);
    owned.domain_entity_ref = try redactCausalText(scratch, event.domain_entity_ref);
    owned.data_subject_ref = try redactCausalText(scratch, event.data_subject_ref);
    owned.schema_ref = try redactCausalText(scratch, event.schema_ref);
    owned.status = try redactCausalText(scratch, event.status);
    owned.redacted_detail = try redactCausalText(scratch, event.redacted_detail);
    try packEventText(allocator, &owned);
    return owned;
}

fn deinitEventStrings(allocator: Allocator, event: CausalEvent) void {
    if (event._owned_text.len > 0) {
        allocator.free(event._owned_text);
        return;
    }
    if (event.label.len > 0) allocator.free(event.label);
    if (event.type_name.len > 0) allocator.free(event.type_name);
    if (event.layer_name.len > 0) allocator.free(event.layer_name);
    if (event.service_key.len > 0) allocator.free(event.service_key);
    if (event.artifact_id.len > 0) allocator.free(event.artifact_id);
    if (event.domain_entity_ref.len > 0) allocator.free(event.domain_entity_ref);
    if (event.data_subject_ref.len > 0) allocator.free(event.data_subject_ref);
    if (event.schema_ref.len > 0) allocator.free(event.schema_ref);
    if (event.status.len > 0) allocator.free(event.status);
    if (event.redacted_detail.len > 0) allocator.free(event.redacted_detail);
}

pub const CausalSnapshot = struct {
    allocator: Allocator,
    events: []CausalEvent,

    pub fn deinit(self: *CausalSnapshot) void {
        for (self.events) |event| {
            deinitEventStrings(self.allocator, event);
        }
        self.allocator.free(self.events);
    }
};

pub const CausalLineage = struct {
    allocator: Allocator,
    events: []CausalEvent,

    pub fn deinit(self: *CausalLineage) void {
        for (self.events) |event| {
            deinitEventStrings(self.allocator, event);
        }
        self.allocator.free(self.events);
    }
};

/// Net (latest) lifecycle state of one fiber, collapsing its event history.
pub const CausalFiberState = struct {
    fiber_id: u64,
    latest_event_id: u64,
    latest_kind: CausalEventKind,
    /// reached a terminal state (joined or interrupted)
    resolved: bool,
    /// latest event is a suspension still awaiting a wake
    parked: bool,
};

pub const CausalFiberStates = struct {
    allocator: Allocator,
    items: []CausalFiberState,

    pub fn deinit(self: *CausalFiberStates) void {
        self.allocator.free(self.items);
    }

    /// Fibers that are neither resolved nor woken — still forked/started/parked.
    pub fn unresolvedCount(self: *const CausalFiberStates) usize {
        var count: usize = 0;
        for (self.items) |state| {
            if (!state.resolved) count += 1;
        }
        return count;
    }
};

pub fn isFiberLifecycleKind(kind: CausalEventKind) bool {
    return switch (kind) {
        .fiber_forked, .fiber_started, .fiber_suspended, .fiber_resumed, .fiber_joined, .fiber_interrupted => true,
        else => false,
    };
}

fn isTerminalFiberKind(kind: CausalEventKind) bool {
    return kind == .fiber_joined or kind == .fiber_interrupted;
}

pub const CausalFindingKind = enum {
    resource_acquired_without_finalization,
    fiber_pending_after_scope_close,
    fiber_suspended_without_resume,
    finalizer_failure,
    retry_budget_exhausted,
    service_requirement_without_provider,
    assertion_failure,
};

pub const CausalFinding = struct {
    kind: CausalFindingKind,
    event_id: u64,
    run_id: ?u64 = null,
    scope_id: ?u64 = null,
    fiber_id: ?u64 = null,
    label: []const u8 = "",
    type_name: []const u8 = "",
    redacted_detail: []const u8 = "",
};

fn cloneFinding(allocator: Allocator, finding: CausalFinding) Allocator.Error!CausalFinding {
    var owned = finding;
    owned.label = try cloneSlice(allocator, finding.label);
    errdefer if (owned.label.len > 0) allocator.free(owned.label);
    owned.type_name = try cloneSlice(allocator, finding.type_name);
    errdefer if (owned.type_name.len > 0) allocator.free(owned.type_name);
    owned.redacted_detail = try cloneSlice(allocator, finding.redacted_detail);
    errdefer if (owned.redacted_detail.len > 0) allocator.free(owned.redacted_detail);
    return owned;
}

fn deinitFindingStrings(allocator: Allocator, finding: CausalFinding) void {
    if (finding.label.len > 0) allocator.free(finding.label);
    if (finding.type_name.len > 0) allocator.free(finding.type_name);
    if (finding.redacted_detail.len > 0) allocator.free(finding.redacted_detail);
}

pub const CausalFindings = struct {
    allocator: Allocator,
    items: []CausalFinding,

    pub fn deinit(self: *CausalFindings) void {
        for (self.items) |finding| {
            deinitFindingStrings(self.allocator, finding);
        }
        self.allocator.free(self.items);
    }
};

pub const CausalInspectOptions = struct {
    max_recent_events: usize = 128,
};

/// A single, internally consistent live view of the causal runtime. Unlike the
/// specialized historical queries, this is captured while holding the store's
/// lock and is therefore safe for an application introspection endpoint while
/// other fibers are still recording events.
pub const CausalInspection = struct {
    allocator: Allocator,
    retained_events: usize,
    dropped_events: u64,
    sampled_events: u64,
    truncated_fields: u64,
    backend_failures: u64,
    backend_kind: ?causal_backend.CausalBackendKind,
    oldest_retained_event_id: ?u64,
    latest_retained_event_id: ?u64,
    recent_events: []CausalEvent,
    findings: []CausalFinding,
    fiber_states: []CausalFiberState,

    pub fn deinit(self: *CausalInspection) void {
        for (self.recent_events) |event| deinitEventStrings(self.allocator, event);
        self.allocator.free(self.recent_events);
        for (self.findings) |finding| deinitFindingStrings(self.allocator, finding);
        self.allocator.free(self.findings);
        self.allocator.free(self.fiber_states);
        self.* = undefined;
    }

    pub fn unresolvedFiberCount(self: *const CausalInspection) usize {
        var count: usize = 0;
        for (self.fiber_states) |fiber| if (!fiber.resolved) {
            count += 1;
        };
        return count;
    }
};

pub const CausalStore = struct {
    allocator: Allocator,
    // Guards the WRITE path: `record` and the `next*` id generators. This makes
    // concurrent recording from multiple OS threads / executors safe (the
    // multi-executor zio + parallel-primitive case). Live inspection and
    // counter accessors take the same lock. Historical queries (`snapshot`,
    // `findings`, lineage filters) still require a quiescent barrier: join
    // fibers before running deterministic assertions. The mutex is uncontended
    // in the ordinary single-threaded case.
    mutex: sync.SpinLock = .{},
    next_event_id: u64 = 1,
    next_run_id_value: u64 = 1,
    next_scope_id_value: u64 = 1,
    next_layer_id_value: u64 = 1,
    next_resource_id_value: u64 = 1,
    next_schedule_id_value: u64 = 1,
    next_boundary_id_value: u64 = 1,
    events: std.ArrayList(CausalEvent) = .empty,
    backend: ?CausalBackend = null,
    backend_failure_count: u64 = 0,
    max_events: ?usize = null,
    dropped_event_count: u64 = 0,
    sampling: CausalSamplingPolicy = .{},
    sampled_event_count: u64 = 0,
    max_event_string_bytes: ?usize = null,
    truncated_field_count: u64 = 0,
    log_seen_count: u64 = 0,
    metric_seen_count: u64 = 0,
    span_seen_count: u64 = 0,
    default_service_key: []const u8 = "",

    pub fn init(allocator: Allocator) CausalStore {
        return initWithOptions(allocator, .{});
    }

    pub fn initWithOptions(allocator: Allocator, options: CausalStoreOptions) CausalStore {
        return .{
            .allocator = allocator,
            .max_events = options.max_events,
            .sampling = options.sampling,
            .max_event_string_bytes = options.max_event_string_bytes,
            .default_service_key = options.service_key,
        };
    }

    pub fn initBounded(allocator: Allocator, max_events: usize) CausalStore {
        return initWithOptions(allocator, .{ .max_events = max_events });
    }

    // Set the service identity once instead of tagging every `record` call.
    // See CausalStoreOptions.service_key for the slice-lifetime contract.
    pub fn initForService(allocator: Allocator, service_key: []const u8) CausalStore {
        return initWithOptions(allocator, .{ .service_key = service_key });
    }

    pub fn deinit(self: *CausalStore) void {
        for (self.events.items) |event| {
            deinitEventStrings(self.allocator, event);
        }
        self.events.deinit(self.allocator);
    }

    pub fn attachBackend(self: *CausalStore, backend: CausalBackend) void {
        _ = self.replaceBackend(backend);
    }

    /// Atomically replace the export backend and return the previous value.
    /// Managed adapters use this to borrow a caller-owned store without leaving
    /// a dangling backend pointer when their own scoped backend is released.
    /// Callers must still perform the swap at a quiescent lifecycle boundary.
    pub fn replaceBackend(self: *CausalStore, backend: ?CausalBackend) ?CausalBackend {
        self.mutex.lock();
        defer self.mutex.unlock();
        const previous = self.backend;
        self.backend = backend;
        return previous;
    }

    pub fn backendFailureCount(self: *const CausalStore) u64 {
        const mutable = @constCast(self);
        mutable.mutex.lock();
        defer mutable.mutex.unlock();
        return self.backend_failure_count;
    }

    pub fn attachedBackendKind(self: *const CausalStore) ?causal_backend.CausalBackendKind {
        const mutable = @constCast(self);
        mutable.mutex.lock();
        defer mutable.mutex.unlock();
        if (self.backend) |backend| return backend.kind;
        return null;
    }

    pub fn droppedEventCount(self: *const CausalStore) u64 {
        const mutable = @constCast(self);
        mutable.mutex.lock();
        defer mutable.mutex.unlock();
        return self.dropped_event_count;
    }

    pub fn sampledEventCount(self: *const CausalStore) u64 {
        const mutable = @constCast(self);
        mutable.mutex.lock();
        defer mutable.mutex.unlock();
        return self.sampled_event_count;
    }

    pub fn truncatedFieldCount(self: *const CausalStore) u64 {
        const mutable = @constCast(self);
        mutable.mutex.lock();
        defer mutable.mutex.unlock();
        return self.truncated_field_count;
    }

    pub fn oldestRetainedEventId(self: *const CausalStore) ?u64 {
        const mutable = @constCast(self);
        mutable.mutex.lock();
        defer mutable.mutex.unlock();
        if (self.events.items.len == 0) return null;
        return self.events.items[0].id;
    }

    pub fn nextRunId(self: *CausalStore) u64 {
        self.mutex.lock();
        defer self.mutex.unlock();
        const id = self.next_run_id_value;
        self.next_run_id_value += 1;
        return id;
    }

    pub fn nextScopeId(self: *CausalStore) u64 {
        self.mutex.lock();
        defer self.mutex.unlock();
        const id = self.next_scope_id_value;
        self.next_scope_id_value += 1;
        return id;
    }

    pub fn nextLayerId(self: *CausalStore) u64 {
        self.mutex.lock();
        defer self.mutex.unlock();
        const id = self.next_layer_id_value;
        self.next_layer_id_value += 1;
        return id;
    }

    pub fn nextResourceId(self: *CausalStore) u64 {
        self.mutex.lock();
        defer self.mutex.unlock();
        const id = self.next_resource_id_value;
        self.next_resource_id_value += 1;
        return id;
    }

    pub fn nextScheduleId(self: *CausalStore) u64 {
        self.mutex.lock();
        defer self.mutex.unlock();
        const id = self.next_schedule_id_value;
        self.next_schedule_id_value += 1;
        return id;
    }

    // Allocate a boundary id on the ORIGIN side of a cross-service call; the
    // callee must receive it over the transport and record the same value.
    pub fn nextBoundaryId(self: *CausalStore) u64 {
        self.mutex.lock();
        defer self.mutex.unlock();
        const id = self.next_boundary_id_value;
        self.next_boundary_id_value += 1;
        return id;
    }

    // Thread-safe append. The mutex makes concurrent `record` from multiple
    // executor threads safe (the events ArrayList + counters are mutated under
    // it). It is held across `cloneEventForStore`, `events.append`,
    // `backend.record`, and `trimRetainedEvents` — none of which re-enter the
    // store (the mutex is non-reentrant). READS still require a quiescent
    // barrier (see the `mutex` field doc).
    pub fn record(self: *CausalStore, event: CausalEvent) Allocator.Error!u64 {
        self.mutex.lock();
        defer self.mutex.unlock();

        const event_id = self.next_event_id;
        if (!self.shouldRecordBySampling(event.kind)) {
            self.next_event_id += 1;
            self.sampled_event_count += 1;
            return event_id;
        }

        var stamped = event;
        if (stamped.service_key.len == 0) stamped.service_key = self.default_service_key;

        var owned = try cloneEventForStore(
            self.allocator,
            stamped,
            self.max_event_string_bytes,
            &self.truncated_field_count,
        );
        errdefer deinitEventStrings(self.allocator, owned);
        owned.id = event_id;
        self.next_event_id += 1;
        try self.events.append(self.allocator, owned);
        if (self.backend) |backend| {
            backend.record(backend.state, owned) catch {
                self.backend_failure_count += 1;
            };
        }
        self.trimRetainedEvents();
        return owned.id;
    }

    pub fn snapshot(self: *const CausalStore, allocator: Allocator) Allocator.Error!CausalSnapshot {
        const events = try allocator.alloc(CausalEvent, self.events.items.len);
        errdefer allocator.free(events);

        var initialized: usize = 0;
        errdefer {
            for (events[0..initialized]) |event| {
                deinitEventStrings(allocator, event);
            }
        }

        for (self.events.items, 0..) |event, index| {
            events[index] = try cloneEvent(allocator, event);
            initialized += 1;
        }

        return .{ .allocator = allocator, .events = events };
    }

    pub fn inspect(
        self: *CausalStore,
        allocator: Allocator,
        options: CausalInspectOptions,
    ) Allocator.Error!CausalInspection {
        self.mutex.lock();
        defer self.mutex.unlock();

        const retained_events = self.events.items.len;
        const recent_count = @min(options.max_recent_events, retained_events);
        const first_recent = retained_events - recent_count;
        const recent_events = try allocator.alloc(CausalEvent, recent_count);
        errdefer allocator.free(recent_events);

        var initialized_events: usize = 0;
        errdefer for (recent_events[0..initialized_events]) |event| {
            deinitEventStrings(allocator, event);
        };
        for (self.events.items[first_recent..], 0..) |event, index| {
            recent_events[index] = try cloneEvent(allocator, event);
            initialized_events += 1;
        }

        var finding_set = try self.findings(allocator);
        errdefer finding_set.deinit();
        var fiber_set = try self.fiberStates(allocator);
        errdefer fiber_set.deinit();

        return .{
            .allocator = allocator,
            .retained_events = retained_events,
            .dropped_events = self.dropped_event_count,
            .sampled_events = self.sampled_event_count,
            .truncated_fields = self.truncated_field_count,
            .backend_failures = self.backend_failure_count,
            .backend_kind = if (self.backend) |backend| backend.kind else null,
            .oldest_retained_event_id = if (retained_events == 0) null else self.events.items[0].id,
            .latest_retained_event_id = if (retained_events == 0) null else self.events.items[retained_events - 1].id,
            .recent_events = recent_events,
            .findings = finding_set.items,
            .fiber_states = fiber_set.items,
        };
    }

    pub fn lineage(self: *const CausalStore, allocator: Allocator, event_id: u64) Allocator.Error!CausalLineage {
        var output = std.ArrayList(CausalEvent).empty;
        errdefer {
            for (output.items) |event| {
                deinitEventStrings(allocator, event);
            }
            output.deinit(allocator);
        }

        for (self.events.items) |event| {
            if (event.id == event_id or event.parent_id == event_id or event.cause_event_id == event_id) {
                {
                    const cloned = try cloneEvent(allocator, event);
                    errdefer deinitEventStrings(allocator, cloned);
                    try output.append(allocator, cloned);
                }
            }
        }

        return .{ .allocator = allocator, .events = try output.toOwnedSlice(allocator) };
    }

    pub fn cause(self: *const CausalStore, allocator: Allocator, event_id: u64) Allocator.Error!CausalLineage {
        var output = std.ArrayList(CausalEvent).empty;
        errdefer {
            for (output.items) |event| {
                deinitEventStrings(allocator, event);
            }
            output.deinit(allocator);
        }

        try self.appendCauseChain(allocator, &output, event_id);

        return .{ .allocator = allocator, .events = try output.toOwnedSlice(allocator) };
    }

    pub fn resources(self: *const CausalStore, allocator: Allocator, scope_id: u64) Allocator.Error!CausalSnapshot {
        return self.filterEvents(allocator, struct {
            fn matches(event: CausalEvent, expected_scope_id: u64) bool {
                return event.scope_id == expected_scope_id and
                    (event.kind == .resource_acquired or event.kind == .resource_finalized);
            }
        }.matches, scope_id);
    }

    pub fn fibers(self: *const CausalStore, allocator: Allocator, status: ?[]const u8) Allocator.Error!CausalSnapshot {
        return self.filterEvents(allocator, struct {
            fn matches(event: CausalEvent, expected_status: ?[]const u8) bool {
                const fiber_event = switch (event.kind) {
                    .fiber_forked, .fiber_started, .fiber_joined, .fiber_interrupted => true,
                    else => false,
                };
                if (!fiber_event) return false;
                if (expected_status) |value| return std.mem.eql(u8, event.status, value);
                return true;
            }
        }.matches, status);
    }

    /// Collapse each fiber's event history to its latest lifecycle state, so an
    /// agent can answer "is anything still parked/unresolved?" in one call
    /// instead of reasoning over the immutable per-event log.
    pub fn fiberStates(self: *const CausalStore, allocator: Allocator) Allocator.Error!CausalFiberStates {
        var list = std.ArrayList(CausalFiberState).empty;
        errdefer list.deinit(allocator);

        for (self.events.items) |event| {
            const fiber_id = event.fiber_id orelse continue;
            if (!isFiberLifecycleKind(event.kind)) continue;

            var found = false;
            for (list.items) |*state| {
                if (state.fiber_id != fiber_id) continue;
                found = true;
                if (event.id >= state.latest_event_id) {
                    state.latest_event_id = event.id;
                    state.latest_kind = event.kind;
                    state.resolved = isTerminalFiberKind(event.kind);
                    state.parked = event.kind == .fiber_suspended;
                }
                break;
            }
            if (!found) {
                try list.append(allocator, .{
                    .fiber_id = fiber_id,
                    .latest_event_id = event.id,
                    .latest_kind = event.kind,
                    .resolved = isTerminalFiberKind(event.kind),
                    .parked = event.kind == .fiber_suspended,
                });
            }
        }

        return .{ .allocator = allocator, .items = try list.toOwnedSlice(allocator) };
    }

    pub fn requirements(self: *const CausalStore, allocator: Allocator, run_id: u64) Allocator.Error!CausalSnapshot {
        return self.filterEvents(allocator, struct {
            fn matches(event: CausalEvent, expected_run_id: u64) bool {
                return event.run_id == expected_run_id and event.kind == .service_required;
            }
        }.matches, run_id);
    }

    pub fn retries(self: *const CausalStore, allocator: Allocator, run_id: u64) Allocator.Error!CausalSnapshot {
        return self.filterEvents(allocator, struct {
            fn matches(event: CausalEvent, expected_run_id: u64) bool {
                return event.run_id == expected_run_id and event.kind == .schedule_decision;
            }
        }.matches, run_id);
    }

    pub fn findings(self: *const CausalStore, allocator: Allocator) Allocator.Error!CausalFindings {
        var output = std.ArrayList(CausalFinding).empty;
        errdefer {
            for (output.items) |finding| {
                deinitFindingStrings(allocator, finding);
            }
            output.deinit(allocator);
        }

        for (self.events.items) |event| {
            switch (event.kind) {
                .resource_acquired => if (!self.hasFinalizedResource(event) and !self.resourceBelongsToOpenScope(event)) {
                    try appendFinding(allocator, &output, .resource_acquired_without_finalization, event);
                },
                .scope_closed => try self.appendPendingFiberFindings(allocator, &output, event),
                .fiber_suspended => if (!self.fiberWokeAfter(event)) {
                    try appendFinding(allocator, &output, .fiber_suspended_without_resume, event);
                },
                .resource_finalized => if (std.mem.eql(u8, event.status, "failure")) {
                    try appendFinding(allocator, &output, .finalizer_failure, event);
                },
                .schedule_decision => if (std.mem.eql(u8, event.status, "exhausted")) {
                    try appendFinding(allocator, &output, .retry_budget_exhausted, event);
                },
                .service_required => if (std.mem.eql(u8, event.status, "missing")) {
                    try appendFinding(allocator, &output, .service_requirement_without_provider, event);
                },
                .assertion_recorded => if (std.mem.eql(u8, event.status, "failure")) {
                    try appendFinding(allocator, &output, .assertion_failure, event);
                },
                else => {},
            }
        }

        return .{ .allocator = allocator, .items = try output.toOwnedSlice(allocator) };
    }

    fn shouldRecordBySampling(self: *CausalStore, kind: CausalEventKind) bool {
        if (!isCausalSampleableEvent(kind)) return true;
        return switch (kind) {
            .log_recorded => shouldRecordEveryN(&self.log_seen_count, self.sampling.log_every_n),
            .metric_recorded => shouldRecordEveryN(&self.metric_seen_count, self.sampling.metric_every_n),
            .span_recorded => shouldRecordEveryN(&self.span_seen_count, self.sampling.span_every_n),
            else => true,
        };
    }

    fn findEvent(self: *const CausalStore, event_id: u64) ?CausalEvent {
        for (self.events.items) |event| {
            if (event.id == event_id) return event;
        }
        return null;
    }

    fn trimRetainedEvents(self: *CausalStore) void {
        const max_events = self.max_events orelse return;
        while (self.events.items.len > max_events) {
            const dropped = self.events.orderedRemove(0);
            deinitEventStrings(self.allocator, dropped);
            self.dropped_event_count += 1;
        }
    }

    fn appendCauseChain(self: *const CausalStore, allocator: Allocator, output: *std.ArrayList(CausalEvent), event_id: u64) Allocator.Error!void {
        const event = self.findEvent(event_id) orelse return;
        if (event.cause_event_id orelse event.parent_id) |cause_id| {
            try self.appendCauseChain(allocator, output, cause_id);
        }
        try appendClonedEvent(allocator, output, event);
    }

    fn filterEvents(
        self: *const CausalStore,
        allocator: Allocator,
        comptime matches: anytype,
        expected: anytype,
    ) Allocator.Error!CausalSnapshot {
        var output = std.ArrayList(CausalEvent).empty;
        errdefer {
            for (output.items) |event| {
                deinitEventStrings(allocator, event);
            }
            output.deinit(allocator);
        }

        for (self.events.items) |event| {
            if (matches(event, expected)) {
                try appendClonedEvent(allocator, &output, event);
            }
        }

        return .{ .allocator = allocator, .events = try output.toOwnedSlice(allocator) };
    }

    fn hasFinalizedResource(self: *const CausalStore, acquired: CausalEvent) bool {
        if (acquired.resource_id) |resource_id| {
            for (self.events.items) |event| {
                if (event.kind != .resource_finalized) continue;
                if (event.resource_id == resource_id) return true;
            }
            return false;
        }

        for (self.events.items) |event| {
            if (event.kind != .resource_finalized) continue;
            if (event.scope_id != acquired.scope_id) continue;
            if (!std.mem.eql(u8, event.type_name, acquired.type_name)) continue;
            return true;
        }
        return false;
    }

    /// An acquired resource in a scope that is observably still open is live,
    /// not leaked. Historical artifacts that did not record `scope_opened`
    /// retain the previous fail-closed behavior and are still treated as leaks.
    fn resourceBelongsToOpenScope(self: *const CausalStore, acquired: CausalEvent) bool {
        const scope_id = acquired.scope_id orelse return false;
        var opened = false;
        for (self.events.items) |event| {
            if (event.scope_id != scope_id) continue;
            switch (event.kind) {
                .scope_opened => opened = true,
                .scope_closed => if (event.id >= acquired.id) return false,
                else => {},
            }
        }
        return opened;
    }

    fn fiberCompletedAfter(self: *const CausalStore, fiber_id: u64, closed_event_id: u64) bool {
        for (self.events.items) |event| {
            if (event.id < closed_event_id) continue;
            if (event.fiber_id != fiber_id) continue;
            switch (event.kind) {
                .fiber_joined, .fiber_interrupted => return true,
                else => {},
            }
        }
        return false;
    }

    // A suspended fiber "woke" if a later event for the same fiber resumed it or
    // reached a terminal state. A `fiber_suspended` with no such follow-up is a
    // hang. A suspension with no fiber id is not trackable, so it is not flagged.
    fn fiberWokeAfter(self: *const CausalStore, suspended: CausalEvent) bool {
        const fiber_id = suspended.fiber_id orelse return true;
        for (self.events.items) |event| {
            if (event.id <= suspended.id) continue;
            if (event.fiber_id != fiber_id) continue;
            switch (event.kind) {
                .fiber_resumed, .fiber_joined, .fiber_interrupted => return true,
                else => {},
            }
        }
        return false;
    }

    fn appendPendingFiberFindings(
        self: *const CausalStore,
        allocator: Allocator,
        output: *std.ArrayList(CausalFinding),
        closed: CausalEvent,
    ) Allocator.Error!void {
        const scope_id = closed.scope_id orelse return;
        for (self.events.items) |event| {
            if (event.scope_id != scope_id) continue;
            if (event.fiber_id == null) continue;
            if (event.kind != .fiber_forked and event.kind != .fiber_started) continue;
            if (!std.mem.eql(u8, event.status, "pending") and !std.mem.eql(u8, event.status, "running")) continue;
            if (self.fiberCompletedAfter(event.fiber_id.?, closed.id)) continue;
            try appendFinding(allocator, output, .fiber_pending_after_scope_close, event);
        }
    }
};

fn shouldRecordEveryN(seen_count: *u64, every_n: ?usize) bool {
    seen_count.* += 1;
    const n = every_n orelse return true;
    if (n == 0) return true;
    return seen_count.* % @as(u64, @intCast(n)) == 0;
}

fn appendClonedEvent(allocator: Allocator, output: *std.ArrayList(CausalEvent), event: CausalEvent) Allocator.Error!void {
    const cloned = try cloneEvent(allocator, event);
    errdefer deinitEventStrings(allocator, cloned);
    try output.append(allocator, cloned);
}

fn appendFinding(
    allocator: Allocator,
    output: *std.ArrayList(CausalFinding),
    kind: CausalFindingKind,
    event: CausalEvent,
) Allocator.Error!void {
    const finding = try cloneFinding(allocator, .{
        .kind = kind,
        .event_id = event.id,
        .run_id = event.run_id,
        .scope_id = event.scope_id,
        .fiber_id = event.fiber_id,
        .label = event.label,
        .type_name = event.type_name,
        .redacted_detail = event.redacted_detail,
    });
    errdefer deinitFindingStrings(allocator, finding);
    try output.append(allocator, finding);
}

fn appendOptionalU64(output: *std.ArrayList(u8), allocator: Allocator, value: ?u64) Allocator.Error!void {
    if (value) |number| {
        try output.print(allocator, "{d}", .{number});
    } else {
        try output.appendSlice(allocator, "null");
    }
}

fn appendRetentionSummary(output: *std.ArrayList(u8), allocator: Allocator, store: *const CausalStore) Allocator.Error!void {
    try output.appendSlice(allocator, "retention: max_events=");
    if (store.max_events) |max_events| {
        try output.print(allocator, "{d}", .{max_events});
    } else {
        try output.appendSlice(allocator, "unbounded");
    }
    try output.print(allocator, " dropped_events={d} oldest_retained_event=", .{store.dropped_event_count});
    try appendOptionalU64(output, allocator, store.oldestRetainedEventId());
    try output.append(allocator, '\n');
}

fn appendSamplingEveryN(output: *std.ArrayList(u8), allocator: Allocator, value: ?usize) Allocator.Error!void {
    if (value) |number| {
        if (number > 0) {
            try output.print(allocator, "{d}", .{number});
            return;
        }
    }
    try output.appendSlice(allocator, "off");
}

fn appendSamplingSummary(output: *std.ArrayList(u8), allocator: Allocator, store: *const CausalStore) Allocator.Error!void {
    try output.appendSlice(allocator, "sampling: log_every_n=");
    try appendSamplingEveryN(output, allocator, store.sampling.log_every_n);
    try output.appendSlice(allocator, " metric_every_n=");
    try appendSamplingEveryN(output, allocator, store.sampling.metric_every_n);
    try output.appendSlice(allocator, " span_every_n=");
    try appendSamplingEveryN(output, allocator, store.sampling.span_every_n);
    try output.print(allocator, " sampled_events={d}\n", .{store.sampled_event_count});
}

fn appendTruncationLimit(output: *std.ArrayList(u8), allocator: Allocator, value: ?usize) Allocator.Error!void {
    if (value) |number| {
        try output.print(allocator, "{d}", .{number});
    } else {
        try output.appendSlice(allocator, "off");
    }
}

fn appendTruncationSummary(output: *std.ArrayList(u8), allocator: Allocator, store: *const CausalStore) Allocator.Error!void {
    try output.appendSlice(allocator, "truncation: max_event_string_bytes=");
    try appendTruncationLimit(output, allocator, store.max_event_string_bytes);
    try output.print(allocator, " truncated_fields={d}\n", .{store.truncated_field_count});
}

fn appendBackendSummary(output: *std.ArrayList(u8), allocator: Allocator, store: *const CausalStore) Allocator.Error!void {
    try output.appendSlice(allocator, "backend: kind=");
    if (store.attachedBackendKind()) |kind| {
        try output.appendSlice(allocator, @tagName(kind));
    } else {
        try output.appendSlice(allocator, "none");
    }
    try output.print(allocator, " failed_writes={d}\n", .{store.backend_failure_count});
}

pub fn formatCausalReport(
    allocator: Allocator,
    label: []const u8,
    store: *const CausalStore,
) Allocator.Error![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.print(allocator, "zigeffect causal report\nprogram: {s}\n", .{label});
    try output.print(allocator, "events: {d}\n", .{store.events.items.len});
    try appendRetentionSummary(&output, allocator, store);
    try appendSamplingSummary(&output, allocator, store);
    try appendTruncationSummary(&output, allocator, store);
    try appendBackendSummary(&output, allocator, store);

    for (store.events.items) |event| {
        try output.print(
            allocator,
            "event: id={d} kind={s} run=",
            .{ event.id, @tagName(event.kind) },
        );
        try appendOptionalU64(&output, allocator, event.run_id);
        try output.appendSlice(allocator, " parent=");
        try appendOptionalU64(&output, allocator, event.parent_id);
        if (event.fiber_id != null) {
            try output.appendSlice(allocator, " fiber=");
            try appendOptionalU64(&output, allocator, event.fiber_id);
        }
        if (event.scope_id != null) {
            try output.appendSlice(allocator, " scope=");
            try appendOptionalU64(&output, allocator, event.scope_id);
        }
        if (event.trace_id != null) {
            try output.appendSlice(allocator, " trace=");
            try appendOptionalU64(&output, allocator, event.trace_id);
        }
        if (event.span_id != null) {
            try output.appendSlice(allocator, " span=");
            try appendOptionalU64(&output, allocator, event.span_id);
        }
        if (event.label.len > 0) try output.print(allocator, " label={s}", .{event.label});
        if (event.type_name.len > 0) try output.print(allocator, " type={s}", .{event.type_name});
        if (event.status.len > 0) try output.print(allocator, " status={s}", .{event.status});
        if (event.redacted_detail.len > 0) try output.print(allocator, " detail={s}", .{event.redacted_detail});
        try output.appendSlice(allocator, "\n");
    }

    return output.toOwnedSlice(allocator);
}

fn appendCiEventSummary(output: *std.ArrayList(u8), allocator: Allocator, event: CausalEvent) Allocator.Error!void {
    try output.print(
        allocator,
        "- event id={d} kind={s}",
        .{ event.id, @tagName(event.kind) },
    );
    if (event.run_id) |run_id| try output.print(allocator, " run={d}", .{run_id});
    if (event.scope_id) |scope_id| try output.print(allocator, " scope={d}", .{scope_id});
    if (event.fiber_id) |fiber_id| try output.print(allocator, " fiber={d}", .{fiber_id});
    if (event.label.len > 0) try output.print(allocator, " label={s}", .{event.label});
    if (event.type_name.len > 0) try output.print(allocator, " type={s}", .{event.type_name});
    if (event.status.len > 0) try output.print(allocator, " status={s}", .{event.status});
    try output.appendSlice(allocator, "\n");
}

fn appendCiFinding(output: *std.ArrayList(u8), allocator: Allocator, finding: CausalFinding) Allocator.Error!void {
    try output.print(
        allocator,
        "- finding event={d} kind={s}",
        .{ finding.event_id, @tagName(finding.kind) },
    );
    if (finding.run_id) |run_id| try output.print(allocator, " run={d}", .{run_id});
    if (finding.scope_id) |scope_id| try output.print(allocator, " scope={d}", .{scope_id});
    if (finding.fiber_id) |fiber_id| try output.print(allocator, " fiber={d}", .{fiber_id});
    if (finding.label.len > 0) try output.print(allocator, " label={s}", .{finding.label});
    if (finding.type_name.len > 0) try output.print(allocator, " type={s}", .{finding.type_name});
    try output.appendSlice(allocator, "\n");
}

fn appendCiNextQueries(output: *std.ArrayList(u8), allocator: Allocator, finding: CausalFinding) Allocator.Error!void {
    try output.print(allocator, "- causal.cause {d}\n", .{finding.event_id});
    try output.print(allocator, "- causal.lineage {d}\n", .{finding.event_id});
    if (finding.scope_id) |scope_id| try output.print(allocator, "- causal.resources {d}\n", .{scope_id});
    if (finding.fiber_id != null) try output.appendSlice(allocator, "- causal.fibers pending\n");
    if (finding.run_id) |run_id| {
        switch (finding.kind) {
            .retry_budget_exhausted => try output.print(allocator, "- causal.retries {d}\n", .{run_id}),
            .service_requirement_without_provider => try output.print(allocator, "- causal.requirements {d}\n", .{run_id}),
            else => {},
        }
    }
}

pub fn formatCausalCiReport(
    allocator: Allocator,
    label: []const u8,
    store: *const CausalStore,
) Allocator.Error![]const u8 {
    var findings = try store.findings(allocator);
    defer findings.deinit();

    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.print(
        allocator,
        "zigeffect causal ci report\nprogram: {s}\nevents: {d}\nfindings: {d}\n",
        .{ label, store.events.items.len, findings.items.len },
    );
    try appendRetentionSummary(&output, allocator, store);
    try appendSamplingSummary(&output, allocator, store);
    try appendTruncationSummary(&output, allocator, store);
    try appendBackendSummary(&output, allocator, store);

    try output.appendSlice(allocator, "event citations:\n");
    if (store.events.items.len == 0) {
        try output.appendSlice(allocator, "- none\n");
    } else {
        for (store.events.items) |event| {
            try appendCiEventSummary(&output, allocator, event);
        }
    }

    try output.appendSlice(allocator, "findings detail:\n");
    if (findings.items.len == 0) {
        try output.appendSlice(allocator, "- none\n");
    } else {
        for (findings.items) |finding| {
            try appendCiFinding(&output, allocator, finding);
        }
    }

    try output.appendSlice(allocator, "next queries:\n");
    if (findings.items.len == 0) {
        try output.appendSlice(allocator, "- causal.snapshot\n");
    } else {
        for (findings.items) |finding| {
            try appendCiNextQueries(&output, allocator, finding);
        }
    }

    return output.toOwnedSlice(allocator);
}

fn appendJsonString(output: *std.ArrayList(u8), allocator: Allocator, value: []const u8) Allocator.Error!void {
    try output.append(allocator, '"');
    for (value) |byte| {
        switch (byte) {
            '"' => try output.appendSlice(allocator, "\\\""),
            '\\' => try output.appendSlice(allocator, "\\\\"),
            '\n' => try output.appendSlice(allocator, "\\n"),
            '\r' => try output.appendSlice(allocator, "\\r"),
            '\t' => try output.appendSlice(allocator, "\\t"),
            0x00...0x08, 0x0b, 0x0c, 0x0e...0x1f => try output.print(allocator, "\\u{x:0>4}", .{byte}),
            else => try output.append(allocator, byte),
        }
    }
    try output.append(allocator, '"');
}

fn appendOptionalJsonU64(output: *std.ArrayList(u8), allocator: Allocator, value: ?u64) Allocator.Error!void {
    if (value) |number| {
        try output.print(allocator, "{d}", .{number});
    } else {
        try output.appendSlice(allocator, "null");
    }
}

fn appendOptionalJsonUsize(output: *std.ArrayList(u8), allocator: Allocator, value: ?usize) Allocator.Error!void {
    if (value) |number| {
        try output.print(allocator, "{d}", .{number});
    } else {
        try output.appendSlice(allocator, "null");
    }
}

pub fn formatCausalJson(allocator: Allocator, store: *const CausalStore) Allocator.Error![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n  \"schema\": ");
    try appendJsonString(&output, allocator, causal_json_schema);
    try output.print(
        allocator,
        ",\n  \"schema_version\": {d},\n  \"event_taxonomy_version\": {d},\n",
        .{ causal_json_schema_version, causal_event_taxonomy_version },
    );
    try output.appendSlice(allocator, "  \"retention\": {\n    \"max_events\": ");
    try appendOptionalJsonUsize(&output, allocator, store.max_events);
    try output.print(allocator, ",\n    \"dropped_events\": {d},\n    \"oldest_retained_event_id\": ", .{store.dropped_event_count});
    try appendOptionalJsonU64(&output, allocator, store.oldestRetainedEventId());
    try output.appendSlice(allocator, "\n  },\n  \"sampling\": {\n    \"log_every_n\": ");
    try appendOptionalJsonUsize(&output, allocator, store.sampling.log_every_n);
    try output.appendSlice(allocator, ",\n    \"metric_every_n\": ");
    try appendOptionalJsonUsize(&output, allocator, store.sampling.metric_every_n);
    try output.appendSlice(allocator, ",\n    \"span_every_n\": ");
    try appendOptionalJsonUsize(&output, allocator, store.sampling.span_every_n);
    try output.print(allocator, ",\n    \"sampled_events\": {d}\n", .{store.sampled_event_count});
    try output.appendSlice(allocator, "  },\n  \"truncation\": {\n    \"max_event_string_bytes\": ");
    try appendOptionalJsonUsize(&output, allocator, store.max_event_string_bytes);
    try output.print(allocator, ",\n    \"truncated_fields\": {d}\n", .{store.truncated_field_count});
    try output.appendSlice(allocator, "  },\n  \"backend\": {\n    \"kind\": ");
    if (store.attachedBackendKind()) |kind| {
        try appendJsonString(&output, allocator, @tagName(kind));
    } else {
        try output.appendSlice(allocator, "null");
    }
    try output.print(allocator, ",\n    \"failed_writes\": {d}\n", .{store.backend_failure_count});
    try output.appendSlice(allocator, "  },\n  \"events\": [\n");
    for (store.events.items, 0..) |event, index| {
        if (index > 0) try output.appendSlice(allocator, ",\n");
        try output.appendSlice(allocator, "    {\n");
        try output.print(allocator, "      \"id\": {d},\n", .{event.id});
        try output.appendSlice(allocator, "      \"kind\": ");
        try appendJsonString(&output, allocator, @tagName(event.kind));
        try output.appendSlice(allocator, ",\n      \"run_id\": ");
        try appendOptionalJsonU64(&output, allocator, event.run_id);
        try output.appendSlice(allocator, ",\n      \"parent_id\": ");
        try appendOptionalJsonU64(&output, allocator, event.parent_id);
        try output.appendSlice(allocator, ",\n      \"fiber_id\": ");
        try appendOptionalJsonU64(&output, allocator, event.fiber_id);
        try output.appendSlice(allocator, ",\n      \"scope_id\": ");
        try appendOptionalJsonU64(&output, allocator, event.scope_id);
        try output.appendSlice(allocator, ",\n      \"layer_id\": ");
        try appendOptionalJsonU64(&output, allocator, event.layer_id);
        try output.appendSlice(allocator, ",\n      \"layer_name\": ");
        try appendJsonString(&output, allocator, event.layer_name);
        try output.appendSlice(allocator, ",\n      \"service_key\": ");
        try appendJsonString(&output, allocator, event.service_key);
        try output.appendSlice(allocator, ",\n      \"resource_id\": ");
        try appendOptionalJsonU64(&output, allocator, event.resource_id);
        try output.appendSlice(allocator, ",\n      \"cause_event_id\": ");
        try appendOptionalJsonU64(&output, allocator, event.cause_event_id);
        try output.appendSlice(allocator, ",\n      \"schedule_id\": ");
        try appendOptionalJsonU64(&output, allocator, event.schedule_id);
        try output.appendSlice(allocator, ",\n      \"source_ref_id\": ");
        try appendOptionalJsonU64(&output, allocator, event.source_ref_id);
        try output.appendSlice(allocator, ",\n      \"boundary_id\": ");
        try appendOptionalJsonU64(&output, allocator, event.boundary_id);
        try output.appendSlice(allocator, ",\n      \"artifact_id\": ");
        try appendJsonString(&output, allocator, event.artifact_id);
        try output.appendSlice(allocator, ",\n      \"domain_entity_ref\": ");
        try appendJsonString(&output, allocator, event.domain_entity_ref);
        try output.appendSlice(allocator, ",\n      \"data_subject_ref\": ");
        try appendJsonString(&output, allocator, event.data_subject_ref);
        try output.appendSlice(allocator, ",\n      \"schema_ref\": ");
        try appendJsonString(&output, allocator, event.schema_ref);
        try output.appendSlice(allocator, ",\n      \"trace_id\": ");
        try appendOptionalJsonU64(&output, allocator, event.trace_id);
        try output.appendSlice(allocator, ",\n      \"span_id\": ");
        try appendOptionalJsonU64(&output, allocator, event.span_id);
        try output.appendSlice(allocator, ",\n      \"label\": ");
        try appendJsonString(&output, allocator, event.label);
        try output.appendSlice(allocator, ",\n      \"type_name\": ");
        try appendJsonString(&output, allocator, event.type_name);
        try output.appendSlice(allocator, ",\n      \"status\": ");
        try appendJsonString(&output, allocator, event.status);
        try output.appendSlice(allocator, ",\n      \"redacted_detail\": ");
        try appendJsonString(&output, allocator, event.redacted_detail);
        try output.appendSlice(allocator, "\n    }");
    }
    try output.appendSlice(allocator, "\n  ]\n}\n");

    return output.toOwnedSlice(allocator);
}

fn appendDotEscaped(output: *std.ArrayList(u8), allocator: Allocator, value: []const u8) Allocator.Error!void {
    for (value) |byte| {
        switch (byte) {
            '"' => try output.appendSlice(allocator, "\\\""),
            '\\' => try output.appendSlice(allocator, "\\\\"),
            '\n', '\r', '\t' => try output.append(allocator, ' '),
            else => try output.append(allocator, byte),
        }
    }
}

fn appendDotOptionalU64Tooltip(
    output: *std.ArrayList(u8),
    allocator: Allocator,
    label: []const u8,
    value: ?u64,
    wrote: *bool,
) Allocator.Error!void {
    if (value) |number| {
        if (wrote.*) try output.append(allocator, ' ');
        try output.print(allocator, "{s}={d}", .{ label, number });
        wrote.* = true;
    }
}

pub fn appendCausalDotGraphHeader(output: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
    try output.appendSlice(allocator, "digraph zigeffect_causal {\n");
    try output.appendSlice(allocator, "  graph [rankdir=\"LR\", labelloc=\"t\", label=\"zigeffect causal graph\"];\n");
    try output.appendSlice(allocator, "  node [shape=\"box\", style=\"rounded,filled\", fontname=\"Menlo\", fontsize=\"10\"];\n");
    try output.appendSlice(allocator, "  edge [fontname=\"Menlo\", fontsize=\"9\", color=\"#64748b\"];\n");
}

pub fn appendCausalDotGraphFooter(output: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
    try output.appendSlice(allocator, "}\n");
}

fn dotEventFillColor(kind: CausalEventKind) []const u8 {
    const taxonomy = causalEventTaxonomy(kind);
    if (taxonomy.finding_evidence) return "#fff7ed";
    if (taxonomy.sampleable) return "#eef2ff";
    return "#f8fafc";
}

fn dotEventBorderColor(kind: CausalEventKind) []const u8 {
    const taxonomy = causalEventTaxonomy(kind);
    if (taxonomy.finding_evidence) return "#c2410c";
    if (taxonomy.sampleable) return "#4338ca";
    return "#334155";
}

fn appendDotEventLabel(output: *std.ArrayList(u8), allocator: Allocator, event: CausalEvent) Allocator.Error!void {
    try output.append(allocator, '"');
    try output.print(allocator, "event {d}\\n{s}", .{ event.id, @tagName(event.kind) });
    if (event.label.len > 0) {
        try output.appendSlice(allocator, "\\n");
        try appendDotEscaped(output, allocator, event.label);
    }
    if (event.status.len > 0) {
        try output.appendSlice(allocator, "\\nstatus=");
        try appendDotEscaped(output, allocator, event.status);
    }
    try output.append(allocator, '"');
}

fn appendDotEventTooltip(output: *std.ArrayList(u8), allocator: Allocator, event: CausalEvent) Allocator.Error!void {
    try output.append(allocator, '"');
    var wrote = false;
    try appendDotOptionalU64Tooltip(output, allocator, "run", event.run_id, &wrote);
    try appendDotOptionalU64Tooltip(output, allocator, "scope", event.scope_id, &wrote);
    try appendDotOptionalU64Tooltip(output, allocator, "fiber", event.fiber_id, &wrote);
    try appendDotOptionalU64Tooltip(output, allocator, "layer", event.layer_id, &wrote);
    if (event.layer_name.len > 0) {
        try appendDotStringTooltip(output, allocator, "layer_name", event.layer_name, &wrote);
    }
    try appendDotOptionalU64Tooltip(output, allocator, "resource", event.resource_id, &wrote);
    try appendDotOptionalU64Tooltip(output, allocator, "cause", event.cause_event_id, &wrote);
    try appendDotOptionalU64Tooltip(output, allocator, "schedule", event.schedule_id, &wrote);
    try appendDotOptionalU64Tooltip(output, allocator, "boundary", event.boundary_id, &wrote);
    try appendDotOptionalU64Tooltip(output, allocator, "trace", event.trace_id, &wrote);
    try appendDotOptionalU64Tooltip(output, allocator, "span", event.span_id, &wrote);
    if (event.service_key.len > 0) {
        try appendDotStringTooltip(output, allocator, "service", event.service_key, &wrote);
    }
    try appendDotStringTooltip(output, allocator, "artifact", event.artifact_id, &wrote);
    try appendDotStringTooltip(output, allocator, "domain", event.domain_entity_ref, &wrote);
    try appendDotStringTooltip(output, allocator, "subject", event.data_subject_ref, &wrote);
    try appendDotStringTooltip(output, allocator, "schema", event.schema_ref, &wrote);
    if (event.type_name.len > 0) {
        try appendDotStringTooltip(output, allocator, "type", event.type_name, &wrote);
    }
    if (!wrote) try output.appendSlice(allocator, "event");
    try output.append(allocator, '"');
}

fn appendDotStringTooltip(
    output: *std.ArrayList(u8),
    allocator: Allocator,
    name: []const u8,
    value: []const u8,
    wrote: *bool,
) Allocator.Error!void {
    if (value.len == 0) return;
    if (wrote.*) try output.append(allocator, ' ');
    try output.appendSlice(allocator, name);
    try output.append(allocator, '=');
    try appendDotEscaped(output, allocator, value);
    wrote.* = true;
}

pub fn appendCausalDotEvent(output: *std.ArrayList(u8), allocator: Allocator, event: CausalEvent) Allocator.Error!void {
    try output.print(allocator, "  event_{d} [label=", .{event.id});
    try appendDotEventLabel(output, allocator, event);
    try output.appendSlice(allocator, ", tooltip=");
    try appendDotEventTooltip(output, allocator, event);
    try output.print(
        allocator,
        ", fillcolor=\"{s}\", color=\"{s}\"];\n",
        .{ dotEventFillColor(event.kind), dotEventBorderColor(event.kind) },
    );
    if (event.parent_id) |parent_id| {
        try output.print(allocator, "  event_{d} -> event_{d} [label=\"parent\"];\n", .{ parent_id, event.id });
    }
    if (event.cause_event_id) |cause_event_id| {
        if (event.parent_id == null or event.parent_id.? != cause_event_id) {
            try output.print(allocator, "  event_{d} -> event_{d} [label=\"cause\"];\n", .{ cause_event_id, event.id });
        }
    }
}

pub fn formatCausalDot(allocator: Allocator, store: *const CausalStore) Allocator.Error![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try appendCausalDotGraphHeader(&output, allocator);
    for (store.events.items) |event| {
        try appendCausalDotEvent(&output, allocator, event);
    }
    try appendCausalDotGraphFooter(&output, allocator);

    return output.toOwnedSlice(allocator);
}

test "recording capability preserves captured runtime lineage" {
    var store = CausalStore.init(std.testing.allocator);
    defer store.deinit();
    const recorder = CausalRecorder.withLineage(&store, .{
        .run_id = 41,
        .parent_id = 42,
        .fiber_id = 43,
        .scope_id = 44,
        .trace_id = 45,
        .span_id = 46,
        .context = .{ .project_id = 47, .component_id = 48 },
    });

    _ = try recorder.record(.{
        .kind = .span_recorded,
        .label = "adapter.boundary",
        .status = "success",
    });

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expectEqual(@as(usize, 1), snapshot.events.len);
    const event = snapshot.events[0];
    try std.testing.expectEqual(@as(?u64, 41), event.run_id);
    try std.testing.expectEqual(@as(?u64, 42), event.parent_id);
    try std.testing.expectEqual(@as(?u64, 43), event.fiber_id);
    try std.testing.expectEqual(@as(?u64, 44), event.scope_id);
    try std.testing.expectEqual(@as(?u64, 45), event.trace_id);
    try std.testing.expectEqual(@as(?u64, 46), event.span_id);
    try std.testing.expectEqual(@as(?u64, 47), event.context.project_id);
    try std.testing.expectEqual(@as(?u64, 48), event.context.component_id);
}
