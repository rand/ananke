const std = @import("std");
const testing = std.testing;
const simd = @import("simd_vector.zig");

const vec = simd.vec;
const Vec4f = simd.Vec4f;
const Mat4 = simd.Mat4;

test "vec4f - create vector" {
    const v = vec.vec4f(1, 2, 3, 4);
    try testing.expectEqual(@as(f32, 1), v[0]);
    try testing.expectEqual(@as(f32, 2), v[1]);
    try testing.expectEqual(@as(f32, 3), v[2]);
    try testing.expectEqual(@as(f32, 4), v[3]);
}

test "splat4f - uniform vector" {
    const v = vec.splat4f(5);
    try testing.expectEqual(@as(f32, 5), v[0]);
    try testing.expectEqual(@as(f32, 5), v[1]);
    try testing.expectEqual(@as(f32, 5), v[2]);
    try testing.expectEqual(@as(f32, 5), v[3]);
}

test "dot - dot product" {
    const a = vec.vec4f(1, 2, 3, 4);
    const b = vec.vec4f(5, 6, 7, 8);
    const result = vec.dot(a, b);
    // 1*5 + 2*6 + 3*7 + 4*8 = 5 + 12 + 21 + 32 = 70
    try testing.expectEqual(@as(f32, 70), result);
}

test "length - vector magnitude" {
    const v = vec.vec4f(3, 0, 4, 0);
    const len = vec.length(v);
    // sqrt(9 + 16) = sqrt(25) = 5
    try testing.expectEqual(@as(f32, 5), len);
}

test "normalize - unit vector" {
    const v = vec.vec4f(3, 0, 4, 0);
    const n = vec.normalize(v);
    const len = vec.length(n);
    try testing.expectApproxEqAbs(@as(f32, 1), len, 0.0001);
}

test "normalize - zero vector" {
    const v = vec.vec4f(0, 0, 0, 0);
    const n = vec.normalize(v);
    try testing.expectEqual(@as(f32, 0), n[0]);
}

test "cross - cross product" {
    const a = vec.vec4f(1, 0, 0, 0);
    const b = vec.vec4f(0, 1, 0, 0);
    const c = vec.cross(a, b);
    // x cross y = z
    try testing.expectApproxEqAbs(@as(f32, 0), c[0], 0.0001);
    try testing.expectApproxEqAbs(@as(f32, 0), c[1], 0.0001);
    try testing.expectApproxEqAbs(@as(f32, 1), c[2], 0.0001);
}

test "lerp - linear interpolation" {
    const a = vec.vec4f(0, 0, 0, 0);
    const b = vec.vec4f(10, 10, 10, 10);
    const mid = vec.lerp(a, b, 0.5);
    try testing.expectEqual(@as(f32, 5), mid[0]);
    try testing.expectEqual(@as(f32, 5), mid[1]);
}

test "min - component minimum" {
    const a = vec.vec4f(1, 5, 3, 7);
    const b = vec.vec4f(2, 3, 4, 6);
    const m = vec.min(a, b);
    try testing.expectEqual(@as(f32, 1), m[0]);
    try testing.expectEqual(@as(f32, 3), m[1]);
    try testing.expectEqual(@as(f32, 3), m[2]);
    try testing.expectEqual(@as(f32, 6), m[3]);
}

test "max - component maximum" {
    const a = vec.vec4f(1, 5, 3, 7);
    const b = vec.vec4f(2, 3, 4, 6);
    const m = vec.max(a, b);
    try testing.expectEqual(@as(f32, 2), m[0]);
    try testing.expectEqual(@as(f32, 5), m[1]);
    try testing.expectEqual(@as(f32, 4), m[2]);
    try testing.expectEqual(@as(f32, 7), m[3]);
}

test "clamp - clamp values" {
    const v = vec.vec4f(-1, 0.5, 1.5, 2);
    const c = vec.clamp(v, 0, 1);
    try testing.expectEqual(@as(f32, 0), c[0]);
    try testing.expectEqual(@as(f32, 0.5), c[1]);
    try testing.expectEqual(@as(f32, 1), c[2]);
    try testing.expectEqual(@as(f32, 1), c[3]);
}

test "abs - absolute value" {
    const v = vec.vec4f(-1, 2, -3, 4);
    const a = vec.abs(v);
    try testing.expectEqual(@as(f32, 1), a[0]);
    try testing.expectEqual(@as(f32, 2), a[1]);
    try testing.expectEqual(@as(f32, 3), a[2]);
    try testing.expectEqual(@as(f32, 4), a[3]);
}

test "floor - floor values" {
    const v = vec.vec4f(1.5, 2.9, -1.5, -2.9);
    const f = vec.floor(v);
    try testing.expectEqual(@as(f32, 1), f[0]);
    try testing.expectEqual(@as(f32, 2), f[1]);
    try testing.expectEqual(@as(f32, -2), f[2]);
    try testing.expectEqual(@as(f32, -3), f[3]);
}

test "ceil - ceiling values" {
    const v = vec.vec4f(1.5, 2.1, -1.5, -2.1);
    const c = vec.ceil(v);
    try testing.expectEqual(@as(f32, 2), c[0]);
    try testing.expectEqual(@as(f32, 3), c[1]);
    try testing.expectEqual(@as(f32, -1), c[2]);
    try testing.expectEqual(@as(f32, -2), c[3]);
}

test "distance - between points" {
    const a = vec.vec4f(0, 0, 0, 0);
    const b = vec.vec4f(3, 4, 0, 0);
    const d = vec.distance(a, b);
    try testing.expectEqual(@as(f32, 5), d);
}

test "Mat4 - identity" {
    const m = Mat4.identity();
    try testing.expectEqual(@as(f32, 1), m.rows[0][0]);
    try testing.expectEqual(@as(f32, 1), m.rows[1][1]);
    try testing.expectEqual(@as(f32, 1), m.rows[2][2]);
    try testing.expectEqual(@as(f32, 1), m.rows[3][3]);
}

test "Mat4 - zero" {
    const m = Mat4.zero();
    for (0..4) |i| {
        for (0..4) |j| {
            try testing.expectEqual(@as(f32, 0), m.rows[i][j]);
        }
    }
}

test "Mat4 - mulVec with identity" {
    const m = Mat4.identity();
    const v = vec.vec4f(1, 2, 3, 1);
    const result = m.mulVec(v);
    try testing.expectEqual(@as(f32, 1), result[0]);
    try testing.expectEqual(@as(f32, 2), result[1]);
    try testing.expectEqual(@as(f32, 3), result[2]);
}

test "Mat4 - translation" {
    const m = Mat4.translation(10, 20, 30);
    const v = vec.vec4f(0, 0, 0, 1);
    const result = m.mulVec(v);
    try testing.expectEqual(@as(f32, 10), result[0]);
    try testing.expectEqual(@as(f32, 20), result[1]);
    try testing.expectEqual(@as(f32, 30), result[2]);
}

test "Mat4 - scaling" {
    const m = Mat4.scaling(2, 3, 4);
    const v = vec.vec4f(1, 1, 1, 1);
    const result = m.mulVec(v);
    try testing.expectEqual(@as(f32, 2), result[0]);
    try testing.expectEqual(@as(f32, 3), result[1]);
    try testing.expectEqual(@as(f32, 4), result[2]);
}

test "Mat4 - mul with identity" {
    const a = Mat4.translation(1, 2, 3);
    const b = Mat4.identity();
    const result = Mat4.mul(a, b);
    try testing.expectEqual(@as(f32, 1), result.rows[0][3]);
    try testing.expectEqual(@as(f32, 2), result.rows[1][3]);
    try testing.expectEqual(@as(f32, 3), result.rows[2][3]);
}

test "Mat4 - transpose" {
    var m = Mat4.zero();
    m.rows[0][1] = 5;
    m.rows[1][0] = 0;

    const t = m.transpose();
    try testing.expectEqual(@as(f32, 5), t.rows[1][0]);
    try testing.expectEqual(@as(f32, 0), t.rows[0][1]);
}

test "SimdArray - add" {
    const SimdF32 = simd.SimdArray(f32, 4);
    var a = [_]f32{ 1, 2, 3, 4, 5, 6, 7, 8 };
    var b = [_]f32{ 8, 7, 6, 5, 4, 3, 2, 1 };
    var result: [8]f32 = undefined;

    SimdF32.add(&a, &b, &result);

    for (result) |v| {
        try testing.expectEqual(@as(f32, 9), v);
    }
}

test "SimdArray - mul" {
    const SimdF32 = simd.SimdArray(f32, 4);
    var a = [_]f32{ 1, 2, 3, 4 };
    var b = [_]f32{ 2, 2, 2, 2 };
    var result: [4]f32 = undefined;

    SimdF32.mul(&a, &b, &result);

    try testing.expectEqual(@as(f32, 2), result[0]);
    try testing.expectEqual(@as(f32, 4), result[1]);
    try testing.expectEqual(@as(f32, 6), result[2]);
    try testing.expectEqual(@as(f32, 8), result[3]);
}

test "SimdArray - scale" {
    const SimdF32 = simd.SimdArray(f32, 4);
    var arr = [_]f32{ 1, 2, 3, 4, 5, 6, 7, 8 };
    var result: [8]f32 = undefined;

    SimdF32.scale(&arr, 2, &result);

    try testing.expectEqual(@as(f32, 2), result[0]);
    try testing.expectEqual(@as(f32, 4), result[1]);
    try testing.expectEqual(@as(f32, 16), result[7]);
}

test "SimdArray - sum" {
    const SimdF32 = simd.SimdArray(f32, 4);
    var arr = [_]f32{ 1, 2, 3, 4, 5, 6, 7, 8 };
    const total = SimdF32.sum(&arr);
    try testing.expectEqual(@as(f32, 36), total);
}

test "SimdArray - dotProduct" {
    const SimdF32 = simd.SimdArray(f32, 4);
    var a = [_]f32{ 1, 2, 3, 4 };
    var b = [_]f32{ 4, 3, 2, 1 };
    const dot_result = SimdF32.dotProduct(&a, &b);
    // 1*4 + 2*3 + 3*2 + 4*1 = 4 + 6 + 6 + 4 = 20
    try testing.expectEqual(@as(f32, 20), dot_result);
}

test "SimdArray - non-aligned length" {
    const SimdF32 = simd.SimdArray(f32, 4);
    var a = [_]f32{ 1, 2, 3, 4, 5 }; // 5 elements, not divisible by 4
    var b = [_]f32{ 1, 1, 1, 1, 1 };
    var result: [5]f32 = undefined;

    SimdF32.add(&a, &b, &result);

    try testing.expectEqual(@as(f32, 2), result[0]);
    try testing.expectEqual(@as(f32, 6), result[4]);
}
