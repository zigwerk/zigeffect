const std = @import("std");
const owned = @import("memory.zig");
const generated_lineage = @import("generated_lineage.zig");
const protobuf_resolution = @import("protobuf_resolution.zig");
const typescript_parser = @import("typescript_parser.zig");
const typescript_resolution = @import("typescript_resolution.zig");
const zig_parser = @import("zig_parser.zig");

pub const schema = "zgraphy.rpc-continuity.v1";
pub const schema_version: u32 = 1;
pub const analyzer_version = "connect-zigeffect-generated-driver-v1";

pub const Language = enum(u8) {
    typescript,
    tsx,
    javascript,
    jsx,
    zig,
    protobuf,
};

pub const Role = enum(u8) {
    frontend_invocation,
    backend_handler,
};

pub const Status = enum(u8) {
    resolved,
    ambiguous,
};

pub const Observation = struct {
    role: Role,
    source_path: []const u8,
    source_symbol: []const u8,
    span: SourceSpan,
    recipe: []const u8,
    status: Status,
    candidate_start: usize,
    candidate_count: usize,
};

pub const SourceSpan = struct {
    start_byte: usize,
    end_byte: usize,
    start_line: u32,
    start_column: u32,
    end_line: u32,
    end_column: u32,

    fn fromTypeScript(span: typescript_parser.Span) SourceSpan {
        return .{
            .start_byte = span.start_byte,
            .end_byte = span.end_byte,
            .start_line = span.start_line,
            .start_column = span.start_column,
            .end_line = span.end_line,
            .end_column = span.end_column,
        };
    }

    fn fromZig(span: zig_parser.Span) SourceSpan {
        return .{
            .start_byte = span.start_byte,
            .end_byte = span.end_byte,
            .start_line = span.start_line,
            .start_column = span.start_column,
            .end_line = span.end_line,
            .end_column = span.end_column,
        };
    }

    fn valid(self: SourceSpan) bool {
        return self.start_byte < self.end_byte and self.start_line > 0 and self.start_column > 0 and
            self.end_line >= self.start_line and self.end_column > 0;
    }
};

pub const Candidate = struct {
    observation_index: usize,
    entity_index: usize,
    canonical_operation: []const u8,
    proto_source_path: []const u8,
    rank: usize,
};

pub const Interaction = struct {
    canonical_operation: []const u8,
    request_type: []const u8,
    response_type: []const u8,
    frontend_observation_index: usize,
    backend_observation_index: usize,
};

pub const Summary = struct {
    documents: usize = 0,
    observations: usize = 0,
    frontend_invocations: usize = 0,
    backend_handlers: usize = 0,
    resolved: usize = 0,
    ambiguous: usize = 0,
    candidates: usize = 0,
    interactions: usize = 0,
};

pub const Result = struct {
    allocator: std.mem.Allocator,
    observations: []Observation,
    candidates: []Candidate,
    interactions: []Interaction,
    summary: Summary,
    proto_fingerprint: [32]u8,
    lineage_fingerprint: [32]u8,
    fingerprint: [32]u8,

    pub fn deinit(self: *Result) void {
        for (self.observations) |observation| {
            self.allocator.free(observation.source_path);
            self.allocator.free(observation.source_symbol);
            self.allocator.free(observation.recipe);
        }
        self.allocator.free(self.observations);
        for (self.candidates) |candidate| {
            self.allocator.free(candidate.canonical_operation);
            self.allocator.free(candidate.proto_source_path);
        }
        self.allocator.free(self.candidates);
        for (self.interactions) |interaction| {
            self.allocator.free(interaction.canonical_operation);
            self.allocator.free(interaction.request_type);
            self.allocator.free(interaction.response_type);
        }
        self.allocator.free(self.interactions);
        self.observations = &.{};
        self.candidates = &.{};
        self.interactions = &.{};
    }

    pub fn candidatesFor(self: *const Result, observation: *const Observation) []const Candidate {
        return self.candidates[observation.candidate_start..][0..observation.candidate_count];
    }

    pub fn findObservation(self: *const Result, role: Role, source_path: []const u8, source_symbol: []const u8) ?*const Observation {
        for (self.observations, 0..) |observation, index| {
            if (observation.role == role and std.mem.eql(u8, observation.source_path, source_path) and
                std.mem.eql(u8, observation.source_symbol, source_symbol)) return &self.observations[index];
        }
        return null;
    }

    pub fn findResolved(
        self: *const Result,
        role: Role,
        source_path: []const u8,
        source_symbol: []const u8,
        canonical_operation: []const u8,
    ) ?*const Observation {
        const observation = self.findObservation(role, source_path, source_symbol) orelse return null;
        if (observation.status != .resolved or observation.candidate_count != 1) return null;
        return if (std.mem.eql(u8, self.candidatesFor(observation)[0].canonical_operation, canonical_operation)) observation else null;
    }

    pub fn findInteraction(self: *const Result, canonical_operation: []const u8) ?*const Interaction {
        for (self.interactions, 0..) |interaction, index| {
            if (std.mem.eql(u8, interaction.canonical_operation, canonical_operation)) return &self.interactions[index];
        }
        return null;
    }
};

pub const Options = struct {
    max_documents: usize = 100_000,
    max_document_bytes: usize = 4 * 1024 * 1024,
    max_total_document_bytes: usize = 256 * 1024 * 1024,
    max_observations: usize = 1_000_000,
    max_candidates: usize = 4_000_000,
    max_interactions: usize = 1_000_000,
};

const Document = struct {
    path: []const u8,
    source: []const u8,
    language: Language,
};

pub const Corpus = struct {
    allocator: std.mem.Allocator,
    options: Options,
    documents: std.ArrayList(Document) = .empty,
    total_document_bytes: usize = 0,

    pub fn init(allocator: std.mem.Allocator, options: Options) !Corpus {
        if (options.max_documents == 0 or options.max_document_bytes == 0 or options.max_total_document_bytes == 0 or
            options.max_observations == 0 or options.max_candidates == 0 or options.max_interactions == 0)
        {
            return error.InvalidRpcContinuityOptions;
        }
        return .{ .allocator = allocator, .options = options };
    }

    pub fn deinit(self: *Corpus) void {
        for (self.documents.items) |document| {
            self.allocator.free(document.path);
            self.allocator.free(document.source);
        }
        self.documents.deinit(self.allocator);
    }

    pub fn addSource(self: *Corpus, path: []const u8, source: []const u8, language: Language) !void {
        if (!validPath(path) or source.len == 0) return error.InvalidRpcContinuityDocument;
        if (source.len > self.options.max_document_bytes) return error.RpcContinuityDocumentByteLimitExceeded;
        if (self.documents.items.len >= self.options.max_documents) return error.RpcContinuityDocumentLimitExceeded;
        for (self.documents.items) |document| if (std.mem.eql(u8, document.path, path)) return error.DuplicateRpcContinuityDocument;
        const total = std.math.add(usize, self.total_document_bytes, source.len) catch return error.RpcContinuityDocumentByteLimitExceeded;
        if (total > self.options.max_total_document_bytes) return error.RpcContinuityDocumentByteLimitExceeded;
        const path_copy = try owned.copy(u8, self.allocator, path);
        errdefer self.allocator.free(path_copy);
        const source_copy = try owned.copy(u8, self.allocator, source);
        errdefer self.allocator.free(source_copy);
        try self.documents.append(self.allocator, .{ .path = path_copy, .source = source_copy, .language = language });
        self.total_document_bytes = total;
    }

    pub fn resolve(self: *const Corpus) !Result {
        const order = try owned.slice(usize, self.allocator, self.documents.items.len);
        defer self.allocator.free(order);
        for (order, 0..) |*slot, index| slot.* = index;
        std.mem.sort(usize, order, self, lessThanDocumentIndex);

        var proto_corpus = try protobuf_resolution.Corpus.init(self.allocator, .{});
        defer proto_corpus.deinit();
        for (order) |index| {
            const document = self.documents.items[index];
            if (document.language == .protobuf) try proto_corpus.addSource(document.path, document.source);
        }
        var proto_result = try proto_corpus.resolve();
        defer proto_result.deinit();

        var lineage_corpus = try generated_lineage.Corpus.init(self.allocator, .{});
        defer lineage_corpus.deinit();
        for (order) |index| {
            const document = self.documents.items[index];
            switch (document.language) {
                .typescript, .tsx, .javascript, .jsx => try lineage_corpus.addSource(document.path, document.source, .typescript),
                .zig => try lineage_corpus.addSource(document.path, document.source, .zig),
                .protobuf => {},
            }
        }
        var lineage_result = try lineage_corpus.resolve(&proto_result);
        defer lineage_result.deinit();

        var parsed_typescript: std.ArrayList(typescript_parser.Result) = .empty;
        defer {
            for (parsed_typescript.items) |*parsed| parsed.deinit();
            parsed_typescript.deinit(self.allocator);
        }
        var module_corpus = try typescript_resolution.Corpus.init(self.allocator, .{});
        defer module_corpus.deinit();
        for (order) |index| {
            const document = self.documents.items[index];
            if (!isTypeScript(document.language)) continue;
            try module_corpus.addFile(document.path);
        }
        for (order) |index| {
            const document = self.documents.items[index];
            if (!isTypeScript(document.language)) continue;
            const mode = typescriptMode(document.language) orelse return error.InvalidRpcContinuityDocumentLanguage;
            var parsed = try typescript_parser.parse(self.allocator, document.path, document.source, mode, .{});
            errdefer parsed.deinit();
            try module_corpus.addParsed(&parsed);
            try parsed_typescript.append(self.allocator, parsed);
        }
        var module_result = try module_corpus.resolve();
        defer module_result.deinit();

        var parsed_zig: std.ArrayList(zig_parser.Result) = .empty;
        defer {
            for (parsed_zig.items) |*parsed| parsed.deinit();
            parsed_zig.deinit(self.allocator);
        }
        for (order) |index| {
            const document = self.documents.items[index];
            if (document.language != .zig) continue;
            try parsed_zig.append(self.allocator, try zig_parser.parse(self.allocator, document.path, document.source, .{}));
        }

        var engine = Engine.init(self, &proto_result, &lineage_result, &module_result, parsed_typescript.items, parsed_zig.items);
        defer engine.deinit();
        return engine.run();
    }
};

const TempObservation = struct {
    role: Role,
    source_path: []const u8,
    source_symbol: []const u8,
    span: SourceSpan,
    recipe: []const u8,
    entity_indexes: []const usize,
};

const Engine = struct {
    corpus: *const Corpus,
    proto: *const protobuf_resolution.Result,
    lineage: *const generated_lineage.Result,
    modules: *const typescript_resolution.Result,
    typescript: []const typescript_parser.Result,
    zig: []const zig_parser.Result,
    arena: std.heap.ArenaAllocator,

    fn init(
        corpus: *const Corpus,
        proto: *const protobuf_resolution.Result,
        lineage: *const generated_lineage.Result,
        modules: *const typescript_resolution.Result,
        typescript: []const typescript_parser.Result,
        zig: []const zig_parser.Result,
    ) Engine {
        return .{
            .corpus = corpus,
            .proto = proto,
            .lineage = lineage,
            .modules = modules,
            .typescript = typescript,
            .zig = zig,
            .arena = std.heap.ArenaAllocator.init(corpus.allocator),
        };
    }

    fn deinit(self: *Engine) void {
        self.arena.deinit();
    }

    fn run(self: *Engine) !Result {
        var temporary: std.ArrayList(TempObservation) = .empty;
        defer temporary.deinit(self.arena.allocator());
        try self.collectFrontend(&temporary);
        try self.collectBackend(&temporary);
        std.mem.sort(TempObservation, temporary.items, {}, lessThanTempObservation);
        deduplicateTempObservations(&temporary);
        if (temporary.items.len > self.corpus.options.max_observations) return error.RpcContinuityObservationLimitExceeded;

        var observations: std.ArrayList(Observation) = .empty;
        errdefer deinitObservationList(self.corpus.allocator, &observations);
        var candidates: std.ArrayList(Candidate) = .empty;
        errdefer deinitCandidateList(self.corpus.allocator, &candidates);
        var summary = Summary{ .documents = self.corpus.documents.items.len };
        for (temporary.items) |item| {
            const observation_index = observations.items.len;
            const candidate_start = candidates.items.len;
            const candidate_end = std.math.add(usize, candidate_start, item.entity_indexes.len) catch return error.RpcContinuityCandidateLimitExceeded;
            if (candidate_end > self.corpus.options.max_candidates) return error.RpcContinuityCandidateLimitExceeded;
            for (item.entity_indexes, 0..) |entity_index, rank| {
                if (entity_index >= self.proto.entities.len) return error.InvalidRpcContinuityCandidate;
                const entity = self.proto.entities[entity_index];
                if (entity.kind != .operation) return error.InvalidRpcContinuityCandidate;
                const canonical = try owned.copy(u8, self.corpus.allocator, entity.canonical_name);
                errdefer self.corpus.allocator.free(canonical);
                const source_path = try owned.copy(u8, self.corpus.allocator, entity.source_path);
                errdefer self.corpus.allocator.free(source_path);
                try candidates.append(self.corpus.allocator, .{
                    .observation_index = observation_index,
                    .entity_index = entity_index,
                    .canonical_operation = canonical,
                    .proto_source_path = source_path,
                    .rank = rank,
                });
            }
            const source_path = try owned.copy(u8, self.corpus.allocator, item.source_path);
            errdefer self.corpus.allocator.free(source_path);
            const source_symbol = try owned.copy(u8, self.corpus.allocator, item.source_symbol);
            errdefer self.corpus.allocator.free(source_symbol);
            const recipe = try owned.copy(u8, self.corpus.allocator, item.recipe);
            errdefer self.corpus.allocator.free(recipe);
            const status: Status = if (item.entity_indexes.len == 1) .resolved else .ambiguous;
            try observations.append(self.corpus.allocator, .{
                .role = item.role,
                .source_path = source_path,
                .source_symbol = source_symbol,
                .span = item.span,
                .recipe = recipe,
                .status = status,
                .candidate_start = candidate_start,
                .candidate_count = item.entity_indexes.len,
            });
            summary.observations += 1;
            switch (item.role) {
                .frontend_invocation => summary.frontend_invocations += 1,
                .backend_handler => summary.backend_handlers += 1,
            }
            switch (status) {
                .resolved => summary.resolved += 1,
                .ambiguous => summary.ambiguous += 1,
            }
        }
        summary.candidates = candidates.items.len;

        var interactions: std.ArrayList(Interaction) = .empty;
        errdefer deinitInteractionList(self.corpus.allocator, &interactions);
        try self.buildInteractions(observations.items, candidates.items, &interactions);
        if (interactions.items.len > self.corpus.options.max_interactions) return error.RpcContinuityInteractionLimitExceeded;
        summary.interactions = interactions.items.len;

        const observation_slice = try observations.toOwnedSlice(self.corpus.allocator);
        var cleanup_observations = true;
        defer if (cleanup_observations) {
            deinitObservations(self.corpus.allocator, observation_slice);
            self.corpus.allocator.free(observation_slice);
        };
        const candidate_slice = try candidates.toOwnedSlice(self.corpus.allocator);
        var cleanup_candidates = true;
        defer if (cleanup_candidates) {
            deinitCandidates(self.corpus.allocator, candidate_slice);
            self.corpus.allocator.free(candidate_slice);
        };
        const interaction_slice = try interactions.toOwnedSlice(self.corpus.allocator);
        var cleanup_interactions = true;
        defer if (cleanup_interactions) {
            deinitInteractions(self.corpus.allocator, interaction_slice);
            self.corpus.allocator.free(interaction_slice);
        };
        var result = Result{
            .allocator = self.corpus.allocator,
            .observations = observation_slice,
            .candidates = candidate_slice,
            .interactions = interaction_slice,
            .summary = summary,
            .proto_fingerprint = self.proto.fingerprint,
            .lineage_fingerprint = self.lineage.fingerprint,
            .fingerprint = resultFingerprint(observation_slice, candidate_slice, interaction_slice, summary, self.proto.fingerprint, self.lineage.fingerprint),
        };
        cleanup_observations = false;
        cleanup_candidates = false;
        cleanup_interactions = false;
        errdefer result.deinit();
        try validate(&result);
        return result;
    }

    fn collectFrontend(self: *Engine, output: *std.ArrayList(TempObservation)) !void {
        for (self.typescript) |*parsed| {
            for (parsed.call_bindings) |binding| {
                const factory = findTypeScriptCallBySpan(parsed.calls, binding.call_span) orelse continue;
                const factory_import = uniqueImportBinding(parsed.import_bindings, factory.callee) orelse continue;
                if (!std.mem.eql(u8, factory_import.target, "@connectrpc/connect") or
                    !std.mem.eql(u8, factory_import.imported, "createClient")) continue;
                const arguments = parsed.argumentsFor(factory);
                if (arguments.len < 1 or arguments[0].kind != .identifier) continue;
                const service_import = uniqueImportBinding(parsed.import_bindings, arguments[0].expression) orelse continue;
                const module = self.modules.findResolution(parsed.path, service_import.target, .static) orelse continue;
                if (module.candidate_count == 0) continue;
                for (parsed.calls) |call| {
                    if (call.kind != .member or !std.mem.eql(u8, call.receiver, binding.binding) or call.enclosing_declaration.len == 0) continue;
                    if (binding.enclosing_declaration.len > 0 and !std.mem.eql(u8, binding.enclosing_declaration, call.enclosing_declaration)) continue;
                    if (hasShadowingDeclaration(parsed, binding.binding, call.enclosing_declaration, call.callee_span.start_byte)) continue;
                    var entity_indexes: std.ArrayList(usize) = .empty;
                    defer entity_indexes.deinit(self.arena.allocator());
                    for (self.modules.candidatesFor(module)) |module_candidate| {
                        const service_link = findUniqueLineageBySymbol(self.lineage, .typescript, .service, module_candidate.target_path, service_import.imported) orelse continue;
                        if (service_link.status == .unresolved) continue;
                        for (self.lineage.links) |*operation_link| {
                            if (operation_link.language != .typescript or operation_link.kind != .operation or
                                !std.mem.eql(u8, operation_link.generated_path, module_candidate.target_path) or
                                !std.mem.eql(u8, operation_link.generated_symbol, call.member) or
                                !operationBelongsToService(operation_link.canonical_name, service_link.canonical_name)) continue;
                            try appendLineageEntityIndexes(self.arena.allocator(), self.lineage, operation_link, &entity_indexes);
                        }
                    }
                    try self.appendTempObservation(output, .frontend_invocation, parsed.path, call.enclosing_declaration, SourceSpan.fromTypeScript(call.span), "connect-create-client-v1", &entity_indexes);
                }
            }
        }
    }

    fn collectBackend(self: *Engine, output: *std.ArrayList(TempObservation)) !void {
        for (self.zig) |*parsed| {
            for (parsed.calls) |call| {
                const root = generatedDriverRoot(call.callee) orelse continue;
                const grpc_import = parsed.findImportBinding(root) orelse continue;
                if (!std.mem.eql(u8, grpc_import.target, "zigeffect-grpc")) continue;
                const arguments = parsed.argumentsFor(&call);
                if (arguments.len != 2 or arguments[0].kind != .call or arguments[1].kind != .identifier) continue;
                const generated_service_call = findZigCallBySpan(parsed.calls, arguments[0].span) orelse continue;
                const imported_service = splitImportedMember(generated_service_call.callee) orelse continue;
                const generated_import = parsed.findImportBinding(imported_service.alias) orelse continue;
                const generated_path = try normalizeRelativeImportAlloc(self.arena.allocator(), parsed.path, generated_import.target) orelse continue;
                const service_link = findUniqueLineageBySymbol(self.lineage, .zig, .service, generated_path, imported_service.member) orelse continue;
                if (service_link.status == .unresolved) continue;
                const implementation = parsed.findBinding(arguments[1].expression, "") orelse continue;
                const adapter_binding = smallestContainingBinding(parsed.bindings, call.span) orelse continue;
                if (!hasRegisterAllCall(parsed, adapter_binding)) continue;
                for (self.lineage.links) |*operation_link| {
                    if (operation_link.language != .zig or operation_link.kind != .operation or
                        !std.mem.eql(u8, operation_link.generated_path, generated_path) or
                        !operationBelongsToService(operation_link.canonical_name, service_link.canonical_name)) continue;
                    const handler = uniqueDeclarationInBinding(parsed.declarations, operation_link.generated_symbol, implementation.initializer_span) orelse continue;
                    const symbol = try std.fmt.allocPrint(self.arena.allocator(), "{s}.{s}", .{ implementation.name, handler.name });
                    var entity_indexes: std.ArrayList(usize) = .empty;
                    defer entity_indexes.deinit(self.arena.allocator());
                    try appendLineageEntityIndexes(self.arena.allocator(), self.lineage, operation_link, &entity_indexes);
                    try self.appendTempObservation(output, .backend_handler, parsed.path, symbol, SourceSpan.fromZig(handler.name_span), "zigeffect-generated-driver-v1", &entity_indexes);
                }
            }
        }
    }

    fn appendTempObservation(
        self: *Engine,
        output: *std.ArrayList(TempObservation),
        role: Role,
        source_path: []const u8,
        source_symbol: []const u8,
        span: SourceSpan,
        recipe: []const u8,
        entity_indexes: *std.ArrayList(usize),
    ) !void {
        if (entity_indexes.items.len == 0) return;
        std.mem.sort(usize, entity_indexes.items, {}, std.sort.asc(usize));
        deduplicateIndexes(entity_indexes);
        const indexes = try entity_indexes.toOwnedSlice(self.arena.allocator());
        try output.append(self.arena.allocator(), .{
            .role = role,
            .source_path = source_path,
            .source_symbol = source_symbol,
            .span = span,
            .recipe = recipe,
            .entity_indexes = indexes,
        });
    }

    fn buildInteractions(
        self: *Engine,
        observations: []const Observation,
        candidates: []const Candidate,
        output: *std.ArrayList(Interaction),
    ) !void {
        for (observations, 0..) |frontend, frontend_index| {
            if (frontend.role != .frontend_invocation or frontend.status != .resolved) continue;
            const frontend_candidate = candidates[frontend.candidate_start];
            for (observations, 0..) |backend, backend_index| {
                if (backend.role != .backend_handler or backend.status != .resolved) continue;
                const backend_candidate = candidates[backend.candidate_start];
                if (!std.mem.eql(u8, frontend_candidate.canonical_operation, backend_candidate.canonical_operation)) continue;
                if (hasInteraction(output.items, frontend_index, backend_index, frontend_candidate.canonical_operation)) continue;
                const request_type = self.resolvedProtocolType(.rpc_request, frontend_candidate.canonical_operation) orelse continue;
                const response_type = self.resolvedProtocolType(.rpc_response, frontend_candidate.canonical_operation) orelse continue;
                const operation_copy = try owned.copy(u8, self.corpus.allocator, frontend_candidate.canonical_operation);
                errdefer self.corpus.allocator.free(operation_copy);
                const request_copy = try owned.copy(u8, self.corpus.allocator, request_type);
                errdefer self.corpus.allocator.free(request_copy);
                const response_copy = try owned.copy(u8, self.corpus.allocator, response_type);
                errdefer self.corpus.allocator.free(response_copy);
                try output.append(self.corpus.allocator, .{
                    .canonical_operation = operation_copy,
                    .request_type = request_copy,
                    .response_type = response_copy,
                    .frontend_observation_index = frontend_index,
                    .backend_observation_index = backend_index,
                });
            }
        }
        std.mem.sort(Interaction, output.items, {}, lessThanInteraction);
    }

    fn resolvedProtocolType(self: *const Engine, kind: protobuf_resolution.ReferenceKind, operation: []const u8) ?[]const u8 {
        const reference = self.proto.findReference(kind, operation) orelse return null;
        if (reference.status != .resolved or reference.candidate_count != 1) return null;
        return self.proto.candidatesFor(reference)[0].canonical_name;
    }
};

pub fn validate(result: *const Result) !void {
    var summary = Summary{ .documents = result.summary.documents };
    var candidate_cursor: usize = 0;
    var previous: ?Observation = null;
    for (result.observations, 0..) |observation, observation_index| {
        if (!validPath(observation.source_path) or observation.source_symbol.len == 0 or observation.recipe.len == 0 or
            !observation.span.valid() or observation.candidate_start != candidate_cursor or observation.candidate_count == 0 or
            observation.candidate_start + observation.candidate_count > result.candidates.len) return error.InvalidRpcContinuityObservation;
        if (previous) |value| if (!lessThanOrEqualObservation(value, observation)) return error.InvalidRpcContinuityObservationOrder;
        previous = observation;
        const expected_status: Status = if (observation.candidate_count == 1) .resolved else .ambiguous;
        if (observation.status != expected_status) return error.InvalidRpcContinuityObservationStatus;
        for (result.candidates[observation.candidate_start..][0..observation.candidate_count], 0..) |candidate, rank| {
            if (candidate.observation_index != observation_index or candidate.rank != rank or candidate.canonical_operation.len == 0 or
                !validPath(candidate.proto_source_path)) return error.InvalidRpcContinuityCandidate;
        }
        candidate_cursor += observation.candidate_count;
        summary.observations += 1;
        switch (observation.role) {
            .frontend_invocation => summary.frontend_invocations += 1,
            .backend_handler => summary.backend_handlers += 1,
        }
        switch (observation.status) {
            .resolved => summary.resolved += 1,
            .ambiguous => summary.ambiguous += 1,
        }
    }
    summary.candidates = result.candidates.len;
    summary.interactions = result.interactions.len;
    if (candidate_cursor != result.candidates.len or !std.meta.eql(summary, result.summary)) return error.InvalidRpcContinuitySummary;
    var previous_interaction: ?Interaction = null;
    for (result.interactions) |interaction| {
        if (interaction.canonical_operation.len == 0 or interaction.request_type.len == 0 or interaction.response_type.len == 0 or
            interaction.frontend_observation_index >= result.observations.len or interaction.backend_observation_index >= result.observations.len or
            result.observations[interaction.frontend_observation_index].role != .frontend_invocation or
            result.observations[interaction.backend_observation_index].role != .backend_handler) return error.InvalidRpcContinuityInteraction;
        const frontend = result.observations[interaction.frontend_observation_index];
        const backend = result.observations[interaction.backend_observation_index];
        if (frontend.status != .resolved or frontend.candidate_count != 1 or backend.status != .resolved or backend.candidate_count != 1 or
            !std.mem.eql(u8, result.candidates[frontend.candidate_start].canonical_operation, interaction.canonical_operation) or
            !std.mem.eql(u8, result.candidates[backend.candidate_start].canonical_operation, interaction.canonical_operation))
        {
            return error.InvalidRpcContinuityInteraction;
        }
        if (previous_interaction) |value| if (lessThanInteraction({}, interaction, value)) return error.InvalidRpcContinuityInteractionOrder;
        previous_interaction = interaction;
    }
    const expected = resultFingerprint(result.observations, result.candidates, result.interactions, result.summary, result.proto_fingerprint, result.lineage_fingerprint);
    if (!std.mem.eql(u8, &expected, &result.fingerprint)) return error.InvalidRpcContinuityFingerprint;
}

fn appendLineageEntityIndexes(
    allocator: std.mem.Allocator,
    lineage: *const generated_lineage.Result,
    link: *const generated_lineage.Link,
    output: *std.ArrayList(usize),
) !void {
    for (lineage.candidatesFor(link)) |candidate| try output.append(allocator, candidate.entity_index);
}

fn findUniqueLineageBySymbol(
    lineage: *const generated_lineage.Result,
    language: generated_lineage.Language,
    kind: generated_lineage.LinkKind,
    path: []const u8,
    symbol: []const u8,
) ?*const generated_lineage.Link {
    var found: ?*const generated_lineage.Link = null;
    for (lineage.links) |*link| {
        if (link.language != language or link.kind != kind or !std.mem.eql(u8, link.generated_path, path) or
            !std.mem.eql(u8, link.generated_symbol, symbol)) continue;
        if (found != null) return null;
        found = link;
    }
    return found;
}

fn operationBelongsToService(operation: []const u8, service: []const u8) bool {
    return operation.len > service.len and std.mem.startsWith(u8, operation, service) and operation[service.len] == '/';
}

fn findTypeScriptCallBySpan(calls: []const typescript_parser.Call, span: typescript_parser.Span) ?*const typescript_parser.Call {
    for (calls) |*call| if (call.span.start_byte == span.start_byte and call.span.end_byte == span.end_byte) return call;
    return null;
}

fn findZigCallBySpan(calls: []const zig_parser.Call, span: zig_parser.Span) ?*const zig_parser.Call {
    for (calls) |*call| if (call.span.start_byte == span.start_byte and call.span.end_byte == span.end_byte) return call;
    return null;
}

fn uniqueImportBinding(bindings: []const typescript_parser.ImportBinding, local: []const u8) ?*const typescript_parser.ImportBinding {
    var found: ?*const typescript_parser.ImportBinding = null;
    for (bindings) |*binding| {
        if (!std.mem.eql(u8, binding.local, local)) continue;
        if (found != null) return null;
        found = binding;
    }
    return found;
}

fn hasShadowingDeclaration(parsed: *const typescript_parser.Result, name: []const u8, enclosing: []const u8, before_byte: usize) bool {
    for (parsed.declarations) |declaration| {
        if (declaration.name_span.start_byte >= before_byte or !std.mem.eql(u8, declaration.name, name) or
            !std.mem.eql(u8, declaration.enclosing_declaration, enclosing)) continue;
        return true;
    }
    return false;
}

fn generatedDriverRoot(callee: []const u8) ?[]const u8 {
    const suffix = ".Typed.GeneratedDriverBinding";
    if (!std.mem.endsWith(u8, callee, suffix) or callee.len <= suffix.len) return null;
    const root = callee[0 .. callee.len - suffix.len];
    return if (isIdentifier(root)) root else null;
}

const ImportedMember = struct { alias: []const u8, member: []const u8 };

fn splitImportedMember(expression: []const u8) ?ImportedMember {
    const dot = std.mem.indexOfScalar(u8, expression, '.') orelse return null;
    if (dot == 0 or dot + 1 >= expression.len or std.mem.indexOfScalar(u8, expression[dot + 1 ..], '.') != null) return null;
    const alias = expression[0..dot];
    const member = expression[dot + 1 ..];
    return if (isIdentifier(alias) and isIdentifier(member)) .{ .alias = alias, .member = member } else null;
}

fn smallestContainingBinding(bindings: []const zig_parser.Binding, span: zig_parser.Span) ?*const zig_parser.Binding {
    var best: ?*const zig_parser.Binding = null;
    for (bindings) |*binding| {
        if (span.start_byte < binding.initializer_span.start_byte or span.end_byte > binding.initializer_span.end_byte) continue;
        if (best == null or binding.initializer_span.end_byte - binding.initializer_span.start_byte <
            best.?.initializer_span.end_byte - best.?.initializer_span.start_byte) best = binding;
    }
    return best;
}

fn hasRegisterAllCall(parsed: *const zig_parser.Result, binding: *const zig_parser.Binding) bool {
    for (parsed.calls) |call| {
        const dot = std.mem.indexOfScalar(u8, call.callee, '.') orelse continue;
        if (!std.mem.eql(u8, call.callee[0..dot], binding.name) or !std.mem.eql(u8, call.callee[dot + 1 ..], "registerAll") or
            !std.mem.eql(u8, call.enclosing_declaration, binding.enclosing_declaration) or
            call.span.start_byte <= binding.span.end_byte) continue;
        return true;
    }
    return false;
}

fn uniqueDeclarationInBinding(declarations: []const zig_parser.Declaration, name: []const u8, span: zig_parser.Span) ?*const zig_parser.Declaration {
    var found: ?*const zig_parser.Declaration = null;
    for (declarations) |*declaration| {
        if (declaration.kind != .function or !std.mem.eql(u8, declaration.name, name) or
            declaration.span.start_byte < span.start_byte or declaration.span.end_byte > span.end_byte) continue;
        if (found != null) return null;
        found = declaration;
    }
    return found;
}

fn normalizeRelativeImportAlloc(allocator: std.mem.Allocator, source_path: []const u8, target: []const u8) !?[]const u8 {
    if (!(std.mem.startsWith(u8, target, "./") or std.mem.startsWith(u8, target, "../"))) return null;
    const directory = std.fs.path.dirname(source_path) orelse "";
    const joined = if (directory.len > 0) try std.fmt.allocPrint(allocator, "{s}/{s}", .{ directory, target }) else try owned.copy(u8, allocator, target);
    defer allocator.free(joined);
    var components: std.ArrayList([]const u8) = .empty;
    defer components.deinit(allocator);
    var parts = std.mem.splitScalar(u8, joined, '/');
    while (parts.next()) |part| {
        if (part.len == 0 or std.mem.eql(u8, part, ".")) continue;
        if (std.mem.eql(u8, part, "..")) {
            if (components.items.len == 0) return null;
            _ = components.pop();
            continue;
        }
        try components.append(allocator, part);
    }
    if (components.items.len == 0) return null;
    const normalized = try std.mem.join(allocator, "/", components.items);
    return @as(?[]const u8, normalized);
}

fn isIdentifier(value: []const u8) bool {
    if (value.len == 0 or !(std.ascii.isAlphabetic(value[0]) or value[0] == '_')) return false;
    for (value[1..]) |byte| if (!(std.ascii.isAlphanumeric(byte) or byte == '_')) return false;
    return true;
}

fn isTypeScript(language: Language) bool {
    return switch (language) {
        .typescript, .tsx, .javascript, .jsx => true,
        .zig, .protobuf => false,
    };
}

fn typescriptMode(language: Language) ?typescript_parser.LanguageMode {
    return switch (language) {
        .typescript => .typescript,
        .tsx => .tsx,
        .javascript => .javascript,
        .jsx => .jsx,
        .zig, .protobuf => null,
    };
}

fn lessThanDocumentIndex(corpus: *const Corpus, left: usize, right: usize) bool {
    const path_order = std.mem.order(u8, corpus.documents.items[left].path, corpus.documents.items[right].path);
    if (path_order != .eq) return path_order == .lt;
    return @intFromEnum(corpus.documents.items[left].language) < @intFromEnum(corpus.documents.items[right].language);
}

fn lessThanTempObservation(_: void, left: TempObservation, right: TempObservation) bool {
    if (left.role != right.role) return @intFromEnum(left.role) < @intFromEnum(right.role);
    const path_order = std.mem.order(u8, left.source_path, right.source_path);
    if (path_order != .eq) return path_order == .lt;
    if (left.span.start_byte != right.span.start_byte) return left.span.start_byte < right.span.start_byte;
    return std.mem.lessThan(u8, left.source_symbol, right.source_symbol);
}

fn deduplicateTempObservations(values: *std.ArrayList(TempObservation)) void {
    var write: usize = 0;
    for (values.items) |value| {
        if (write > 0 and sameTempObservation(values.items[write - 1], value)) continue;
        values.items[write] = value;
        write += 1;
    }
    values.items.len = write;
}

fn sameTempObservation(left: TempObservation, right: TempObservation) bool {
    return left.role == right.role and std.mem.eql(u8, left.source_path, right.source_path) and
        std.mem.eql(u8, left.source_symbol, right.source_symbol) and left.span.start_byte == right.span.start_byte and
        left.span.end_byte == right.span.end_byte and std.mem.eql(usize, left.entity_indexes, right.entity_indexes);
}

fn deduplicateIndexes(values: *std.ArrayList(usize)) void {
    var write: usize = 0;
    for (values.items) |value| {
        if (write > 0 and values.items[write - 1] == value) continue;
        values.items[write] = value;
        write += 1;
    }
    values.items.len = write;
}

fn lessThanOrEqualObservation(left: Observation, right: Observation) bool {
    if (left.role != right.role) return @intFromEnum(left.role) < @intFromEnum(right.role);
    const path_order = std.mem.order(u8, left.source_path, right.source_path);
    if (path_order != .eq) return path_order == .lt;
    if (left.span.start_byte != right.span.start_byte) return left.span.start_byte < right.span.start_byte;
    return std.mem.order(u8, left.source_symbol, right.source_symbol) != .gt;
}

fn lessThanInteraction(_: void, left: Interaction, right: Interaction) bool {
    const operation_order = std.mem.order(u8, left.canonical_operation, right.canonical_operation);
    if (operation_order != .eq) return operation_order == .lt;
    if (left.frontend_observation_index != right.frontend_observation_index) return left.frontend_observation_index < right.frontend_observation_index;
    return left.backend_observation_index < right.backend_observation_index;
}

fn hasInteraction(values: []const Interaction, frontend: usize, backend: usize, operation: []const u8) bool {
    for (values) |value| if (value.frontend_observation_index == frontend and value.backend_observation_index == backend and
        std.mem.eql(u8, value.canonical_operation, operation)) return true;
    return false;
}

fn resultFingerprint(
    observations: []const Observation,
    candidates: []const Candidate,
    interactions: []const Interaction,
    summary: Summary,
    proto_fingerprint: [32]u8,
    lineage_fingerprint: [32]u8,
) [32]u8 {
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    updateBytes(&hasher, schema);
    updateBytes(&hasher, analyzer_version);
    hasher.update(&proto_fingerprint);
    hasher.update(&lineage_fingerprint);
    for (observations) |observation| {
        updateU64(&hasher, @intFromEnum(observation.role));
        updateBytes(&hasher, observation.source_path);
        updateBytes(&hasher, observation.source_symbol);
        updateSpan(&hasher, observation.span);
        updateBytes(&hasher, observation.recipe);
        updateU64(&hasher, @intFromEnum(observation.status));
        updateU64(&hasher, @intCast(observation.candidate_start));
        updateU64(&hasher, @intCast(observation.candidate_count));
    }
    for (candidates) |candidate| {
        updateU64(&hasher, @intCast(candidate.observation_index));
        updateU64(&hasher, @intCast(candidate.entity_index));
        updateBytes(&hasher, candidate.canonical_operation);
        updateBytes(&hasher, candidate.proto_source_path);
        updateU64(&hasher, @intCast(candidate.rank));
    }
    for (interactions) |interaction| {
        updateBytes(&hasher, interaction.canonical_operation);
        updateBytes(&hasher, interaction.request_type);
        updateBytes(&hasher, interaction.response_type);
        updateU64(&hasher, @intCast(interaction.frontend_observation_index));
        updateU64(&hasher, @intCast(interaction.backend_observation_index));
    }
    updateU64(&hasher, @intCast(summary.documents));
    updateU64(&hasher, @intCast(summary.observations));
    updateU64(&hasher, @intCast(summary.frontend_invocations));
    updateU64(&hasher, @intCast(summary.backend_handlers));
    updateU64(&hasher, @intCast(summary.resolved));
    updateU64(&hasher, @intCast(summary.ambiguous));
    updateU64(&hasher, @intCast(summary.candidates));
    updateU64(&hasher, @intCast(summary.interactions));
    var digest: [32]u8 = @splat(0);
    hasher.final(&digest);
    return digest;
}

fn updateSpan(hasher: *std.crypto.hash.sha2.Sha256, span: SourceSpan) void {
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

fn validPath(path: []const u8) bool {
    if (path.len == 0 or std.fs.path.isAbsolute(path) or std.mem.indexOfScalar(u8, path, '\\') != null) return false;
    var parts = std.mem.splitScalar(u8, path, '/');
    while (parts.next()) |part| if (part.len == 0 or std.mem.eql(u8, part, ".") or std.mem.eql(u8, part, "..")) return false;
    return true;
}

fn deinitObservationList(allocator: std.mem.Allocator, values: *std.ArrayList(Observation)) void {
    deinitObservations(allocator, values.items);
    values.deinit(allocator);
}

fn deinitCandidateList(allocator: std.mem.Allocator, values: *std.ArrayList(Candidate)) void {
    deinitCandidates(allocator, values.items);
    values.deinit(allocator);
}

fn deinitInteractionList(allocator: std.mem.Allocator, values: *std.ArrayList(Interaction)) void {
    deinitInteractions(allocator, values.items);
    values.deinit(allocator);
}

fn deinitObservations(allocator: std.mem.Allocator, values: []const Observation) void {
    for (values) |value| {
        allocator.free(value.source_path);
        allocator.free(value.source_symbol);
        allocator.free(value.recipe);
    }
}

fn deinitCandidates(allocator: std.mem.Allocator, values: []const Candidate) void {
    for (values) |value| {
        allocator.free(value.canonical_operation);
        allocator.free(value.proto_source_path);
    }
}

fn deinitInteractions(allocator: std.mem.Allocator, values: []const Interaction) void {
    for (values) |value| {
        allocator.free(value.canonical_operation);
        allocator.free(value.request_type);
        allocator.free(value.response_type);
    }
}
