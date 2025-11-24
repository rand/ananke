// Zig Fixture (target ~5000 lines)
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

    pub fn operation4(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation5(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation6(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation7(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation8(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation9(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation10(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation11(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation12(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation13(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation14(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation15(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation16(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation17(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation18(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation19(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation20(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation21(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation22(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation23(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation24(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation25(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation26(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation27(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation28(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation29(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation30(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation31(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation32(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation33(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation34(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation35(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation36(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation37(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation38(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation39(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation40(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation41(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation42(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation43(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation44(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation45(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation46(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation47(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation48(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation49(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation50(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation51(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation52(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation53(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation54(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation55(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation56(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation57(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation58(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation59(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation60(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation61(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation62(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation63(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation64(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation65(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation66(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation67(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation68(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation69(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation70(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation71(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation72(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation73(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation74(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation75(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation76(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation77(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation78(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation79(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation80(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation81(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation82(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation83(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation84(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation85(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation86(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation87(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation88(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation89(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation90(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation91(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation92(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation93(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation94(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation95(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation96(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation97(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation98(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation99(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation100(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation101(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation102(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation103(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation104(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation105(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation106(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation107(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation108(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation109(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation110(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation111(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation112(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation113(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation114(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation115(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation116(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation117(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation118(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation119(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation120(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation121(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation122(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation123(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation124(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation125(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation126(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation127(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation128(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation129(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation130(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation131(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation132(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation133(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation134(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation135(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation136(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation137(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation138(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation139(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation140(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation141(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation142(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation143(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation144(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation145(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation146(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation147(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation148(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation149(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation150(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation151(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation152(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation153(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation154(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation155(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation156(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation157(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation158(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation159(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation160(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation161(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation162(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation163(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation164(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation165(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation166(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation167(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation168(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation169(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation170(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation171(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation172(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation173(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation174(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation175(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation176(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation177(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation178(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation179(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation180(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation181(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation182(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation183(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation184(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation185(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation186(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation187(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation188(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation189(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation190(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation191(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation192(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation193(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation194(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation195(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation196(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation197(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation198(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation199(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation200(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation201(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation202(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation203(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation204(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation205(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation206(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation207(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation208(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation209(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation210(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation211(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation212(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation213(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation214(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation215(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation216(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation217(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation218(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation219(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation220(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation221(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation222(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation223(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation224(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation225(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation226(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation227(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation228(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation229(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation230(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation231(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation232(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation233(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation234(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation235(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation236(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation237(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation238(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation239(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation240(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation241(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation242(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation243(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation244(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation245(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation246(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation247(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation248(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation249(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation250(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation251(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation252(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation253(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation254(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation255(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation256(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation257(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation258(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation259(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation260(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation261(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation262(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation263(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation264(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation265(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation266(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation267(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation268(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation269(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation270(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation271(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation272(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation273(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation274(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation275(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation276(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation277(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation278(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation279(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation280(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation281(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation282(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation283(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation284(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation285(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation286(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation287(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation288(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation289(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation290(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation291(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation292(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation293(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation294(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation295(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation296(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation297(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation298(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation299(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation300(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation301(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation302(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation303(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation304(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation305(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation306(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation307(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation308(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation309(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation310(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation311(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation312(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation313(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation314(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation315(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation316(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation317(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation318(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation319(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation320(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation321(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation322(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation323(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation324(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation325(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation326(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation327(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation328(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation329(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation330(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation331(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation332(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation333(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation334(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation335(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation336(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation337(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation338(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation339(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation340(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation341(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation342(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation343(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation344(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation345(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation346(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation347(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation348(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation349(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation350(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation351(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation352(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation353(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation354(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation355(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation356(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation357(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation358(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation359(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation360(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation361(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation362(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation363(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation364(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation365(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation366(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation367(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation368(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation369(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation370(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation371(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation372(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation373(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation374(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation375(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation376(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation377(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation378(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation379(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation380(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation381(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation382(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation383(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation384(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation385(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation386(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation387(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation388(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation389(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation390(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation391(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation392(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation393(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation394(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation395(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation396(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation397(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation398(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation399(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation400(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation401(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation402(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation403(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation404(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation405(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation406(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation407(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation408(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation409(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation410(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation411(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation412(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation413(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation414(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation415(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation416(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation417(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation418(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation419(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation420(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation421(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation422(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation423(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation424(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation425(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation426(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation427(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation428(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation429(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation430(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation431(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation432(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation433(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation434(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation435(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation436(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation437(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation438(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation439(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation440(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation441(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation442(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation443(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation444(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation445(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation446(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation447(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation448(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation449(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation450(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation451(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation452(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation453(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation454(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation455(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation456(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation457(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation458(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation459(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation460(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation461(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation462(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation463(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation464(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation465(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation466(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation467(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation468(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation469(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation470(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation471(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation472(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation473(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation474(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation475(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation476(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation477(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation478(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation479(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation480(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation481(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation482(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation483(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation484(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation485(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation486(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation487(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation488(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation489(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation490(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation491(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation492(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }

    pub fn operation493(self: *Self, id: u64, data: []const u8) !?Entity {
        const result = self.db.query("SELECT * FROM entities WHERE id = ?", .{id}) catch |err| {
            self.logger.err("Operation failed: {}", .{err});
            return err;
        };
        self.logger.debug("Fetched {}", .{id});
        return if (result) |r| Entity.fromRow(r) else null;
    }
};
