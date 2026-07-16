const std = @import("std");
const fx = @import("zigeffect");
const StdService = @import("../service/root.zig");

pub const schema = "zigeffect.document-structural-facts.v4";
pub const schema_version: u32 = 4;

pub const Language = enum(u8) {
    typescript,
    tsx,
    javascript,
    jsx,
    zig,
    protobuf,
    json,
    jsonl,
    yaml,
    toml,
    markdown,
    mdx,
    html,
    css,
};

pub const LanguageMode = Language;

pub const DeclarationKind = enum(u8) {
    function,
    class,
    interface,
    type_alias,
    enumeration,
    method,
    variable,
    function_value,
    structure,
    union_type,
    opaque_type,
    error_set,
    test_decl,
    module,
    message,
    service,
    rpc,
    field,
    heading,
    section,
    key,
};

pub const ImportKind = enum(u8) {
    static,
    side_effect,
    import_require,
    dynamic,
    commonjs_require,
    proto_public,
    proto_weak,
};

pub const ImportBindingKind = enum(u8) {
    default,
    named,
    namespace,
    import_require,
    commonjs_require,
};

pub const ExportKind = enum(u8) {
    local_named,
    local_default,
    re_export_named,
    re_export_namespace,
    re_export_star,
    commonjs_named,
    commonjs_default,
    default_expression,
};

pub const TypeBindingKind = enum(u8) {
    parameter,
    constructor_parameter_property,
    field,
    local_annotation,
    constructor_instance,
};

pub const CallKind = enum(u8) {
    direct,
    member,
    constructor,
    dynamic_import,
};

pub const Span = struct {
    start_byte: usize,
    end_byte: usize,
    start_line: u32,
    start_column: u32,
    end_line: u32,
    end_column: u32,

    pub fn valid(self: Span, source_bytes: usize) bool {
        return self.start_byte < self.end_byte and self.end_byte <= source_bytes and
            self.start_line > 0 and self.start_column > 0 and self.end_line >= self.start_line and self.end_column > 0;
    }
};

pub const Declaration = struct {
    kind: DeclarationKind,
    name: []const u8,
    enclosing_declaration: []const u8,
    exported: bool,
    span: Span,
    name_span: Span,
};

pub const Import = struct {
    target: []const u8,
    kind: ImportKind,
    type_only: bool,
    span: Span,
    target_span: Span,
};

pub const ImportBinding = struct {
    target: []const u8,
    imported: []const u8,
    local: []const u8,
    kind: ImportBindingKind,
    type_only: bool,
    span: Span,
};

pub const Export = struct {
    target: []const u8,
    imported: []const u8,
    exported: []const u8,
    kind: ExportKind,
    type_only: bool,
    span: Span,
    target_span: ?Span,
    exported_span: Span,
};

pub const TypeBinding = struct {
    binding: []const u8,
    type_name: []const u8,
    enclosing_declaration: []const u8,
    kind: TypeBindingKind,
    span: Span,
    name_span: Span,
    type_span: Span,
    scope_span: Span,
};

pub const Call = struct {
    kind: CallKind,
    callee: []const u8,
    receiver: []const u8,
    member: []const u8,
    enclosing_declaration: []const u8,
    span: Span,
    callee_span: Span,
};

pub const ExpressionKind = enum(u8) {
    identifier,
    member,
    string_literal,
    number_literal,
    object_literal,
    array_literal,
    call,
    function,
    other,
};

pub const CallArgument = struct {
    call_span: Span,
    index: u32,
    expression: []const u8,
    kind: ExpressionKind,
    span: Span,
};

pub const CallBinding = struct {
    binding: []const u8,
    enclosing_declaration: []const u8,
    span: Span,
    name_span: Span,
    call_span: Span,
};

pub const ProtocolFieldKind = enum(u8) {
    normal,
    map,
    oneof,
};

pub const ProtocolCardinality = enum(u8) {
    singular,
    optional,
    required,
    repeated,
};

pub const ProtocolPackage = struct {
    name: []const u8,
    span: Span,
    name_span: Span,
};

pub const ProtocolField = struct {
    owner: []const u8,
    name: []const u8,
    type_name: []const u8,
    map_key_type: []const u8,
    oneof_name: []const u8,
    number: u32,
    kind: ProtocolFieldKind,
    cardinality: ProtocolCardinality,
    span: Span,
    name_span: Span,
    type_span: Span,
    number_span: Span,
};

pub const ProtocolEnumValue = struct {
    owner: []const u8,
    name: []const u8,
    number: i32,
    span: Span,
    name_span: Span,
    number_span: Span,
};

pub const ProtocolRpc = struct {
    service: []const u8,
    name: []const u8,
    request_type: []const u8,
    response_type: []const u8,
    client_streaming: bool,
    server_streaming: bool,
    span: Span,
    name_span: Span,
    request_span: Span,
    response_span: Span,
};

pub const Summary = struct {
    declarations: usize = 0,
    imports: usize = 0,
    import_bindings: usize = 0,
    exports: usize = 0,
    type_bindings: usize = 0,
    calls: usize = 0,
    call_arguments: usize = 0,
    call_bindings: usize = 0,
    protocol_packages: usize = 0,
    protocol_fields: usize = 0,
    protocol_enum_values: usize = 0,
    protocol_rpcs: usize = 0,
    traversed_nodes: usize = 0,
    parse_errors: usize = 0,
};

pub const Limits = struct {
    max_source_bytes: usize = 4 * 1024 * 1024,
    max_nodes: usize = 1_000_000,
    max_depth: usize = 512,
    max_facts: usize = 250_000,
    max_label_bytes: usize = 4096,

    pub fn validate(self: Limits) !void {
        if (self.max_source_bytes == 0 or self.max_nodes == 0 or self.max_depth == 0 or self.max_depth > 1024 or
            self.max_facts == 0 or self.max_label_bytes == 0 or self.max_label_bytes > 64 * 1024)
        {
            return error.InvalidParserLimits;
        }
    }
};

pub const Options = Limits;

pub const Result = struct {
    allocator: std.mem.Allocator,
    path: []const u8,
    language: Language,
    source_bytes: usize,
    parser_id: []const u8,
    parser_version: []const u8,
    declarations: []Declaration,
    imports: []Import,
    import_bindings: []ImportBinding,
    exports: []Export,
    type_bindings: []TypeBinding,
    calls: []Call,
    call_arguments: []CallArgument,
    call_bindings: []CallBinding,
    protocol_packages: []ProtocolPackage,
    protocol_fields: []ProtocolField,
    protocol_enum_values: []ProtocolEnumValue,
    protocol_rpcs: []ProtocolRpc,
    summary: Summary,
    fingerprint: [32]u8,
    owns_memory: bool = true,

    pub fn initOwned(
        allocator: std.mem.Allocator,
        path: []const u8,
        language: Language,
        source_bytes: usize,
        parser_id: []const u8,
        parser_version: []const u8,
        declarations: []Declaration,
        imports: []Import,
        import_bindings: []ImportBinding,
        exports: []Export,
        type_bindings: []TypeBinding,
        calls: []Call,
        call_arguments: []CallArgument,
        call_bindings: []CallBinding,
        protocol_packages: []ProtocolPackage,
        protocol_fields: []ProtocolField,
        protocol_enum_values: []ProtocolEnumValue,
        protocol_rpcs: []ProtocolRpc,
        traversed_nodes: usize,
    ) !Result {
        const copied_path = try allocator.dupe(u8, path);
        errdefer allocator.free(copied_path);
        const summary = Summary{
            .declarations = declarations.len,
            .imports = imports.len,
            .import_bindings = import_bindings.len,
            .exports = exports.len,
            .type_bindings = type_bindings.len,
            .calls = calls.len,
            .call_arguments = call_arguments.len,
            .call_bindings = call_bindings.len,
            .protocol_packages = protocol_packages.len,
            .protocol_fields = protocol_fields.len,
            .protocol_enum_values = protocol_enum_values.len,
            .protocol_rpcs = protocol_rpcs.len,
            .traversed_nodes = traversed_nodes,
        };
        var result = Result{
            .allocator = allocator,
            .path = copied_path,
            .language = language,
            .source_bytes = source_bytes,
            .parser_id = parser_id,
            .parser_version = parser_version,
            .declarations = declarations,
            .imports = imports,
            .import_bindings = import_bindings,
            .exports = exports,
            .type_bindings = type_bindings,
            .calls = calls,
            .call_arguments = call_arguments,
            .call_bindings = call_bindings,
            .protocol_packages = protocol_packages,
            .protocol_fields = protocol_fields,
            .protocol_enum_values = protocol_enum_values,
            .protocol_rpcs = protocol_rpcs,
            .summary = summary,
            .fingerprint = structuralFingerprint(parser_id, parser_version, copied_path, language, source_bytes, declarations, imports, import_bindings, exports, type_bindings, calls, call_arguments, call_bindings, protocol_packages, protocol_fields, protocol_enum_values, protocol_rpcs, summary),
        };
        result.validate() catch |failure| {
            allocator.free(copied_path);
            return failure;
        };
        return result;
    }

    pub fn emptyAlloc(
        allocator: std.mem.Allocator,
        path: []const u8,
        language: Language,
        source_bytes: usize,
        parser_id: []const u8,
        parser_version: []const u8,
        traversed_nodes: usize,
    ) !Result {
        const declarations = try allocator.alloc(Declaration, 0);
        errdefer allocator.free(declarations);
        const imports = try allocator.alloc(Import, 0);
        errdefer allocator.free(imports);
        const bindings = try allocator.alloc(ImportBinding, 0);
        errdefer allocator.free(bindings);
        const exports = try allocator.alloc(Export, 0);
        errdefer allocator.free(exports);
        const type_bindings = try allocator.alloc(TypeBinding, 0);
        errdefer allocator.free(type_bindings);
        const calls = try allocator.alloc(Call, 0);
        errdefer allocator.free(calls);
        const call_arguments = try allocator.alloc(CallArgument, 0);
        errdefer allocator.free(call_arguments);
        const call_bindings = try allocator.alloc(CallBinding, 0);
        errdefer allocator.free(call_bindings);
        const protocol_packages = try allocator.alloc(ProtocolPackage, 0);
        errdefer allocator.free(protocol_packages);
        const protocol_fields = try allocator.alloc(ProtocolField, 0);
        errdefer allocator.free(protocol_fields);
        const protocol_enum_values = try allocator.alloc(ProtocolEnumValue, 0);
        errdefer allocator.free(protocol_enum_values);
        const protocol_rpcs = try allocator.alloc(ProtocolRpc, 0);
        errdefer allocator.free(protocol_rpcs);
        return initOwned(
            allocator,
            path,
            language,
            source_bytes,
            parser_id,
            parser_version,
            declarations,
            imports,
            bindings,
            exports,
            type_bindings,
            calls,
            call_arguments,
            call_bindings,
            protocol_packages,
            protocol_fields,
            protocol_enum_values,
            protocol_rpcs,
            traversed_nodes,
        );
    }

    pub fn deinit(self: *Result) void {
        if (!self.owns_memory) return;
        for (self.declarations) |declaration| {
            self.allocator.free(declaration.name);
            if (declaration.enclosing_declaration.len > 0) self.allocator.free(declaration.enclosing_declaration);
        }
        self.allocator.free(self.declarations);
        for (self.imports) |item| self.allocator.free(item.target);
        self.allocator.free(self.imports);
        for (self.import_bindings) |binding| {
            self.allocator.free(binding.target);
            self.allocator.free(binding.imported);
            self.allocator.free(binding.local);
        }
        self.allocator.free(self.import_bindings);
        for (self.exports) |item| {
            if (item.target.len > 0) self.allocator.free(item.target);
            self.allocator.free(item.imported);
            self.allocator.free(item.exported);
        }
        self.allocator.free(self.exports);
        for (self.type_bindings) |binding| {
            self.allocator.free(binding.binding);
            self.allocator.free(binding.type_name);
            if (binding.enclosing_declaration.len > 0) self.allocator.free(binding.enclosing_declaration);
        }
        self.allocator.free(self.type_bindings);
        for (self.calls) |call| {
            self.allocator.free(call.callee);
            if (call.receiver.len > 0) self.allocator.free(call.receiver);
            if (call.member.len > 0) self.allocator.free(call.member);
            if (call.enclosing_declaration.len > 0) self.allocator.free(call.enclosing_declaration);
        }
        self.allocator.free(self.calls);
        for (self.call_arguments) |argument| self.allocator.free(argument.expression);
        self.allocator.free(self.call_arguments);
        for (self.call_bindings) |binding| {
            self.allocator.free(binding.binding);
            if (binding.enclosing_declaration.len > 0) self.allocator.free(binding.enclosing_declaration);
        }
        self.allocator.free(self.call_bindings);
        for (self.protocol_packages) |item| self.allocator.free(item.name);
        self.allocator.free(self.protocol_packages);
        for (self.protocol_fields) |field| {
            self.allocator.free(field.owner);
            self.allocator.free(field.name);
            self.allocator.free(field.type_name);
            if (field.map_key_type.len > 0) self.allocator.free(field.map_key_type);
            if (field.oneof_name.len > 0) self.allocator.free(field.oneof_name);
        }
        self.allocator.free(self.protocol_fields);
        for (self.protocol_enum_values) |value| {
            self.allocator.free(value.owner);
            self.allocator.free(value.name);
        }
        self.allocator.free(self.protocol_enum_values);
        for (self.protocol_rpcs) |rpc| {
            self.allocator.free(rpc.service);
            self.allocator.free(rpc.name);
            self.allocator.free(rpc.request_type);
            self.allocator.free(rpc.response_type);
        }
        self.allocator.free(self.protocol_rpcs);
        self.allocator.free(self.path);
        self.path = "";
        self.declarations = &.{};
        self.imports = &.{};
        self.import_bindings = &.{};
        self.exports = &.{};
        self.type_bindings = &.{};
        self.calls = &.{};
        self.call_arguments = &.{};
        self.call_bindings = &.{};
        self.protocol_packages = &.{};
        self.protocol_fields = &.{};
        self.protocol_enum_values = &.{};
        self.protocol_rpcs = &.{};
        self.owns_memory = false;
    }

    pub fn validate(self: *const Result) !void {
        if (!self.owns_memory or !validPath(self.path) or self.source_bytes == 0 or self.parser_id.len == 0 or
            self.parser_version.len == 0 or self.summary.traversed_nodes == 0 or
            self.summary.declarations != self.declarations.len or self.summary.imports != self.imports.len or
            self.summary.import_bindings != self.import_bindings.len or self.summary.exports != self.exports.len or
            self.summary.type_bindings != self.type_bindings.len or self.summary.calls != self.calls.len or
            self.summary.call_arguments != self.call_arguments.len or self.summary.call_bindings != self.call_bindings.len or
            self.summary.protocol_packages != self.protocol_packages.len or self.summary.protocol_fields != self.protocol_fields.len or
            self.summary.protocol_enum_values != self.protocol_enum_values.len or self.summary.protocol_rpcs != self.protocol_rpcs.len or
            self.summary.parse_errors != 0)
        {
            return error.InvalidParserResult;
        }
        var previous_start: usize = 0;
        for (self.declarations, 0..) |declaration, index| {
            if (declaration.name.len == 0 or !declaration.span.valid(self.source_bytes) or !declaration.name_span.valid(self.source_bytes) or
                declaration.name_span.start_byte < declaration.span.start_byte or declaration.name_span.end_byte > declaration.span.end_byte or
                (index > 0 and declaration.name_span.start_byte < previous_start)) return error.InvalidParserDeclaration;
            previous_start = declaration.name_span.start_byte;
        }
        previous_start = 0;
        for (self.imports, 0..) |item, index| {
            if (item.target.len == 0 or !item.span.valid(self.source_bytes) or !item.target_span.valid(self.source_bytes) or
                item.target_span.start_byte < item.span.start_byte or item.target_span.end_byte > item.span.end_byte or
                (index > 0 and item.target_span.start_byte < previous_start)) return error.InvalidParserImport;
            previous_start = item.target_span.start_byte;
        }
        previous_start = 0;
        for (self.import_bindings, 0..) |binding, index| {
            if (binding.target.len == 0 or binding.imported.len == 0 or binding.local.len == 0 or !binding.span.valid(self.source_bytes) or
                findImportTarget(self.imports, binding.target) == null or
                (index > 0 and binding.span.start_byte < previous_start)) return error.InvalidParserImportBinding;
            previous_start = binding.span.start_byte;
        }
        previous_start = 0;
        for (self.exports, 0..) |item, index| {
            if (item.imported.len == 0 or item.exported.len == 0 or !item.span.valid(self.source_bytes) or
                !item.exported_span.valid(self.source_bytes) or item.exported_span.start_byte < item.span.start_byte or
                item.exported_span.end_byte > item.span.end_byte or
                (index > 0 and item.exported_span.start_byte < previous_start))
            {
                return error.InvalidParserExport;
            }
            if (item.target_span) |target_span| {
                if (item.target.len == 0 or !target_span.valid(self.source_bytes) or target_span.start_byte < item.span.start_byte or target_span.end_byte > item.span.end_byte) {
                    return error.InvalidParserExport;
                }
            } else if (item.target.len > 0) return error.InvalidParserExport;
            if ((item.kind == .re_export_named or item.kind == .re_export_namespace or item.kind == .re_export_star) and item.target.len == 0) {
                return error.InvalidParserExport;
            }
            previous_start = item.exported_span.start_byte;
        }
        previous_start = 0;
        for (self.type_bindings, 0..) |binding, index| {
            if (binding.binding.len == 0 or binding.type_name.len == 0 or !binding.span.valid(self.source_bytes) or
                !binding.name_span.valid(self.source_bytes) or !binding.type_span.valid(self.source_bytes) or
                !binding.scope_span.valid(self.source_bytes) or binding.name_span.start_byte < binding.span.start_byte or
                binding.name_span.end_byte > binding.span.end_byte or binding.type_span.start_byte < binding.span.start_byte or
                binding.type_span.end_byte > binding.span.end_byte or binding.span.start_byte < binding.scope_span.start_byte or
                binding.span.end_byte > binding.scope_span.end_byte or
                (index > 0 and binding.name_span.start_byte < previous_start))
            {
                return error.InvalidParserTypeBinding;
            }
            previous_start = binding.name_span.start_byte;
        }
        previous_start = 0;
        for (self.calls, 0..) |call, index| {
            if (call.callee.len == 0 or !call.span.valid(self.source_bytes) or !call.callee_span.valid(self.source_bytes) or
                call.callee_span.start_byte < call.span.start_byte or call.callee_span.end_byte > call.span.end_byte or
                (call.kind == .member and (call.receiver.len == 0 or call.member.len == 0)) or
                (call.kind != .member and (call.receiver.len > 0 or call.member.len > 0)) or
                (index > 0 and call.callee_span.start_byte < previous_start)) return error.InvalidParserCall;
            previous_start = call.callee_span.start_byte;
        }
        var previous_call_span: ?Span = null;
        var previous_argument_index: u32 = 0;
        for (self.call_arguments) |argument| {
            if (argument.expression.len == 0 or !argument.call_span.valid(self.source_bytes) or !argument.span.valid(self.source_bytes) or
                argument.span.start_byte < argument.call_span.start_byte or argument.span.end_byte > argument.call_span.end_byte or
                findCallBySpan(self.calls, argument.call_span) == null)
            {
                return error.InvalidParserCallArgument;
            }
            if (previous_call_span) |previous| {
                const order = compareSpans(previous, argument.call_span);
                if (order == .gt or (order == .eq and argument.index != previous_argument_index + 1)) {
                    return error.InvalidParserCallArgument;
                }
                if (order != .eq and argument.index != 0) return error.InvalidParserCallArgument;
            } else if (argument.index != 0) return error.InvalidParserCallArgument;
            previous_call_span = argument.call_span;
            previous_argument_index = argument.index;
        }
        previous_start = 0;
        for (self.call_bindings, 0..) |binding, index| {
            if (binding.binding.len == 0 or !binding.span.valid(self.source_bytes) or !binding.name_span.valid(self.source_bytes) or
                !binding.call_span.valid(self.source_bytes) or binding.name_span.start_byte < binding.span.start_byte or
                binding.name_span.end_byte > binding.span.end_byte or binding.call_span.start_byte < binding.span.start_byte or
                binding.call_span.end_byte > binding.span.end_byte or findCallBySpan(self.calls, binding.call_span) == null or
                (index > 0 and binding.name_span.start_byte < previous_start))
            {
                return error.InvalidParserCallBinding;
            }
            previous_start = binding.name_span.start_byte;
        }
        previous_start = 0;
        for (self.protocol_packages, 0..) |item, index| {
            if (item.name.len == 0 or !item.span.valid(self.source_bytes) or !item.name_span.valid(self.source_bytes) or
                item.name_span.start_byte < item.span.start_byte or item.name_span.end_byte > item.span.end_byte or
                (index > 0 and item.name_span.start_byte < previous_start)) return error.InvalidParserProtocolPackage;
            previous_start = item.name_span.start_byte;
        }
        previous_start = 0;
        for (self.protocol_fields, 0..) |field, index| {
            if (field.owner.len == 0 or field.name.len == 0 or field.type_name.len == 0 or field.number == 0 or
                !field.span.valid(self.source_bytes) or !field.name_span.valid(self.source_bytes) or
                !field.type_span.valid(self.source_bytes) or !field.number_span.valid(self.source_bytes) or
                field.name_span.start_byte < field.span.start_byte or field.name_span.end_byte > field.span.end_byte or
                field.type_span.start_byte < field.span.start_byte or field.type_span.end_byte > field.span.end_byte or
                field.number_span.start_byte < field.span.start_byte or field.number_span.end_byte > field.span.end_byte or
                (field.kind == .map and field.map_key_type.len == 0) or (field.kind != .map and field.map_key_type.len > 0) or
                (field.kind == .oneof and field.oneof_name.len == 0) or (field.kind != .oneof and field.oneof_name.len > 0) or
                (index > 0 and field.name_span.start_byte < previous_start)) return error.InvalidParserProtocolField;
            previous_start = field.name_span.start_byte;
        }
        previous_start = 0;
        for (self.protocol_enum_values, 0..) |value, index| {
            if (value.owner.len == 0 or value.name.len == 0 or !value.span.valid(self.source_bytes) or
                !value.name_span.valid(self.source_bytes) or !value.number_span.valid(self.source_bytes) or
                value.name_span.start_byte < value.span.start_byte or value.name_span.end_byte > value.span.end_byte or
                value.number_span.start_byte < value.span.start_byte or value.number_span.end_byte > value.span.end_byte or
                (index > 0 and value.name_span.start_byte < previous_start)) return error.InvalidParserProtocolEnumValue;
            previous_start = value.name_span.start_byte;
        }
        previous_start = 0;
        for (self.protocol_rpcs, 0..) |rpc, index| {
            if (rpc.service.len == 0 or rpc.name.len == 0 or rpc.request_type.len == 0 or rpc.response_type.len == 0 or
                !rpc.span.valid(self.source_bytes) or !rpc.name_span.valid(self.source_bytes) or
                !rpc.request_span.valid(self.source_bytes) or !rpc.response_span.valid(self.source_bytes) or
                rpc.name_span.start_byte < rpc.span.start_byte or rpc.name_span.end_byte > rpc.span.end_byte or
                rpc.request_span.start_byte < rpc.span.start_byte or rpc.request_span.end_byte > rpc.span.end_byte or
                rpc.response_span.start_byte < rpc.span.start_byte or rpc.response_span.end_byte > rpc.span.end_byte or
                (index > 0 and rpc.name_span.start_byte < previous_start)) return error.InvalidParserProtocolRpc;
            previous_start = rpc.name_span.start_byte;
        }
        const expected = structuralFingerprint(
            self.parser_id,
            self.parser_version,
            self.path,
            self.language,
            self.source_bytes,
            self.declarations,
            self.imports,
            self.import_bindings,
            self.exports,
            self.type_bindings,
            self.calls,
            self.call_arguments,
            self.call_bindings,
            self.protocol_packages,
            self.protocol_fields,
            self.protocol_enum_values,
            self.protocol_rpcs,
            self.summary,
        );
        if (!std.mem.eql(u8, &expected, &self.fingerprint)) return error.InvalidParserFingerprint;
    }

    pub fn findDeclaration(self: *const Result, name: []const u8) ?*const Declaration {
        for (self.declarations, 0..) |declaration, index| {
            if (std.mem.eql(u8, declaration.name, name)) return &self.declarations[index];
        }
        return null;
    }

    pub fn findImport(self: *const Result, target: []const u8) ?*const Import {
        for (self.imports, 0..) |item, index| {
            if (std.mem.eql(u8, item.target, target)) return &self.imports[index];
        }
        return null;
    }

    pub fn findImportBinding(self: *const Result, local: []const u8) ?*const ImportBinding {
        for (self.import_bindings, 0..) |binding, index| {
            if (std.mem.eql(u8, binding.local, local)) return &self.import_bindings[index];
        }
        return null;
    }

    pub fn findExport(self: *const Result, exported: []const u8) ?*const Export {
        for (self.exports, 0..) |item, index| {
            if (std.mem.eql(u8, item.exported, exported)) return &self.exports[index];
        }
        return null;
    }

    pub fn findTypeBinding(self: *const Result, binding_name: []const u8, enclosing_declaration: []const u8) ?*const TypeBinding {
        for (self.type_bindings, 0..) |binding, index| {
            if (std.mem.eql(u8, binding.binding, binding_name) and std.mem.eql(u8, binding.enclosing_declaration, enclosing_declaration)) return &self.type_bindings[index];
        }
        return null;
    }

    pub fn findCall(self: *const Result, callee: []const u8) ?*const Call {
        for (self.calls, 0..) |call, index| {
            if (std.mem.eql(u8, call.callee, callee)) return &self.calls[index];
        }
        return null;
    }

    pub fn argumentsFor(self: *const Result, call: *const Call) []const CallArgument {
        var start: ?usize = null;
        var end: usize = 0;
        for (self.call_arguments, 0..) |argument, index| {
            if (!spansEqual(argument.call_span, call.span)) {
                if (start != null) break;
                continue;
            }
            if (start == null) start = index;
            end = index + 1;
        }
        return if (start) |index| self.call_arguments[index..end] else &.{};
    }

    pub fn findCallBinding(self: *const Result, binding_name: []const u8, enclosing_declaration: []const u8) ?*const CallBinding {
        for (self.call_bindings, 0..) |binding, index| {
            if (std.mem.eql(u8, binding.binding, binding_name) and
                std.mem.eql(u8, binding.enclosing_declaration, enclosing_declaration)) return &self.call_bindings[index];
        }
        return null;
    }

    pub fn findProtocolPackage(self: *const Result) ?*const ProtocolPackage {
        return if (self.protocol_packages.len == 1) &self.protocol_packages[0] else null;
    }

    pub fn findProtocolField(self: *const Result, owner: []const u8, number: u32) ?*const ProtocolField {
        for (self.protocol_fields, 0..) |field, index| {
            if (field.number == number and std.mem.eql(u8, field.owner, owner)) return &self.protocol_fields[index];
        }
        return null;
    }

    pub fn findProtocolEnumValue(self: *const Result, owner: []const u8, name: []const u8) ?*const ProtocolEnumValue {
        for (self.protocol_enum_values, 0..) |value, index| {
            if (std.mem.eql(u8, value.owner, owner) and std.mem.eql(u8, value.name, name)) return &self.protocol_enum_values[index];
        }
        return null;
    }

    pub fn findProtocolRpc(self: *const Result, service: []const u8, name: []const u8) ?*const ProtocolRpc {
        for (self.protocol_rpcs, 0..) |rpc, index| {
            if (std.mem.eql(u8, rpc.service, service) and std.mem.eql(u8, rpc.name, name)) return &self.protocol_rpcs[index];
        }
        return null;
    }
};

pub const Request = struct {
    path: []const u8,
    source: []const u8,
    language: Language,
    limits: Limits = .{},

    pub fn validate(self: Request) !void {
        try self.limits.validate();
        if (!validPath(self.path)) return error.InvalidParserSourcePath;
        if (self.source.len == 0) return error.InvalidParserSource;
        if (self.source.len > self.limits.max_source_bytes) return error.ParserSourceLimitExceeded;
    }
};

pub const Api = struct {
    pointer: *anyopaque,
    parse_fn: *const fn (*anyopaque, std.mem.Allocator, Request) anyerror!Result,

    pub fn from(comptime Provider: type, provider: *Provider) Api {
        return .{
            .pointer = provider,
            .parse_fn = struct {
                fn run(pointer: *anyopaque, allocator: std.mem.Allocator, request: Request) anyerror!Result {
                    const typed: *Provider = @ptrCast(@alignCast(pointer));
                    return typed.parseAlloc(allocator, request);
                }
            }.run,
        };
    }

    pub fn parseAlloc(self: Api, allocator: std.mem.Allocator, request: Request) !Result {
        try request.validate();
        var result = try self.parse_fn(self.pointer, allocator, request);
        errdefer result.deinit();
        try result.validate();
        return result;
    }
};

pub const DocumentParser = fx.kernel.Service("zigeffect/std/DocumentParser", Api);

pub fn parserLayer(api: Api) @TypeOf(fx.kernel.Layer.succeed(DocumentParser, api)) {
    return fx.kernel.Layer.succeed(DocumentParser, api);
}

pub const ParseEffect = fx.kernel.Effect(Result, anyerror, .{DocumentParser}).Stateful(Request);

pub fn parse(request: Request) ParseEffect {
    const Parse = fx.kernel.Effect(Result, anyerror, .{DocumentParser});
    return Parse.fromState(Request, request, struct {
        fn run(value: Request, ctx: *Parse.Context) anyerror!Result {
            const operation = StdService.beginOperation(ctx, DocumentParser.service_key, "Parser.parse", "bounded source document");
            const result = ctx.service(DocumentParser).parseAlloc(ctx.allocator(), value) catch |failure| {
                _ = StdService.completeOperation(ctx, operation, "failure", @errorName(failure));
                return failure;
            };
            _ = StdService.completeOperation(ctx, operation, "success", "normalized structural facts");
            return result;
        }
    }.run);
}

pub fn structuralFingerprint(
    parser_id: []const u8,
    parser_version: []const u8,
    path: []const u8,
    language: Language,
    source_bytes: usize,
    declarations: []const Declaration,
    imports: []const Import,
    bindings: []const ImportBinding,
    exports: []const Export,
    type_bindings: []const TypeBinding,
    calls: []const Call,
    call_arguments: []const CallArgument,
    call_bindings: []const CallBinding,
    protocol_packages: []const ProtocolPackage,
    protocol_fields: []const ProtocolField,
    protocol_enum_values: []const ProtocolEnumValue,
    protocol_rpcs: []const ProtocolRpc,
    summary: Summary,
) [32]u8 {
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    updateBytes(&hasher, schema);
    updateBytes(&hasher, parser_id);
    updateBytes(&hasher, parser_version);
    updateBytes(&hasher, path);
    updateU64(&hasher, @intCast(@intFromEnum(language)));
    updateU64(&hasher, @intCast(source_bytes));
    for (declarations) |declaration| {
        updateU64(&hasher, @intCast(@intFromEnum(declaration.kind)));
        updateBytes(&hasher, declaration.name);
        updateBytes(&hasher, declaration.enclosing_declaration);
        updateU64(&hasher, @intFromBool(declaration.exported));
        updateSpan(&hasher, declaration.span);
        updateSpan(&hasher, declaration.name_span);
    }
    for (imports) |item| {
        updateBytes(&hasher, item.target);
        updateU64(&hasher, @intCast(@intFromEnum(item.kind)));
        updateU64(&hasher, @intFromBool(item.type_only));
        updateSpan(&hasher, item.span);
        updateSpan(&hasher, item.target_span);
    }
    for (bindings) |binding| {
        updateBytes(&hasher, binding.target);
        updateBytes(&hasher, binding.imported);
        updateBytes(&hasher, binding.local);
        updateU64(&hasher, @intCast(@intFromEnum(binding.kind)));
        updateU64(&hasher, @intFromBool(binding.type_only));
        updateSpan(&hasher, binding.span);
    }
    for (exports) |item| {
        updateBytes(&hasher, item.target);
        updateBytes(&hasher, item.imported);
        updateBytes(&hasher, item.exported);
        updateU64(&hasher, @intCast(@intFromEnum(item.kind)));
        updateU64(&hasher, @intFromBool(item.type_only));
        updateSpan(&hasher, item.span);
        updateU64(&hasher, @intFromBool(item.target_span != null));
        if (item.target_span) |target_span| updateSpan(&hasher, target_span);
        updateSpan(&hasher, item.exported_span);
    }
    for (type_bindings) |binding| {
        updateBytes(&hasher, binding.binding);
        updateBytes(&hasher, binding.type_name);
        updateBytes(&hasher, binding.enclosing_declaration);
        updateU64(&hasher, @intCast(@intFromEnum(binding.kind)));
        updateSpan(&hasher, binding.span);
        updateSpan(&hasher, binding.name_span);
        updateSpan(&hasher, binding.type_span);
        updateSpan(&hasher, binding.scope_span);
    }
    for (calls) |call| {
        updateU64(&hasher, @intCast(@intFromEnum(call.kind)));
        updateBytes(&hasher, call.callee);
        updateBytes(&hasher, call.receiver);
        updateBytes(&hasher, call.member);
        updateBytes(&hasher, call.enclosing_declaration);
        updateSpan(&hasher, call.span);
        updateSpan(&hasher, call.callee_span);
    }
    for (call_arguments) |argument| {
        updateSpan(&hasher, argument.call_span);
        updateU64(&hasher, argument.index);
        updateBytes(&hasher, argument.expression);
        updateU64(&hasher, @intFromEnum(argument.kind));
        updateSpan(&hasher, argument.span);
    }
    for (call_bindings) |binding| {
        updateBytes(&hasher, binding.binding);
        updateBytes(&hasher, binding.enclosing_declaration);
        updateSpan(&hasher, binding.span);
        updateSpan(&hasher, binding.name_span);
        updateSpan(&hasher, binding.call_span);
    }
    for (protocol_packages) |item| {
        updateBytes(&hasher, item.name);
        updateSpan(&hasher, item.span);
        updateSpan(&hasher, item.name_span);
    }
    for (protocol_fields) |field| {
        updateBytes(&hasher, field.owner);
        updateBytes(&hasher, field.name);
        updateBytes(&hasher, field.type_name);
        updateBytes(&hasher, field.map_key_type);
        updateBytes(&hasher, field.oneof_name);
        updateU64(&hasher, field.number);
        updateU64(&hasher, @intFromEnum(field.kind));
        updateU64(&hasher, @intFromEnum(field.cardinality));
        updateSpan(&hasher, field.span);
        updateSpan(&hasher, field.name_span);
        updateSpan(&hasher, field.type_span);
        updateSpan(&hasher, field.number_span);
    }
    for (protocol_enum_values) |value| {
        updateBytes(&hasher, value.owner);
        updateBytes(&hasher, value.name);
        var number_bytes: [4]u8 = @splat(0);
        std.mem.writeInt(i32, &number_bytes, value.number, .little);
        hasher.update(&number_bytes);
        updateSpan(&hasher, value.span);
        updateSpan(&hasher, value.name_span);
        updateSpan(&hasher, value.number_span);
    }
    for (protocol_rpcs) |rpc| {
        updateBytes(&hasher, rpc.service);
        updateBytes(&hasher, rpc.name);
        updateBytes(&hasher, rpc.request_type);
        updateBytes(&hasher, rpc.response_type);
        updateU64(&hasher, @intFromBool(rpc.client_streaming));
        updateU64(&hasher, @intFromBool(rpc.server_streaming));
        updateSpan(&hasher, rpc.span);
        updateSpan(&hasher, rpc.name_span);
        updateSpan(&hasher, rpc.request_span);
        updateSpan(&hasher, rpc.response_span);
    }
    updateU64(&hasher, @intCast(summary.declarations));
    updateU64(&hasher, @intCast(summary.imports));
    updateU64(&hasher, @intCast(summary.import_bindings));
    updateU64(&hasher, @intCast(summary.exports));
    updateU64(&hasher, @intCast(summary.type_bindings));
    updateU64(&hasher, @intCast(summary.calls));
    updateU64(&hasher, @intCast(summary.call_arguments));
    updateU64(&hasher, @intCast(summary.call_bindings));
    updateU64(&hasher, @intCast(summary.protocol_packages));
    updateU64(&hasher, @intCast(summary.protocol_fields));
    updateU64(&hasher, @intCast(summary.protocol_enum_values));
    updateU64(&hasher, @intCast(summary.protocol_rpcs));
    updateU64(&hasher, @intCast(summary.traversed_nodes));
    updateU64(&hasher, @intCast(summary.parse_errors));
    var digest: [32]u8 = @splat(0);
    hasher.final(&digest);
    return digest;
}

fn findImportTarget(imports: []const Import, target: []const u8) ?*const Import {
    for (imports) |*item| if (std.mem.eql(u8, item.target, target)) return item;
    return null;
}

fn findCallBySpan(calls: []const Call, span: Span) ?*const Call {
    for (calls) |*call| if (spansEqual(call.span, span)) return call;
    return null;
}

fn spansEqual(left: Span, right: Span) bool {
    return left.start_byte == right.start_byte and left.end_byte == right.end_byte;
}

fn compareSpans(left: Span, right: Span) std.math.Order {
    if (left.start_byte < right.start_byte) return .lt;
    if (left.start_byte > right.start_byte) return .gt;
    if (left.end_byte < right.end_byte) return .lt;
    if (left.end_byte > right.end_byte) return .gt;
    return .eq;
}

fn validPath(path: []const u8) bool {
    if (path.len == 0 or std.fs.path.isAbsolute(path) or std.mem.indexOfScalar(u8, path, '\\') != null) return false;
    var components = std.mem.splitScalar(u8, path, '/');
    while (components.next()) |component| {
        if (component.len == 0 or std.mem.eql(u8, component, ".") or std.mem.eql(u8, component, "..")) return false;
    }
    return true;
}

fn updateSpan(hasher: *std.crypto.hash.sha2.Sha256, span: Span) void {
    updateU64(hasher, @intCast(span.start_byte));
    updateU64(hasher, @intCast(span.end_byte));
    updateU64(hasher, span.start_line);
    updateU64(hasher, span.start_column);
    updateU64(hasher, span.end_line);
    updateU64(hasher, span.end_column);
}

fn updateBytes(hasher: *std.crypto.hash.sha2.Sha256, value: []const u8) void {
    updateU64(hasher, @intCast(value.len));
    hasher.update(value);
}

fn updateU64(hasher: *std.crypto.hash.sha2.Sha256, value: u64) void {
    var bytes: [8]u8 = @splat(0);
    std.mem.writeInt(u64, &bytes, value, .little);
    hasher.update(&bytes);
}

const request_source_marker = "export const value";

test "Parser service is provider-substitutable and records bounded causal evidence" {
    const Fake = struct {
        calls: usize = 0,

        fn parseAlloc(self: *@This(), allocator: std.mem.Allocator, request: Request) !Result {
            self.calls += 1;
            return Result.emptyAlloc(
                allocator,
                request.path,
                request.language,
                request.source.len,
                "test.fake-parser",
                "1.0.0",
                3,
            );
        }
    };

    var fake = Fake{};
    const root = parserLayer(Api.from(Fake, &fake));
    var causal = fx.CausalStore.init(std.testing.allocator);
    defer causal.deinit();
    var runtime = try fx.kernel.ManagedRuntime(@TypeOf(root)).make(std.testing.allocator, root, .{ .causal_store = &causal });
    defer runtime.deinit();

    var result = try runtime.run(parse(.{
        .path = "src/example.ts",
        .source = "export const value = 1;",
        .language = .typescript,
    }));
    defer result.deinit();
    try result.validate();
    try std.testing.expectEqual(@as(usize, 1), fake.calls);
    try std.testing.expectEqualStrings("test.fake-parser", result.parser_id);
    try std.testing.expectEqual(@as(usize, 3), result.summary.traversed_nodes);

    var snapshot = try causal.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    var saw_completion = false;
    for (snapshot.events) |event| {
        if (event.kind == .io_completed and std.mem.eql(u8, event.service_key, DocumentParser.service_key)) {
            saw_completion = true;
            try std.testing.expectEqualStrings("success", event.status);
            try std.testing.expect(std.mem.indexOf(u8, event.redacted_detail, request_source_marker) == null);
        }
    }
    try std.testing.expect(saw_completion);
}
