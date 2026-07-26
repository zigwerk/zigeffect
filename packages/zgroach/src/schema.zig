//! The schema a plan is written against.
//!
//! A query plan names nodes, relations and fields. What those *are* — a table
//! and its columns, or an index column in a causal log — is the schema's job,
//! and keeping it out of the plan is what lets one query serve more than one
//! store.
//!
//! This is the part of roachgraph's model the SQL compiler consults on every
//! line it emits: `schema.nodes[name].fields[field]` to resolve a column,
//! `schema.relations[name]` to resolve a join and its endpoints. Without it a
//! plan cannot be lowered to SQL at all, which is why this exists before the
//! CockroachDB connector rather than after it.
//!
//! Everything is comptime data. A schema is declared once, validated once, and
//! then only read — so a misspelled field is a compile-time or connect-time
//! error rather than an empty result set.

const std = @import("std");

pub const Error = error{
    UnknownNode,
    UnknownRelation,
    UnknownField,
    InvalidSchema,
};

/// What a field holds. The plan compares against this rather than guessing from
/// the value, so a text predicate on a numeric column is rejected rather than
/// silently matching nothing.
pub const FieldKind = enum {
    text,
    integer,
    /// An opaque 64-bit identifier — a requirement, scenario or run. Compared
    /// for equality only; never ordered or ranged.
    id,
    /// Ranked by full-text relevance. Requires `text_search` capability.
    document,
    /// Ordered by distance. Requires `vector_search` capability.
    vector,
};

pub const Field = struct {
    name: []const u8,
    /// Where the value lives in the store. For SQL this is a column; for the
    /// embedded engine it is the materialised index column of the same meaning.
    column: []const u8,
    kind: FieldKind = .text,
};

pub const Node = struct {
    name: []const u8,
    /// Relational stores need somewhere to select from. Stores that have no
    /// such concept leave it empty and never read it.
    table: []const u8 = "",
    fields: []const Field = &.{},

    pub fn field(self: Node, name: []const u8) Error!Field {
        for (self.fields) |candidate| {
            if (std.mem.eql(u8, candidate.name, name)) return candidate;
        }
        return error.UnknownField;
    }
};

/// A typed edge between two node kinds.
///
/// Endpoints are named rather than positional because a relation is directional
/// and a traversal has to know which way it is going — the difference between
/// "what this caused" and "what caused this" is which column joins to which.
pub const Relation = struct {
    name: []const u8,
    from_node: []const u8,
    to_node: []const u8,
    table: []const u8 = "",
    from_column: []const u8 = "",
    to_column: []const u8 = "",
    fields: []const Field = &.{},

    pub fn field(self: Relation, name: []const u8) Error!Field {
        for (self.fields) |candidate| {
            if (std.mem.eql(u8, candidate.name, name)) return candidate;
        }
        return error.UnknownField;
    }
};

pub const Schema = struct {
    name: []const u8,
    nodes: []const Node = &.{},
    relations: []const Relation = &.{},

    pub fn node(self: Schema, name: []const u8) Error!Node {
        for (self.nodes) |candidate| {
            if (std.mem.eql(u8, candidate.name, name)) return candidate;
        }
        return error.UnknownNode;
    }

    pub fn relation(self: Schema, name: []const u8) Error!Relation {
        for (self.relations) |candidate| {
            if (std.mem.eql(u8, candidate.name, name)) return candidate;
        }
        return error.UnknownRelation;
    }

    /// Resolve a field on a node.
    pub fn nodeField(self: Schema, node_name: []const u8, field_name: []const u8) Error!Field {
        return (try self.node(node_name)).field(field_name);
    }

    /// Every relation must connect nodes that exist, or a traversal would
    /// resolve to nothing at execution time instead of being rejected here.
    pub fn validate(self: Schema) Error!void {
        if (self.name.len == 0) return error.InvalidSchema;
        for (self.nodes) |candidate| {
            if (candidate.name.len == 0) return error.InvalidSchema;
            for (candidate.fields) |declared| {
                if (declared.name.len == 0 or declared.column.len == 0) return error.InvalidSchema;
            }
        }
        for (self.relations) |edge| {
            if (edge.name.len == 0) return error.InvalidSchema;
            _ = try self.node(edge.from_node);
            _ = try self.node(edge.to_node);
        }
    }
};

/// The causal graph as a schema.
///
/// One node kind and one self-relation, because that is genuinely all the causal
/// forest is: events, and the single parent edge between them. Declaring it here
/// rather than hardcoding the columns in the connector means the same plan
/// vocabulary describes this store and a relational one.
pub const causal = Schema{
    .name = "causal",
    .nodes = &.{
        .{
            .name = "Event",
            .table = "causal_event",
            .fields = &.{
                .{ .name = "label", .column = "label" },
                .{ .name = "kind", .column = "kind" },
                .{ .name = "status", .column = "status" },
                .{ .name = "service_key", .column = "service_key" },
                .{ .name = "type_name", .column = "type_name" },
                .{ .name = "requirement_id", .column = "requirement_id", .kind = .id },
                .{ .name = "acceptance_check_id", .column = "acceptance_check_id", .kind = .id },
                .{ .name = "scenario_id", .column = "scenario_id", .kind = .id },
                .{ .name = "run_id", .column = "run_id", .kind = .id },
                .{ .name = "session_id", .column = "session_id", .kind = .id },
            },
        },
    },
    .relations = &.{
        .{
            .name = "caused",
            .from_node = "Event",
            .to_node = "Event",
            .table = "causal_edge",
            .from_column = "parent_id",
            .to_column = "event_id",
        },
    },
};

test "the causal schema declares exactly the columns the index materialises" {
    try causal.validate();

    const event = try causal.node("Event");
    try std.testing.expectEqualStrings("causal_event", event.table);

    const status = try causal.nodeField("Event", "status");
    try std.testing.expectEqualStrings("status", status.column);
    try std.testing.expectEqual(FieldKind.text, status.kind);

    const requirement = try causal.nodeField("Event", "requirement_id");
    try std.testing.expectEqual(FieldKind.id, requirement.kind);

    // The causal log has no documents and no embeddings, so no field claims to.
    for (event.fields) |field| {
        try std.testing.expect(field.kind != .document);
        try std.testing.expect(field.kind != .vector);
    }

    try std.testing.expectError(error.UnknownField, causal.nodeField("Event", "nonexistent"));
    try std.testing.expectError(error.UnknownNode, causal.node("Nope"));
}

test "a relation is directional and its endpoints must exist" {
    const caused = try causal.relation("caused");
    try std.testing.expectEqualStrings("Event", caused.from_node);
    try std.testing.expectEqualStrings("Event", caused.to_node);
    // Which column joins to which is the difference between "what this caused"
    // and "what caused this".
    try std.testing.expectEqualStrings("parent_id", caused.from_column);
    try std.testing.expectEqualStrings("event_id", caused.to_column);

    const dangling = Schema{
        .name = "dangling",
        .nodes = &.{.{ .name = "A" }},
        .relations = &.{.{ .name = "x", .from_node = "A", .to_node = "Missing" }},
    };
    try std.testing.expectError(error.UnknownNode, dangling.validate());
}

test "a relational schema carries what SQL needs and the embedded one ignores" {
    // The same shape describes a store with real tables; a connector reads only
    // the parts its store has a concept for.
    const commerce = Schema{
        .name = "commerce",
        .nodes = &.{
            .{ .name = "User", .table = "user", .fields = &.{
                .{ .name = "id", .column = "id", .kind = .id },
                .{ .name = "status", .column = "status" },
                .{ .name = "bio", .column = "bio_search", .kind = .document },
                .{ .name = "profile", .column = "embedding", .kind = .vector },
            } },
            .{ .name = "Crew", .table = "crew_member", .fields = &.{.{ .name = "id", .column = "id", .kind = .id }} },
        },
        .relations = &.{.{
            .name = "reviewed",
            .from_node = "User",
            .to_node = "Crew",
            .table = "reviewed",
            .from_column = "from_user_id",
            .to_column = "to_crew_member_id",
            .fields = &.{.{ .name = "synergy_score", .column = "synergy_score", .kind = .integer }},
        }},
    };
    try commerce.validate();

    try std.testing.expectEqual(FieldKind.document, (try commerce.nodeField("User", "bio")).kind);
    try std.testing.expectEqual(FieldKind.vector, (try commerce.nodeField("User", "profile")).kind);

    const reviewed = try commerce.relation("reviewed");
    try std.testing.expectEqualStrings("from_user_id", reviewed.from_column);
    try std.testing.expectEqual(FieldKind.integer, (try reviewed.field("synergy_score")).kind);
}
