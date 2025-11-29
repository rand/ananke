// Zig Fixture (target ~100 lines)
// Generated for benchmark testing

const std = @import("std");

pub const Entity = struct {
    id: u64,
    name: []const u8,
    email: []const u8,
    is_active: bool,
    created_at: i64,
    updated_at: i64,
};

pub const CreateDto = struct {
    name: []const u8,
    email: []const u8,
};

pub const UpdateDto = struct {
    name: ?[]const u8 = null,
    email: ?[]const u8 = null,
    is_active: ?bool = null,
};

pub const EntityService = struct {
    const Self = @This();

    db: *Database,
    logger: *Logger,
    cache: *Cache(u64, Entity),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, db: *Database, logger: *Logger, cache: *Cache(u64, Entity)) !*Self {
        var self = try allocator.create(Self);
        self.* = .{
            .db = db,
            .logger = logger,
            .cache = cache,
            .allocator = allocator,
        };
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.destroy(self);
    }

    pub fn operation0(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation1(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation2(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation3(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }
};
