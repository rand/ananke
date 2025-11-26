const std = @import("std");
const Allocator = std.mem.Allocator;

/// High-performance ring buffer queue with O(1) enqueue/dequeue operations.
///
/// Replaces ArrayList.orderedRemove(0) which is O(n) with proper queue semantics.
/// Uses power-of-2 capacity for efficient modulo via bitwise AND.
///
/// Performance characteristics:
/// - enqueue: O(1) amortized (O(n) when growing, but rare)
/// - dequeue: O(1) always
/// - peek: O(1) always
/// - len/isEmpty: O(1) always
///
/// Memory: Auto-grows by 2x when full to maintain amortized O(1) performance.
pub fn RingQueue(comptime T: type) type {
    return struct {
        const Self = @This();

        items: []T,
        head: usize, // Index of first element (dequeue from here)
        tail: usize, // Index where next element will be enqueued
        count: usize, // Number of elements currently in queue
        allocator: Allocator,

        /// Initialize a new ring queue with given initial capacity.
        /// Capacity will be rounded up to next power of 2 for efficiency.
        pub fn init(allocator: Allocator, initial_capacity: usize) !Self {
            // Round up to next power of 2 for efficient modulo
            const capacity = std.math.ceilPowerOfTwo(usize, @max(initial_capacity, 4)) catch return error.OutOfMemory;
            const items = try allocator.alloc(T, capacity);

            return Self{
                .items = items,
                .head = 0,
                .tail = 0,
                .count = 0,
                .allocator = allocator,
            };
        }

        /// Free all memory used by this queue.
        pub fn deinit(self: *Self) void {
            self.allocator.free(self.items);
            self.items = &[_]T{};
            self.head = 0;
            self.tail = 0;
            self.count = 0;
        }

        /// Add an item to the back of the queue.
        /// O(1) amortized - may trigger O(n) growth when full.
        pub fn enqueue(self: *Self, item: T) !void {
            // Grow if full
            if (self.count == self.items.len) {
                try self.grow();
            }

            self.items[self.tail] = item;
            // Use bitwise AND for efficient modulo with power-of-2
            self.tail = (self.tail + 1) & (self.items.len - 1);
            self.count += 1;
        }

        /// Remove and return the item from the front of the queue.
        /// O(1) always.
        /// Returns error.EmptyQueue if queue is empty.
        pub fn dequeue(self: *Self) !T {
            if (self.count == 0) {
                return error.EmptyQueue;
            }

            const item = self.items[self.head];
            // Use bitwise AND for efficient modulo with power-of-2
            self.head = (self.head + 1) & (self.items.len - 1);
            self.count -= 1;

            return item;
        }

        /// Return the item at the front of the queue without removing it.
        /// O(1) always.
        /// Returns null if queue is empty.
        pub fn peek(self: *Self) ?T {
            if (self.count == 0) {
                return null;
            }
            return self.items[self.head];
        }

        /// Return the number of items currently in the queue.
        /// O(1) always.
        pub fn len(self: *Self) usize {
            return self.count;
        }

        /// Check if the queue is empty.
        /// O(1) always.
        pub fn isEmpty(self: *Self) bool {
            return self.count == 0;
        }

        /// Double the capacity and copy all elements.
        /// Called automatically when queue is full.
        fn grow(self: *Self) !void {
            const old_capacity = self.items.len;
            const new_capacity = old_capacity * 2;

            var new_items = try self.allocator.alloc(T, new_capacity);

            // Copy elements in order from head to tail
            // This unwraps the ring buffer into a linear layout
            var i: usize = 0;
            var current = self.head;
            while (i < self.count) : (i += 1) {
                new_items[i] = self.items[current];
                current = (current + 1) & (old_capacity - 1);
            }

            // Free old buffer
            self.allocator.free(self.items);

            // Update to new buffer with elements at start
            self.items = new_items;
            self.head = 0;
            self.tail = self.count;
        }
    };
}

// ============================================================================
// Tests
// ============================================================================

test "RingQueue: basic enqueue/dequeue" {
    const allocator = std.testing.allocator;

    var queue = try RingQueue(u32).init(allocator, 4);
    defer queue.deinit();

    try std.testing.expectEqual(@as(usize, 0), queue.len());
    try std.testing.expect(queue.isEmpty());

    try queue.enqueue(10);
    try queue.enqueue(20);
    try queue.enqueue(30);

    try std.testing.expectEqual(@as(usize, 3), queue.len());
    try std.testing.expect(!queue.isEmpty());

    try std.testing.expectEqual(@as(u32, 10), try queue.dequeue());
    try std.testing.expectEqual(@as(u32, 20), try queue.dequeue());
    try std.testing.expectEqual(@as(u32, 30), try queue.dequeue());

    try std.testing.expectEqual(@as(usize, 0), queue.len());
    try std.testing.expect(queue.isEmpty());
}

test "RingQueue: peek without dequeue" {
    const allocator = std.testing.allocator;

    var queue = try RingQueue(u32).init(allocator, 4);
    defer queue.deinit();

    try std.testing.expectEqual(@as(?u32, null), queue.peek());

    try queue.enqueue(42);
    try std.testing.expectEqual(@as(?u32, 42), queue.peek());
    try std.testing.expectEqual(@as(usize, 1), queue.len());

    try queue.enqueue(43);
    try std.testing.expectEqual(@as(?u32, 42), queue.peek());
    try std.testing.expectEqual(@as(usize, 2), queue.len());

    try std.testing.expectEqual(@as(u32, 42), try queue.dequeue());
    try std.testing.expectEqual(@as(?u32, 43), queue.peek());
}

test "RingQueue: auto-grow on capacity exceeded" {
    const allocator = std.testing.allocator;

    var queue = try RingQueue(u32).init(allocator, 2);
    defer queue.deinit();

    // Initial capacity is rounded up to power of 2, so at least 4
    try queue.enqueue(1);
    try queue.enqueue(2);
    try queue.enqueue(3);
    try queue.enqueue(4);
    try queue.enqueue(5); // Should trigger growth
    try queue.enqueue(6);
    try queue.enqueue(7);
    try queue.enqueue(8);
    try queue.enqueue(9); // Should trigger another growth

    try std.testing.expectEqual(@as(usize, 9), queue.len());

    // Verify FIFO order
    for (1..10) |expected| {
        const value = try queue.dequeue();
        try std.testing.expectEqual(@as(u32, @intCast(expected)), value);
    }
}

test "RingQueue: wrap-around behavior" {
    const allocator = std.testing.allocator;

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
    try std.testing.expectEqual(@as(u32, 3), try queue.dequeue());
    try std.testing.expectEqual(@as(u32, 4), try queue.dequeue());
    try std.testing.expectEqual(@as(u32, 5), try queue.dequeue());
    try std.testing.expectEqual(@as(u32, 6), try queue.dequeue());
}

test "RingQueue: dequeue from empty queue" {
    const allocator = std.testing.allocator;

    var queue = try RingQueue(u32).init(allocator, 4);
    defer queue.deinit();

    const result = queue.dequeue();
    try std.testing.expectError(error.EmptyQueue, result);
}

test "RingQueue: with struct type" {
    const allocator = std.testing.allocator;

    const Point = struct {
        x: i32,
        y: i32,
    };

    var queue = try RingQueue(Point).init(allocator, 4);
    defer queue.deinit();

    try queue.enqueue(.{ .x = 1, .y = 2 });
    try queue.enqueue(.{ .x = 3, .y = 4 });

    const p1 = try queue.dequeue();
    try std.testing.expectEqual(@as(i32, 1), p1.x);
    try std.testing.expectEqual(@as(i32, 2), p1.y);

    const p2 = try queue.dequeue();
    try std.testing.expectEqual(@as(i32, 3), p2.x);
    try std.testing.expectEqual(@as(i32, 4), p2.y);
}

test "RingQueue: stress test with many operations" {
    const allocator = std.testing.allocator;

    var queue = try RingQueue(usize).init(allocator, 8);
    defer queue.deinit();

    // Enqueue 1000 items, dequeue 500, enqueue 500 more
    for (0..1000) |i| {
        try queue.enqueue(i);
    }

    for (0..500) |i| {
        const value = try queue.dequeue();
        try std.testing.expectEqual(i, value);
    }

    for (1000..1500) |i| {
        try queue.enqueue(i);
    }

    // Should have items 500-1499
    for (500..1500) |expected| {
        const value = try queue.dequeue();
        try std.testing.expectEqual(expected, value);
    }

    try std.testing.expect(queue.isEmpty());
}
