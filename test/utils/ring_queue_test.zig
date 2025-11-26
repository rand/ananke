const std = @import("std");
const testing = std.testing;
const RingQueue = @import("../../src/utils/ring_queue.zig").RingQueue;

test "RingQueue: basic operations" {
    const allocator = testing.allocator;

    var queue = try RingQueue(u32).init(allocator, 4);
    defer queue.deinit();

    try testing.expectEqual(@as(usize, 0), queue.len());
    try testing.expect(queue.isEmpty());

    try queue.enqueue(10);
    try queue.enqueue(20);
    try queue.enqueue(30);

    try testing.expectEqual(@as(usize, 3), queue.len());
    try testing.expect(!queue.isEmpty());

    try testing.expectEqual(@as(u32, 10), try queue.dequeue());
    try testing.expectEqual(@as(u32, 20), try queue.dequeue());
    try testing.expectEqual(@as(u32, 30), try queue.dequeue());

    try testing.expectEqual(@as(usize, 0), queue.len());
    try testing.expect(queue.isEmpty());
}

test "RingQueue: peek without removing" {
    const allocator = testing.allocator;

    var queue = try RingQueue(u32).init(allocator, 4);
    defer queue.deinit();

    try testing.expectEqual(@as(?u32, null), queue.peek());

    try queue.enqueue(42);
    try testing.expectEqual(@as(?u32, 42), queue.peek());
    try testing.expectEqual(@as(usize, 1), queue.len());

    try queue.enqueue(43);
    try testing.expectEqual(@as(?u32, 42), queue.peek());
    try testing.expectEqual(@as(usize, 2), queue.len());

    try testing.expectEqual(@as(u32, 42), try queue.dequeue());
    try testing.expectEqual(@as(?u32, 43), queue.peek());
}

test "RingQueue: auto-grow when full" {
    const allocator = testing.allocator;

    var queue = try RingQueue(u32).init(allocator, 2);
    defer queue.deinit();

    // Fill beyond initial capacity
    for (1..20) |i| {
        try queue.enqueue(@intCast(i));
    }

    try testing.expectEqual(@as(usize, 19), queue.len());

    // Verify FIFO order
    for (1..20) |expected| {
        const value = try queue.dequeue();
        try testing.expectEqual(@as(u32, @intCast(expected)), value);
    }

    try testing.expect(queue.isEmpty());
}

test "RingQueue: wrap-around behavior" {
    const allocator = testing.allocator;

    var queue = try RingQueue(u32).init(allocator, 4);
    defer queue.deinit();

    // Fill queue
    try queue.enqueue(1);
    try queue.enqueue(2);
    try queue.enqueue(3);

    // Dequeue and enqueue to cause wrap-around
    _ = try queue.dequeue();
    _ = try queue.dequeue();

    try queue.enqueue(4);
    try queue.enqueue(5);
    try queue.enqueue(6);

    // Should be: 3, 4, 5, 6
    try testing.expectEqual(@as(u32, 3), try queue.dequeue());
    try testing.expectEqual(@as(u32, 4), try queue.dequeue());
    try testing.expectEqual(@as(u32, 5), try queue.dequeue());
    try testing.expectEqual(@as(u32, 6), try queue.dequeue());
}

test "RingQueue: dequeue from empty" {
    const allocator = testing.allocator;

    var queue = try RingQueue(u32).init(allocator, 4);
    defer queue.deinit();

    const result = queue.dequeue();
    try testing.expectError(error.EmptyQueue, result);
}

test "RingQueue: with struct elements" {
    const allocator = testing.allocator;

    const Point = struct {
        x: i32,
        y: i32,
    };

    var queue = try RingQueue(Point).init(allocator, 4);
    defer queue.deinit();

    try queue.enqueue(.{ .x = 1, .y = 2 });
    try queue.enqueue(.{ .x = 3, .y = 4 });

    const p1 = try queue.dequeue();
    try testing.expectEqual(@as(i32, 1), p1.x);
    try testing.expectEqual(@as(i32, 2), p1.y);

    const p2 = try queue.dequeue();
    try testing.expectEqual(@as(i32, 3), p2.x);
    try testing.expectEqual(@as(i32, 4), p2.y);
}

test "RingQueue: stress test with many operations" {
    const allocator = testing.allocator;

    var queue = try RingQueue(usize).init(allocator, 8);
    defer queue.deinit();

    // Enqueue 1000 items, dequeue 500, enqueue 500 more
    for (0..1000) |i| {
        try queue.enqueue(i);
    }

    for (0..500) |i| {
        const value = try queue.dequeue();
        try testing.expectEqual(i, value);
    }

    for (1000..1500) |i| {
        try queue.enqueue(i);
    }

    // Should have items 500-1499
    for (500..1500) |expected| {
        const value = try queue.dequeue();
        try testing.expectEqual(expected, value);
    }

    try testing.expect(queue.isEmpty());
}

test "RingQueue: interleaved operations" {
    const allocator = testing.allocator;

    var queue = try RingQueue(u32).init(allocator, 4);
    defer queue.deinit();

    try queue.enqueue(1);
    try testing.expectEqual(@as(u32, 1), try queue.dequeue());

    try queue.enqueue(2);
    try queue.enqueue(3);
    try testing.expectEqual(@as(u32, 2), try queue.dequeue());

    try queue.enqueue(4);
    try queue.enqueue(5);
    try queue.enqueue(6);

    try testing.expectEqual(@as(u32, 3), try queue.dequeue());
    try testing.expectEqual(@as(u32, 4), try queue.dequeue());
    try testing.expectEqual(@as(u32, 5), try queue.dequeue());
    try testing.expectEqual(@as(u32, 6), try queue.dequeue());
}

test "RingQueue: memory leak check with GPA" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked == .leak) {
            @panic("Memory leak detected!");
        }
    }
    const allocator = gpa.allocator();

    var queue = try RingQueue(u32).init(allocator, 4);
    defer queue.deinit();

    // Trigger multiple growths
    for (0..100) |i| {
        try queue.enqueue(@intCast(i));
    }

    // Dequeue everything
    for (0..100) |i| {
        const value = try queue.dequeue();
        try testing.expectEqual(@as(u32, @intCast(i)), value);
    }
}
