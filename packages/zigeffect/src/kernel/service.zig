const std = @import("std");

pub const Allocator = std.mem.Allocator;

pub const RegistryError = error{
    DuplicateService,
    MissingService,
    ServiceTypeMismatch,
};

pub fn Service(comptime key: []const u8, comptime ServiceApi: type) type {
    if (key.len == 0) @compileError("zigeffect service keys must not be empty");

    return struct {
        pub const service_key = key;
        pub const API = ServiceApi;
        /// Static operation catalog included in application snapshots. A
        /// service API opts in with `pub const operations`.
        pub const operations: []const []const u8 = if (@hasDecl(ServiceApi, "operations"))
            ServiceApi.operations
        else
            &.{};
    };
}

pub fn assertServiceTag(comptime Tag: type) void {
    if (!@hasDecl(Tag, "service_key") or !@hasDecl(Tag, "API")) {
        @compileError(
            "zigeffect expected a service tag created with fx.Service(key, API); received " ++
                @typeName(Tag),
        );
    }
}

pub fn contains(comptime services: anytype, comptime Tag: type) bool {
    assertServiceTag(Tag);
    inline for (services) |Candidate| {
        assertServiceTag(Candidate);
        if (Candidate == Tag) return true;
    }
    return false;
}

pub fn subset(comptime required: anytype, comptime provided: anytype) bool {
    inline for (required) |Tag| {
        if (!contains(provided, Tag)) return false;
    }
    return true;
}

fn unionCount(comptime left: anytype, comptime right: anytype) usize {
    comptime var count = left.len;
    inline for (right) |Tag| {
        if (!contains(left, Tag)) count += 1;
    }
    return count;
}

pub fn unionServices(comptime left: anytype, comptime right: anytype) [unionCount(left, right)]type {
    comptime var result: [unionCount(left, right)]type = undefined;
    comptime var index: usize = 0;
    inline for (left) |Tag| {
        result[index] = Tag;
        index += 1;
    }
    inline for (right) |Tag| {
        if (!contains(left, Tag)) {
            result[index] = Tag;
            index += 1;
        }
    }
    return result;
}

fn differenceCount(comptime left: anytype, comptime removed: anytype) usize {
    comptime var count: usize = 0;
    inline for (left) |Tag| {
        if (!contains(removed, Tag)) count += 1;
    }
    return count;
}

pub fn difference(comptime left: anytype, comptime removed: anytype) [differenceCount(left, removed)]type {
    comptime var result: [differenceCount(left, removed)]type = undefined;
    comptime var index: usize = 0;
    inline for (left) |Tag| {
        if (!contains(removed, Tag)) {
            result[index] = Tag;
            index += 1;
        }
    }
    return result;
}

pub const Registry = struct {
    const Entry = struct {
        pointer: *anyopaque,
        type_name: []const u8,
        destroy: *const fn (Allocator, *anyopaque) void,
    };

    allocator: Allocator,
    entries: std.StringHashMap(Entry),

    pub fn init(allocator: Allocator) Registry {
        return .{
            .allocator = allocator,
            .entries = std.StringHashMap(Entry).init(allocator),
        };
    }

    pub fn deinit(self: *Registry) void {
        var iterator = self.entries.iterator();
        while (iterator.next()) |entry| {
            entry.value_ptr.destroy(self.allocator, entry.value_ptr.pointer);
        }
        self.entries.deinit();
    }

    pub fn containsTag(self: *const Registry, comptime Tag: type) bool {
        assertServiceTag(Tag);
        return self.entries.contains(Tag.service_key);
    }

    pub fn putOwned(self: *Registry, comptime Tag: type, value: Tag.API) (Allocator.Error || RegistryError)!*Tag.API {
        assertServiceTag(Tag);
        if (self.entries.get(Tag.service_key)) |existing| {
            if (!std.mem.eql(u8, existing.type_name, @typeName(Tag.API))) {
                return error.ServiceTypeMismatch;
            }
            return error.DuplicateService;
        }

        const pointer = try self.allocator.create(Tag.API);
        errdefer self.allocator.destroy(pointer);
        pointer.* = value;

        const Destroy = struct {
            fn destroy(allocator: Allocator, raw: *anyopaque) void {
                const typed: *Tag.API = @ptrCast(@alignCast(raw));
                allocator.destroy(typed);
            }
        };

        try self.entries.put(Tag.service_key, .{
            .pointer = pointer,
            .type_name = @typeName(Tag.API),
            .destroy = Destroy.destroy,
        });
        return pointer;
    }

    pub fn get(self: *const Registry, comptime Tag: type) RegistryError!*Tag.API {
        assertServiceTag(Tag);
        const entry = self.entries.get(Tag.service_key) orelse return error.MissingService;
        if (!std.mem.eql(u8, entry.type_name, @typeName(Tag.API))) {
            return error.ServiceTypeMismatch;
        }
        return @ptrCast(@alignCast(entry.pointer));
    }
};
