const std = @import("std");
const zstd = @import("zigeffect_std");

const Parser = zstd.Parser;

pub const schema = Parser.schema;
pub const schema_version = Parser.schema_version;
pub const parser_id = "zigeffect.parser.protobuf.native";
pub const parser_version = "1.1.0";

pub const Span = Parser.Span;
pub const Declaration = Parser.Declaration;
pub const Import = Parser.Import;
pub const ProtocolPackage = Parser.ProtocolPackage;
pub const ProtocolField = Parser.ProtocolField;
pub const ProtocolEnumValue = Parser.ProtocolEnumValue;
pub const ProtocolRpc = Parser.ProtocolRpc;
pub const Options = Parser.Options;
pub const Result = Parser.Result;

const TokenKind = enum {
    identifier,
    string,
    integer,
    symbol,
    eof,
};

const Token = struct {
    kind: TokenKind,
    lexeme: []const u8,
    span: Span,
    value_span: Span,

    fn isSymbol(self: Token, symbol: u8) bool {
        return self.kind == .symbol and self.lexeme.len == 1 and self.lexeme[0] == symbol;
    }
};

const Lexer = struct {
    source: []const u8,
    limits: Options,
    index: usize = 0,
    line: u32 = 1,
    column: u32 = 1,
    token_count: usize = 0,

    fn next(self: *Lexer) !Token {
        try self.skipTrivia();
        if (self.index == self.source.len) {
            const point = Span{
                .start_byte = self.index,
                .end_byte = self.index,
                .start_line = self.line,
                .start_column = self.column,
                .end_line = self.line,
                .end_column = self.column,
            };
            return .{ .kind = .eof, .lexeme = "", .span = point, .value_span = point };
        }
        self.token_count += 1;
        if (self.token_count > self.limits.max_nodes) return error.ParserNodeLimitExceeded;

        const start = self.index;
        const start_line = self.line;
        const start_column = self.column;
        const first = self.source[self.index];
        if (isIdentifierStart(first)) {
            self.advance();
            while (self.index < self.source.len and isIdentifierContinue(self.source[self.index])) self.advance();
            const span = self.spanFrom(start, start_line, start_column);
            const value = self.source[start..self.index];
            try self.checkLabel(value);
            return .{ .kind = .identifier, .lexeme = value, .span = span, .value_span = span };
        }
        if (std.ascii.isDigit(first) or (first == '-' and self.index + 1 < self.source.len and std.ascii.isDigit(self.source[self.index + 1]))) {
            self.advance();
            while (self.index < self.source.len and std.ascii.isDigit(self.source[self.index])) self.advance();
            const span = self.spanFrom(start, start_line, start_column);
            return .{ .kind = .integer, .lexeme = self.source[start..self.index], .span = span, .value_span = span };
        }
        if (first == '"' or first == '\'') {
            const quote = first;
            self.advance();
            const value_start = self.index;
            const value_line = self.line;
            const value_column = self.column;
            while (self.index < self.source.len and self.source[self.index] != quote) {
                const byte = self.source[self.index];
                if (byte == '\n' or byte == '\r') return error.InvalidProtoString;
                if (byte == '\\') {
                    self.advance();
                    if (self.index >= self.source.len or self.source[self.index] == '\n' or self.source[self.index] == '\r') return error.InvalidProtoString;
                }
                self.advance();
            }
            if (self.index >= self.source.len) return error.UnterminatedProtoString;
            const value_end = self.index;
            const value_end_line = self.line;
            const value_end_column = self.column;
            self.advance();
            const span = self.spanFrom(start, start_line, start_column);
            const value_span = Span{
                .start_byte = value_start,
                .end_byte = value_end,
                .start_line = value_line,
                .start_column = value_column,
                .end_line = value_end_line,
                .end_column = value_end_column,
            };
            const value = self.source[value_start..value_end];
            if (value.len == 0) return error.InvalidProtoString;
            try self.checkLabel(value);
            return .{ .kind = .string, .lexeme = value, .span = span, .value_span = value_span };
        }
        if (std.mem.indexOfScalar(u8, "{}[]()<>=;,.+-", first) != null) {
            self.advance();
            const span = self.spanFrom(start, start_line, start_column);
            return .{ .kind = .symbol, .lexeme = self.source[start..self.index], .span = span, .value_span = span };
        }
        return error.UnsupportedProtoToken;
    }

    fn skipTrivia(self: *Lexer) !void {
        while (self.index < self.source.len) {
            const byte = self.source[self.index];
            if (std.ascii.isWhitespace(byte)) {
                self.advance();
                continue;
            }
            if (byte != '/' or self.index + 1 >= self.source.len) return;
            const next_byte = self.source[self.index + 1];
            if (next_byte == '/') {
                self.advance();
                self.advance();
                while (self.index < self.source.len and self.source[self.index] != '\n') self.advance();
                continue;
            }
            if (next_byte == '*') {
                self.advance();
                self.advance();
                var closed = false;
                while (self.index + 1 < self.source.len) {
                    if (self.source[self.index] == '*' and self.source[self.index + 1] == '/') {
                        self.advance();
                        self.advance();
                        closed = true;
                        break;
                    }
                    self.advance();
                }
                if (!closed) return error.UnterminatedProtoComment;
                continue;
            }
            return;
        }
    }

    fn advance(self: *Lexer) void {
        const byte = self.source[self.index];
        self.index += 1;
        if (byte == '\n') {
            self.line += 1;
            self.column = 1;
        } else {
            self.column += 1;
        }
    }

    fn spanFrom(self: *const Lexer, start: usize, start_line: u32, start_column: u32) Span {
        return .{
            .start_byte = start,
            .end_byte = self.index,
            .start_line = start_line,
            .start_column = start_column,
            .end_line = self.line,
            .end_column = self.column,
        };
    }

    fn checkLabel(self: *const Lexer, value: []const u8) !void {
        if (value.len > self.limits.max_label_bytes) return error.ParserLabelLimitExceeded;
    }
};

const OwnedName = struct {
    value: []u8,
    span: Span,
};

const NativeParser = struct {
    allocator: std.mem.Allocator,
    source: []const u8,
    limits: Options,
    lexer: Lexer,
    current: Token,
    depth: usize = 0,
    facts: usize = 0,
    declarations: std.ArrayList(Declaration) = .empty,
    imports: std.ArrayList(Import) = .empty,
    packages: std.ArrayList(ProtocolPackage) = .empty,
    fields: std.ArrayList(ProtocolField) = .empty,
    enum_values: std.ArrayList(ProtocolEnumValue) = .empty,
    rpcs: std.ArrayList(ProtocolRpc) = .empty,

    fn init(allocator: std.mem.Allocator, source: []const u8, limits: Options) !NativeParser {
        var lexer = Lexer{ .source = source, .limits = limits };
        const first = try lexer.next();
        return .{
            .allocator = allocator,
            .source = source,
            .limits = limits,
            .lexer = lexer,
            .current = first,
        };
    }

    fn deinit(self: *NativeParser) void {
        for (self.declarations.items) |item| {
            self.allocator.free(item.name);
            if (item.enclosing_declaration.len > 0) self.allocator.free(item.enclosing_declaration);
        }
        self.declarations.deinit(self.allocator);
        for (self.imports.items) |item| self.allocator.free(item.target);
        self.imports.deinit(self.allocator);
        for (self.packages.items) |item| self.allocator.free(item.name);
        self.packages.deinit(self.allocator);
        for (self.fields.items) |item| {
            self.allocator.free(item.owner);
            self.allocator.free(item.name);
            self.allocator.free(item.type_name);
            if (item.map_key_type.len > 0) self.allocator.free(item.map_key_type);
            if (item.oneof_name.len > 0) self.allocator.free(item.oneof_name);
        }
        self.fields.deinit(self.allocator);
        for (self.enum_values.items) |item| {
            self.allocator.free(item.owner);
            self.allocator.free(item.name);
        }
        self.enum_values.deinit(self.allocator);
        for (self.rpcs.items) |item| {
            self.allocator.free(item.service);
            self.allocator.free(item.name);
            self.allocator.free(item.request_type);
            self.allocator.free(item.response_type);
        }
        self.rpcs.deinit(self.allocator);
    }

    fn parseDocument(self: *NativeParser) !void {
        while (self.current.kind != .eof) {
            if (self.keyword("syntax") or self.keyword("edition")) {
                try self.parseVersionStatement();
            } else if (self.keyword("package")) {
                try self.parsePackage();
            } else if (self.keyword("import")) {
                try self.parseImport();
            } else if (self.keyword("message")) {
                try self.parseMessage("");
            } else if (self.keyword("enum")) {
                try self.parseEnum("");
            } else if (self.keyword("service")) {
                try self.parseService();
            } else if (self.keyword("option") or self.keyword("reserved") or self.keyword("extensions")) {
                try self.skipStatement();
            } else if (self.keyword("extend")) {
                try self.skipDeclarationBody();
            } else {
                return error.UnsupportedProtoDeclaration;
            }
        }
        if (self.lexer.token_count == 0) return error.InvalidProtoDocument;
    }

    fn parseVersionStatement(self: *NativeParser) !void {
        _ = try self.take();
        try self.expectSymbol('=');
        if (self.current.kind != .string and self.current.kind != .identifier) return error.InvalidProtoVersion;
        _ = try self.take();
        try self.expectSymbol(';');
    }

    fn parsePackage(self: *NativeParser) !void {
        if (self.packages.items.len != 0) return error.DuplicateProtoPackage;
        const start = try self.take();
        const name = try self.parseDottedName(false);
        errdefer self.allocator.free(name.value);
        const end = self.current;
        try self.expectSymbol(';');
        try self.addFact();
        try self.packages.append(self.allocator, .{
            .name = name.value,
            .span = mergeSpan(start.span, end.span),
            .name_span = name.span,
        });
    }

    fn parseImport(self: *NativeParser) !void {
        const start = try self.take();
        var kind: Parser.ImportKind = .static;
        if (self.keyword("public")) {
            kind = .proto_public;
            _ = try self.take();
        } else if (self.keyword("weak")) {
            kind = .proto_weak;
            _ = try self.take();
        }
        if (self.current.kind != .string) return error.InvalidProtoImport;
        const target = try self.take();
        const copied = try self.copyLabel(target.lexeme);
        errdefer self.allocator.free(copied);
        const end = self.current;
        try self.expectSymbol(';');
        try self.addFact();
        try self.imports.append(self.allocator, .{
            .target = copied,
            .kind = kind,
            .type_only = false,
            .span = mergeSpan(start.span, end.span),
            .target_span = target.value_span,
        });
    }

    fn parseMessage(self: *NativeParser, parent: []const u8) !void {
        try self.enter();
        defer self.leave();
        const start = try self.take();
        const name_token = try self.expectIdentifier();
        const full_name = try self.qualify(parent, name_token.lexeme);
        var declaration_owned = false;
        errdefer if (!declaration_owned) self.allocator.free(full_name);
        const enclosing = if (parent.len == 0) "" else try self.copyLabel(parent);
        errdefer if (!declaration_owned and enclosing.len > 0) self.allocator.free(enclosing);
        try self.expectSymbol('{');
        try self.addFact();
        const declaration_index = self.declarations.items.len;
        try self.declarations.append(self.allocator, .{
            .kind = .message,
            .name = full_name,
            .enclosing_declaration = enclosing,
            .exported = true,
            .span = mergeSpan(start.span, name_token.span),
            .name_span = name_token.span,
        });
        declaration_owned = true;
        var numbers = std.AutoHashMap(u32, void).init(self.allocator);
        defer numbers.deinit();
        while (!self.current.isSymbol('}')) {
            if (self.current.kind == .eof) return error.UnterminatedProtoMessage;
            if (self.keyword("message")) {
                try self.parseMessage(full_name);
            } else if (self.keyword("enum")) {
                try self.parseEnum(full_name);
            } else if (self.keyword("oneof")) {
                try self.parseOneof(full_name, &numbers);
            } else if (self.keyword("option") or self.keyword("reserved") or self.keyword("extensions")) {
                try self.skipStatement();
            } else if (self.keyword("extend")) {
                try self.skipDeclarationBody();
            } else {
                try self.parseField(full_name, "", &numbers);
            }
        }
        const end = try self.take();
        self.declarations.items[declaration_index].span = mergeSpan(start.span, end.span);
    }

    fn parseEnum(self: *NativeParser, parent: []const u8) !void {
        try self.enter();
        defer self.leave();
        const start = try self.take();
        const name_token = try self.expectIdentifier();
        const full_name = try self.qualify(parent, name_token.lexeme);
        var declaration_owned = false;
        errdefer if (!declaration_owned) self.allocator.free(full_name);
        const enclosing = if (parent.len == 0) "" else try self.copyLabel(parent);
        errdefer if (!declaration_owned and enclosing.len > 0) self.allocator.free(enclosing);
        try self.expectSymbol('{');
        try self.addFact();
        const declaration_index = self.declarations.items.len;
        try self.declarations.append(self.allocator, .{
            .kind = .enumeration,
            .name = full_name,
            .enclosing_declaration = enclosing,
            .exported = true,
            .span = mergeSpan(start.span, name_token.span),
            .name_span = name_token.span,
        });
        declaration_owned = true;
        while (!self.current.isSymbol('}')) {
            if (self.current.kind == .eof) return error.UnterminatedProtoEnum;
            if (self.keyword("option") or self.keyword("reserved")) {
                try self.skipStatement();
                continue;
            }
            const value_start = self.current;
            const value_name = try self.expectIdentifier();
            try self.expectSymbol('=');
            const number = try self.expectInteger(i32);
            try self.skipFieldOptions();
            const end = self.current;
            try self.expectSymbol(';');
            const owner = try self.copyLabel(full_name);
            errdefer self.allocator.free(owner);
            const name = try self.copyLabel(value_name.lexeme);
            errdefer self.allocator.free(name);
            try self.addFact();
            try self.enum_values.append(self.allocator, .{
                .owner = owner,
                .name = name,
                .number = number.value,
                .span = mergeSpan(value_start.span, end.span),
                .name_span = value_name.span,
                .number_span = number.span,
            });
        }
        const end = try self.take();
        self.declarations.items[declaration_index].span = mergeSpan(start.span, end.span);
    }

    fn parseService(self: *NativeParser) !void {
        try self.enter();
        defer self.leave();
        const start = try self.take();
        const name_token = try self.expectIdentifier();
        const service_name = try self.copyLabel(name_token.lexeme);
        var declaration_owned = false;
        errdefer if (!declaration_owned) self.allocator.free(service_name);
        try self.expectSymbol('{');
        try self.addFact();
        const declaration_index = self.declarations.items.len;
        try self.declarations.append(self.allocator, .{
            .kind = .service,
            .name = service_name,
            .enclosing_declaration = "",
            .exported = true,
            .span = mergeSpan(start.span, name_token.span),
            .name_span = name_token.span,
        });
        declaration_owned = true;
        while (!self.current.isSymbol('}')) {
            if (self.current.kind == .eof) return error.UnterminatedProtoService;
            if (self.keyword("rpc")) {
                try self.parseRpc(service_name);
            } else if (self.keyword("option") or self.keyword("reserved")) {
                try self.skipStatement();
            } else {
                return error.UnsupportedProtoServiceMember;
            }
        }
        const end = try self.take();
        self.declarations.items[declaration_index].span = mergeSpan(start.span, end.span);
    }

    fn parseRpc(self: *NativeParser, service: []const u8) !void {
        const start = try self.take();
        const name_token = try self.expectIdentifier();
        const declaration_name = try self.qualify(service, name_token.lexeme);
        var declaration_owned = false;
        errdefer if (!declaration_owned) self.allocator.free(declaration_name);
        const enclosing = try self.copyLabel(service);
        errdefer if (!declaration_owned) self.allocator.free(enclosing);
        try self.expectSymbol('(');
        const client_streaming = if (self.keyword("stream")) block: {
            _ = try self.take();
            break :block true;
        } else false;
        const request = try self.parseDottedName(true);
        errdefer self.allocator.free(request.value);
        try self.expectSymbol(')');
        if (!self.keyword("returns")) return error.InvalidProtoRpc;
        _ = try self.take();
        try self.expectSymbol('(');
        const server_streaming = if (self.keyword("stream")) block: {
            _ = try self.take();
            break :block true;
        } else false;
        const response = try self.parseDottedName(true);
        errdefer self.allocator.free(response.value);
        try self.expectSymbol(')');
        const declaration_index = self.declarations.items.len;
        try self.addFact();
        try self.declarations.append(self.allocator, .{
            .kind = .rpc,
            .name = declaration_name,
            .enclosing_declaration = enclosing,
            .exported = true,
            .span = mergeSpan(start.span, response.span),
            .name_span = name_token.span,
        });
        declaration_owned = true;
        var end_span = response.span;
        if (self.current.isSymbol(';')) {
            end_span = self.current.span;
            _ = try self.take();
        } else if (self.current.isSymbol('{')) {
            end_span = try self.skipBalanced('{', '}');
        } else return error.InvalidProtoRpc;
        self.declarations.items[declaration_index].span = mergeSpan(start.span, end_span);
        const service_copy = try self.copyLabel(service);
        errdefer self.allocator.free(service_copy);
        const name_copy = try self.copyLabel(name_token.lexeme);
        errdefer self.allocator.free(name_copy);
        try self.addFact();
        try self.rpcs.append(self.allocator, .{
            .service = service_copy,
            .name = name_copy,
            .request_type = request.value,
            .response_type = response.value,
            .client_streaming = client_streaming,
            .server_streaming = server_streaming,
            .span = mergeSpan(start.span, end_span),
            .name_span = name_token.span,
            .request_span = request.span,
            .response_span = response.span,
        });
    }

    fn parseOneof(self: *NativeParser, owner: []const u8, numbers: *std.AutoHashMap(u32, void)) !void {
        try self.enter();
        defer self.leave();
        _ = try self.take();
        const name = try self.expectIdentifier();
        try self.expectSymbol('{');
        while (!self.current.isSymbol('}')) {
            if (self.current.kind == .eof) return error.UnterminatedProtoOneof;
            if (self.keyword("option")) {
                try self.skipStatement();
            } else {
                try self.parseField(owner, name.lexeme, numbers);
            }
        }
        _ = try self.take();
    }

    fn parseField(self: *NativeParser, owner: []const u8, oneof_name: []const u8, numbers: *std.AutoHashMap(u32, void)) !void {
        const start = self.current;
        var cardinality: Parser.ProtocolCardinality = .singular;
        if (self.keyword("optional")) {
            cardinality = .optional;
            _ = try self.take();
        } else if (self.keyword("required")) {
            cardinality = .required;
            _ = try self.take();
        } else if (self.keyword("repeated")) {
            cardinality = .repeated;
            _ = try self.take();
        }

        var kind: Parser.ProtocolFieldKind = if (oneof_name.len == 0) .normal else .oneof;
        var map_key: []u8 = &.{};
        errdefer if (map_key.len > 0) self.allocator.free(map_key);
        const type_name: OwnedName = if (self.keyword("map")) block: {
            if (oneof_name.len > 0 or cardinality != .singular) return error.InvalidProtoMapField;
            kind = .map;
            _ = try self.take();
            try self.expectSymbol('<');
            const key = try self.parseDottedName(false);
            defer self.allocator.free(key.value);
            map_key = try self.copyLabel(key.value);
            try self.expectSymbol(',');
            const map_value = try self.parseDottedName(true);
            errdefer self.allocator.free(map_value.value);
            try self.expectSymbol('>');
            break :block map_value;
        } else try self.parseDottedName(true);
        errdefer self.allocator.free(type_name.value);
        const name_token = try self.expectIdentifier();
        try self.expectSymbol('=');
        const number = try self.expectInteger(u32);
        if (number.value == 0 or number.value > 536_870_911 or (number.value >= 19_000 and number.value <= 19_999)) return error.InvalidProtoFieldNumber;
        if (numbers.contains(number.value)) return error.DuplicateProtoFieldNumber;
        try numbers.put(number.value, {});
        try self.skipFieldOptions();
        const end = self.current;
        try self.expectSymbol(';');

        const owner_copy = try self.copyLabel(owner);
        errdefer self.allocator.free(owner_copy);
        const name_copy = try self.copyLabel(name_token.lexeme);
        errdefer self.allocator.free(name_copy);
        const oneof_copy = if (oneof_name.len == 0) @as([]u8, &.{}) else try self.copyLabel(oneof_name);
        errdefer if (oneof_copy.len > 0) self.allocator.free(oneof_copy);
        const declaration_name = try self.qualify(owner, name_token.lexeme);
        var declaration_owned = false;
        errdefer if (!declaration_owned) self.allocator.free(declaration_name);
        const enclosing = try self.copyLabel(owner);
        errdefer if (!declaration_owned) self.allocator.free(enclosing);
        try self.addFact();
        try self.declarations.append(self.allocator, .{
            .kind = .field,
            .name = declaration_name,
            .enclosing_declaration = enclosing,
            .exported = true,
            .span = mergeSpan(start.span, end.span),
            .name_span = name_token.span,
        });
        declaration_owned = true;
        try self.addFact();
        try self.fields.append(self.allocator, .{
            .owner = owner_copy,
            .name = name_copy,
            .type_name = type_name.value,
            .map_key_type = map_key,
            .oneof_name = oneof_copy,
            .number = number.value,
            .kind = kind,
            .cardinality = cardinality,
            .span = mergeSpan(start.span, end.span),
            .name_span = name_token.span,
            .type_span = type_name.span,
            .number_span = number.span,
        });
    }

    fn skipFieldOptions(self: *NativeParser) !void {
        if (self.current.isSymbol('[')) _ = try self.skipBalanced('[', ']');
    }

    fn skipStatement(self: *NativeParser) !void {
        _ = try self.take();
        var nesting: usize = 0;
        while (self.current.kind != .eof) {
            if (nesting == 0 and self.current.isSymbol(';')) {
                _ = try self.take();
                return;
            }
            if (self.current.isSymbol('[') or self.current.isSymbol('(') or self.current.isSymbol('{')) nesting += 1;
            if (self.current.isSymbol(']') or self.current.isSymbol(')') or self.current.isSymbol('}')) {
                if (nesting == 0) return error.InvalidProtoStatement;
                nesting -= 1;
            }
            _ = try self.take();
        }
        return error.UnterminatedProtoStatement;
    }

    fn skipDeclarationBody(self: *NativeParser) !void {
        _ = try self.take();
        while (self.current.kind != .eof and !self.current.isSymbol('{') and !self.current.isSymbol(';')) _ = try self.take();
        if (self.current.isSymbol(';')) {
            _ = try self.take();
            return;
        }
        if (self.current.isSymbol('{')) {
            _ = try self.skipBalanced('{', '}');
            return;
        }
        return error.UnterminatedProtoDeclaration;
    }

    fn skipBalanced(self: *NativeParser, open: u8, close: u8) !Span {
        if (!self.current.isSymbol(open)) return error.InvalidProtoDelimiter;
        try self.enter();
        defer self.leave();
        var depth: usize = 0;
        var last = self.current.span;
        while (self.current.kind != .eof) {
            const token = try self.take();
            last = token.span;
            if (token.isSymbol(open)) depth += 1;
            if (token.isSymbol(close)) {
                depth -= 1;
                if (depth == 0) return last;
            }
        }
        return error.UnterminatedProtoDelimiter;
    }

    fn parseDottedName(self: *NativeParser, allow_leading_dot: bool) !OwnedName {
        var bytes = std.ArrayList(u8).empty;
        defer bytes.deinit(self.allocator);
        var first_span: ?Span = null;
        var last_span: Span = undefined;
        if (self.current.isSymbol('.')) {
            if (!allow_leading_dot) return error.InvalidProtoName;
            const dot = try self.take();
            try bytes.append(self.allocator, '.');
            first_span = dot.span;
            last_span = dot.span;
        }
        const first = try self.expectIdentifier();
        if (first_span == null) first_span = first.span;
        last_span = first.span;
        try bytes.appendSlice(self.allocator, first.lexeme);
        while (self.current.isSymbol('.')) {
            _ = try self.take();
            const part = try self.expectIdentifier();
            try bytes.append(self.allocator, '.');
            try bytes.appendSlice(self.allocator, part.lexeme);
            last_span = part.span;
        }
        if (bytes.items.len > self.limits.max_label_bytes) return error.ParserLabelLimitExceeded;
        return .{
            .value = try bytes.toOwnedSlice(self.allocator),
            .span = mergeSpan(first_span.?, last_span),
        };
    }

    fn expectIdentifier(self: *NativeParser) !Token {
        if (self.current.kind != .identifier) return error.ExpectedProtoIdentifier;
        return self.take();
    }

    fn expectInteger(self: *NativeParser, comptime T: type) !struct { value: T, span: Span } {
        if (self.current.kind != .integer) return error.ExpectedProtoInteger;
        const token = try self.take();
        const value = std.fmt.parseInt(T, token.lexeme, 10) catch return error.InvalidProtoInteger;
        return .{ .value = value, .span = token.span };
    }

    fn expectSymbol(self: *NativeParser, symbol: u8) !void {
        if (!self.current.isSymbol(symbol)) return error.ExpectedProtoSymbol;
        _ = try self.take();
    }

    fn take(self: *NativeParser) !Token {
        const value = self.current;
        self.current = try self.lexer.next();
        return value;
    }

    fn keyword(self: *const NativeParser, value: []const u8) bool {
        return self.current.kind == .identifier and std.mem.eql(u8, self.current.lexeme, value);
    }

    fn qualify(self: *NativeParser, parent: []const u8, child: []const u8) ![]u8 {
        const size = child.len + if (parent.len == 0) @as(usize, 0) else parent.len + 1;
        if (size > self.limits.max_label_bytes) return error.ParserLabelLimitExceeded;
        if (parent.len == 0) return self.allocator.dupe(u8, child);
        return std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ parent, child });
    }

    fn copyLabel(self: *NativeParser, value: []const u8) ![]u8 {
        if (value.len == 0 or value.len > self.limits.max_label_bytes) return error.ParserLabelLimitExceeded;
        return self.allocator.dupe(u8, value);
    }

    fn addFact(self: *NativeParser) !void {
        self.facts += 1;
        if (self.facts > self.limits.max_facts) return error.ParserFactLimitExceeded;
    }

    fn enter(self: *NativeParser) !void {
        self.depth += 1;
        if (self.depth > self.limits.max_depth) return error.ParserDepthLimitExceeded;
    }

    fn leave(self: *NativeParser) void {
        self.depth -= 1;
    }
};

pub fn parse(
    allocator: std.mem.Allocator,
    path: []const u8,
    source: []const u8,
    options: Options,
) !Result {
    try options.validate();
    if (source.len == 0) return error.InvalidProtoDocument;
    if (source.len > options.max_source_bytes) return error.ParserSourceLimitExceeded;
    var parser = try NativeParser.init(allocator, source, options);
    defer parser.deinit();
    try parser.parseDocument();

    const declarations = try parser.declarations.toOwnedSlice(allocator);
    errdefer deinitDeclarations(allocator, declarations);
    const imports = try parser.imports.toOwnedSlice(allocator);
    errdefer deinitImports(allocator, imports);
    const packages = try parser.packages.toOwnedSlice(allocator);
    errdefer deinitPackages(allocator, packages);
    const fields = try parser.fields.toOwnedSlice(allocator);
    errdefer deinitFields(allocator, fields);
    const enum_values = try parser.enum_values.toOwnedSlice(allocator);
    errdefer deinitEnumValues(allocator, enum_values);
    const rpcs = try parser.rpcs.toOwnedSlice(allocator);
    errdefer deinitRpcs(allocator, rpcs);
    const bindings = try allocator.alloc(Parser.ImportBinding, 0);
    errdefer allocator.free(bindings);
    const exports = try allocator.alloc(Parser.Export, 0);
    errdefer allocator.free(exports);
    const type_bindings = try allocator.alloc(Parser.TypeBinding, 0);
    errdefer allocator.free(type_bindings);
    const calls = try allocator.alloc(Parser.Call, 0);
    errdefer allocator.free(calls);
    const call_arguments = try allocator.alloc(Parser.CallArgument, 0);
    errdefer allocator.free(call_arguments);
    const call_bindings = try allocator.alloc(Parser.CallBinding, 0);
    errdefer allocator.free(call_bindings);

    const copied_path = try allocator.dupe(u8, path);
    errdefer allocator.free(copied_path);
    const summary = Parser.Summary{
        .declarations = declarations.len,
        .imports = imports.len,
        .protocol_packages = packages.len,
        .protocol_fields = fields.len,
        .protocol_enum_values = enum_values.len,
        .protocol_rpcs = rpcs.len,
        .traversed_nodes = parser.lexer.token_count,
    };
    var result = Result{
        .allocator = allocator,
        .path = copied_path,
        .language = .protobuf,
        .source_bytes = source.len,
        .parser_id = parser_id,
        .parser_version = parser_version,
        .declarations = declarations,
        .imports = imports,
        .import_bindings = bindings,
        .exports = exports,
        .type_bindings = type_bindings,
        .calls = calls,
        .call_arguments = call_arguments,
        .call_bindings = call_bindings,
        .protocol_packages = packages,
        .protocol_fields = fields,
        .protocol_enum_values = enum_values,
        .protocol_rpcs = rpcs,
        .summary = summary,
        .fingerprint = Parser.structuralFingerprint(parser_id, parser_version, path, .protobuf, source.len, declarations, imports, bindings, exports, type_bindings, calls, call_arguments, call_bindings, packages, fields, enum_values, rpcs, summary),
    };
    errdefer result.deinit();
    try result.validate();
    return result;
}

fn deinitDeclarations(allocator: std.mem.Allocator, values: []Declaration) void {
    for (values) |item| {
        allocator.free(item.name);
        if (item.enclosing_declaration.len > 0) allocator.free(item.enclosing_declaration);
    }
    allocator.free(values);
}

fn deinitImports(allocator: std.mem.Allocator, values: []Import) void {
    for (values) |item| allocator.free(item.target);
    allocator.free(values);
}

fn deinitPackages(allocator: std.mem.Allocator, values: []ProtocolPackage) void {
    for (values) |item| allocator.free(item.name);
    allocator.free(values);
}

fn deinitFields(allocator: std.mem.Allocator, values: []ProtocolField) void {
    for (values) |item| {
        allocator.free(item.owner);
        allocator.free(item.name);
        allocator.free(item.type_name);
        if (item.map_key_type.len > 0) allocator.free(item.map_key_type);
        if (item.oneof_name.len > 0) allocator.free(item.oneof_name);
    }
    allocator.free(values);
}

fn deinitEnumValues(allocator: std.mem.Allocator, values: []ProtocolEnumValue) void {
    for (values) |item| {
        allocator.free(item.owner);
        allocator.free(item.name);
    }
    allocator.free(values);
}

fn deinitRpcs(allocator: std.mem.Allocator, values: []ProtocolRpc) void {
    for (values) |item| {
        allocator.free(item.service);
        allocator.free(item.name);
        allocator.free(item.request_type);
        allocator.free(item.response_type);
    }
    allocator.free(values);
}

fn mergeSpan(first: Span, last: Span) Span {
    return .{
        .start_byte = first.start_byte,
        .end_byte = last.end_byte,
        .start_line = first.start_line,
        .start_column = first.start_column,
        .end_line = last.end_line,
        .end_column = last.end_column,
    };
}

fn isIdentifierStart(byte: u8) bool {
    return std.ascii.isAlphabetic(byte) or byte == '_';
}

fn isIdentifierContinue(byte: u8) bool {
    return isIdentifierStart(byte) or std.ascii.isDigit(byte);
}

test "Proto parser rejects duplicate immutable field numbers" {
    const source = "message Duplicate { string first = 1; string second = 1; }";
    try std.testing.expectError(error.DuplicateProtoFieldNumber, parse(
        std.testing.allocator,
        "duplicate.proto",
        source,
        .{},
    ));
}

test "Proto parser enforces configured fact and depth bounds" {
    const source = "message Outer { message Inner { string id = 1; } }";
    try std.testing.expectError(error.ParserFactLimitExceeded, parse(
        std.testing.allocator,
        "bounds.proto",
        source,
        .{ .max_facts = 1 },
    ));
    try std.testing.expectError(error.ParserDepthLimitExceeded, parse(
        std.testing.allocator,
        "bounds.proto",
        source,
        .{ .max_depth = 1 },
    ));
}

test "Proto parser covers Proto2 Editions weak imports and all RPC streaming shapes" {
    const proto2_source =
        \\syntax = "proto2";
        \\package legacy.v1;
        \\import weak "legacy/optional.proto";
        \\message Legacy {
        \\  required string id = 1;
        \\  optional int32 count = 2;
        \\  repeated bytes payloads = 3;
        \\}
    ;
    var proto2 = try parse(std.testing.allocator, "legacy/v1/legacy.proto", proto2_source, .{});
    defer proto2.deinit();
    const weak_import = proto2.findImport("legacy/optional.proto") orelse return error.MissingWeakProtoImport;
    try std.testing.expectEqual(Parser.ImportKind.proto_weak, weak_import.kind);
    try std.testing.expectEqual(Parser.ProtocolCardinality.required, proto2.findProtocolField("Legacy", 1).?.cardinality);
    try std.testing.expectEqual(Parser.ProtocolCardinality.optional, proto2.findProtocolField("Legacy", 2).?.cardinality);
    try std.testing.expectEqual(Parser.ProtocolCardinality.repeated, proto2.findProtocolField("Legacy", 3).?.cardinality);

    const editions_source =
        \\edition = "2023";
        \\package modern.v1;
        \\option features.field_presence = EXPLICIT;
        \\message Input {}
        \\message Output {}
        \\service Matrix {
        \\  rpc Unary(Input) returns (Output);
        \\  rpc Client(stream Input) returns (Output);
        \\  rpc Server(Input) returns (stream Output);
        \\  rpc Bidi(stream Input) returns (stream Output);
        \\}
    ;
    var editions = try parse(std.testing.allocator, "modern/v1/matrix.proto", editions_source, .{});
    defer editions.deinit();
    const unary = editions.findProtocolRpc("Matrix", "Unary") orelse return error.MissingUnaryRpcShape;
    const client = editions.findProtocolRpc("Matrix", "Client") orelse return error.MissingClientStreamingRpcShape;
    const server = editions.findProtocolRpc("Matrix", "Server") orelse return error.MissingServerStreamingRpcShape;
    const bidi = editions.findProtocolRpc("Matrix", "Bidi") orelse return error.MissingBidiStreamingRpcShape;
    try std.testing.expect(!unary.client_streaming and !unary.server_streaming);
    try std.testing.expect(client.client_streaming and !client.server_streaming);
    try std.testing.expect(!server.client_streaming and server.server_streaming);
    try std.testing.expect(bidi.client_streaming and bidi.server_streaming);
}

test "Proto parser fails malformed map syntax without retaining partial ownership" {
    try std.testing.expectError(error.ExpectedProtoSymbol, parse(
        std.testing.allocator,
        "malformed-map.proto",
        "message Broken { map<string, Broken value = 1; }",
        .{},
    ));
}
