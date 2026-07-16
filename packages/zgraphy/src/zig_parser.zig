const std = @import("std");
const owned = @import("memory.zig");

pub const schema = "zgraphy.zig-structural-facts.v3";
pub const schema_version: u32 = 3;
pub const parser_version = "std.zig.Ast-0.16-v3";

pub const DeclarationKind = enum(u8) {
    function,
    structure,
    enumeration,
    union_type,
    opaque_type,
    error_set,
    test_decl,
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
    span: Span,
    name_span: Span,
};

pub const Import = struct {
    target: []const u8,
    binding: []const u8,
    enclosing_declaration: []const u8,
    span: Span,
    target_span: Span,
};

pub const BindingScope = enum(u8) {
    file,
    local,
};

pub const Binding = struct {
    name: []const u8,
    enclosing_declaration: []const u8,
    scope: BindingScope,
    span: Span,
    name_span: Span,
    initializer_span: Span,
};

pub const BindingReference = struct {
    binding: []const u8,
    enclosing_declaration: []const u8,
    expression: []const u8,
    span: Span,
};

pub const Call = struct {
    callee: []const u8,
    enclosing_declaration: []const u8,
    span: Span,
    callee_span: Span,
};

pub const ExpressionKind = enum(u8) {
    identifier,
    member,
    string_literal,
    number_literal,
    struct_literal,
    call,
    other,
};

pub const CallArgument = struct {
    call_span: Span,
    index: u32,
    expression: []const u8,
    kind: ExpressionKind,
    span: Span,
};

pub const Summary = struct {
    declarations: usize = 0,
    imports: usize = 0,
    calls: usize = 0,
    call_arguments: usize = 0,
    bindings: usize = 0,
    binding_references: usize = 0,
    parse_errors: usize = 0,
};

pub const Options = struct {
    max_source_bytes: usize = 4 * 1024 * 1024,
    max_facts: usize = 100_000,
    max_label_bytes: usize = 1024,
};

pub const Result = struct {
    allocator: std.mem.Allocator,
    path: []const u8,
    source_bytes: usize,
    declarations: []Declaration,
    imports: []Import,
    calls: []Call,
    call_arguments: []CallArgument,
    bindings: []Binding,
    binding_references: []BindingReference,
    summary: Summary,
    fingerprint: [32]u8,

    pub fn deinit(self: *Result) void {
        for (self.declarations) |declaration| self.allocator.free(declaration.name);
        self.allocator.free(self.declarations);
        for (self.imports) |item| {
            self.allocator.free(item.target);
            if (item.binding.len > 0) self.allocator.free(item.binding);
            if (item.enclosing_declaration.len > 0) self.allocator.free(item.enclosing_declaration);
        }
        self.allocator.free(self.imports);
        for (self.calls) |call| {
            self.allocator.free(call.callee);
            if (call.enclosing_declaration.len > 0) self.allocator.free(call.enclosing_declaration);
        }
        self.allocator.free(self.calls);
        for (self.call_arguments) |argument| self.allocator.free(argument.expression);
        self.allocator.free(self.call_arguments);
        for (self.bindings) |binding| {
            self.allocator.free(binding.name);
            if (binding.enclosing_declaration.len > 0) self.allocator.free(binding.enclosing_declaration);
        }
        self.allocator.free(self.bindings);
        for (self.binding_references) |reference| {
            self.allocator.free(reference.binding);
            if (reference.enclosing_declaration.len > 0) self.allocator.free(reference.enclosing_declaration);
            self.allocator.free(reference.expression);
        }
        self.allocator.free(self.binding_references);
        self.allocator.free(self.path);
        self.path = "";
        self.declarations = &.{};
        self.imports = &.{};
        self.calls = &.{};
        self.call_arguments = &.{};
        self.bindings = &.{};
        self.binding_references = &.{};
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

    pub fn findImportBinding(self: *const Result, binding: []const u8) ?*const Import {
        for (self.imports, 0..) |item, index| {
            if (std.mem.eql(u8, item.binding, binding)) return &self.imports[index];
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
            if (argument.call_span.start_byte != call.span.start_byte or argument.call_span.end_byte != call.span.end_byte) {
                if (start != null) break;
                continue;
            }
            if (start == null) start = index;
            end = index + 1;
        }
        return if (start) |index| self.call_arguments[index..end] else &.{};
    }

    pub fn findBinding(self: *const Result, name: []const u8, enclosing_declaration: []const u8) ?*const Binding {
        for (self.bindings, 0..) |binding, index| {
            if (std.mem.eql(u8, binding.name, name) and std.mem.eql(u8, binding.enclosing_declaration, enclosing_declaration)) {
                return &self.bindings[index];
            }
        }
        return null;
    }
};

const EnclosingRange = struct {
    start_byte: usize,
    end_byte: usize,
    name: []const u8,
};

pub fn parse(
    allocator: std.mem.Allocator,
    path: []const u8,
    source: []const u8,
    options: Options,
) !Result {
    try validateOptions(path, source, options);
    const sentinel_source = try allocator.allocSentinel(u8, source.len, 0);
    defer allocator.free(sentinel_source);
    @memcpy(sentinel_source[0..source.len], source);
    var tree = try std.zig.Ast.parse(allocator, sentinel_source, .zig);
    defer tree.deinit(allocator);
    if (tree.errors.len != 0) return error.InvalidZigSource;

    var declarations: std.ArrayList(Declaration) = .empty;
    errdefer deinitDeclarations(allocator, &declarations);
    var imports: std.ArrayList(Import) = .empty;
    errdefer deinitImports(allocator, &imports);
    var calls: std.ArrayList(Call) = .empty;
    errdefer deinitCalls(allocator, &calls);
    var call_arguments: std.ArrayList(CallArgument) = .empty;
    errdefer deinitCallArguments(allocator, &call_arguments);
    var bindings: std.ArrayList(Binding) = .empty;
    errdefer deinitBindings(allocator, &bindings);
    var binding_references: std.ArrayList(BindingReference) = .empty;
    errdefer deinitBindingReferences(allocator, &binding_references);
    var ranges: std.ArrayList(EnclosingRange) = .empty;
    defer ranges.deinit(allocator);

    var node_integer: usize = 1;
    while (node_integer < tree.nodes.len) : (node_integer += 1) {
        const node: std.zig.Ast.Node.Index = @enumFromInt(node_integer);
        if (tree.nodeTag(node) != .fn_decl) continue;
        try appendFunction(allocator, source, &tree, node, options, &declarations, &ranges);
    }
    node_integer = 1;
    while (node_integer < tree.nodes.len) : (node_integer += 1) {
        const node: std.zig.Ast.Node.Index = @enumFromInt(node_integer);
        if (tree.nodeTag(node) == .fn_decl) continue;
        var fn_buffer = [1]std.zig.Ast.Node.Index{.root};
        const proto = tree.fullFnProto(&fn_buffer, node) orelse continue;
        const name_token = proto.name_token orelse continue;
        if (hasDeclarationAt(declarations.items, tree.tokenStart(name_token))) continue;
        try appendNamedDeclaration(allocator, source, &tree, node, name_token, .function, options, &declarations);
    }
    node_integer = 1;
    while (node_integer < tree.nodes.len) : (node_integer += 1) {
        const node: std.zig.Ast.Node.Index = @enumFromInt(node_integer);
        if (tree.nodeTag(node) != .test_decl) continue;
        try appendTest(allocator, source, &tree, node, options, &declarations, &ranges);
    }
    node_integer = 1;
    while (node_integer < tree.nodes.len) : (node_integer += 1) {
        const node: std.zig.Ast.Node.Index = @enumFromInt(node_integer);
        const var_decl = tree.fullVarDecl(node) orelse continue;
        const init_node = var_decl.ast.init_node.unwrap() orelse continue;
        const name_token = var_decl.ast.mut_token + 1;
        if (tree.tokenTag(name_token) != .identifier) continue;
        try appendBinding(
            allocator,
            source,
            &tree,
            node,
            init_node,
            name_token,
            ranges.items,
            options,
            &declarations,
            &imports,
            &calls,
            &bindings,
            &binding_references,
        );
        const kind = declarationKindForInit(&tree, init_node) orelse continue;
        try ensureFactCapacity(try factCount(&.{ declarations.items.len, imports.items.len, calls.items.len, bindings.items.len, binding_references.items.len }), options.max_facts);
        try appendNamedDeclaration(allocator, source, &tree, node, name_token, kind, options, &declarations);
    }

    node_integer = 1;
    while (node_integer < tree.nodes.len) : (node_integer += 1) {
        const node: std.zig.Ast.Node.Index = @enumFromInt(node_integer);
        var builtin_buffer = [2]std.zig.Ast.Node.Index{ .root, .root };
        const params = tree.builtinCallParams(&builtin_buffer, node) orelse continue;
        const builtin_token = tree.nodeMainToken(node);
        if (!std.mem.eql(u8, tree.tokenSlice(builtin_token), "@import") or params.len != 1) continue;
        const target_token = tree.firstToken(params[0]);
        if (tree.tokenTag(target_token) != .string_literal) continue;
        const raw_target = tree.tokenSlice(target_token);
        const target = std.zig.string_literal.parseAlloc(allocator, raw_target) catch return error.InvalidStaticImport;
        errdefer allocator.free(target);
        if (target.len == 0 or target.len > options.max_label_bytes) return error.InvalidStaticImport;
        const import_span = spanForNode(source, &tree, node);
        const containing_binding = bindingForInitializer(bindings.items, import_span.start_byte, import_span.end_byte);
        const binding_copy = if (containing_binding) |binding| try owned.copy(u8, allocator, binding.name) else "";
        errdefer if (binding_copy.len > 0) allocator.free(binding_copy);
        const enclosing_copy = if (containing_binding) |binding|
            if (binding.enclosing_declaration.len > 0) try owned.copy(u8, allocator, binding.enclosing_declaration) else ""
        else
            "";
        errdefer if (enclosing_copy.len > 0) allocator.free(enclosing_copy);
        try ensureFactCapacity(try factCount(&.{ declarations.items.len, imports.items.len, calls.items.len, bindings.items.len, binding_references.items.len }), options.max_facts);
        try imports.append(allocator, .{
            .target = target,
            .binding = binding_copy,
            .enclosing_declaration = enclosing_copy,
            .span = import_span,
            .target_span = spanForToken(source, &tree, target_token),
        });
    }

    node_integer = 1;
    while (node_integer < tree.nodes.len) : (node_integer += 1) {
        const node: std.zig.Ast.Node.Index = @enumFromInt(node_integer);
        if (tree.nodeTag(node) != .field_access) continue;
        const reference_span = spanForNode(source, &tree, node);
        const binding = bindingForInitializer(bindings.items, reference_span.start_byte, reference_span.end_byte) orelse continue;
        const expression = try compactExpressionAlloc(allocator, source[reference_span.start_byte..reference_span.end_byte], options.max_label_bytes);
        errdefer allocator.free(expression);
        if (std.mem.indexOfScalar(u8, expression, '.') == null) {
            allocator.free(expression);
            continue;
        }
        const binding_copy = try owned.copy(u8, allocator, binding.name);
        errdefer allocator.free(binding_copy);
        const enclosing_copy = if (binding.enclosing_declaration.len > 0) try owned.copy(u8, allocator, binding.enclosing_declaration) else "";
        errdefer if (enclosing_copy.len > 0) allocator.free(enclosing_copy);
        try ensureFactCapacity(try factCount(&.{ declarations.items.len, imports.items.len, calls.items.len, bindings.items.len, binding_references.items.len }), options.max_facts);
        try binding_references.append(allocator, .{
            .binding = binding_copy,
            .enclosing_declaration = enclosing_copy,
            .expression = expression,
            .span = reference_span,
        });
    }

    node_integer = 1;
    while (node_integer < tree.nodes.len) : (node_integer += 1) {
        const node: std.zig.Ast.Node.Index = @enumFromInt(node_integer);
        var call_buffer = [1]std.zig.Ast.Node.Index{.root};
        const full_call = tree.fullCall(&call_buffer, node) orelse continue;
        const callee_span = spanForNode(source, &tree, full_call.ast.fn_expr);
        const callee = try compactExpressionAlloc(allocator, source[callee_span.start_byte..callee_span.end_byte], options.max_label_bytes);
        errdefer allocator.free(callee);
        if (callee.len == 0) return error.InvalidCallExpression;
        const enclosing = enclosingName(ranges.items, callee_span.start_byte, callee_span.end_byte);
        const enclosing_copy = if (enclosing.len > 0) try owned.copy(u8, allocator, enclosing) else "";
        errdefer if (enclosing_copy.len > 0) allocator.free(enclosing_copy);
        try ensureFactCapacity(try factCount(&.{ declarations.items.len, imports.items.len, calls.items.len, call_arguments.items.len, bindings.items.len, binding_references.items.len }), options.max_facts);
        const call_span = spanForNode(source, &tree, node);
        try calls.append(allocator, .{
            .callee = callee,
            .enclosing_declaration = enclosing_copy,
            .span = call_span,
            .callee_span = callee_span,
        });
        for (full_call.ast.params, 0..) |parameter, argument_index| {
            const argument_span = spanForNode(source, &tree, parameter);
            const expression = try compactExpressionAlloc(allocator, source[argument_span.start_byte..argument_span.end_byte], options.max_label_bytes);
            errdefer allocator.free(expression);
            try ensureFactCapacity(try factCount(&.{ declarations.items.len, imports.items.len, calls.items.len, call_arguments.items.len, bindings.items.len, binding_references.items.len }), options.max_facts);
            try call_arguments.append(allocator, .{
                .call_span = call_span,
                .index = @intCast(argument_index),
                .expression = expression,
                .kind = expressionKind(&tree, parameter, argument_span, source),
                .span = argument_span,
            });
        }
    }

    std.mem.sort(Declaration, declarations.items, {}, lessThanDeclaration);
    std.mem.sort(Import, imports.items, {}, lessThanImport);
    std.mem.sort(Call, calls.items, {}, lessThanCall);
    std.mem.sort(CallArgument, call_arguments.items, {}, lessThanCallArgument);
    std.mem.sort(Binding, bindings.items, {}, lessThanBinding);
    std.mem.sort(BindingReference, binding_references.items, {}, lessThanBindingReference);
    const declaration_slice = try declarations.toOwnedSlice(allocator);
    errdefer {
        var values = std.ArrayList(Declaration).fromOwnedSlice(declaration_slice);
        deinitDeclarations(allocator, &values);
    }
    const import_slice = try imports.toOwnedSlice(allocator);
    errdefer {
        var values = std.ArrayList(Import).fromOwnedSlice(import_slice);
        deinitImports(allocator, &values);
    }
    const call_slice = try calls.toOwnedSlice(allocator);
    errdefer {
        var values = std.ArrayList(Call).fromOwnedSlice(call_slice);
        deinitCalls(allocator, &values);
    }
    const call_argument_slice = try call_arguments.toOwnedSlice(allocator);
    errdefer {
        var values = std.ArrayList(CallArgument).fromOwnedSlice(call_argument_slice);
        deinitCallArguments(allocator, &values);
    }
    const binding_slice = try bindings.toOwnedSlice(allocator);
    errdefer {
        var values = std.ArrayList(Binding).fromOwnedSlice(binding_slice);
        deinitBindings(allocator, &values);
    }
    const binding_reference_slice = try binding_references.toOwnedSlice(allocator);
    errdefer {
        var values = std.ArrayList(BindingReference).fromOwnedSlice(binding_reference_slice);
        deinitBindingReferences(allocator, &values);
    }
    const copied_path = try owned.copy(u8, allocator, path);
    errdefer allocator.free(copied_path);
    var result = Result{
        .allocator = allocator,
        .path = copied_path,
        .source_bytes = source.len,
        .declarations = declaration_slice,
        .imports = import_slice,
        .calls = call_slice,
        .call_arguments = call_argument_slice,
        .bindings = binding_slice,
        .binding_references = binding_reference_slice,
        .summary = .{
            .declarations = declaration_slice.len,
            .imports = import_slice.len,
            .calls = call_slice.len,
            .call_arguments = call_argument_slice.len,
            .bindings = binding_slice.len,
            .binding_references = binding_reference_slice.len,
        },
        .fingerprint = fingerprint(path, source.len, declaration_slice, import_slice, call_slice, call_argument_slice, binding_slice, binding_reference_slice),
    };
    errdefer result.deinit();
    try validate(&result);
    return result;
}

pub fn validate(result: *const Result) !void {
    if (!validPath(result.path) or result.source_bytes == 0 or
        result.summary.declarations != result.declarations.len or result.summary.imports != result.imports.len or
        result.summary.calls != result.calls.len or result.summary.call_arguments != result.call_arguments.len or result.summary.bindings != result.bindings.len or
        result.summary.binding_references != result.binding_references.len or result.summary.parse_errors != 0)
    {
        return error.InvalidZigParserResult;
    }
    var previous_start: usize = 0;
    for (result.declarations, 0..) |declaration, index| {
        if (declaration.name.len == 0 or !declaration.span.valid(result.source_bytes) or !declaration.name_span.valid(result.source_bytes) or
            declaration.name_span.start_byte < declaration.span.start_byte or declaration.name_span.end_byte > declaration.span.end_byte or
            (index > 0 and declaration.name_span.start_byte < previous_start))
        {
            return error.InvalidZigDeclaration;
        }
        previous_start = declaration.name_span.start_byte;
    }
    previous_start = 0;
    for (result.imports, 0..) |item, index| {
        if (item.target.len == 0 or !item.span.valid(result.source_bytes) or !item.target_span.valid(result.source_bytes) or
            (item.binding.len == 0 and item.enclosing_declaration.len > 0) or
            (item.binding.len > 0 and findBindingByNameScopeAndContainment(result.bindings, item.binding, item.enclosing_declaration, item.span) == null) or
            (index > 0 and item.target_span.start_byte < previous_start)) return error.InvalidZigImport;
        previous_start = item.target_span.start_byte;
    }
    previous_start = 0;
    for (result.calls, 0..) |call, index| {
        if (call.callee.len == 0 or !call.span.valid(result.source_bytes) or !call.callee_span.valid(result.source_bytes) or
            call.callee_span.start_byte < call.span.start_byte or call.callee_span.end_byte > call.span.end_byte or
            (index > 0 and call.callee_span.start_byte < previous_start)) return error.InvalidZigCall;
        previous_start = call.callee_span.start_byte;
    }
    var previous_call_span: ?Span = null;
    var previous_argument_index: u32 = 0;
    for (result.call_arguments) |argument| {
        if (argument.expression.len == 0 or !argument.call_span.valid(result.source_bytes) or !argument.span.valid(result.source_bytes) or
            argument.span.start_byte < argument.call_span.start_byte or argument.span.end_byte > argument.call_span.end_byte or
            findCallBySpan(result.calls, argument.call_span) == null) return error.InvalidZigCallArgument;
        if (previous_call_span) |previous| {
            const order = compareSpans(previous, argument.call_span);
            if (order == .gt or (order == .eq and argument.index != previous_argument_index + 1) or
                (order != .eq and argument.index != 0)) return error.InvalidZigCallArgument;
        } else if (argument.index != 0) return error.InvalidZigCallArgument;
        previous_call_span = argument.call_span;
        previous_argument_index = argument.index;
    }
    previous_start = 0;
    for (result.bindings, 0..) |binding, index| {
        if (binding.name.len == 0 or !binding.span.valid(result.source_bytes) or !binding.name_span.valid(result.source_bytes) or
            !binding.initializer_span.valid(result.source_bytes) or binding.name_span.start_byte < binding.span.start_byte or
            binding.name_span.end_byte > binding.span.end_byte or binding.initializer_span.start_byte < binding.span.start_byte or
            binding.initializer_span.end_byte > binding.span.end_byte or
            (binding.scope == .local) != (binding.enclosing_declaration.len > 0) or
            (index > 0 and binding.name_span.start_byte < previous_start)) return error.InvalidZigBinding;
        previous_start = binding.name_span.start_byte;
    }
    previous_start = 0;
    for (result.binding_references, 0..) |reference, index| {
        const binding = findBindingExact(result.bindings, reference.binding, reference.enclosing_declaration) orelse return error.InvalidZigBindingReference;
        if (reference.expression.len == 0 or std.mem.indexOfScalar(u8, reference.expression, '.') == null or
            !reference.span.valid(result.source_bytes) or reference.span.start_byte < binding.initializer_span.start_byte or
            reference.span.end_byte > binding.initializer_span.end_byte or
            (index > 0 and reference.span.start_byte < previous_start)) return error.InvalidZigBindingReference;
        previous_start = reference.span.start_byte;
    }
    const expected = fingerprint(result.path, result.source_bytes, result.declarations, result.imports, result.calls, result.call_arguments, result.bindings, result.binding_references);
    if (!std.mem.eql(u8, &expected, &result.fingerprint)) return error.InvalidZigParserFingerprint;
}

fn validateOptions(path: []const u8, source: []const u8, options: Options) !void {
    if (!validPath(path)) return error.InvalidZigSourcePath;
    if (options.max_source_bytes == 0 or options.max_facts == 0 or options.max_label_bytes == 0 or options.max_label_bytes > 64 * 1024) return error.InvalidZigParserOptions;
    if (source.len == 0) return error.InvalidZigSource;
    if (source.len > options.max_source_bytes) return error.ZigSourceLimitExceeded;
}

fn validPath(path: []const u8) bool {
    if (path.len == 0 or std.fs.path.isAbsolute(path) or std.mem.indexOfScalar(u8, path, '\\') != null) return false;
    var components = std.mem.splitScalar(u8, path, '/');
    while (components.next()) |component| if (component.len == 0 or std.mem.eql(u8, component, ".") or std.mem.eql(u8, component, "..")) return false;
    return true;
}

fn appendFunction(
    allocator: std.mem.Allocator,
    source: []const u8,
    tree: *const std.zig.Ast,
    node: std.zig.Ast.Node.Index,
    options: Options,
    declarations: *std.ArrayList(Declaration),
    ranges: *std.ArrayList(EnclosingRange),
) !void {
    var buffer = [1]std.zig.Ast.Node.Index{.root};
    const proto = tree.fullFnProto(&buffer, node) orelse return;
    const name_token = proto.name_token orelse return;
    try appendNamedDeclaration(allocator, source, tree, node, name_token, .function, options, declarations);
    const declaration = declarations.items[declarations.items.len - 1];
    try ranges.append(allocator, .{
        .start_byte = declaration.span.start_byte,
        .end_byte = declaration.span.end_byte,
        .name = declaration.name,
    });
}

fn appendTest(
    allocator: std.mem.Allocator,
    source: []const u8,
    tree: *const std.zig.Ast,
    node: std.zig.Ast.Node.Index,
    options: Options,
    declarations: *std.ArrayList(Declaration),
    ranges: *std.ArrayList(EnclosingRange),
) !void {
    const name_token = tree.nodeData(node).opt_token_and_node[0].unwrap();
    const node_span = spanForNode(source, tree, node);
    const name_span = if (name_token) |token| spanForToken(source, tree, token) else spanForToken(source, tree, tree.nodeMainToken(node));
    const name = if (name_token) |token|
        try decodedTokenAlloc(allocator, tree, token)
    else
        try std.fmt.allocPrint(allocator, "test@{d}:{d}", .{ name_span.start_line, name_span.start_column });
    defer allocator.free(name);
    try appendDeclaration(allocator, name, .test_decl, node_span, name_span, options, declarations);
    const declaration = declarations.items[declarations.items.len - 1];
    try ranges.append(allocator, .{
        .start_byte = declaration.span.start_byte,
        .end_byte = declaration.span.end_byte,
        .name = declaration.name,
    });
}

fn appendNamedDeclaration(
    allocator: std.mem.Allocator,
    source: []const u8,
    tree: *const std.zig.Ast,
    node: std.zig.Ast.Node.Index,
    name_token: std.zig.Ast.TokenIndex,
    kind: DeclarationKind,
    options: Options,
    declarations: *std.ArrayList(Declaration),
) !void {
    const name = tree.tokenSlice(name_token);
    try appendDeclaration(allocator, name, kind, spanForNode(source, tree, node), spanForToken(source, tree, name_token), options, declarations);
}

fn appendDeclaration(
    allocator: std.mem.Allocator,
    name: []const u8,
    kind: DeclarationKind,
    span: Span,
    name_span: Span,
    options: Options,
    declarations: *std.ArrayList(Declaration),
) !void {
    if (name.len == 0 or name.len > options.max_label_bytes) return error.InvalidZigDeclaration;
    try ensureFactCapacity(declarations.items.len, options.max_facts);
    const copied_name = try owned.copy(u8, allocator, name);
    errdefer allocator.free(copied_name);
    try declarations.append(allocator, .{ .kind = kind, .name = copied_name, .span = span, .name_span = name_span });
}

fn appendBinding(
    allocator: std.mem.Allocator,
    source: []const u8,
    tree: *const std.zig.Ast,
    node: std.zig.Ast.Node.Index,
    init_node: std.zig.Ast.Node.Index,
    name_token: std.zig.Ast.TokenIndex,
    ranges: []const EnclosingRange,
    options: Options,
    declarations: *const std.ArrayList(Declaration),
    imports: *const std.ArrayList(Import),
    calls: *const std.ArrayList(Call),
    bindings: *std.ArrayList(Binding),
    binding_references: *const std.ArrayList(BindingReference),
) !void {
    const name = tree.tokenSlice(name_token);
    if (name.len == 0 or name.len > options.max_label_bytes) return error.InvalidZigBinding;
    const initializer_span = spanForNode(source, tree, init_node);
    const enclosing = enclosingName(ranges, initializer_span.start_byte, initializer_span.end_byte);
    const name_copy = try owned.copy(u8, allocator, name);
    errdefer allocator.free(name_copy);
    const enclosing_copy = if (enclosing.len > 0) try owned.copy(u8, allocator, enclosing) else "";
    errdefer if (enclosing_copy.len > 0) allocator.free(enclosing_copy);
    try ensureFactCapacity(try factCount(&.{ declarations.items.len, imports.items.len, calls.items.len, bindings.items.len, binding_references.items.len }), options.max_facts);
    try bindings.append(allocator, .{
        .name = name_copy,
        .enclosing_declaration = enclosing_copy,
        .scope = if (enclosing.len > 0) .local else .file,
        .span = spanForNode(source, tree, node),
        .name_span = spanForToken(source, tree, name_token),
        .initializer_span = initializer_span,
    });
}

fn declarationKindForInit(tree: *const std.zig.Ast, init_node: std.zig.Ast.Node.Index) ?DeclarationKind {
    if (tree.nodeTag(init_node) == .error_set_decl) return .error_set;
    var buffer = [2]std.zig.Ast.Node.Index{ .root, .root };
    _ = tree.fullContainerDecl(&buffer, init_node) orelse return null;
    return switch (tree.tokenTag(tree.nodeMainToken(init_node))) {
        .keyword_struct => .structure,
        .keyword_enum => .enumeration,
        .keyword_union => .union_type,
        .keyword_opaque => .opaque_type,
        else => null,
    };
}

fn hasDeclarationAt(declarations: []const Declaration, start_byte: usize) bool {
    for (declarations) |declaration| if (declaration.name_span.start_byte == start_byte) return true;
    return false;
}

fn enclosingName(ranges: []const EnclosingRange, start_byte: usize, end_byte: usize) []const u8 {
    var best: ?EnclosingRange = null;
    for (ranges) |range| {
        if (start_byte < range.start_byte or end_byte > range.end_byte) continue;
        if (best == null or range.end_byte - range.start_byte < best.?.end_byte - best.?.start_byte) best = range;
    }
    return if (best) |range| range.name else "";
}

fn bindingForInitializer(bindings: []const Binding, start_byte: usize, end_byte: usize) ?*const Binding {
    var best: ?*const Binding = null;
    for (bindings) |*binding| {
        if (start_byte < binding.initializer_span.start_byte or end_byte > binding.initializer_span.end_byte) continue;
        if (best == null or binding.initializer_span.end_byte - binding.initializer_span.start_byte <
            best.?.initializer_span.end_byte - best.?.initializer_span.start_byte) best = binding;
    }
    return best;
}

fn findBindingExact(bindings: []const Binding, name: []const u8, enclosing: []const u8) ?*const Binding {
    for (bindings) |*binding| {
        if (std.mem.eql(u8, binding.name, name) and std.mem.eql(u8, binding.enclosing_declaration, enclosing)) return binding;
    }
    return null;
}

fn findBindingByNameScopeAndContainment(bindings: []const Binding, name: []const u8, enclosing: []const u8, span: Span) ?*const Binding {
    for (bindings) |*binding| {
        if (std.mem.eql(u8, binding.name, name) and std.mem.eql(u8, binding.enclosing_declaration, enclosing) and
            span.start_byte >= binding.initializer_span.start_byte and
            span.end_byte <= binding.initializer_span.end_byte) return binding;
    }
    return null;
}

fn decodedTokenAlloc(allocator: std.mem.Allocator, tree: *const std.zig.Ast, token: std.zig.Ast.TokenIndex) ![]u8 {
    const raw = tree.tokenSlice(token);
    if (tree.tokenTag(token) == .string_literal) return std.zig.string_literal.parseAlloc(allocator, raw) catch return error.InvalidZigStringLiteral;
    return owned.copy(u8, allocator, raw);
}

fn compactExpressionAlloc(allocator: std.mem.Allocator, expression: []const u8, max_bytes: usize) ![]u8 {
    var compact: std.ArrayList(u8) = .empty;
    errdefer compact.deinit(allocator);
    for (expression) |byte| {
        if (std.ascii.isWhitespace(byte)) continue;
        if (compact.items.len >= max_bytes) return error.ZigLabelLimitExceeded;
        try compact.append(allocator, byte);
    }
    return compact.toOwnedSlice(allocator);
}

fn expressionKind(tree: *const std.zig.Ast, node: std.zig.Ast.Node.Index, span: Span, source: []const u8) ExpressionKind {
    const first = tree.firstToken(node);
    const last = tree.lastToken(node);
    if (first == last) return switch (tree.tokenTag(first)) {
        .identifier => .identifier,
        .string_literal, .multiline_string_literal_line => .string_literal,
        .number_literal => .number_literal,
        else => .other,
    };
    if (tree.nodeTag(node) == .field_access) return .member;
    var call_buffer = [1]std.zig.Ast.Node.Index{.root};
    if (tree.fullCall(&call_buffer, node) != null) return .call;
    if (span.start_byte + 1 < span.end_byte and std.mem.startsWith(u8, source[span.start_byte..span.end_byte], ".{")) return .struct_literal;
    return .other;
}

fn findCallBySpan(calls: []const Call, span: Span) ?*const Call {
    for (calls) |*call| {
        if (call.span.start_byte == span.start_byte and call.span.end_byte == span.end_byte) return call;
    }
    return null;
}

fn compareSpans(left: Span, right: Span) std.math.Order {
    if (left.start_byte < right.start_byte) return .lt;
    if (left.start_byte > right.start_byte) return .gt;
    if (left.end_byte < right.end_byte) return .lt;
    if (left.end_byte > right.end_byte) return .gt;
    return .eq;
}

fn spanForNode(source: []const u8, tree: *const std.zig.Ast, node: std.zig.Ast.Node.Index) Span {
    return spanForTokens(source, tree, tree.firstToken(node), tree.lastToken(node));
}

fn spanForToken(source: []const u8, tree: *const std.zig.Ast, token: std.zig.Ast.TokenIndex) Span {
    return spanForTokens(source, tree, token, token);
}

fn spanForTokens(_: []const u8, tree: *const std.zig.Ast, first: std.zig.Ast.TokenIndex, last: std.zig.Ast.TokenIndex) Span {
    const start = tree.tokenStart(first);
    const end = tree.tokenStart(last) + tree.tokenSlice(last).len;
    const start_location = tree.tokenLocation(0, first);
    const end_location = tree.tokenLocation(0, last);
    return .{
        .start_byte = start,
        .end_byte = end,
        .start_line = @intCast(start_location.line + 1),
        .start_column = @intCast(start_location.column + 1),
        .end_line = @intCast(end_location.line + 1),
        .end_column = @intCast(end_location.column + tree.tokenSlice(last).len + 1),
    };
}

fn factCount(counts: []const usize) !usize {
    var total: usize = 0;
    for (counts) |count| total = std.math.add(usize, total, count) catch return error.ZigFactLimitExceeded;
    return total;
}

fn ensureFactCapacity(current: usize, max_facts: usize) !void {
    if (current >= max_facts) return error.ZigFactLimitExceeded;
}

fn lessThanDeclaration(_: void, left: Declaration, right: Declaration) bool {
    if (left.name_span.start_byte != right.name_span.start_byte) return left.name_span.start_byte < right.name_span.start_byte;
    return std.mem.lessThan(u8, left.name, right.name);
}

fn lessThanImport(_: void, left: Import, right: Import) bool {
    if (left.target_span.start_byte != right.target_span.start_byte) return left.target_span.start_byte < right.target_span.start_byte;
    return std.mem.lessThan(u8, left.target, right.target);
}

fn lessThanCall(_: void, left: Call, right: Call) bool {
    if (left.callee_span.start_byte != right.callee_span.start_byte) return left.callee_span.start_byte < right.callee_span.start_byte;
    return std.mem.lessThan(u8, left.callee, right.callee);
}

fn lessThanCallArgument(_: void, left: CallArgument, right: CallArgument) bool {
    if (left.call_span.start_byte != right.call_span.start_byte) return left.call_span.start_byte < right.call_span.start_byte;
    if (left.call_span.end_byte != right.call_span.end_byte) return left.call_span.end_byte < right.call_span.end_byte;
    return left.index < right.index;
}

fn lessThanBinding(_: void, left: Binding, right: Binding) bool {
    if (left.name_span.start_byte != right.name_span.start_byte) return left.name_span.start_byte < right.name_span.start_byte;
    return std.mem.lessThan(u8, left.name, right.name);
}

fn lessThanBindingReference(_: void, left: BindingReference, right: BindingReference) bool {
    if (left.span.start_byte != right.span.start_byte) return left.span.start_byte < right.span.start_byte;
    return std.mem.lessThan(u8, left.expression, right.expression);
}

fn deinitDeclarations(allocator: std.mem.Allocator, values: *std.ArrayList(Declaration)) void {
    for (values.items) |value| allocator.free(value.name);
    values.deinit(allocator);
}

fn deinitImports(allocator: std.mem.Allocator, values: *std.ArrayList(Import)) void {
    for (values.items) |value| {
        allocator.free(value.target);
        if (value.binding.len > 0) allocator.free(value.binding);
        if (value.enclosing_declaration.len > 0) allocator.free(value.enclosing_declaration);
    }
    values.deinit(allocator);
}

fn deinitCalls(allocator: std.mem.Allocator, values: *std.ArrayList(Call)) void {
    for (values.items) |value| {
        allocator.free(value.callee);
        if (value.enclosing_declaration.len > 0) allocator.free(value.enclosing_declaration);
    }
    values.deinit(allocator);
}

fn deinitCallArguments(allocator: std.mem.Allocator, values: *std.ArrayList(CallArgument)) void {
    for (values.items) |value| allocator.free(value.expression);
    values.deinit(allocator);
}

fn deinitBindings(allocator: std.mem.Allocator, values: *std.ArrayList(Binding)) void {
    for (values.items) |value| {
        allocator.free(value.name);
        if (value.enclosing_declaration.len > 0) allocator.free(value.enclosing_declaration);
    }
    values.deinit(allocator);
}

fn deinitBindingReferences(allocator: std.mem.Allocator, values: *std.ArrayList(BindingReference)) void {
    for (values.items) |value| {
        allocator.free(value.binding);
        if (value.enclosing_declaration.len > 0) allocator.free(value.enclosing_declaration);
        allocator.free(value.expression);
    }
    values.deinit(allocator);
}

fn fingerprint(
    path: []const u8,
    source_bytes: usize,
    declarations: []const Declaration,
    imports: []const Import,
    calls: []const Call,
    call_arguments: []const CallArgument,
    bindings: []const Binding,
    binding_references: []const BindingReference,
) [32]u8 {
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    updateBytes(&hasher, schema);
    updateBytes(&hasher, parser_version);
    updateBytes(&hasher, path);
    updateU64(&hasher, @intCast(source_bytes));
    for (declarations) |declaration| {
        updateU64(&hasher, @intCast(@intFromEnum(declaration.kind)));
        updateBytes(&hasher, declaration.name);
        updateSpan(&hasher, declaration.span);
        updateSpan(&hasher, declaration.name_span);
    }
    for (imports) |item| {
        updateBytes(&hasher, item.target);
        updateBytes(&hasher, item.binding);
        updateBytes(&hasher, item.enclosing_declaration);
        updateSpan(&hasher, item.span);
        updateSpan(&hasher, item.target_span);
    }
    for (calls) |call| {
        updateBytes(&hasher, call.callee);
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
    for (bindings) |binding| {
        updateBytes(&hasher, binding.name);
        updateBytes(&hasher, binding.enclosing_declaration);
        updateU64(&hasher, @intCast(@intFromEnum(binding.scope)));
        updateSpan(&hasher, binding.span);
        updateSpan(&hasher, binding.name_span);
        updateSpan(&hasher, binding.initializer_span);
    }
    for (binding_references) |reference| {
        updateBytes(&hasher, reference.binding);
        updateBytes(&hasher, reference.enclosing_declaration);
        updateBytes(&hasher, reference.expression);
        updateSpan(&hasher, reference.span);
    }
    var digest: [32]u8 = @splat(0);
    hasher.final(&digest);
    return digest;
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
