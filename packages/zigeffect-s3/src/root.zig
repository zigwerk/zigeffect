const std = @import("std");
pub const zstd = @import("zigeffect_std");
pub const capability = zstd.Capability.Descriptor{ .id = "zigeffect-s3.object-storage", .kind = .object_storage, .maturity = .production_candidate, .package = "zigeffect-s3", .version = "0.1.0", .features = &.{ "s3-compatible", "sigv4", "put", "get", "head", "delete", "list", "multipart", "sha256" }, .side_effects = .real, .conformance = .{ .schema = "zigeffect.s3-live-conformance", .version = 1, .receipt = "conformance/minio-live.v1.json", .authority = .live_external, .observed_at_ms = 1783777336000, .valid_until_ms = 1791553336000, .content_sha256 = "sha256:6767bb1a464008824bb38d42eb880fbd451ffe2d55ecbb3271cd8d4e2f4edfc2" }, .limitations = &.{ "plain HTTP path-style endpoints only", "multipart coordinator state is process-local", "resumable multipart and versioned buckets are not implemented" } };
pub const Options = struct { host: []const u8 = "127.0.0.1", port: u16 = 9000, bucket: []const u8, region: []const u8 = "us-east-1", access_key: []const u8, secret_key: []const u8, max_response_bytes: usize = 128 * 1024 * 1024 };
const Upload = struct { key: []u8, remote_id: []u8, parts: std.ArrayList(UploadedPart) = .empty };
const UploadedPart = struct { number: u32, etag: []u8 };
const Response = struct {
    allocator: std.mem.Allocator,
    status: u16,
    headers: []u8,
    body: []u8,
    pub fn deinit(self: *Response) void {
        self.allocator.free(self.headers);
        self.allocator.free(self.body);
        self.* = undefined;
    }
    fn header(self: Response, name: []const u8) ?[]const u8 {
        var lines = std.mem.splitSequence(u8, self.headers, "\r\n");
        _ = lines.next();
        while (lines.next()) |line| {
            const colon = std.mem.indexOfScalar(u8, line, ':') orelse continue;
            if (std.ascii.eqlIgnoreCase(line[0..colon], name)) return std.mem.trim(u8, line[colon + 1 ..], " \t");
        }
        return null;
    }
};
pub const Client = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    options: Options,
    uploads: std.AutoHashMap(u64, Upload),
    next_upload_id: u64 = 1,
    mutex: std.atomic.Mutex = .unlocked,
    pub fn init(allocator: std.mem.Allocator, io: std.Io, options: Options) !Client {
        if (options.host.len == 0 or options.port == 0 or options.bucket.len == 0 or options.region.len == 0 or options.access_key.len == 0 or options.secret_key.len < 8 or options.max_response_bytes == 0) return error.InvalidS3Options;
        return .{ .allocator = allocator, .io = io, .options = options, .uploads = .init(allocator) };
    }
    pub fn deinit(self: *Client) void {
        var iterator = self.uploads.valueIterator();
        while (iterator.next()) |upload| self.freeUpload(upload.*);
        self.uploads.deinit();
    }
    pub fn asObjectStorage(self: *Client) zstd.ObjectStorage.Service {
        return zstd.ObjectStorage.Service.from(Client, self);
    }
    pub fn put(self: *Client, key: []const u8, bytes: []const u8, options: zstd.ObjectStorage.PutOptions) !zstd.ObjectStorage.Metadata {
        try validateKey(key);
        const digest = zstd.ObjectStorage.sha256(bytes);
        if (options.expected_sha256) |expected| if (!std.crypto.timing_safe.eql([32]u8, expected, digest)) return error.ChecksumMismatch;
        var response = try self.request("PUT", key, "", bytes, options.content_type);
        defer response.deinit();
        try expectStatus(response.status, &.{200});
        return .{ .key = key, .size = bytes.len, .sha256 = digest, .content_type = options.content_type, .version = 1 };
    }
    pub fn getAlloc(self: *Client, allocator: std.mem.Allocator, key: []const u8) !?zstd.ObjectStorage.Object {
        try validateKey(key);
        var response = try self.request("GET", key, "", "", null);
        defer response.deinit();
        if (response.status == 404) return null;
        try expectStatus(response.status, &.{200});
        const owned_key = try allocator.dupe(u8, key);
        errdefer allocator.free(owned_key);
        const bytes = try allocator.dupe(u8, response.body);
        errdefer allocator.free(bytes);
        const content_type = if (response.header("content-type")) |value| try allocator.dupe(u8, value) else null;
        return .{ .allocator = allocator, .metadata = .{ .key = owned_key, .size = bytes.len, .sha256 = zstd.ObjectStorage.sha256(bytes), .content_type = content_type, .version = 1 }, .bytes = bytes };
    }
    pub fn head(self: *Client, key: []const u8) !?zstd.ObjectStorage.Metadata {
        try validateKey(key);
        var response = try self.request("HEAD", key, "", "", null);
        defer response.deinit();
        if (response.status == 404) return null;
        try expectStatus(response.status, &.{200});
        const size = if (response.header("content-length")) |value| try std.fmt.parseUnsigned(usize, value, 10) else 0;
        return .{ .key = key, .size = size, .sha256 = [_]u8{0} ** 32, .content_type = response.header("content-type"), .version = 1 };
    }
    pub fn delete(self: *Client, key: []const u8) !bool {
        try validateKey(key);
        const existed = (try self.head(key)) != null;
        var response = try self.request("DELETE", key, "", "", null);
        defer response.deinit();
        try expectStatus(response.status, &.{ 204, 200 });
        return existed;
    }
    pub fn listAlloc(self: *Client, allocator: std.mem.Allocator, prefix: []const u8, limit: usize) !zstd.ObjectStorage.ListResult {
        if (limit == 0 or limit > 1000) return error.InvalidListLimit;
        const encoded_prefix = try uriEncodeAlloc(self.allocator, prefix, true);
        defer self.allocator.free(encoded_prefix);
        const query = try std.fmt.allocPrint(self.allocator, "list-type=2&max-keys={d}&prefix={s}", .{ limit, encoded_prefix });
        defer self.allocator.free(query);
        var response = try self.request("GET", "", query, "", null);
        defer response.deinit();
        try expectStatus(response.status, &.{200});
        var keys = std.ArrayList([]u8).empty;
        errdefer {
            for (keys.items) |key| allocator.free(key);
            keys.deinit(allocator);
        }
        var offset: usize = 0;
        while (std.mem.indexOfPos(u8, response.body, offset, "<Key>")) |start_tag| {
            const start = start_tag + 5;
            const end = std.mem.indexOfPos(u8, response.body, start, "</Key>") orelse return error.InvalidS3Response;
            try keys.append(allocator, try xmlDecodeAlloc(allocator, response.body[start..end]));
            offset = end + 6;
        }
        return .{ .allocator = allocator, .keys = try keys.toOwnedSlice(allocator) };
    }
    pub fn beginMultipart(self: *Client, key: []const u8) !zstd.ObjectStorage.Multipart {
        try validateKey(key);
        var response = try self.request("POST", key, "uploads=", "", null);
        defer response.deinit();
        try expectStatus(response.status, &.{200});
        const remote = xmlValue(response.body, "UploadId") orelse return error.InvalidS3Response;
        self.lock();
        defer self.mutex.unlock();
        const id = self.next_upload_id;
        self.next_upload_id += 1;
        const owned_key = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(owned_key);
        const owned_remote = try self.allocator.dupe(u8, remote);
        errdefer self.allocator.free(owned_remote);
        try self.uploads.put(id, .{ .key = owned_key, .remote_id = owned_remote });
        return .{ .upload_id = id, .key = key };
    }
    pub fn uploadPart(self: *Client, id: u64, part: zstd.ObjectStorage.Part) !void {
        if (part.number == 0 or !std.crypto.timing_safe.eql([32]u8, part.sha256, zstd.ObjectStorage.sha256(part.bytes))) return error.InvalidMultipartPart;
        self.lock();
        const upload = self.uploads.get(id) orelse {
            self.mutex.unlock();
            return error.UploadNotFound;
        };
        const key = try self.allocator.dupe(u8, upload.key);
        const remote = try self.allocator.dupe(u8, upload.remote_id);
        self.mutex.unlock();
        defer self.allocator.free(key);
        defer self.allocator.free(remote);
        const encoded_id = try uriEncodeAlloc(self.allocator, remote, true);
        defer self.allocator.free(encoded_id);
        const query = try std.fmt.allocPrint(self.allocator, "partNumber={d}&uploadId={s}", .{ part.number, encoded_id });
        defer self.allocator.free(query);
        var response = try self.request("PUT", key, query, part.bytes, null);
        defer response.deinit();
        try expectStatus(response.status, &.{200});
        const etag = response.header("etag") orelse return error.InvalidS3Response;
        self.lock();
        defer self.mutex.unlock();
        const target = self.uploads.getPtr(id) orelse return error.UploadNotFound;
        const owned_etag = try self.allocator.dupe(u8, etag);
        errdefer self.allocator.free(owned_etag);
        try target.parts.append(self.allocator, .{ .number = part.number, .etag = owned_etag });
    }
    pub fn completeMultipart(self: *Client, id: u64, options: zstd.ObjectStorage.PutOptions) !zstd.ObjectStorage.Metadata {
        self.lock();
        const removed = self.uploads.fetchRemove(id) orelse {
            self.mutex.unlock();
            return error.UploadNotFound;
        };
        const upload = removed.value;
        self.mutex.unlock();
        defer self.freeUpload(upload);
        std.mem.sort(UploadedPart, upload.parts.items, {}, struct {
            fn less(_: void, left: UploadedPart, right: UploadedPart) bool {
                return left.number < right.number;
            }
        }.less);
        var xml = std.ArrayList(u8).empty;
        defer xml.deinit(self.allocator);
        try xml.appendSlice(self.allocator, "<CompleteMultipartUpload>");
        for (upload.parts.items, 0..) |part, index| {
            if (part.number != index + 1) return error.MissingMultipartPart;
            try xml.print(self.allocator, "<Part><PartNumber>{d}</PartNumber><ETag>{s}</ETag></Part>", .{ part.number, part.etag });
        }
        try xml.appendSlice(self.allocator, "</CompleteMultipartUpload>");
        const encoded_id = try uriEncodeAlloc(self.allocator, upload.remote_id, true);
        defer self.allocator.free(encoded_id);
        const query = try std.fmt.allocPrint(self.allocator, "uploadId={s}", .{encoded_id});
        defer self.allocator.free(query);
        var response = try self.request("POST", upload.key, query, xml.items, "application/xml");
        defer response.deinit();
        try expectStatus(response.status, &.{200});
        const metadata = (try self.head(upload.key)) orelse return error.InvalidS3Response;
        _ = options;
        return metadata;
    }
    fn request(self: *Client, method: []const u8, key: []const u8, query: []const u8, body: []const u8, content_type: ?[]const u8) !Response {
        const encoded_key = try uriEncodeAlloc(self.allocator, key, false);
        defer self.allocator.free(encoded_key);
        const path = if (encoded_key.len == 0) try std.fmt.allocPrint(self.allocator, "/{s}", .{self.options.bucket}) else try std.fmt.allocPrint(self.allocator, "/{s}/{s}", .{ self.options.bucket, encoded_key });
        defer self.allocator.free(path);
        const now_ms = wallMillis();
        var amz_date: [16]u8 = undefined;
        var date: [8]u8 = undefined;
        formatAwsDate(now_ms / 1000, &amz_date, &date);
        const payload_digest = zstd.ObjectStorage.sha256(body);
        var payload_hex: [64]u8 = undefined;
        hexLower(&payload_digest, &payload_hex);
        const host_header = try std.fmt.allocPrint(self.allocator, "{s}:{d}", .{ self.options.host, self.options.port });
        defer self.allocator.free(host_header);
        const canonical_headers = try std.fmt.allocPrint(self.allocator, "host:{s}\nx-amz-content-sha256:{s}\nx-amz-date:{s}\n", .{ host_header, payload_hex, amz_date });
        defer self.allocator.free(canonical_headers);
        const canonical = try std.fmt.allocPrint(self.allocator, "{s}\n{s}\n{s}\n{s}\nhost;x-amz-content-sha256;x-amz-date\n{s}", .{ method, path, query, canonical_headers, payload_hex });
        defer self.allocator.free(canonical);
        const canonical_digest = zstd.ObjectStorage.sha256(canonical);
        var canonical_hex: [64]u8 = undefined;
        hexLower(&canonical_digest, &canonical_hex);
        const scope = try std.fmt.allocPrint(self.allocator, "{s}/{s}/s3/aws4_request", .{ date, self.options.region });
        defer self.allocator.free(scope);
        const string_to_sign = try std.fmt.allocPrint(self.allocator, "AWS4-HMAC-SHA256\n{s}\n{s}\n{s}", .{ amz_date, scope, canonical_hex });
        defer self.allocator.free(string_to_sign);
        const signature = signatureV4(self.options.secret_key, &date, self.options.region, string_to_sign);
        var signature_hex: [64]u8 = undefined;
        hexLower(&signature, &signature_hex);
        const authorization = try std.fmt.allocPrint(self.allocator, "AWS4-HMAC-SHA256 Credential={s}/{s}, SignedHeaders=host;x-amz-content-sha256;x-amz-date, Signature={s}", .{ self.options.access_key, scope, signature_hex });
        defer self.allocator.free(authorization);
        const target = if (query.len == 0) path else try std.fmt.allocPrint(self.allocator, "{s}?{s}", .{ path, query });
        defer if (query.len != 0) self.allocator.free(target);
        var request_bytes = std.ArrayList(u8).empty;
        defer request_bytes.deinit(self.allocator);
        try request_bytes.print(self.allocator, "{s} {s} HTTP/1.1\r\nHost: {s}\r\nx-amz-date: {s}\r\nx-amz-content-sha256: {s}\r\nAuthorization: {s}\r\nContent-Length: {d}\r\n", .{ method, target, host_header, amz_date, payload_hex, authorization, body.len });
        if (content_type) |value| try request_bytes.print(self.allocator, "Content-Type: {s}\r\n", .{value});
        try request_bytes.appendSlice(self.allocator, "Connection: close\r\n\r\n");
        try request_bytes.appendSlice(self.allocator, body);
        const address = std.Io.net.IpAddress.resolve(self.io, self.options.host, self.options.port) catch return error.S3Unavailable;
        var stream = address.connect(self.io, .{ .mode = .stream }) catch return error.S3Unavailable;
        defer stream.close(self.io);
        try writeAll(stream, self.io, request_bytes.items);
        const raw = try readToEndAlloc(self.allocator, stream, self.io, self.options.max_response_bytes);
        defer self.allocator.free(raw);
        const headers_end = std.mem.indexOf(u8, raw, "\r\n\r\n") orelse return error.InvalidS3Response;
        const line_end = std.mem.indexOf(u8, raw, "\r\n") orelse return error.InvalidS3Response;
        const line = raw[0..line_end];
        if (line.len < 12) return error.InvalidS3Response;
        const status = std.fmt.parseUnsigned(u16, line[9..12], 10) catch return error.InvalidS3Response;
        return .{ .allocator = self.allocator, .status = status, .headers = try self.allocator.dupe(u8, raw[0..headers_end]), .body = try self.allocator.dupe(u8, raw[headers_end + 4 ..]) };
    }
    fn freeUpload(self: *Client, upload: Upload) void {
        self.allocator.free(upload.key);
        self.allocator.free(upload.remote_id);
        for (upload.parts.items) |part| self.allocator.free(part.etag);
        var parts = upload.parts;
        parts.deinit(self.allocator);
    }
    fn lock(self: *Client) void {
        while (!self.mutex.tryLock()) std.Thread.yield() catch {};
    }
};
fn expectStatus(actual: u16, expected: []const u16) !void {
    for (expected) |status| if (actual == status) return;
    return switch (actual) {
        401, 403 => error.S3PermissionDenied,
        404 => error.S3NotFound,
        429 => error.S3Capacity,
        500...599 => error.S3Unavailable,
        else => error.S3RejectedRequest,
    };
}
fn validateKey(key: []const u8) !void {
    if (key.len == 0 or key.len > 1024 or key[0] == '/' or std.mem.indexOf(u8, key, "..") != null) return error.InvalidObjectKey;
}
fn hmac(key: []const u8, message: []const u8) [32]u8 {
    var output: [32]u8 = undefined;
    std.crypto.auth.hmac.sha2.HmacSha256.create(&output, message, key);
    return output;
}
fn signatureV4(secret: []const u8, date: *const [8]u8, region: []const u8, string_to_sign: []const u8) [32]u8 {
    var first: [256]u8 = undefined;
    const seed = std.fmt.bufPrint(&first, "AWS4{s}", .{secret}) catch unreachable;
    const date_key = hmac(seed, date);
    const region_key = hmac(&date_key, region);
    const service_key = hmac(&region_key, "s3");
    const signing_key = hmac(&service_key, "aws4_request");
    return hmac(&signing_key, string_to_sign);
}
fn hexLower(input: []const u8, output: []u8) void {
    const chars = "0123456789abcdef";
    for (input, 0..) |byte, index| {
        output[index * 2] = chars[byte >> 4];
        output[index * 2 + 1] = chars[byte & 15];
    }
}
fn wallMillis() u64 {
    var value: std.c.timeval = undefined;
    if (std.c.gettimeofday(&value, null) != 0) return 0;
    return @intCast(value.sec * 1000 + @divTrunc(value.usec, 1000));
}
fn formatAwsDate(epoch_seconds: u64, amz: *[16]u8, date: *[8]u8) void {
    const days: i64 = @intCast(epoch_seconds / 86400);
    const seconds = epoch_seconds % 86400;
    const civil = civilFromDays(days);
    writeDigits(date[0..4], @intCast(civil.year));
    writeDigits(date[4..6], civil.month);
    writeDigits(date[6..8], civil.day);
    @memcpy(amz[0..8], date);
    amz[8] = 'T';
    writeDigits(amz[9..11], seconds / 3600);
    writeDigits(amz[11..13], (seconds % 3600) / 60);
    writeDigits(amz[13..15], seconds % 60);
    amz[15] = 'Z';
}
fn writeDigits(output: []u8, value: u64) void {
    var remaining = value;
    var index = output.len;
    while (index > 0) {
        index -= 1;
        output[index] = @intCast('0' + remaining % 10);
        remaining /= 10;
    }
}
const Civil = struct { year: i64, month: u64, day: u64 };
fn civilFromDays(days_since_epoch: i64) Civil {
    const z = days_since_epoch + 719468;
    const era = @divFloor(z, 146097);
    const doe = z - era * 146097;
    const yoe = @divFloor(doe - @divFloor(doe, 1460) + @divFloor(doe, 36524) - @divFloor(doe, 146096), 365);
    var year = yoe + era * 400;
    const doy = doe - (365 * yoe + @divFloor(yoe, 4) - @divFloor(yoe, 100));
    const mp = @divFloor(5 * doy + 2, 153);
    const day = doy - @divFloor(153 * mp + 2, 5) + 1;
    const month = mp + if (mp < 10) @as(i64, 3) else -9;
    year += if (month <= 2) @as(i64, 1) else 0;
    return .{ .year = year, .month = @intCast(month), .day = @intCast(day) };
}
fn uriEncodeAlloc(allocator: std.mem.Allocator, input: []const u8, encode_slash: bool) ![]u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);
    const hex = "0123456789ABCDEF";
    for (input) |byte| {
        if (std.ascii.isAlphanumeric(byte) or byte == '-' or byte == '_' or byte == '.' or byte == '~' or (byte == '/' and !encode_slash)) try output.append(allocator, byte) else {
            try output.append(allocator, '%');
            try output.append(allocator, hex[byte >> 4]);
            try output.append(allocator, hex[byte & 15]);
        }
    }
    return output.toOwnedSlice(allocator);
}
fn xmlValue(body: []const u8, comptime name: []const u8) ?[]const u8 {
    const open = "<" ++ name ++ ">";
    const close = "</" ++ name ++ ">";
    const start_tag = std.mem.indexOf(u8, body, open) orelse return null;
    const start = start_tag + open.len;
    const end = std.mem.indexOfPos(u8, body, start, close) orelse return null;
    return body[start..end];
}
fn xmlDecodeAlloc(allocator: std.mem.Allocator, value: []const u8) ![]u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);
    var index: usize = 0;
    while (index < value.len) {
        if (std.mem.startsWith(u8, value[index..], "&amp;")) {
            try output.append(allocator, '&');
            index += 5;
        } else if (std.mem.startsWith(u8, value[index..], "&lt;")) {
            try output.append(allocator, '<');
            index += 4;
        } else if (std.mem.startsWith(u8, value[index..], "&gt;")) {
            try output.append(allocator, '>');
            index += 4;
        } else {
            try output.append(allocator, value[index]);
            index += 1;
        }
    }
    return output.toOwnedSlice(allocator);
}
fn readToEndAlloc(allocator: std.mem.Allocator, stream: std.Io.net.Stream, io: std.Io, max: usize) ![]u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);
    var buffer: [8192]u8 = undefined;
    while (output.items.len <= max) {
        var parts = [_][]u8{&buffer};
        const count = try io.vtable.netRead(io.userdata, stream.socket.handle, &parts);
        if (count == 0) return output.toOwnedSlice(allocator);
        try output.appendSlice(allocator, buffer[0..count]);
    }
    return error.S3ResponseTooLarge;
}
fn writeAll(stream: std.Io.net.Stream, io: std.Io, bytes: []const u8) !void {
    var offset: usize = 0;
    while (offset < bytes.len) {
        const parts = [_][]const u8{bytes[offset..]};
        const count = try io.vtable.netWrite(io.userdata, stream.socket.handle, "", &parts, 1);
        if (count == 0) return error.WriteZero;
        offset += count;
    }
}
test "SigV4 date and canonical URI primitives are deterministic" {
    var amz: [16]u8 = undefined;
    var date: [8]u8 = undefined;
    formatAwsDate(0, &amz, &date);
    try std.testing.expectEqualStrings("19700101", &date);
    try std.testing.expectEqualStrings("19700101T000000Z", &amz);
    const encoded = try uriEncodeAlloc(std.testing.allocator, "a b/c", false);
    defer std.testing.allocator.free(encoded);
    try std.testing.expectEqualStrings("a%20b/c", encoded);
}
