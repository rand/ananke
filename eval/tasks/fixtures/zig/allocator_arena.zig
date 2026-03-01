//! Arena Allocator Implementation
//! Demonstrates memory management with arena allocation in Zig

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Simple arena allocator that allocates from a fixed buffer
pub const FixedBufferArena = struct {
    buffer: []u8,
    end_index: usize = 0,

    const Self = @This();

    pub fn init(buffer: []u8) Self {
        return .{ .buffer = buffer };
    }

    pub fn allocator(self: *Self) Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .remap = remap,
                .free = free,
            },
        };
    }

    fn alloc(ctx: *anyopaque, len: usize, ptr_align: std.mem.Alignment, ret_addr: usize) ?[*]u8 {
        _ = ret_addr;
        const self: *Self = @ptrCast(@alignCast(ctx));
        const alignment = ptr_align.toByteUnits();
        const aligned_index = std.mem.alignForward(usize, self.end_index, alignment);

        if (aligned_index + len > self.buffer.len) {
            return null;
        }

        self.end_index = aligned_index + len;
        return self.buffer.ptr + aligned_index;
    }

    fn resize(ctx: *anyopaque, buf: []u8, buf_align: std.mem.Alignment, new_len: usize, ret_addr: usize) bool {
        _ = ctx;
        _ = buf;
        _ = buf_align;
        _ = new_len;
        _ = ret_addr;
        return false; // Arena doesn't support resize
    }

    fn remap(ctx: *anyopaque, buf: []u8, buf_align: std.mem.Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
        _ = ctx;
        _ = buf;
        _ = buf_align;
        _ = new_len;
        _ = ret_addr;
        return null; // Arena doesn't support remap
    }

    fn free(ctx: *anyopaque, buf: []u8, buf_align: std.mem.Alignment, ret_addr: usize) void {
        _ = ctx;
        _ = buf;
        _ = buf_align;
        _ = ret_addr;
        // Arena doesn't free individual allocations
    }

    pub fn reset(self: *Self) void {
        self.end_index = 0;
    }

    pub fn bytesUsed(self: Self) usize {
        return self.end_index;
    }

    pub fn bytesRemaining(self: Self) usize {
        return self.buffer.len - self.end_index;
    }
};

/// Growing arena that allocates pages from a backing allocator
pub const GrowingArena = struct {
    const Page = struct {
        data: []u8,
        next: ?*Page,
    };

    backing_allocator: Allocator,
    page_size: usize,
    first_page: ?*Page = null,
    current_page: ?*Page = null,
    current_offset: usize = 0,

    const Self = @This();

    pub fn init(backing_allocator: Allocator, page_size: usize) Self {
        return .{
            .backing_allocator = backing_allocator,
            .page_size = page_size,
        };
    }

    pub fn deinit(self: *Self) void {
        var page = self.first_page;
        while (page) |p| {
            const next = p.next;
            self.backing_allocator.free(p.data);
            self.backing_allocator.destroy(p);
            page = next;
        }
        self.first_page = null;
        self.current_page = null;
        self.current_offset = 0;
    }

    pub fn allocator(self: *Self) Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .remap = remap,
                .free = free,
            },
        };
    }

    fn alloc(ctx: *anyopaque, len: usize, ptr_align: std.mem.Alignment, ret_addr: usize) ?[*]u8 {
        _ = ret_addr;
        const self: *Self = @ptrCast(@alignCast(ctx));
        return self.allocBytes(len, ptr_align);
    }

    fn allocBytes(self: *Self, len: usize, ptr_align: std.mem.Alignment) ?[*]u8 {
        const alignment = ptr_align.toByteUnits();

        // Try to allocate from current page
        if (self.current_page) |page| {
            const aligned_offset = std.mem.alignForward(usize, self.current_offset, alignment);
            if (aligned_offset + len <= page.data.len) {
                self.current_offset = aligned_offset + len;
                return page.data.ptr + aligned_offset;
            }
        }

        // Need a new page
        const page_data_size = @max(self.page_size, len + alignment);
        const new_page = self.backing_allocator.create(Page) catch return null;
        new_page.data = self.backing_allocator.alloc(u8, page_data_size) catch {
            self.backing_allocator.destroy(new_page);
            return null;
        };
        new_page.next = null;

        if (self.current_page) |current| {
            current.next = new_page;
        } else {
            self.first_page = new_page;
        }
        self.current_page = new_page;
        self.current_offset = len;
        return new_page.data.ptr;
    }

    fn resize(ctx: *anyopaque, buf: []u8, buf_align: std.mem.Alignment, new_len: usize, ret_addr: usize) bool {
        _ = ctx;
        _ = buf;
        _ = buf_align;
        _ = new_len;
        _ = ret_addr;
        return false;
    }

    fn remap(ctx: *anyopaque, buf: []u8, buf_align: std.mem.Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
        _ = ctx;
        _ = buf;
        _ = buf_align;
        _ = new_len;
        _ = ret_addr;
        return null;
    }

    fn free(ctx: *anyopaque, buf: []u8, buf_align: std.mem.Alignment, ret_addr: usize) void {
        _ = ctx;
        _ = buf;
        _ = buf_align;
        _ = ret_addr;
    }

    pub fn reset(self: *Self) void {
        self.current_page = self.first_page;
        self.current_offset = 0;
    }
};

/// Scratch allocator for temporary allocations with automatic cleanup
pub fn ScratchAllocator(comptime size: usize) type {
    return struct {
        buffer: [size]u8 = undefined,
        arena: FixedBufferArena = undefined,

        const Self = @This();

        pub fn init(self: *Self) void {
            self.arena = FixedBufferArena.init(&self.buffer);
        }

        pub fn allocator(self: *Self) Allocator {
            return self.arena.allocator();
        }

        pub fn reset(self: *Self) void {
            self.arena.reset();
        }

        pub fn bytesUsed(self: Self) usize {
            return self.arena.bytesUsed();
        }
    };
}

/// Pool allocator for fixed-size objects
pub fn PoolAllocator(comptime T: type) type {
    const Node = struct {
        next: ?*@This() = null,
        data: T = undefined,
    };

    return struct {
        free_list: ?*Node = null,
        backing_allocator: Allocator,
        allocated_count: usize = 0,
        free_count: usize = 0,

        const Self = @This();

        pub fn init(backing_allocator: Allocator) Self {
            return .{ .backing_allocator = backing_allocator };
        }

        pub fn deinit(self: *Self) void {
            // In a real implementation, we'd track all nodes to free them
            _ = self;
        }

        pub fn create(self: *Self) !*T {
            if (self.free_list) |node| {
                self.free_list = node.next;
                self.free_count -= 1;
                return &node.data;
            }

            const node = try self.backing_allocator.create(Node);
            self.allocated_count += 1;
            return &node.data;
        }

        pub fn destroy(self: *Self, ptr: *T) void {
            const node: *Node = @alignCast(@fieldParentPtr("data", ptr));
            node.next = self.free_list;
            self.free_list = node;
            self.free_count += 1;
        }

        pub fn stats(self: Self) struct { allocated: usize, free: usize } {
            return .{ .allocated = self.allocated_count, .free = self.free_count };
        }
    };
}

/// Stack-based allocator with mark/release
pub const StackAllocator = struct {
    buffer: []u8,
    offset: usize = 0,

    const Self = @This();
    pub const Mark = usize;

    pub fn init(buffer: []u8) Self {
        return .{ .buffer = buffer };
    }

    pub fn alloc(self: *Self, comptime T: type, n: usize) ![]T {
        const byte_count = @sizeOf(T) * n;
        const alignment = @alignOf(T);
        const aligned_offset = std.mem.alignForward(usize, self.offset, alignment);

        if (aligned_offset + byte_count > self.buffer.len) {
            return error.OutOfMemory;
        }

        const ptr: [*]T = @ptrCast(@alignCast(self.buffer.ptr + aligned_offset));
        self.offset = aligned_offset + byte_count;
        return ptr[0..n];
    }

    pub fn mark(self: Self) Mark {
        return self.offset;
    }

    pub fn release(self: *Self, m: Mark) void {
        self.offset = m;
    }

    pub fn reset(self: *Self) void {
        self.offset = 0;
    }
};
