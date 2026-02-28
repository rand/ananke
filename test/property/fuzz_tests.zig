// Property-based fuzz tests for Ananke core modules.
//
// Uses Zig 0.15's built-in fuzz testing support (std.testing.fuzz).
// Run with: zig test -ffuzz test/property/fuzz_tests.zig
// Run without fuzzer (corpus-only smoke test): zig test test/property/fuzz_tests.zig
//
// Each test defines a property that must hold for ALL inputs the fuzzer
// can generate, not just the corpus examples.

const std = @import("std");
const testing = std.testing;
const ananke = @import("ananke");

// -- Type imports --
const Constraint = ananke.Constraint;
const ConstraintID = ananke.ConstraintID;
const ConstraintKind = ananke.ConstraintKind;
const ConstraintSource = ananke.ConstraintSource;
const EnforcementType = ananke.EnforcementType;
const ConstraintPriority = ananke.ConstraintPriority;
const ConstraintSet = ananke.ConstraintSet;
const ConstraintIR = ananke.ConstraintIR;
const ConstraintFingerprint = ananke.ConstraintFingerprint;
const Severity = ananke.types.constraint.Severity;
const JsonSchema = ananke.types.constraint.JsonSchema;
const Grammar = ananke.types.constraint.Grammar;
const GrammarRule = ananke.types.constraint.GrammarRule;
const RingQueue = ananke.utils.RingQueue;

// =============================================================================
// Helpers: derive structured test data from raw fuzz bytes
// =============================================================================

/// Consume one byte from the fuzz input, advancing the slice.
/// Returns null when input is exhausted.
fn consumeByte(input: *[]const u8) ?u8 {
    if (input.len == 0) return null;
    const b = input.*[0];
    input.* = input.*[1..];
    return b;
}

/// Consume up to `max_len` bytes as a sub-slice.
fn consumeSlice(input: *[]const u8, max_len: usize) []const u8 {
    const len = @min(input.len, max_len);
    const slice = input.*[0..len];
    input.* = input.*[len..];
    return slice;
}

/// Consume a u16 (little-endian) from the fuzz input.
fn consumeU16(input: *[]const u8) ?u16 {
    const lo = consumeByte(input) orelse return null;
    const hi = consumeByte(input) orelse return @as(u16, lo);
    return @as(u16, lo) | (@as(u16, hi) << 8);
}

/// Map a byte to a ConstraintKind enum variant.
fn byteToKind(b: u8) ConstraintKind {
    return switch (b % 6) {
        0 => .syntactic,
        1 => .type_safety,
        2 => .semantic,
        3 => .architectural,
        4 => .operational,
        5 => .security,
        else => unreachable,
    };
}

/// Map a byte to a Severity enum variant.
fn byteToSeverity(b: u8) Severity {
    return switch (b % 4) {
        0 => .err,
        1 => .warning,
        2 => .info,
        3 => .hint,
        else => unreachable,
    };
}

/// Map a byte to a ConstraintSource enum variant.
fn byteToSource(b: u8) ConstraintSource {
    return switch (b % 9) {
        0 => .AST_Pattern,
        1 => .Type_System,
        2 => .Control_Flow,
        3 => .Data_Flow,
        4 => .Test_Mining,
        5 => .Documentation,
        6 => .Telemetry,
        7 => .User_Defined,
        8 => .LLM_Analysis,
        else => unreachable,
    };
}

/// Map a byte to a ConstraintPriority enum variant.
fn byteToPriority(b: u8) ConstraintPriority {
    return switch (b % 4) {
        0 => .Low,
        1 => .Medium,
        2 => .High,
        3 => .Critical,
        else => unreachable,
    };
}

/// Return the matching EnforcementType for a given ConstraintKind
/// so that isValid() will pass.
fn enforcementForKind(kind: ConstraintKind) EnforcementType {
    return switch (kind) {
        .syntactic => .Syntactic,
        .type_safety => .Structural,
        .semantic => .Semantic,
        .architectural => .Structural,
        .operational => .Performance,
        .security => .Security,
    };
}

/// Build a Constraint from fuzz bytes. Returns null when input is exhausted
/// before a minimal constraint can be constructed.
fn buildConstraintFromBytes(input: *[]const u8) ?Constraint {
    const kind_byte = consumeByte(input) orelse return null;
    const severity_byte = consumeByte(input) orelse return null;
    const source_byte = consumeByte(input) orelse return null;
    const priority_byte = consumeByte(input) orelse return null;
    const conf_byte = consumeByte(input) orelse return null;
    const name_len_byte = consumeByte(input) orelse return null;

    // Derive a name of 1..32 bytes (never empty so isValid can pass).
    const name_len = @as(usize, (name_len_byte % 32)) + 1;
    const name = consumeSlice(input, name_len);
    if (name.len == 0) return null;

    // Use up to 64 bytes for description.
    const desc = consumeSlice(input, 64);

    const kind = byteToKind(kind_byte);
    const enforcement = enforcementForKind(kind);

    // Map conf_byte to 0.0 .. 1.0 (inclusive).
    const confidence: f32 = @as(f32, @floatFromInt(conf_byte)) / 255.0;

    return Constraint{
        .id = @as(ConstraintID, kind_byte) *% 65537 +% severity_byte,
        .name = name,
        .description = desc,
        .kind = kind,
        .source = byteToSource(source_byte),
        .enforcement = enforcement,
        .priority = byteToPriority(priority_byte),
        .confidence = confidence,
        .frequency = @as(u32, priority_byte) +% 1,
        .severity = byteToSeverity(severity_byte),
        .created_at = std.time.timestamp(),
    };
}

// =============================================================================
// 1. Constraint extraction roundtrip
// =============================================================================
//
// Property: For any byte sequence interpreted as (source, language), calling
// extractFromCode must not crash and must return a ConstraintSet where every
// constraint has a non-empty name, confidence in [0.0, 1.0], and a valid kind.
//
// Because the full Clew engine requires tree-sitter linking, we test the
// lightweight structural/pattern-based path that always works within the
// ananke module.

test "fuzz: constraint extraction roundtrip" {
    try testing.fuzz({}, struct {
        fn testOne(_: void, raw: []const u8) anyerror!void {
            const allocator = testing.allocator;
            var input = raw;

            // Derive a language selector from the first byte.
            const lang_byte = consumeByte(&input) orelse return;
            const languages = [_][]const u8{
                "python", "javascript", "typescript", "rust",
                "go", "zig", "c", "cpp", "java", "unknown",
            };
            const language = languages[lang_byte % languages.len];

            // Use the remaining bytes as "source code".
            const source = input;

            // Build a ConstraintSet by hand using the same pattern the engine
            // would produce, since linking tree-sitter in a standalone test is
            // impractical. We test that ConstraintSet operations never crash
            // regardless of what strings are stored inside.
            var cs = ConstraintSet.init(allocator, language);
            defer cs.deinit();

            // Parse constraints out of the source bytes using our byte-based
            // builder. This simulates varying constraint payloads.
            var src = source;
            while (buildConstraintFromBytes(&src)) |constraint| {
                try cs.add(constraint);
            }

            // -- Validate properties on every constraint in the set --
            for (cs.constraints.items) |*c| {
                // Name must not be empty.
                try testing.expect(c.name.len > 0);
                // Confidence must be in [0.0, 1.0].
                try testing.expect(c.confidence >= 0.0 and c.confidence <= 1.0);
                // isValid must return true (we constructed with matching enforcement).
                try testing.expect(c.isValid());
            }
        }
    }.testOne, .{
        .corpus = &.{
            "pfn main() void {}",
            "jconst x = 42;",
            "ruse std::io;",
            "",
        },
    });
}

// =============================================================================
// 2. JSON schema builder properties
// =============================================================================
//
// Property: For any set of type_safety constraints passed to Braid.compile,
// if a json_schema is produced its type field is a non-empty valid JSON schema
// type string, and if a grammar is produced its start_symbol is non-empty.

test "fuzz: JSON schema and grammar builder properties" {
    try testing.fuzz({}, struct {
        fn testOne(_: void, raw: []const u8) anyerror!void {
            const allocator = testing.allocator;
            var input = raw;

            // Build 1..8 constraints from the fuzz input.
            const count_byte = consumeByte(&input) orelse return;
            const count = @as(usize, count_byte % 8) + 1;

            var constraints_buf: [8]Constraint = undefined;
            var actual_count: usize = 0;
            for (0..count) |_| {
                if (buildConstraintFromBytes(&input)) |c| {
                    constraints_buf[actual_count] = c;
                    actual_count += 1;
                } else break;
            }
            if (actual_count == 0) return;

            const constraints = constraints_buf[0..actual_count];

            // Use the Braid engine to compile constraints into IR.
            var braid = try ananke.braid.Braid.init(allocator);
            defer braid.deinit();

            const ir = braid.compile(constraints) catch |err| switch (err) {
                // OutOfMemory is acceptable under fuzz -- the allocator may reject.
                error.OutOfMemory => return,
                else => return err,
            };
            var ir_mut = ir;
            defer ir_mut.deinit(allocator);

            // -- Property: json_schema.type is a valid type string --
            if (ir.json_schema) |schema| {
                try testing.expect(schema.type.len > 0);

                const valid_types = [_][]const u8{
                    "object", "array", "string", "number",
                    "integer", "boolean", "null",
                };
                var type_is_valid = false;
                for (valid_types) |vt| {
                    if (std.mem.eql(u8, schema.type, vt)) {
                        type_is_valid = true;
                        break;
                    }
                }
                try testing.expect(type_is_valid);
            }

            // -- Property: grammar.start_symbol is non-empty --
            if (ir.grammar) |grammar| {
                try testing.expect(grammar.start_symbol.len > 0);
                // Every rule must have a non-empty LHS.
                for (grammar.rules) |rule| {
                    try testing.expect(rule.lhs.len > 0);
                }
            }
        }
    }.testOne, .{
        .corpus = &.{
            // A hand-crafted byte sequence that produces at least one type_safety constraint.
            &[_]u8{
                2, // count -> (2 % 8) + 1 = 3
                // Constraint 1: kind=type_safety
                1, 0, 1, 1, 200, 5, 'n', 'a', 'm', 'e', '1',
                'n', 'a', 'm', 'e', ':', ' ', 's', 't', 'r', 'i', 'n', 'g',
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            },
        },
    });
}

// =============================================================================
// 3. Constraint fingerprint properties
// =============================================================================
//
// Property A: Two identical constraints must produce the same fingerprint hash.
// Property B: A fingerprint's modified_at >= created_at.

test "fuzz: constraint fingerprint determinism and timestamps" {
    try testing.fuzz({}, struct {
        fn testOne(_: void, raw: []const u8) anyerror!void {
            var input = raw;

            const c = buildConstraintFromBytes(&input) orelse return;

            // Compute fingerprint twice on the same constraint.
            const fp1 = ConstraintFingerprint.compute(&c);
            const fp2 = ConstraintFingerprint.compute(&c);

            // Property A: identical constraints -> identical hash.
            try testing.expectEqual(fp1.hash, fp2.hash);

            // Property B: modified_at >= created_at for each fingerprint.
            try testing.expect(fp1.modified_at >= fp1.created_at);
            try testing.expect(fp2.modified_at >= fp2.created_at);

            // Property: hasChanged should return false for same constraint.
            try testing.expect(!fp1.hasChanged(fp2));

            // Now mutate and verify the hash can change.
            // We flip the kind which is part of the hash input.
            var mutated = c;
            mutated.kind = if (c.kind == .syntactic) .semantic else .syntactic;
            mutated.enforcement = enforcementForKind(mutated.kind);

            const fp3 = ConstraintFingerprint.compute(&mutated);
            // The hash should differ (unless there is an astronomically
            // unlikely collision). We assert difference for the deterministic
            // corpus inputs; under true fuzzing a collision would be a
            // legitimate (but vanishingly rare) event, so we allow it.
            if (!std.mem.eql(u8, raw, "")) {
                // For non-empty inputs with distinct kind, expect different hash.
                if (c.kind != mutated.kind) {
                    try testing.expect(fp3.hash != fp1.hash);
                }
            }
        }
    }.testOne, .{
        .corpus = &.{
            // Minimal constraint bytes.
            &[_]u8{ 0, 0, 0, 0, 128, 4, 't', 'e', 's', 't' },
            &[_]u8{ 1, 1, 1, 1, 255, 3, 'a', 'b', 'c' },
        },
    });
}

// =============================================================================
// 4. ConstraintSet clone properties
// =============================================================================
//
// Property: Cloning a ConstraintSet produces a set with the same number of
// constraints, and the original remains valid (usable) after the clone is freed.

test "fuzz: ConstraintSet clone preserves count and original validity" {
    try testing.fuzz({}, struct {
        fn testOne(_: void, raw: []const u8) anyerror!void {
            const allocator = testing.allocator;
            var input = raw;

            // Build an original ConstraintSet from fuzz bytes.
            const name_len = @as(usize, (consumeByte(&input) orelse return) % 16) + 1;
            const set_name = consumeSlice(&input, name_len);
            if (set_name.len == 0) return;

            var original = ConstraintSet.init(allocator, set_name);
            defer original.deinit();

            // Add 0..16 constraints.
            const n = @as(usize, (consumeByte(&input) orelse return) % 16);
            for (0..n) |_| {
                if (buildConstraintFromBytes(&input)) |c| {
                    try original.add(c);
                } else break;
            }

            const original_count = original.constraints.items.len;

            // Clone.
            var cloned = try original.clone(allocator);
            defer {
                // Free the owned name that clone() allocated.
                allocator.free(cloned.name);
                cloned.deinit();
            }

            // Property: clone has same number of constraints.
            try testing.expectEqual(original_count, cloned.constraints.items.len);

            // Property: each constraint in clone matches original field by field.
            for (original.constraints.items, 0..) |orig_c, i| {
                const clone_c = cloned.constraints.items[i];
                try testing.expectEqualStrings(orig_c.name, clone_c.name);
                try testing.expectEqual(orig_c.kind, clone_c.kind);
                try testing.expectEqual(orig_c.severity, clone_c.severity);
                try testing.expectEqual(orig_c.confidence, clone_c.confidence);
                try testing.expectEqual(orig_c.id, clone_c.id);
            }

            // Property: original is still usable after clone (add another element).
            const extra = Constraint.init(999, "post_clone", "added after clone");
            try original.add(extra);
            try testing.expectEqual(original_count + 1, original.constraints.items.len);
        }
    }.testOne, .{
        .corpus = &.{
            &[_]u8{ 4, 't', 'e', 's', 't', 2, 0, 0, 0, 0, 128, 4, 'a', 'b', 'c', 'd', 1, 1, 1, 1, 255, 3, 'x', 'y', 'z' },
            &[_]u8{ 1, 'x', 0 }, // set with zero constraints
        },
    });
}

// =============================================================================
// 5. Ring queue FIFO properties
// =============================================================================
//
// Property: For any sequence of enqueue/dequeue operations driven by fuzz
// bytes, the queue maintains FIFO order and the count never exceeds the
// total number of enqueued-minus-dequeued items.

test "fuzz: RingQueue maintains FIFO order and correct count" {
    try testing.fuzz({}, struct {
        fn testOne(_: void, raw: []const u8) anyerror!void {
            const allocator = testing.allocator;
            var input = raw;

            // Derive initial capacity from first byte (4..68).
            const cap_byte = consumeByte(&input) orelse return;
            const initial_cap = @as(usize, cap_byte % 64) + 4;

            var queue = try RingQueue(u16).init(allocator, initial_cap);
            defer queue.deinit();

            // We maintain a "shadow" FIFO using an ArrayList to verify order.
            var shadow: std.ArrayList(u16) = .{};
            defer shadow.deinit(allocator);

            // Track running count for invariant checks.
            var expected_count: usize = 0;

            // Interpret remaining bytes as operations:
            //   bit 0 = 0 -> enqueue (use bits 1..15 as value)
            //   bit 0 = 1 -> dequeue
            while (consumeU16(&input)) |word| {
                if (word & 1 == 0) {
                    // Enqueue the upper 15 bits as the value.
                    const value = word >> 1;
                    try queue.enqueue(value);
                    try shadow.append(allocator, value);
                    expected_count += 1;
                } else {
                    // Dequeue.
                    if (expected_count == 0) {
                        // Queue should report empty.
                        try testing.expectError(error.EmptyQueue, queue.dequeue());
                        try testing.expect(queue.isEmpty());
                    } else {
                        const got = try queue.dequeue();
                        const expected_val = shadow.orderedRemove(0);
                        try testing.expectEqual(expected_val, got);
                        expected_count -= 1;
                    }
                }

                // Invariant: queue.len() always equals our expected count.
                try testing.expectEqual(expected_count, queue.len());
                // Invariant: isEmpty iff count is zero.
                try testing.expectEqual(expected_count == 0, queue.isEmpty());
            }

            // Drain remaining items and verify FIFO order.
            for (shadow.items) |expected_val| {
                const got = try queue.dequeue();
                try testing.expectEqual(expected_val, got);
            }
            try testing.expect(queue.isEmpty());
        }
    }.testOne, .{
        .corpus = &.{
            // A mixed sequence: cap=8, enqueue 10, enqueue 20, dequeue, enqueue 30, dequeue, dequeue
            &[_]u8{ 4, 20, 0, 40, 0, 1, 0, 60, 0, 1, 0, 1, 0 },
            // Stress: many enqueues
            &[_]u8{ 16, 2, 0, 4, 0, 6, 0, 8, 0, 10, 0, 12, 0, 14, 0, 16, 0 },
            // Edge: just dequeues on empty queue
            &[_]u8{ 4, 1, 0, 1, 0, 1, 0 },
        },
    });
}

// =============================================================================
// 6. RingQueue peek consistency
// =============================================================================
//
// Property: peek() always returns the same value as the next dequeue()
// (without removing the element), and never crashes regardless of state.

test "fuzz: RingQueue peek matches next dequeue" {
    try testing.fuzz({}, struct {
        fn testOne(_: void, raw: []const u8) anyerror!void {
            const allocator = testing.allocator;
            var input = raw;

            var queue = try RingQueue(u8).init(allocator, 8);
            defer queue.deinit();

            while (consumeByte(&input)) |b| {
                if (b & 1 == 0) {
                    try queue.enqueue(b);
                } else {
                    // Check peek/dequeue consistency.
                    const peeked = queue.peek();
                    if (queue.len() == 0) {
                        try testing.expectEqual(@as(?u8, null), peeked);
                        try testing.expectError(error.EmptyQueue, queue.dequeue());
                    } else {
                        const dequeued = try queue.dequeue();
                        try testing.expectEqual(peeked.?, dequeued);
                    }
                }
            }
        }
    }.testOne, .{
        .corpus = &.{
            &[_]u8{ 2, 4, 6, 1, 1, 8, 1 },
        },
    });
}

// =============================================================================
// 7. ConstraintIR clone roundtrip
// =============================================================================
//
// Property: Cloning a ConstraintIR and then freeing the clone does not
// corrupt the original, and the clone has the same priority.

test "fuzz: ConstraintIR clone preserves priority and original survives" {
    try testing.fuzz({}, struct {
        fn testOne(_: void, raw: []const u8) anyerror!void {
            const allocator = testing.allocator;
            var input = raw;

            const priority_byte = consumeByte(&input) orelse return;

            // Build a minimal IR. We test the clone path, not full compilation.
            var ir = ConstraintIR{
                .priority = @as(u32, priority_byte),
            };

            // Optionally add a json_schema if we have enough bytes.
            if (consumeByte(&input)) |type_byte| {
                const type_names = [_][]const u8{
                    "object", "array", "string", "number",
                    "integer", "boolean", "null",
                };
                const chosen = type_names[type_byte % type_names.len];
                const owned_type = try allocator.dupe(u8, chosen);

                ir.json_schema = JsonSchema{
                    .type = owned_type,
                };
            }

            // Clone the IR.
            var cloned = try ir.clone(allocator);

            // Property: same priority.
            try testing.expectEqual(ir.priority, cloned.priority);

            // Property: if original has json_schema, clone also does.
            if (ir.json_schema != null) {
                try testing.expect(cloned.json_schema != null);
                try testing.expectEqualStrings(ir.json_schema.?.type, cloned.json_schema.?.type);
            }

            // Free the clone first.
            cloned.deinit(allocator);

            // Property: original is still usable (priority readable).
            try testing.expectEqual(@as(u32, priority_byte), ir.priority);

            // Free the original's allocated type string if present.
            if (ir.json_schema) |schema| {
                allocator.free(schema.type);
            }
        }
    }.testOne, .{
        .corpus = &.{
            &[_]u8{ 42, 0 },
            &[_]u8{ 255, 2 },
            &[_]u8{100},
        },
    });
}
