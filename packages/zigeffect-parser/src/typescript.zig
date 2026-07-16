const std = @import("std");
const owned = @import("memory.zig");
const Parser = @import("zigeffect_std").Parser;

const c = @cImport({
    @cInclude("tree_sitter/api.h");
});

extern fn tree_sitter_typescript() ?*const c.TSLanguage;
extern fn tree_sitter_tsx() ?*const c.TSLanguage;

pub const schema = Parser.schema;
pub const schema_version = Parser.schema_version;
pub const parser_id = "zigeffect-parser.tree-sitter-typescript";
pub const parser_version = "tree-sitter-0.25.10-typescript-0.23.2-v3";
pub const LanguageMode = Parser.LanguageMode;
pub const DeclarationKind = Parser.DeclarationKind;
pub const ImportKind = Parser.ImportKind;
pub const ImportBindingKind = Parser.ImportBindingKind;
pub const ExportKind = Parser.ExportKind;
pub const TypeBindingKind = Parser.TypeBindingKind;
pub const CallKind = Parser.CallKind;
pub const Span = Parser.Span;
pub const Declaration = Parser.Declaration;
pub const Import = Parser.Import;
pub const ImportBinding = Parser.ImportBinding;
pub const Export = Parser.Export;
pub const TypeBinding = Parser.TypeBinding;
pub const Call = Parser.Call;
pub const Summary = Parser.Summary;
pub const Options = Parser.Options;
pub const Result = Parser.Result;

pub fn parse(
    allocator: std.mem.Allocator,
    path: []const u8,
    source: []const u8,
    language_mode: LanguageMode,
    options: Options,
) !Result {
    try validateOptions(path, source, options);
    const parser = c.ts_parser_new() orelse return error.TypeScriptParserAllocationFailed;
    defer c.ts_parser_delete(parser);
    const language = switch (language_mode) {
        .typescript, .javascript => tree_sitter_typescript(),
        .tsx, .jsx => tree_sitter_tsx(),
        else => return error.UnsupportedDocumentLanguage,
    } orelse return error.TypeScriptLanguageUnavailable;
    if (!c.ts_parser_set_language(parser, language)) return error.IncompatibleTypeScriptGrammar;
    const tree = c.ts_parser_parse_string(parser, null, source.ptr, @intCast(source.len)) orelse return error.TypeScriptParseFailed;
    defer c.ts_tree_delete(tree);
    const root = c.ts_tree_root_node(tree);
    if (c.ts_node_is_null(root) or c.ts_node_has_error(root)) return error.InvalidTypeScriptSource;

    var extractor = Extractor{
        .allocator = allocator,
        .source = source,
        .options = options,
    };
    defer extractor.deinit();
    const root_span = spanForNode(root);
    try extractor.walk(root, 0, .{ .span = root_span, .container_span = root_span }, false, false);
    std.mem.sort(Declaration, extractor.declarations.items, {}, lessThanDeclaration);
    std.mem.sort(Import, extractor.imports.items, {}, lessThanImport);
    std.mem.sort(ImportBinding, extractor.import_bindings.items, {}, lessThanImportBinding);
    std.mem.sort(Export, extractor.exports.items, {}, lessThanExport);
    std.mem.sort(TypeBinding, extractor.type_bindings.items, {}, lessThanTypeBinding);
    std.mem.sort(Call, extractor.calls.items, {}, lessThanCall);

    const declaration_slice = try extractor.declarations.toOwnedSlice(allocator);
    errdefer deinitDeclarations(allocator, declaration_slice);
    const import_slice = try extractor.imports.toOwnedSlice(allocator);
    errdefer deinitImports(allocator, import_slice);
    const binding_slice = try extractor.import_bindings.toOwnedSlice(allocator);
    errdefer deinitImportBindings(allocator, binding_slice);
    const export_slice = try extractor.exports.toOwnedSlice(allocator);
    errdefer deinitExports(allocator, export_slice);
    const type_binding_slice = try extractor.type_bindings.toOwnedSlice(allocator);
    errdefer deinitTypeBindings(allocator, type_binding_slice);
    const call_slice = try extractor.calls.toOwnedSlice(allocator);
    errdefer deinitCalls(allocator, call_slice);
    const copied_path = try owned.copy(u8, allocator, path);
    errdefer allocator.free(copied_path);
    const summary = Summary{
        .declarations = declaration_slice.len,
        .imports = import_slice.len,
        .import_bindings = binding_slice.len,
        .exports = export_slice.len,
        .type_bindings = type_binding_slice.len,
        .calls = call_slice.len,
        .traversed_nodes = extractor.traversed_nodes,
    };
    var result = Result{
        .allocator = allocator,
        .path = copied_path,
        .language = language_mode,
        .source_bytes = source.len,
        .parser_id = parser_id,
        .parser_version = parser_version,
        .declarations = declaration_slice,
        .imports = import_slice,
        .import_bindings = binding_slice,
        .exports = export_slice,
        .type_bindings = type_binding_slice,
        .calls = call_slice,
        .summary = summary,
        .fingerprint = Parser.structuralFingerprint(parser_id, parser_version, path, language_mode, source.len, declaration_slice, import_slice, binding_slice, export_slice, type_binding_slice, call_slice, summary),
    };
    errdefer result.deinit();
    try validate(&result);
    return result;
}

pub fn validate(result: *const Result) !void {
    try result.validate();
}

const Scope = struct {
    container: []const u8 = "",
    declaration: []const u8 = "",
    span: ?Span = null,
    container_span: ?Span = null,
};

const Extractor = struct {
    allocator: std.mem.Allocator,
    source: []const u8,
    options: Options,
    declarations: std.ArrayList(Declaration) = .empty,
    imports: std.ArrayList(Import) = .empty,
    import_bindings: std.ArrayList(ImportBinding) = .empty,
    exports: std.ArrayList(Export) = .empty,
    type_bindings: std.ArrayList(TypeBinding) = .empty,
    calls: std.ArrayList(Call) = .empty,
    traversed_nodes: usize = 0,

    fn deinit(self: *Extractor) void {
        deinitDeclarationList(self.allocator, &self.declarations);
        deinitImportList(self.allocator, &self.imports);
        deinitImportBindingList(self.allocator, &self.import_bindings);
        deinitExportList(self.allocator, &self.exports);
        deinitTypeBindingList(self.allocator, &self.type_bindings);
        deinitCallList(self.allocator, &self.calls);
    }

    fn walk(self: *Extractor, node: c.TSNode, depth: usize, scope: Scope, exported: bool, default_export: bool) !void {
        if (depth > self.options.max_depth) return error.TypeScriptDepthLimitExceeded;
        if (self.traversed_nodes >= self.options.max_nodes) return error.TypeScriptNodeLimitExceeded;
        self.traversed_nodes += 1;

        const node_type = nodeType(node);
        var child_scope = scope;
        var child_exported = false;
        var child_default_export = false;
        var allocated_declaration_name: ?[]u8 = null;
        defer if (allocated_declaration_name) |name| self.allocator.free(name);

        if (std.mem.eql(u8, node_type, "export_statement")) {
            try self.extractExport(node);
            child_exported = true;
            child_default_export = hasDirectChildType(node, "default");
        } else if (exported and (std.mem.eql(u8, node_type, "lexical_declaration") or
            std.mem.eql(u8, node_type, "variable_declaration")))
        {
            child_exported = true;
        }

        if (std.mem.eql(u8, node_type, "import_statement")) {
            try self.extractImport(node);
        } else if (declarationKind(node_type)) |kind| {
            const name_node = fieldNode(node, "name");
            if (!c.ts_node_is_null(name_node)) {
                const name = try self.nameAlloc(name_node);
                allocated_declaration_name = name;
                try self.appendDeclaration(node, name_node, name, kind, scope, exported);
                if (exported) try self.appendDeclarationExport(node, name_node, name, default_export);
                child_exported = false;
                child_scope = switch (kind) {
                    .class => .{ .container = name, .span = spanForNode(node), .container_span = spanForNode(node) },
                    .function => .{ .container = scope.container, .declaration = name, .span = spanForNode(node), .container_span = scope.container_span },
                    .method => .{ .container = scope.container, .declaration = name, .span = spanForNode(node), .container_span = scope.container_span },
                    else => scope,
                };
            }
        } else if (std.mem.eql(u8, node_type, "variable_declarator")) {
            const name_node = fieldNode(node, "name");
            const value_node = fieldNode(node, "value");
            if (!c.ts_node_is_null(name_node) and std.mem.eql(u8, nodeType(name_node), "identifier")) {
                const name = nodeText(self.source, name_node) orelse return error.InvalidTypeScriptSourceRange;
                const kind: DeclarationKind = if (!c.ts_node_is_null(value_node) and isFunctionValue(nodeType(value_node))) .function_value else .variable;
                try self.appendDeclaration(node, name_node, name, kind, scope, exported);
                if (exported) try self.appendDeclarationExport(node, name_node, name, default_export);
                const require_source = self.staticStringModuleArgument(value_node, "require");
                if (!c.ts_node_is_null(require_source)) {
                    const target = try self.stringValueAlloc(require_source);
                    defer self.allocator.free(target);
                    try self.appendImportBinding(target, "*", name, .commonjs_require, false, name_node);
                }
                try self.extractVariableTypeBinding(node, name_node, value_node, scope);
                child_exported = false;
                if (kind == .function_value) child_scope = .{
                    .container = scope.container,
                    .declaration = name,
                    .span = if (!c.ts_node_is_null(value_node)) spanForNode(value_node) else spanForNode(node),
                    .container_span = scope.container_span,
                };
            }
        } else if (std.mem.eql(u8, node_type, "required_parameter") or std.mem.eql(u8, node_type, "optional_parameter")) {
            try self.extractParameterTypeBinding(node, scope);
        } else if (std.mem.eql(u8, node_type, "public_field_definition")) {
            try self.extractFieldTypeBinding(node, scope);
        } else if (std.mem.eql(u8, node_type, "assignment_expression")) {
            try self.extractCommonJsExport(node);
        } else if (std.mem.eql(u8, node_type, "call_expression")) {
            try self.extractCall(node, scope);
        } else if (std.mem.eql(u8, node_type, "new_expression")) {
            try self.extractConstructorCall(node, scope);
        }

        const child_count = c.ts_node_named_child_count(node);
        var index: u32 = 0;
        while (index < child_count) : (index += 1) {
            const child = c.ts_node_named_child(node, index);
            if (!c.ts_node_is_null(child)) try self.walk(child, depth + 1, child_scope, child_exported, child_default_export);
        }
    }

    fn extractExport(self: *Extractor, node: c.TSNode) !void {
        const source_node = fieldNode(node, "source");
        const has_source = !c.ts_node_is_null(source_node);
        var target: []const u8 = "";
        if (has_source) {
            target = try self.stringValueAlloc(source_node);
            try self.appendImport(node, source_node, target, .static, hasDirectChildType(node, "type"));
        }
        defer if (target.len > 0) self.allocator.free(target);

        const clause = directNamedChild(node, "export_clause");
        if (!c.ts_node_is_null(clause)) {
            const child_count = c.ts_node_named_child_count(clause);
            var index: u32 = 0;
            while (index < child_count) : (index += 1) {
                const specifier = c.ts_node_named_child(clause, index);
                if (!std.mem.eql(u8, nodeType(specifier), "export_specifier")) continue;
                const name_node = fieldNode(specifier, "name");
                const alias_node = fieldNode(specifier, "alias");
                if (c.ts_node_is_null(name_node)) return error.InvalidTypeScriptExport;
                const imported = try self.nameAlloc(name_node);
                defer self.allocator.free(imported);
                const exported_node = if (c.ts_node_is_null(alias_node)) name_node else alias_node;
                const exported_name = if (c.ts_node_is_null(alias_node)) imported else try self.nameAlloc(alias_node);
                defer if (!c.ts_node_is_null(alias_node)) self.allocator.free(exported_name);
                try self.appendExport(
                    node,
                    if (has_source) source_node else nullNode(node),
                    exported_node,
                    target,
                    imported,
                    exported_name,
                    if (has_source) .re_export_named else .local_named,
                    hasDirectChildType(node, "type") or hasDirectChildType(specifier, "type"),
                );
            }
            return;
        }

        const namespace = directNamedChild(node, "namespace_export");
        if (!c.ts_node_is_null(namespace)) {
            const name_node = firstDirectNamedChild(namespace, "identifier");
            if (!has_source or c.ts_node_is_null(name_node)) return error.InvalidTypeScriptExport;
            const exported_name = try self.nameAlloc(name_node);
            defer self.allocator.free(exported_name);
            try self.appendExport(node, source_node, name_node, target, "*", exported_name, .re_export_namespace, false);
            return;
        }

        const value = fieldNode(node, "value");
        if (!c.ts_node_is_null(value) and hasDirectChildType(node, "default")) {
            const value_type = nodeType(value);
            if (std.mem.eql(u8, value_type, "identifier") or std.mem.eql(u8, value_type, "type_identifier")) {
                const imported = try self.nameAlloc(value);
                defer self.allocator.free(imported);
                try self.appendExport(node, nullNode(node), value, "", imported, "default", .local_default, false);
            } else {
                try self.appendExport(node, nullNode(node), value, "", "*", "default", .default_expression, false);
            }
            return;
        }

        const declaration = fieldNode(node, "declaration");
        if (!c.ts_node_is_null(declaration)) return;
        if (has_source) try self.appendExport(node, source_node, source_node, target, "*", "*", .re_export_star, hasDirectChildType(node, "type"));
    }

    fn appendDeclarationExport(self: *Extractor, node: c.TSNode, name_node: c.TSNode, name: []const u8, default_export: bool) !void {
        try self.appendExport(
            node,
            nullNode(node),
            name_node,
            "",
            name,
            if (default_export) "default" else name,
            if (default_export) .local_default else .local_named,
            false,
        );
    }

    fn extractParameterTypeBinding(self: *Extractor, node: c.TSNode, scope: Scope) !void {
        const name_node = fieldNode(node, "pattern");
        const annotation = fieldNode(node, "type");
        if (c.ts_node_is_null(name_node) or !std.mem.eql(u8, nodeType(name_node), "identifier") or c.ts_node_is_null(annotation)) return;
        const type_node = bareTypeNode(annotation) orelse return;
        const name = nodeText(self.source, name_node) orelse return error.InvalidTypeScriptSourceRange;
        const type_name = nodeText(self.source, type_node) orelse return error.InvalidTypeScriptSourceRange;
        const is_property = std.mem.eql(u8, scope.declaration, "constructor") and
            (hasDirectChildType(node, "accessibility_modifier") or hasDirectChildType(node, "readonly"));
        if (is_property) {
            const binding = try std.fmt.allocPrint(self.allocator, "this.{s}", .{name});
            defer self.allocator.free(binding);
            try self.appendTypeBinding(
                node,
                name_node,
                type_node,
                binding,
                type_name,
                scope.container,
                .constructor_parameter_property,
                scope.container_span orelse scope.span orelse spanForNode(node),
            );
            return;
        }
        const enclosing = try scopeNameAlloc(self.allocator, scope, self.options.max_label_bytes);
        defer if (enclosing.len > 0) self.allocator.free(enclosing);
        try self.appendTypeBinding(node, name_node, type_node, name, type_name, enclosing, .parameter, scope.span orelse spanForNode(node));
    }

    fn extractVariableTypeBinding(self: *Extractor, node: c.TSNode, name_node: c.TSNode, value_node: c.TSNode, scope: Scope) !void {
        const name = nodeText(self.source, name_node) orelse return error.InvalidTypeScriptSourceRange;
        const enclosing = try scopeNameAlloc(self.allocator, scope, self.options.max_label_bytes);
        defer if (enclosing.len > 0) self.allocator.free(enclosing);
        const annotation = fieldNode(node, "type");
        if (!c.ts_node_is_null(annotation)) if (bareTypeNode(annotation)) |type_node| {
            const type_name = nodeText(self.source, type_node) orelse return error.InvalidTypeScriptSourceRange;
            try self.appendTypeBinding(node, name_node, type_node, name, type_name, enclosing, .local_annotation, scope.span orelse spanForNode(node));
            return;
        };
        if (c.ts_node_is_null(value_node) or !std.mem.eql(u8, nodeType(value_node), "new_expression")) return;
        const constructor = fieldNode(value_node, "constructor");
        if (c.ts_node_is_null(constructor) or !isBareTypeNode(constructor)) return;
        const type_name = nodeText(self.source, constructor) orelse return error.InvalidTypeScriptSourceRange;
        try self.appendTypeBinding(node, name_node, constructor, name, type_name, enclosing, .constructor_instance, scope.span orelse spanForNode(node));
    }

    fn extractFieldTypeBinding(self: *Extractor, node: c.TSNode, scope: Scope) !void {
        if (scope.container.len == 0) return;
        const name_node = fieldNode(node, "name");
        const annotation = fieldNode(node, "type");
        if (c.ts_node_is_null(name_node) or !std.mem.eql(u8, nodeType(name_node), "property_identifier") or c.ts_node_is_null(annotation)) return;
        const type_node = bareTypeNode(annotation) orelse return;
        const name = nodeText(self.source, name_node) orelse return error.InvalidTypeScriptSourceRange;
        const type_name = nodeText(self.source, type_node) orelse return error.InvalidTypeScriptSourceRange;
        const binding = try std.fmt.allocPrint(self.allocator, "this.{s}", .{name});
        defer self.allocator.free(binding);
        try self.appendTypeBinding(node, name_node, type_node, binding, type_name, scope.container, .field, scope.container_span orelse scope.span orelse spanForNode(node));
    }

    fn extractCommonJsExport(self: *Extractor, node: c.TSNode) !void {
        const left = fieldNode(node, "left");
        const right = fieldNode(node, "right");
        if (c.ts_node_is_null(left) or c.ts_node_is_null(right) or
            !std.mem.eql(u8, nodeType(left), "member_expression") or !isBareTypeNode(right)) return;
        const imported = nodeText(self.source, right) orelse return error.InvalidTypeScriptSourceRange;
        const target = try self.compactNodeAlloc(left);
        defer self.allocator.free(target);
        if (std.mem.eql(u8, target, "module.exports")) {
            try self.appendExport(node, nullNode(node), left, "", imported, "default", .commonjs_default, false);
            return;
        }
        const prefix = if (std.mem.startsWith(u8, target, "exports."))
            "exports."
        else if (std.mem.startsWith(u8, target, "module.exports."))
            "module.exports."
        else
            return;
        const exported_name = target[prefix.len..];
        if (!bareIdentifier(exported_name)) return;
        const property = fieldNode(left, "property");
        if (c.ts_node_is_null(property)) return;
        try self.appendExport(node, nullNode(node), property, "", imported, exported_name, .commonjs_named, false);
    }

    fn extractImport(self: *Extractor, node: c.TSNode) !void {
        const require_clause = directNamedChild(node, "import_require_clause");
        var source_node = fieldNode(node, "source");
        if (c.ts_node_is_null(source_node) and !c.ts_node_is_null(require_clause)) {
            source_node = fieldNode(require_clause, "source");
        }
        if (c.ts_node_is_null(source_node)) return error.InvalidTypeScriptImport;
        const target = try self.stringValueAlloc(source_node);
        defer self.allocator.free(target);
        const clause = directNamedChild(node, "import_clause");
        const kind: ImportKind = if (!c.ts_node_is_null(require_clause))
            .import_require
        else if (!c.ts_node_is_null(clause))
            .static
        else
            .side_effect;
        const type_only = hasDirectChildType(node, "type");
        try self.appendImport(node, source_node, target, kind, type_only);

        if (!c.ts_node_is_null(require_clause)) {
            const local_node = firstDirectNamedChild(require_clause, "identifier");
            if (c.ts_node_is_null(local_node)) return error.InvalidTypeScriptImportBinding;
            const local = nodeText(self.source, local_node) orelse return error.InvalidTypeScriptSourceRange;
            try self.appendImportBinding(target, local, local, .import_require, false, local_node);
            return;
        }
        if (c.ts_node_is_null(clause)) return;

        const child_count = c.ts_node_named_child_count(clause);
        var index: u32 = 0;
        while (index < child_count) : (index += 1) {
            const child = c.ts_node_named_child(clause, index);
            const child_type = nodeType(child);
            if (std.mem.eql(u8, child_type, "identifier")) {
                const local = nodeText(self.source, child) orelse return error.InvalidTypeScriptSourceRange;
                try self.appendImportBinding(target, "default", local, .default, type_only, child);
            } else if (std.mem.eql(u8, child_type, "namespace_import")) {
                const local_node = firstDirectNamedChild(child, "identifier");
                if (c.ts_node_is_null(local_node)) return error.InvalidTypeScriptImportBinding;
                const local = nodeText(self.source, local_node) orelse return error.InvalidTypeScriptSourceRange;
                try self.appendImportBinding(target, "*", local, .namespace, type_only, child);
            } else if (std.mem.eql(u8, child_type, "named_imports")) {
                try self.extractNamedImports(target, child, type_only);
            }
        }
    }

    fn extractNamedImports(self: *Extractor, target: []const u8, named_imports: c.TSNode, statement_type_only: bool) !void {
        const child_count = c.ts_node_named_child_count(named_imports);
        var index: u32 = 0;
        while (index < child_count) : (index += 1) {
            const specifier = c.ts_node_named_child(named_imports, index);
            if (!std.mem.eql(u8, nodeType(specifier), "import_specifier")) continue;
            const imported_node = fieldNode(specifier, "name");
            const alias_node = fieldNode(specifier, "alias");
            if (c.ts_node_is_null(imported_node)) return error.InvalidTypeScriptImportBinding;
            const imported = try self.nameAlloc(imported_node);
            defer self.allocator.free(imported);
            const local = if (c.ts_node_is_null(alias_node)) imported else try self.nameAlloc(alias_node);
            defer if (!c.ts_node_is_null(alias_node)) self.allocator.free(local);
            try self.appendImportBinding(
                target,
                imported,
                local,
                .named,
                statement_type_only or hasDirectChildType(specifier, "type"),
                specifier,
            );
        }
    }

    fn extractCall(self: *Extractor, node: c.TSNode, scope: Scope) !void {
        const function_node = fieldNode(node, "function");
        if (c.ts_node_is_null(function_node)) return error.InvalidTypeScriptCall;
        const function_type = nodeType(function_node);
        if (std.mem.eql(u8, function_type, "import")) {
            const source_node = self.firstStaticStringArgument(node);
            if (!c.ts_node_is_null(source_node)) {
                const target = try self.stringValueAlloc(source_node);
                defer self.allocator.free(target);
                try self.appendImport(node, source_node, target, .dynamic, false);
            }
            try self.appendCall(node, function_node, .dynamic_import, "import", "", "", scope);
            return;
        }
        if (std.mem.eql(u8, function_type, "identifier")) {
            const function_name = nodeText(self.source, function_node) orelse return error.InvalidTypeScriptSourceRange;
            if (std.mem.eql(u8, function_name, "require")) {
                const source_node = self.firstStaticStringArgument(node);
                if (!c.ts_node_is_null(source_node)) {
                    const target = try self.stringValueAlloc(source_node);
                    defer self.allocator.free(target);
                    try self.appendImport(node, source_node, target, .commonjs_require, false);
                }
            }
        }
        const callee = try self.compactNodeAlloc(function_node);
        defer self.allocator.free(callee);
        if (std.mem.eql(u8, function_type, "member_expression")) {
            const object_node = fieldNode(function_node, "object");
            const property_node = fieldNode(function_node, "property");
            if (c.ts_node_is_null(object_node) or c.ts_node_is_null(property_node)) return error.InvalidTypeScriptCall;
            const receiver = try self.compactNodeAlloc(object_node);
            defer self.allocator.free(receiver);
            const member = try self.nameAlloc(property_node);
            defer self.allocator.free(member);
            try self.appendCall(node, function_node, .member, callee, receiver, member, scope);
        } else {
            try self.appendCall(node, function_node, .direct, callee, "", "", scope);
        }
    }

    fn extractConstructorCall(self: *Extractor, node: c.TSNode, scope: Scope) !void {
        const constructor = fieldNode(node, "constructor");
        if (c.ts_node_is_null(constructor)) return error.InvalidTypeScriptCall;
        const callee = try self.compactNodeAlloc(constructor);
        defer self.allocator.free(callee);
        try self.appendCall(node, constructor, .constructor, callee, "", "", scope);
    }

    fn firstStaticStringArgument(self: *const Extractor, call: c.TSNode) c.TSNode {
        _ = self;
        const arguments = fieldNode(call, "arguments");
        if (c.ts_node_is_null(arguments)) return nullNode(arguments);
        return firstDirectNamedChild(arguments, "string");
    }

    fn staticStringModuleArgument(self: *const Extractor, node: c.TSNode, function_name: []const u8) c.TSNode {
        if (c.ts_node_is_null(node) or !std.mem.eql(u8, nodeType(node), "call_expression")) return nullNode(node);
        const function_node = fieldNode(node, "function");
        if (c.ts_node_is_null(function_node) or !std.mem.eql(u8, nodeType(function_node), "identifier")) return nullNode(node);
        const actual = nodeText(self.source, function_node) orelse return nullNode(node);
        if (!std.mem.eql(u8, actual, function_name)) return nullNode(node);
        return self.firstStaticStringArgument(node);
    }

    fn appendDeclaration(
        self: *Extractor,
        node: c.TSNode,
        name_node: c.TSNode,
        name: []const u8,
        kind: DeclarationKind,
        scope: Scope,
        exported: bool,
    ) !void {
        try self.validateLabel(name, error.InvalidTypeScriptDeclaration);
        try self.ensureFactCapacity();
        const copied_name = try owned.copy(u8, self.allocator, name);
        errdefer self.allocator.free(copied_name);
        const enclosing = try scopeNameAlloc(self.allocator, scope, self.options.max_label_bytes);
        errdefer if (enclosing.len > 0) self.allocator.free(enclosing);
        try self.declarations.append(self.allocator, .{
            .kind = kind,
            .name = copied_name,
            .enclosing_declaration = enclosing,
            .exported = exported,
            .span = spanForNode(node),
            .name_span = spanForNode(name_node),
        });
    }

    fn appendImport(self: *Extractor, node: c.TSNode, target_node: c.TSNode, target: []const u8, kind: ImportKind, type_only: bool) !void {
        try self.validateLabel(target, error.InvalidTypeScriptImport);
        try self.ensureFactCapacity();
        const copied_target = try owned.copy(u8, self.allocator, target);
        errdefer self.allocator.free(copied_target);
        try self.imports.append(self.allocator, .{
            .target = copied_target,
            .kind = kind,
            .type_only = type_only,
            .span = spanForNode(node),
            .target_span = spanForNode(target_node),
        });
    }

    fn appendImportBinding(
        self: *Extractor,
        target: []const u8,
        imported: []const u8,
        local: []const u8,
        kind: ImportBindingKind,
        type_only: bool,
        node: c.TSNode,
    ) !void {
        try self.validateLabel(target, error.InvalidTypeScriptImportBinding);
        try self.validateLabel(imported, error.InvalidTypeScriptImportBinding);
        try self.validateLabel(local, error.InvalidTypeScriptImportBinding);
        try self.ensureFactCapacity();
        const copied_target = try owned.copy(u8, self.allocator, target);
        errdefer self.allocator.free(copied_target);
        const copied_imported = try owned.copy(u8, self.allocator, imported);
        errdefer self.allocator.free(copied_imported);
        const copied_local = try owned.copy(u8, self.allocator, local);
        errdefer self.allocator.free(copied_local);
        try self.import_bindings.append(self.allocator, .{
            .target = copied_target,
            .imported = copied_imported,
            .local = copied_local,
            .kind = kind,
            .type_only = type_only,
            .span = spanForNode(node),
        });
    }

    fn appendExport(
        self: *Extractor,
        node: c.TSNode,
        target_node: c.TSNode,
        exported_node: c.TSNode,
        target: []const u8,
        imported: []const u8,
        exported_name: []const u8,
        kind: ExportKind,
        type_only: bool,
    ) !void {
        if (target.len > 0) try self.validateLabel(target, error.InvalidTypeScriptExport);
        try self.validateLabel(imported, error.InvalidTypeScriptExport);
        try self.validateLabel(exported_name, error.InvalidTypeScriptExport);
        try self.ensureFactCapacity();
        const copied_target = if (target.len > 0) try owned.copy(u8, self.allocator, target) else "";
        errdefer if (copied_target.len > 0) self.allocator.free(copied_target);
        const copied_imported = try owned.copy(u8, self.allocator, imported);
        errdefer self.allocator.free(copied_imported);
        const copied_exported = try owned.copy(u8, self.allocator, exported_name);
        errdefer self.allocator.free(copied_exported);
        try self.exports.append(self.allocator, .{
            .target = copied_target,
            .imported = copied_imported,
            .exported = copied_exported,
            .kind = kind,
            .type_only = type_only,
            .span = spanForNode(node),
            .target_span = if (target.len > 0) spanForNode(target_node) else null,
            .exported_span = spanForNode(exported_node),
        });
    }

    fn appendTypeBinding(
        self: *Extractor,
        node: c.TSNode,
        name_node: c.TSNode,
        type_node: c.TSNode,
        binding: []const u8,
        type_name: []const u8,
        enclosing_declaration: []const u8,
        kind: TypeBindingKind,
        scope_span: Span,
    ) !void {
        try self.validateLabel(binding, error.InvalidTypeScriptTypeBinding);
        try self.validateLabel(type_name, error.InvalidTypeScriptTypeBinding);
        if (enclosing_declaration.len > 0) try self.validateLabel(enclosing_declaration, error.InvalidTypeScriptTypeBinding);
        try self.ensureFactCapacity();
        const copied_binding = try owned.copy(u8, self.allocator, binding);
        errdefer self.allocator.free(copied_binding);
        const copied_type = try owned.copy(u8, self.allocator, type_name);
        errdefer self.allocator.free(copied_type);
        const copied_enclosing = if (enclosing_declaration.len > 0) try owned.copy(u8, self.allocator, enclosing_declaration) else "";
        errdefer if (copied_enclosing.len > 0) self.allocator.free(copied_enclosing);
        try self.type_bindings.append(self.allocator, .{
            .binding = copied_binding,
            .type_name = copied_type,
            .enclosing_declaration = copied_enclosing,
            .kind = kind,
            .span = spanForNode(node),
            .name_span = spanForNode(name_node),
            .type_span = spanForNode(type_node),
            .scope_span = scope_span,
        });
    }

    fn appendCall(
        self: *Extractor,
        node: c.TSNode,
        callee_node: c.TSNode,
        kind: CallKind,
        callee: []const u8,
        receiver: []const u8,
        member: []const u8,
        scope: Scope,
    ) !void {
        try self.validateLabel(callee, error.InvalidTypeScriptCall);
        if (receiver.len > 0) try self.validateLabel(receiver, error.InvalidTypeScriptCall);
        if (member.len > 0) try self.validateLabel(member, error.InvalidTypeScriptCall);
        try self.ensureFactCapacity();
        const copied_callee = try owned.copy(u8, self.allocator, callee);
        errdefer self.allocator.free(copied_callee);
        const copied_receiver = if (receiver.len > 0) try owned.copy(u8, self.allocator, receiver) else "";
        errdefer if (copied_receiver.len > 0) self.allocator.free(copied_receiver);
        const copied_member = if (member.len > 0) try owned.copy(u8, self.allocator, member) else "";
        errdefer if (copied_member.len > 0) self.allocator.free(copied_member);
        const enclosing = try scopeNameAlloc(self.allocator, scope, self.options.max_label_bytes);
        errdefer if (enclosing.len > 0) self.allocator.free(enclosing);
        try self.calls.append(self.allocator, .{
            .kind = kind,
            .callee = copied_callee,
            .receiver = copied_receiver,
            .member = copied_member,
            .enclosing_declaration = enclosing,
            .span = spanForNode(node),
            .callee_span = spanForNode(callee_node),
        });
    }

    fn compactNodeAlloc(self: *Extractor, node: c.TSNode) ![]u8 {
        const text_value = nodeText(self.source, node) orelse return error.InvalidTypeScriptSourceRange;
        var compact: std.ArrayList(u8) = .empty;
        errdefer compact.deinit(self.allocator);
        for (text_value) |byte| {
            if (std.ascii.isWhitespace(byte)) continue;
            if (compact.items.len >= self.options.max_label_bytes) return error.TypeScriptLabelLimitExceeded;
            try compact.append(self.allocator, byte);
        }
        if (compact.items.len == 0) return error.InvalidTypeScriptLabel;
        return compact.toOwnedSlice(self.allocator);
    }

    fn nameAlloc(self: *Extractor, node: c.TSNode) ![]u8 {
        if (std.mem.eql(u8, nodeType(node), "string")) return self.stringValueAlloc(node);
        return self.compactNodeAlloc(node);
    }

    fn stringValueAlloc(self: *Extractor, node: c.TSNode) ![]u8 {
        const raw = nodeText(self.source, node) orelse return error.InvalidTypeScriptSourceRange;
        if (raw.len < 2) return error.InvalidTypeScriptStringLiteral;
        const quote = raw[0];
        if ((quote != '\'' and quote != '"') or raw[raw.len - 1] != quote) return error.InvalidTypeScriptStringLiteral;
        var decoded: std.ArrayList(u8) = .empty;
        errdefer decoded.deinit(self.allocator);
        var index: usize = 1;
        while (index + 1 < raw.len) : (index += 1) {
            var byte = raw[index];
            if (byte == '\\') {
                index += 1;
                if (index + 1 > raw.len) return error.InvalidTypeScriptStringLiteral;
                byte = switch (raw[index]) {
                    'n' => '\n',
                    'r' => '\r',
                    't' => '\t',
                    'b' => 0x08,
                    'f' => 0x0c,
                    'v' => 0x0b,
                    '0' => 0,
                    '\\' => '\\',
                    '\'' => '\'',
                    '"' => '"',
                    else => return error.UnsupportedTypeScriptStringEscape,
                };
            }
            if (decoded.items.len >= self.options.max_label_bytes) return error.TypeScriptLabelLimitExceeded;
            try decoded.append(self.allocator, byte);
        }
        if (decoded.items.len == 0) return error.InvalidTypeScriptStringLiteral;
        return decoded.toOwnedSlice(self.allocator);
    }

    fn validateLabel(self: *const Extractor, label: []const u8, comptime invalid_error: anyerror) !void {
        if (label.len == 0) return invalid_error;
        if (label.len > self.options.max_label_bytes) return error.TypeScriptLabelLimitExceeded;
    }

    fn ensureFactCapacity(self: *const Extractor) !void {
        const declaration_and_import = std.math.add(usize, self.declarations.items.len, self.imports.items.len) catch return error.TypeScriptFactLimitExceeded;
        const with_bindings = std.math.add(usize, declaration_and_import, self.import_bindings.items.len) catch return error.TypeScriptFactLimitExceeded;
        const with_exports = std.math.add(usize, with_bindings, self.exports.items.len) catch return error.TypeScriptFactLimitExceeded;
        const with_types = std.math.add(usize, with_exports, self.type_bindings.items.len) catch return error.TypeScriptFactLimitExceeded;
        const total = std.math.add(usize, with_types, self.calls.items.len) catch return error.TypeScriptFactLimitExceeded;
        if (total >= self.options.max_facts) return error.TypeScriptFactLimitExceeded;
    }
};

fn validateOptions(path: []const u8, source: []const u8, options: Options) !void {
    if (!validPath(path)) return error.InvalidTypeScriptSourcePath;
    if (options.max_source_bytes == 0 or options.max_nodes == 0 or options.max_depth == 0 or options.max_depth > 1024 or
        options.max_facts == 0 or options.max_label_bytes == 0 or options.max_label_bytes > 64 * 1024)
    {
        return error.InvalidTypeScriptParserOptions;
    }
    if (source.len == 0) return error.InvalidTypeScriptSource;
    if (source.len > options.max_source_bytes or source.len > std.math.maxInt(u32)) return error.TypeScriptSourceLimitExceeded;
}

fn validPath(path: []const u8) bool {
    if (path.len == 0 or std.fs.path.isAbsolute(path) or std.mem.indexOfScalar(u8, path, '\\') != null) return false;
    var components = std.mem.splitScalar(u8, path, '/');
    while (components.next()) |component| {
        if (component.len == 0 or std.mem.eql(u8, component, ".") or std.mem.eql(u8, component, "..")) return false;
    }
    return true;
}

fn declarationKind(node_type: []const u8) ?DeclarationKind {
    if (std.mem.eql(u8, node_type, "function_declaration")) return .function;
    if (std.mem.eql(u8, node_type, "class_declaration")) return .class;
    if (std.mem.eql(u8, node_type, "interface_declaration")) return .interface;
    if (std.mem.eql(u8, node_type, "type_alias_declaration")) return .type_alias;
    if (std.mem.eql(u8, node_type, "enum_declaration")) return .enumeration;
    if (std.mem.eql(u8, node_type, "method_definition")) return .method;
    return null;
}

fn isFunctionValue(node_type: []const u8) bool {
    return std.mem.eql(u8, node_type, "arrow_function") or std.mem.eql(u8, node_type, "function_expression") or
        std.mem.eql(u8, node_type, "generator_function");
}

fn isBareTypeNode(node: c.TSNode) bool {
    const node_type = nodeType(node);
    return std.mem.eql(u8, node_type, "type_identifier") or std.mem.eql(u8, node_type, "identifier");
}

fn bareIdentifier(value: []const u8) bool {
    if (value.len == 0 or !(std.ascii.isAlphabetic(value[0]) or value[0] == '_' or value[0] == '$')) return false;
    for (value[1..]) |byte| if (!(std.ascii.isAlphanumeric(byte) or byte == '_' or byte == '$')) return false;
    return true;
}

fn bareTypeNode(annotation: c.TSNode) ?c.TSNode {
    if (c.ts_node_is_null(annotation)) return null;
    if (isBareTypeNode(annotation)) return annotation;
    const child_count = c.ts_node_named_child_count(annotation);
    if (child_count != 1) return null;
    const child = c.ts_node_named_child(annotation, 0);
    return if (isBareTypeNode(child)) child else null;
}

fn nodeType(node: c.TSNode) []const u8 {
    const raw = c.ts_node_type(node);
    if (raw == null) return "";
    return std.mem.span(@as([*:0]const u8, @ptrCast(raw)));
}

fn fieldNode(node: c.TSNode, field: []const u8) c.TSNode {
    return c.ts_node_child_by_field_name(node, @ptrCast(field.ptr), @intCast(field.len));
}

fn directNamedChild(node: c.TSNode, expected_type: []const u8) c.TSNode {
    const child_count = c.ts_node_named_child_count(node);
    var index: u32 = 0;
    while (index < child_count) : (index += 1) {
        const child = c.ts_node_named_child(node, index);
        if (std.mem.eql(u8, nodeType(child), expected_type)) return child;
    }
    return c.ts_node_named_child(node, child_count);
}

fn firstDirectNamedChild(node: c.TSNode, expected_type: []const u8) c.TSNode {
    return directNamedChild(node, expected_type);
}

fn nullNode(node: c.TSNode) c.TSNode {
    return c.ts_node_named_child(node, c.ts_node_named_child_count(node));
}

fn hasDirectChildType(node: c.TSNode, expected_type: []const u8) bool {
    const child_count = c.ts_node_child_count(node);
    var index: u32 = 0;
    while (index < child_count) : (index += 1) {
        if (std.mem.eql(u8, nodeType(c.ts_node_child(node, index)), expected_type)) return true;
    }
    return false;
}

fn nodeText(source: []const u8, node: c.TSNode) ?[]const u8 {
    const start: usize = @intCast(c.ts_node_start_byte(node));
    const end: usize = @intCast(c.ts_node_end_byte(node));
    if (start >= end or end > source.len) return null;
    return source[start..end];
}

fn spanForNode(node: c.TSNode) Span {
    const start = c.ts_node_start_point(node);
    const end = c.ts_node_end_point(node);
    return .{
        .start_byte = @intCast(c.ts_node_start_byte(node)),
        .end_byte = @intCast(c.ts_node_end_byte(node)),
        .start_line = @intCast(start.row + 1),
        .start_column = @intCast(start.column + 1),
        .end_line = @intCast(end.row + 1),
        .end_column = @intCast(end.column + 1),
    };
}

fn scopeNameAlloc(allocator: std.mem.Allocator, scope: Scope, max_label_bytes: usize) ![]const u8 {
    if (scope.container.len == 0 and scope.declaration.len == 0) return "";
    if (scope.container.len == 0) return owned.copy(u8, allocator, scope.declaration);
    if (scope.declaration.len == 0) return owned.copy(u8, allocator, scope.container);
    const length = std.math.add(usize, scope.container.len, scope.declaration.len + 1) catch return error.TypeScriptLabelLimitExceeded;
    if (length > max_label_bytes) return error.TypeScriptLabelLimitExceeded;
    return std.fmt.allocPrint(allocator, "{s}.{s}", .{ scope.container, scope.declaration });
}

fn lessThanDeclaration(_: void, left: Declaration, right: Declaration) bool {
    if (left.name_span.start_byte != right.name_span.start_byte) return left.name_span.start_byte < right.name_span.start_byte;
    return std.mem.lessThan(u8, left.name, right.name);
}

fn lessThanImport(_: void, left: Import, right: Import) bool {
    if (left.target_span.start_byte != right.target_span.start_byte) return left.target_span.start_byte < right.target_span.start_byte;
    return std.mem.lessThan(u8, left.target, right.target);
}

fn lessThanImportBinding(_: void, left: ImportBinding, right: ImportBinding) bool {
    if (left.span.start_byte != right.span.start_byte) return left.span.start_byte < right.span.start_byte;
    return std.mem.lessThan(u8, left.local, right.local);
}

fn lessThanExport(_: void, left: Export, right: Export) bool {
    if (left.exported_span.start_byte != right.exported_span.start_byte) return left.exported_span.start_byte < right.exported_span.start_byte;
    return std.mem.lessThan(u8, left.exported, right.exported);
}

fn lessThanTypeBinding(_: void, left: TypeBinding, right: TypeBinding) bool {
    if (left.name_span.start_byte != right.name_span.start_byte) return left.name_span.start_byte < right.name_span.start_byte;
    return std.mem.lessThan(u8, left.binding, right.binding);
}

fn lessThanCall(_: void, left: Call, right: Call) bool {
    if (left.callee_span.start_byte != right.callee_span.start_byte) return left.callee_span.start_byte < right.callee_span.start_byte;
    return std.mem.lessThan(u8, left.callee, right.callee);
}

fn findImportTarget(imports: []const Import, target: []const u8) ?*const Import {
    for (imports) |*item| if (std.mem.eql(u8, item.target, target)) return item;
    return null;
}

fn deinitDeclarationList(allocator: std.mem.Allocator, values: *std.ArrayList(Declaration)) void {
    for (values.items) |value| {
        allocator.free(value.name);
        if (value.enclosing_declaration.len > 0) allocator.free(value.enclosing_declaration);
    }
    values.deinit(allocator);
}

fn deinitImportList(allocator: std.mem.Allocator, values: *std.ArrayList(Import)) void {
    for (values.items) |value| allocator.free(value.target);
    values.deinit(allocator);
}

fn deinitImportBindingList(allocator: std.mem.Allocator, values: *std.ArrayList(ImportBinding)) void {
    for (values.items) |value| {
        allocator.free(value.target);
        allocator.free(value.imported);
        allocator.free(value.local);
    }
    values.deinit(allocator);
}

fn deinitExportList(allocator: std.mem.Allocator, values: *std.ArrayList(Export)) void {
    for (values.items) |value| {
        if (value.target.len > 0) allocator.free(value.target);
        allocator.free(value.imported);
        allocator.free(value.exported);
    }
    values.deinit(allocator);
}

fn deinitTypeBindingList(allocator: std.mem.Allocator, values: *std.ArrayList(TypeBinding)) void {
    for (values.items) |value| {
        allocator.free(value.binding);
        allocator.free(value.type_name);
        if (value.enclosing_declaration.len > 0) allocator.free(value.enclosing_declaration);
    }
    values.deinit(allocator);
}

fn deinitCallList(allocator: std.mem.Allocator, values: *std.ArrayList(Call)) void {
    for (values.items) |value| {
        allocator.free(value.callee);
        if (value.receiver.len > 0) allocator.free(value.receiver);
        if (value.member.len > 0) allocator.free(value.member);
        if (value.enclosing_declaration.len > 0) allocator.free(value.enclosing_declaration);
    }
    values.deinit(allocator);
}

fn deinitDeclarations(allocator: std.mem.Allocator, values: []Declaration) void {
    for (values) |value| {
        allocator.free(value.name);
        if (value.enclosing_declaration.len > 0) allocator.free(value.enclosing_declaration);
    }
    allocator.free(values);
}

fn deinitImports(allocator: std.mem.Allocator, values: []Import) void {
    for (values) |value| allocator.free(value.target);
    allocator.free(values);
}

fn deinitImportBindings(allocator: std.mem.Allocator, values: []ImportBinding) void {
    for (values) |value| {
        allocator.free(value.target);
        allocator.free(value.imported);
        allocator.free(value.local);
    }
    allocator.free(values);
}

fn deinitExports(allocator: std.mem.Allocator, values: []Export) void {
    for (values) |value| {
        if (value.target.len > 0) allocator.free(value.target);
        allocator.free(value.imported);
        allocator.free(value.exported);
    }
    allocator.free(values);
}

fn deinitTypeBindings(allocator: std.mem.Allocator, values: []TypeBinding) void {
    for (values) |value| {
        allocator.free(value.binding);
        allocator.free(value.type_name);
        if (value.enclosing_declaration.len > 0) allocator.free(value.enclosing_declaration);
    }
    allocator.free(values);
}

fn deinitCalls(allocator: std.mem.Allocator, values: []Call) void {
    for (values) |value| {
        allocator.free(value.callee);
        if (value.receiver.len > 0) allocator.free(value.receiver);
        if (value.member.len > 0) allocator.free(value.member);
        if (value.enclosing_declaration.len > 0) allocator.free(value.enclosing_declaration);
    }
    allocator.free(values);
}
