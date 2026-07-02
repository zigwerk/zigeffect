const std = @import("std");
const fx = @import("zigeffect");

const AlertCapture = struct {
    count: usize = 0,
    last_kind: ?fx.CausalEventKind = null,

    fn sink(self: *AlertCapture) fx.CausalOpsAlertSink {
        return .{
            .state = self,
            .emit = emit,
        };
    }

    fn emit(raw: ?*anyopaque, event: fx.CausalEvent) anyerror!void {
        const self: *AlertCapture = @ptrCast(@alignCast(raw.?));
        self.count += 1;
        self.last_kind = event.kind;
    }
};

fn hasAlertHeader(headers: []const fx.CausalOpsAlertHttpHeader, name: []const u8, value: []const u8) bool {
    for (headers) |header| {
        if (std.mem.eql(u8, header.name, name) and std.mem.eql(u8, header.value, value)) {
            return true;
        }
    }
    return false;
}

test "ops alert sink emits alert facts only" {
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    _ = try store.record(.{ .kind = .run_started, .run_id = 1, .label = "not alert" });
    _ = try store.record(.{ .kind = .alert_emitted, .label = "retention threshold", .type_name = "retention.threshold" });

    var capture = AlertCapture{};
    const report = try fx.emitCausalOpsAlerts(&store, capture.sink());

    try std.testing.expectEqual(@as(usize, 2), report.scanned_events);
    try std.testing.expectEqual(@as(usize, 1), report.emitted_alerts);
    try std.testing.expectEqual(@as(usize, 1), capture.count);
    try std.testing.expectEqual(fx.CausalEventKind.alert_emitted, capture.last_kind.?);
}

test "ops runbook json summarizes deployment retention and redacts secrets" {
    const json = try fx.formatCausalOpsRunbookJson(std.testing.allocator, .{
        .deployment = .{
            .service = "zigeffect",
            .environment = "prod",
            .region = "eu-west",
            .cluster_id = "password=hunter2",
        },
        .retention = .{
            .max_events = 100,
            .alert_threshold = 3,
        },
        .retained_events = 120,
        .alert_count = 2,
    });
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"schema\":\"zigeffect.causal.ops-runbook.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"service\":\"zigeffect\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"max_events\":100") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"alert_count\":2") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "hunter2") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, fx.causal_redaction_marker) != null);
}

test "ops runbook json escapes control bytes into parseable output" {
    const json = try fx.formatCausalOpsRunbookJson(std.testing.allocator, .{
        .deployment = .{
            .service = "zigeffect",
            .environment = "prod",
            .region = "eu\x1bwest",
            .cluster_id = "cluster-a",
        },
        .retention = .{
            .max_events = 100,
            .alert_threshold = 3,
        },
        .retained_events = 10,
        .alert_count = 0,
    });
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\\u001b") != null);
    try std.testing.expect(std.mem.indexOfScalar(u8, json, 0x1b) == null);

    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, json, .{});
    defer parsed.deinit();
}

test "ops runbook json includes operator endpoint metadata" {
    const json = try fx.formatCausalOpsRunbookJson(std.testing.allocator, .{
        .deployment = .{
            .service = "zigeffect",
            .environment = "prod",
            .region = "eu-west",
            .cluster_id = "cluster-a",
        },
        .retention = .{
            .max_events = 100,
            .alert_threshold = 3,
        },
        .retained_events = 80,
        .alert_count = 1,
        .endpoints = .{
            .artifact_endpoint_path = "/causal-artifacts",
            .alert_delivery_kind = "webhook",
            .alert_endpoint_id = "pager-duty-primary",
        },
    });
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"operator_endpoints\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"artifact_endpoint_path\":\"/causal-artifacts\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"alert_delivery_kind\":\"webhook\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"alert_endpoint_id\":\"pager-duty-primary\"") != null);
}

test "ops alert delivery json redacts alert evidence for external adapters" {
    const json = try fx.formatCausalOpsAlertDeliveryJson(std.testing.allocator, .{
        .deployment = .{
            .service = "zigeffect",
            .environment = "prod",
            .region = "eu-west",
            .cluster_id = "cluster-a",
        },
        .delivery_kind = "webhook",
        .endpoint_id = "pager-duty-primary",
        .event = .{
            .id = 42,
            .kind = .alert_emitted,
            .status = "emitted",
            .label = "retention password=sentinel-secret threshold",
            .type_name = "retention.threshold",
            .redacted_detail = "token=sentinel-secret",
        },
    });
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"schema\":\"zigeffect.causal.ops-alert-delivery.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"delivery_kind\":\"webhook\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"endpoint_id\":\"pager-duty-primary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"event_id\":42") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "sentinel-secret") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, fx.causal_redaction_marker) != null);
}

const DeliveryCapture = struct {
    delivered: usize = 0,
    saw_delivery_schema: bool = false,
    saw_secret: bool = false,

    fn sink(self: *DeliveryCapture) fx.CausalOpsAlertDeliverySink {
        return .{
            .state = self,
            .deliver = deliver,
        };
    }

    fn deliver(raw: ?*anyopaque, json: []const u8) anyerror!void {
        const self: *DeliveryCapture = @ptrCast(@alignCast(raw.?));
        self.delivered += 1;
        self.saw_delivery_schema = std.mem.indexOf(u8, json, "\"schema\":\"zigeffect.causal.ops-alert-delivery.v1\"") != null;
        self.saw_secret = std.mem.indexOf(u8, json, "sentinel-secret") != null;
    }
};

test "ops alert delivery sink receives redacted delivery envelope" {
    var capture = DeliveryCapture{};

    try fx.deliverCausalOpsAlert(std.testing.allocator, .{
        .deployment = .{
            .service = "zigeffect",
            .environment = "prod",
            .region = "eu-west",
            .cluster_id = "cluster-a",
        },
        .delivery_kind = "webhook",
        .endpoint_id = "pager-duty-primary",
        .event = .{
            .id = 43,
            .kind = .alert_emitted,
            .status = "emitted",
            .label = "retention password=sentinel-secret threshold",
            .type_name = "retention.threshold",
            .redacted_detail = "token=sentinel-secret",
        },
    }, capture.sink());

    try std.testing.expectEqual(@as(usize, 1), capture.delivered);
    try std.testing.expect(capture.saw_delivery_schema);
    try std.testing.expect(!capture.saw_secret);
}

const WebhookCapture = struct {
    sent: usize = 0,
    saw_method: bool = false,
    saw_url: bool = false,
    saw_headers: bool = false,
    saw_schema: bool = false,
    saw_secret: bool = false,

    fn sink(self: *WebhookCapture) fx.CausalOpsAlertHttpSink {
        return .{
            .state = self,
            .send = send,
        };
    }

    fn send(raw: ?*anyopaque, request: fx.CausalOpsAlertHttpRequest) anyerror!void {
        const self: *WebhookCapture = @ptrCast(@alignCast(raw.?));
        self.sent += 1;
        self.saw_method = std.mem.eql(u8, request.method, "POST");
        self.saw_url = std.mem.eql(u8, request.url, "https://alerts.internal/hook");
        self.saw_headers =
            hasAlertHeader(request.headers, "content-type", "application/json") and
            hasAlertHeader(request.headers, "cache-control", "no-store") and
            hasAlertHeader(request.headers, "x-content-type-options", "nosniff");
        self.saw_schema = std.mem.indexOf(u8, request.body, "\"schema\":\"zigeffect.causal.ops-alert-delivery.v1\"") != null;
        self.saw_secret = std.mem.indexOf(u8, request.body, "sentinel-secret") != null;
    }
};

test "ops alert webhook adapter sends redacted http request shape" {
    var capture = WebhookCapture{};

    try fx.deliverCausalOpsAlertWebhook(std.testing.allocator, .{
        .endpoint_url = "https://alerts.internal/hook",
        .delivery = .{
            .deployment = .{
                .service = "zigeffect",
                .environment = "prod",
                .region = "eu-west",
                .cluster_id = "cluster-a",
            },
            .delivery_kind = "webhook",
            .endpoint_id = "pager-duty-primary",
            .event = .{
                .id = 44,
                .kind = .alert_emitted,
                .status = "emitted",
                .label = "retention password=sentinel-secret threshold",
                .type_name = "retention.threshold",
                .redacted_detail = "token=sentinel-secret",
            },
        },
    }, capture.sink());

    try std.testing.expectEqual(@as(usize, 1), capture.sent);
    try std.testing.expect(capture.saw_method);
    try std.testing.expect(capture.saw_url);
    try std.testing.expect(capture.saw_headers);
    try std.testing.expect(capture.saw_schema);
    try std.testing.expect(!capture.saw_secret);
}

test "ops alert provider adapter formats slack and pagerduty request shapes" {
    const delivery = fx.CausalOpsAlertDeliveryOptions{
        .deployment = .{
            .service = "zigeffect",
            .environment = "prod",
            .region = "eu-west",
            .cluster_id = "cluster-a",
        },
        .delivery_kind = "provider",
        .endpoint_id = "primary-alerts",
        .event = .{
            .id = 45,
            .kind = .alert_emitted,
            .status = "emitted",
            .label = "retention password=sentinel-secret threshold",
            .type_name = "retention.threshold",
            .redacted_detail = "token=sentinel-secret",
        },
    };

    var slack = try fx.formatCausalOpsAlertProviderRequest(std.testing.allocator, .{
        .provider = .slack_webhook,
        .endpoint_url = "https://hooks.slack.test/services/primary",
        .delivery = delivery,
    });
    defer slack.deinit();

    try std.testing.expectEqualStrings("POST", slack.method);
    try std.testing.expectEqualStrings("https://hooks.slack.test/services/primary", slack.url);
    try std.testing.expect(hasAlertHeader(slack.headers, "content-type", "application/json"));
    try std.testing.expect(hasAlertHeader(slack.headers, "cache-control", "no-store"));
    try std.testing.expect(hasAlertHeader(slack.headers, "x-content-type-options", "nosniff"));
    try std.testing.expect(std.mem.indexOf(u8, slack.body, "\"text\":\"zigeffect alert 45\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, slack.body, "\"provider\":\"slack_webhook\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, slack.body, "sentinel-secret") == null);
    try std.testing.expect(std.mem.indexOf(u8, slack.body, fx.causal_redaction_marker) != null);

    var pagerduty = try fx.formatCausalOpsAlertProviderRequest(std.testing.allocator, .{
        .provider = .pagerduty_events_v2,
        .endpoint_url = "https://events.pagerduty.test/v2/enqueue",
        .secret_ref = "pd-routing-key-prod",
        .delivery = delivery,
    });
    defer pagerduty.deinit();

    try std.testing.expectEqualStrings("POST", pagerduty.method);
    try std.testing.expectEqualStrings("https://events.pagerduty.test/v2/enqueue", pagerduty.url);
    try std.testing.expect(hasAlertHeader(pagerduty.headers, "content-type", "application/json"));
    try std.testing.expect(std.mem.indexOf(u8, pagerduty.body, "\"event_action\":\"trigger\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, pagerduty.body, "\"routing_key_secret_ref\":\"pd-routing-key-prod\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, pagerduty.body, "\"severity\":\"warning\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, pagerduty.body, "sentinel-secret") == null);
    try std.testing.expect(std.mem.indexOf(u8, pagerduty.body, fx.causal_redaction_marker) != null);
}

const ProviderSecretDeliveryCapture = struct {
    resolved: usize = 0,
    sent: usize = 0,
    saw_ref: bool = false,
    saw_method: bool = false,
    saw_headers: bool = false,
    saw_routing_key: bool = false,
    saw_secret_ref_field: bool = false,
    saw_secret_alert_evidence: bool = false,

    fn resolver(self: *ProviderSecretDeliveryCapture) fx.CausalOpsAlertProviderSecretResolver {
        return .{ .state = self, .resolve = resolve };
    }

    fn sink(self: *ProviderSecretDeliveryCapture) fx.CausalOpsAlertHttpSink {
        return .{ .state = self, .send = send };
    }

    fn resolve(raw: ?*anyopaque, secret_ref: []const u8) anyerror![]const u8 {
        const self: *ProviderSecretDeliveryCapture = @ptrCast(@alignCast(raw.?));
        self.resolved += 1;
        self.saw_ref = std.mem.eql(u8, secret_ref, "pd-routing-key-prod");
        return "pd_test_routing_key_123";
    }

    fn send(raw: ?*anyopaque, request: fx.CausalOpsAlertHttpRequest) anyerror!void {
        const self: *ProviderSecretDeliveryCapture = @ptrCast(@alignCast(raw.?));
        self.sent += 1;
        self.saw_method = std.mem.eql(u8, request.method, "POST");
        self.saw_headers =
            hasAlertHeader(request.headers, "content-type", "application/json") and
            hasAlertHeader(request.headers, "cache-control", "no-store") and
            hasAlertHeader(request.headers, "x-content-type-options", "nosniff");
        self.saw_routing_key = std.mem.indexOf(u8, request.body, "\"routing_key\":\"pd_test_routing_key_123\"") != null;
        self.saw_secret_ref_field = std.mem.indexOf(u8, request.body, "routing_key_secret_ref") != null;
        self.saw_secret_alert_evidence = std.mem.indexOf(u8, request.body, "sentinel-secret") != null;
    }
};

test "ops alert provider delivery injects pagerduty secret through caller-owned resolver" {
    var capture = ProviderSecretDeliveryCapture{};

    try fx.deliverCausalOpsAlertProviderWithSecret(std.testing.allocator, .{
        .provider = .pagerduty_events_v2,
        .endpoint_url = "https://events.pagerduty.test/v2/enqueue",
        .secret_ref = "pd-routing-key-prod",
        .delivery = .{
            .deployment = .{
                .service = "zigeffect",
                .environment = "prod",
                .region = "eu-west",
                .cluster_id = "cluster-a",
            },
            .delivery_kind = "provider",
            .endpoint_id = "primary-alerts",
            .event = .{
                .id = 46,
                .kind = .alert_emitted,
                .status = "emitted",
                .label = "retention password=sentinel-secret threshold",
                .type_name = "retention.threshold",
                .redacted_detail = "token=sentinel-secret",
            },
        },
    }, capture.resolver(), capture.sink());

    try std.testing.expectEqual(@as(usize, 1), capture.resolved);
    try std.testing.expectEqual(@as(usize, 1), capture.sent);
    try std.testing.expect(capture.saw_ref);
    try std.testing.expect(capture.saw_method);
    try std.testing.expect(capture.saw_headers);
    try std.testing.expect(capture.saw_routing_key);
    try std.testing.expect(!capture.saw_secret_ref_field);
    try std.testing.expect(!capture.saw_secret_alert_evidence);
}

const ProviderSecretRetryCapture = struct {
    resolved: usize = 0,
    sent: usize = 0,
    saw_routing_key: bool = false,
    saw_secret_alert_evidence: bool = false,

    fn resolver(self: *ProviderSecretRetryCapture) fx.CausalOpsAlertProviderSecretResolver {
        return .{ .state = self, .resolve = resolve };
    }

    fn sink(self: *ProviderSecretRetryCapture) fx.CausalOpsAlertHttpSink {
        return .{ .state = self, .send = send };
    }

    fn resolve(raw: ?*anyopaque, secret_ref: []const u8) anyerror![]const u8 {
        const self: *ProviderSecretRetryCapture = @ptrCast(@alignCast(raw.?));
        self.resolved += 1;
        try std.testing.expectEqualStrings("pd-routing-key-prod", secret_ref);
        return "pd_retry_routing_key_456";
    }

    fn send(raw: ?*anyopaque, request: fx.CausalOpsAlertHttpRequest) anyerror!void {
        const self: *ProviderSecretRetryCapture = @ptrCast(@alignCast(raw.?));
        self.sent += 1;
        self.saw_routing_key = self.saw_routing_key or std.mem.indexOf(u8, request.body, "\"routing_key\":\"pd_retry_routing_key_456\"") != null;
        self.saw_secret_alert_evidence = self.saw_secret_alert_evidence or std.mem.indexOf(u8, request.body, "sentinel-secret") != null;
        if (self.sent == 1) return error.TransientAlertSinkFailure;
    }
};

const ProviderSecretPermanentResolverFailureCapture = struct {
    resolved: usize = 0,
    sent: usize = 0,

    fn resolver(self: *ProviderSecretPermanentResolverFailureCapture) fx.CausalOpsAlertProviderSecretResolver {
        return .{ .state = self, .resolve = resolve };
    }

    fn sink(self: *ProviderSecretPermanentResolverFailureCapture) fx.CausalOpsAlertHttpSink {
        return .{ .state = self, .send = send };
    }

    fn resolve(raw: ?*anyopaque, secret_ref: []const u8) anyerror![]const u8 {
        const self: *ProviderSecretPermanentResolverFailureCapture = @ptrCast(@alignCast(raw.?));
        self.resolved += 1;
        try std.testing.expectEqualStrings("pd-routing-key-prod", secret_ref);
        return error.PermanentSecretStoreFailure;
    }

    fn send(raw: ?*anyopaque, request: fx.CausalOpsAlertHttpRequest) anyerror!void {
        _ = request;
        const self: *ProviderSecretPermanentResolverFailureCapture = @ptrCast(@alignCast(raw.?));
        self.sent += 1;
    }
};

test "ops alert provider secret delivery retries transient sink failures" {
    var capture = ProviderSecretRetryCapture{};

    const report = try fx.deliverCausalOpsAlertProviderWithSecretRetrying(std.testing.allocator, .{
        .provider = .pagerduty_events_v2,
        .endpoint_url = "https://events.pagerduty.test/v2/enqueue",
        .secret_ref = "pd-routing-key-prod",
        .delivery = .{
            .deployment = .{
                .service = "zigeffect",
                .environment = "prod",
                .region = "eu-west",
                .cluster_id = "cluster-a",
            },
            .delivery_kind = "provider",
            .endpoint_id = "primary-alerts",
            .event = .{
                .id = 47,
                .kind = .alert_emitted,
                .status = "emitted",
                .label = "retention password=sentinel-secret threshold",
                .type_name = "retention.threshold",
                .redacted_detail = "token=sentinel-secret",
            },
        },
    }, capture.resolver(), capture.sink(), .{ .max_attempts = 2 });

    try std.testing.expectEqual(@as(usize, 2), report.attempts);
    try std.testing.expectEqual(@as(usize, 1), report.failures);
    try std.testing.expect(report.delivered);
    try std.testing.expectEqualStrings("TransientAlertSinkFailure", report.last_error_name);
    try std.testing.expectEqual(@as(usize, 2), capture.resolved);
    try std.testing.expectEqual(@as(usize, 2), capture.sent);
    try std.testing.expect(capture.saw_routing_key);
    try std.testing.expect(!capture.saw_secret_alert_evidence);
}

test "ops alert provider secret delivery does not retry permanent resolver failures" {
    var capture = ProviderSecretPermanentResolverFailureCapture{};

    const result = fx.deliverCausalOpsAlertProviderWithSecretRetrying(std.testing.allocator, .{
        .provider = .pagerduty_events_v2,
        .endpoint_url = "https://events.pagerduty.test/v2/enqueue",
        .secret_ref = "pd-routing-key-prod",
        .delivery = .{
            .deployment = .{
                .service = "zigeffect",
                .environment = "prod",
                .region = "eu-west",
                .cluster_id = "cluster-a",
            },
            .delivery_kind = "provider",
            .endpoint_id = "primary-alerts",
            .event = .{
                .id = 47,
                .kind = .alert_emitted,
                .status = "emitted",
                .label = "retention threshold",
                .type_name = "retention.threshold",
                .redacted_detail = "secret_ref=pd-routing-key-prod",
            },
        },
    }, capture.resolver(), capture.sink(), .{ .max_attempts = 3 });

    try std.testing.expectError(error.PermanentSecretStoreFailure, result);
    try std.testing.expectEqual(@as(usize, 1), capture.resolved);
    try std.testing.expectEqual(@as(usize, 0), capture.sent);
}
