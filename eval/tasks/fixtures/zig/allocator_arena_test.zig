const std = @import("std");
const testing = std.testing;
const arena = @import("allocator_arena.zig");

test "FixedBufferArena - basic allocation" {
    var buffer: [1024]u8 = undefined;
    var fba = arena.FixedBufferArena.init(&buffer);
    const alloc = fba.allocator();

    const slice = try alloc.alloc(u8, 100);
    try testing.expectEqual(@as(usize, 100), slice.len);
}

test "FixedBufferArena - multiple allocations" {
    var buffer: [1024]u8 = undefined;
    var fba = arena.FixedBufferArena.init(&buffer);
    const alloc = fba.allocator();

    _ = try alloc.alloc(u8, 100);
    _ = try alloc.alloc(u8, 200);
    _ = try alloc.alloc(u8, 300);

    try testing.expect(fba.bytesUsed() >= 600);
}

test "FixedBufferArena - allocation failure" {
    var buffer: [100]u8 = undefined;
    var fba = arena.FixedBufferArena.init(&buffer);
    const alloc = fba.allocator();

    const result = alloc.alloc(u8, 200);
    try testing.expectError(error.OutOfMemory, result);
}

test "FixedBufferArena - reset" {
    var buffer: [1024]u8 = undefined;
    var fba = arena.FixedBufferArena.init(&buffer);
    const alloc = fba.allocator();

    _ = try alloc.alloc(u8, 500);
    try testing.expect(fba.bytesUsed() >= 500);

    fba.reset();
    try testing.expectEqual(@as(usize, 0), fba.bytesUsed());
}

test "FixedBufferArena - bytesRemaining" {
    var buffer: [1024]u8 = undefined;
    var fba = arena.FixedBufferArena.init(&buffer);

    try testing.expectEqual(@as(usize, 1024), fba.bytesRemaining());

    const alloc = fba.allocator();
    _ = try alloc.alloc(u8, 100);

    try testing.expect(fba.bytesRemaining() < 1024);
}

test "FixedBufferArena - alignment" {
    var buffer: [1024]u8 = undefined;
    var fba = arena.FixedBufferArena.init(&buffer);
    const alloc = fba.allocator();

    // Allocate a single byte first
    _ = try alloc.alloc(u8, 1);

    // Then allocate something that needs alignment
    const aligned = try alloc.alloc(u64, 1);
    const addr = @intFromPtr(aligned.ptr);
    try testing.expect(addr % @alignOf(u64) == 0);
}

test "GrowingArena - basic allocation" {
    var ga = arena.GrowingArena.init(testing.allocator, 4096);
    defer ga.deinit();

    const alloc = ga.allocator();
    const slice = try alloc.alloc(u8, 100);
    try testing.expectEqual(@as(usize, 100), slice.len);
}

test "GrowingArena - grows automatically" {
    var ga = arena.GrowingArena.init(testing.allocator, 100);
    defer ga.deinit();

    const alloc = ga.allocator();

    // Allocate more than one page
    _ = try alloc.alloc(u8, 50);
    _ = try alloc.alloc(u8, 50);
    _ = try alloc.alloc(u8, 50);
    _ = try alloc.alloc(u8, 50);
}

test "GrowingArena - large allocation" {
    var ga = arena.GrowingArena.init(testing.allocator, 100);
    defer ga.deinit();

    const alloc = ga.allocator();
    // Allocate more than page size
    const large = try alloc.alloc(u8, 1000);
    try testing.expectEqual(@as(usize, 1000), large.len);
}

test "GrowingArena - reset" {
    var ga = arena.GrowingArena.init(testing.allocator, 4096);
    defer ga.deinit();

    const alloc = ga.allocator();
    _ = try alloc.alloc(u8, 100);

    ga.reset();

    // Can allocate again after reset
    _ = try alloc.alloc(u8, 100);
}

test "ScratchAllocator - basic usage" {
    var scratch = arena.ScratchAllocator(1024){};
    scratch.init();

    const alloc = scratch.allocator();
    const slice = try alloc.alloc(u8, 100);
    try testing.expectEqual(@as(usize, 100), slice.len);
}

test "ScratchAllocator - reset" {
    var scratch = arena.ScratchAllocator(1024){};
    scratch.init();

    const alloc = scratch.allocator();
    _ = try alloc.alloc(u8, 500);
    try testing.expect(scratch.bytesUsed() >= 500);

    scratch.reset();
    try testing.expectEqual(@as(usize, 0), scratch.bytesUsed());
}

const TestObject = struct {
    value: i32,
    name: [32]u8 = undefined,
};

test "PoolAllocator - create and destroy" {
    var pool = arena.PoolAllocator(TestObject).init(testing.allocator);
    defer pool.deinit();

    const obj = try pool.create();
    obj.value = 42;

    const stats = pool.stats();
    try testing.expectEqual(@as(usize, 1), stats.allocated);
    try testing.expectEqual(@as(usize, 0), stats.free);

    pool.destroy(obj);

    const stats2 = pool.stats();
    try testing.expectEqual(@as(usize, 1), stats2.free);
}

test "PoolAllocator - reuse freed objects" {
    var pool = arena.PoolAllocator(TestObject).init(testing.allocator);
    defer pool.deinit();

    const obj1 = try pool.create();
    pool.destroy(obj1);

    const obj2 = try pool.create();
    // Should reuse the freed object
    try testing.expectEqual(obj1, obj2);
}

test "PoolAllocator - multiple objects" {
    var pool = arena.PoolAllocator(TestObject).init(testing.allocator);
    defer pool.deinit();

    var objects: [10]*TestObject = undefined;
    for (&objects, 0..) |*obj, i| {
        obj.* = try pool.create();
        obj.*.value = @intCast(i);
    }

    // Verify all values
    for (objects, 0..) |obj, i| {
        try testing.expectEqual(@as(i32, @intCast(i)), obj.value);
    }

    // Free half
    for (objects[0..5]) |obj| {
        pool.destroy(obj);
    }

    const stats = pool.stats();
    try testing.expectEqual(@as(usize, 10), stats.allocated);
    try testing.expectEqual(@as(usize, 5), stats.free);
}

test "StackAllocator - basic allocation" {
    var buffer: [1024]u8 = undefined;
    var stack = arena.StackAllocator.init(&buffer);

    const slice = try stack.alloc(u32, 10);
    try testing.expectEqual(@as(usize, 10), slice.len);
}

test "StackAllocator - mark and release" {
    var buffer: [1024]u8 = undefined;
    var stack = arena.StackAllocator.init(&buffer);

    _ = try stack.alloc(u8, 100);
    const m = stack.mark();

    _ = try stack.alloc(u8, 200);
    _ = try stack.alloc(u8, 300);

    stack.release(m);

    // Should be able to allocate from the mark point again
    const after_release = try stack.alloc(u8, 200);
    try testing.expectEqual(@as(usize, 200), after_release.len);
}

test "StackAllocator - reset" {
    var buffer: [1024]u8 = undefined;
    var stack = arena.StackAllocator.init(&buffer);

    _ = try stack.alloc(u8, 500);
    stack.reset();

    // Should be able to allocate full buffer again
    _ = try stack.alloc(u8, 900);
}

test "StackAllocator - out of memory" {
    var buffer: [100]u8 = undefined;
    var stack = arena.StackAllocator.init(&buffer);

    const result = stack.alloc(u8, 200);
    try testing.expectError(error.OutOfMemory, result);
}

test "StackAllocator - nested marks" {
    var buffer: [1024]u8 = undefined;
    var stack = arena.StackAllocator.init(&buffer);

    _ = try stack.alloc(u8, 100);
    const m1 = stack.mark();

    _ = try stack.alloc(u8, 100);
    const m2 = stack.mark();

    _ = try stack.alloc(u8, 100);

    stack.release(m2);
    _ = try stack.alloc(u8, 50); // Can allocate from m2

    stack.release(m1);
    _ = try stack.alloc(u8, 150); // Can allocate from m1
}
