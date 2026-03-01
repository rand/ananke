//! SIMD Vector Implementation
//! Demonstrates SIMD operations using Zig's vector types

const std = @import("std");

/// 4-component float vector using SIMD
pub const Vec4f = @Vector(4, f32);

/// 4-component integer vector
pub const Vec4i = @Vector(4, i32);

/// 8-component float vector for wider SIMD
pub const Vec8f = @Vector(8, f32);

/// Vector operations namespace
pub const vec = struct {
    /// Create a Vec4f from individual components
    pub fn vec4f(x: f32, y: f32, z: f32, w: f32) Vec4f {
        return .{ x, y, z, w };
    }

    /// Create a Vec4f with all components set to the same value
    pub fn splat4f(v: f32) Vec4f {
        return @splat(v);
    }

    /// Create a Vec4i with all components set to the same value
    pub fn splat4i(v: i32) Vec4i {
        return @splat(v);
    }

    /// Dot product of two Vec4f
    pub fn dot(a: Vec4f, b: Vec4f) f32 {
        const prod = a * b;
        return @reduce(.Add, prod);
    }

    /// Length/magnitude of a Vec4f
    pub fn length(v: Vec4f) f32 {
        return @sqrt(dot(v, v));
    }

    /// Normalize a Vec4f to unit length
    pub fn normalize(v: Vec4f) Vec4f {
        const len = length(v);
        if (len == 0) return v;
        return v / splat4f(len);
    }

    /// Cross product (for 3D vectors, w component ignored)
    pub fn cross(a: Vec4f, b: Vec4f) Vec4f {
        // a.y*b.z - a.z*b.y, a.z*b.x - a.x*b.z, a.x*b.y - a.y*b.x
        const mask_yzx = @Vector(4, i32){ 1, 2, 0, 3 };
        const mask_zxy = @Vector(4, i32){ 2, 0, 1, 3 };
        const a_yzx = @shuffle(f32, a, undefined, mask_yzx);
        const a_zxy = @shuffle(f32, a, undefined, mask_zxy);
        const b_yzx = @shuffle(f32, b, undefined, mask_yzx);
        const b_zxy = @shuffle(f32, b, undefined, mask_zxy);

        var result = a_yzx * b_zxy - a_zxy * b_yzx;
        result[3] = 0;
        return result;
    }

    /// Linear interpolation between two vectors
    pub fn lerp(a: Vec4f, b: Vec4f, t: f32) Vec4f {
        const t_vec = splat4f(t);
        const one_minus_t = splat4f(1.0 - t);
        return a * one_minus_t + b * t_vec;
    }

    /// Component-wise minimum
    pub fn min(a: Vec4f, b: Vec4f) Vec4f {
        return @min(a, b);
    }

    /// Component-wise maximum
    pub fn max(a: Vec4f, b: Vec4f) Vec4f {
        return @max(a, b);
    }

    /// Clamp each component between min and max
    pub fn clamp(v: Vec4f, min_val: f32, max_val: f32) Vec4f {
        return @min(@max(v, splat4f(min_val)), splat4f(max_val));
    }

    /// Absolute value of each component
    pub fn abs(v: Vec4f) Vec4f {
        return @abs(v);
    }

    /// Floor of each component
    pub fn floor(v: Vec4f) Vec4f {
        return @floor(v);
    }

    /// Ceiling of each component
    pub fn ceil(v: Vec4f) Vec4f {
        return @ceil(v);
    }

    /// Distance between two points
    pub fn distance(a: Vec4f, b: Vec4f) f32 {
        return length(a - b);
    }

    /// Reflect vector off a surface with given normal
    pub fn reflect(v: Vec4f, normal: Vec4f) Vec4f {
        const d = dot(v, normal);
        return v - splat4f(2.0 * d) * normal;
    }
};

/// Matrix 4x4 using SIMD vectors
pub const Mat4 = struct {
    rows: [4]Vec4f,

    const Self = @This();

    pub fn identity() Self {
        return .{
            .rows = .{
                vec.vec4f(1, 0, 0, 0),
                vec.vec4f(0, 1, 0, 0),
                vec.vec4f(0, 0, 1, 0),
                vec.vec4f(0, 0, 0, 1),
            },
        };
    }

    pub fn zero() Self {
        return .{
            .rows = .{
                vec.splat4f(0),
                vec.splat4f(0),
                vec.splat4f(0),
                vec.splat4f(0),
            },
        };
    }

    pub fn translation(x: f32, y: f32, z: f32) Self {
        return .{
            .rows = .{
                vec.vec4f(1, 0, 0, x),
                vec.vec4f(0, 1, 0, y),
                vec.vec4f(0, 0, 1, z),
                vec.vec4f(0, 0, 0, 1),
            },
        };
    }

    pub fn scaling(x: f32, y: f32, z: f32) Self {
        return .{
            .rows = .{
                vec.vec4f(x, 0, 0, 0),
                vec.vec4f(0, y, 0, 0),
                vec.vec4f(0, 0, z, 0),
                vec.vec4f(0, 0, 0, 1),
            },
        };
    }

    pub fn rotationX(angle: f32) Self {
        const c = @cos(angle);
        const s = @sin(angle);
        return .{
            .rows = .{
                vec.vec4f(1, 0, 0, 0),
                vec.vec4f(0, c, -s, 0),
                vec.vec4f(0, s, c, 0),
                vec.vec4f(0, 0, 0, 1),
            },
        };
    }

    pub fn rotationY(angle: f32) Self {
        const c = @cos(angle);
        const s = @sin(angle);
        return .{
            .rows = .{
                vec.vec4f(c, 0, s, 0),
                vec.vec4f(0, 1, 0, 0),
                vec.vec4f(-s, 0, c, 0),
                vec.vec4f(0, 0, 0, 1),
            },
        };
    }

    pub fn rotationZ(angle: f32) Self {
        const c = @cos(angle);
        const s = @sin(angle);
        return .{
            .rows = .{
                vec.vec4f(c, -s, 0, 0),
                vec.vec4f(s, c, 0, 0),
                vec.vec4f(0, 0, 1, 0),
                vec.vec4f(0, 0, 0, 1),
            },
        };
    }

    /// Multiply matrix by vector
    pub fn mulVec(self: Self, v: Vec4f) Vec4f {
        return .{
            vec.dot(self.rows[0], v),
            vec.dot(self.rows[1], v),
            vec.dot(self.rows[2], v),
            vec.dot(self.rows[3], v),
        };
    }

    /// Multiply two matrices
    pub fn mul(a: Self, b: Self) Self {
        var result: Self = undefined;

        for (0..4) |i| {
            const row = a.rows[i];
            result.rows[i] = vec.splat4f(row[0]) * b.rows[0] +
                vec.splat4f(row[1]) * b.rows[1] +
                vec.splat4f(row[2]) * b.rows[2] +
                vec.splat4f(row[3]) * b.rows[3];
        }

        return result;
    }

    /// Transpose the matrix
    pub fn transpose(self: Self) Self {
        return .{
            .rows = .{
                vec.vec4f(self.rows[0][0], self.rows[1][0], self.rows[2][0], self.rows[3][0]),
                vec.vec4f(self.rows[0][1], self.rows[1][1], self.rows[2][1], self.rows[3][1]),
                vec.vec4f(self.rows[0][2], self.rows[1][2], self.rows[2][2], self.rows[3][2]),
                vec.vec4f(self.rows[0][3], self.rows[1][3], self.rows[2][3], self.rows[3][3]),
            },
        };
    }
};

/// SIMD array operations
pub fn SimdArray(comptime T: type, comptime vector_len: usize) type {
    const VecT = @Vector(vector_len, T);

    return struct {
        pub fn add(a: []const T, b: []const T, result: []T) void {
            const len = @min(a.len, @min(b.len, result.len));
            var i: usize = 0;

            // Process vector_len elements at a time
            while (i + vector_len <= len) : (i += vector_len) {
                const va: VecT = a[i..][0..vector_len].*;
                const vb: VecT = b[i..][0..vector_len].*;
                result[i..][0..vector_len].* = va + vb;
            }

            // Handle remainder
            while (i < len) : (i += 1) {
                result[i] = a[i] + b[i];
            }
        }

        pub fn mul(a: []const T, b: []const T, result: []T) void {
            const len = @min(a.len, @min(b.len, result.len));
            var i: usize = 0;

            while (i + vector_len <= len) : (i += vector_len) {
                const va: VecT = a[i..][0..vector_len].*;
                const vb: VecT = b[i..][0..vector_len].*;
                result[i..][0..vector_len].* = va * vb;
            }

            while (i < len) : (i += 1) {
                result[i] = a[i] * b[i];
            }
        }

        pub fn scale(arr: []const T, scalar: T, result: []T) void {
            const len = @min(arr.len, result.len);
            const scalar_vec: VecT = @splat(scalar);
            var i: usize = 0;

            while (i + vector_len <= len) : (i += vector_len) {
                const v: VecT = arr[i..][0..vector_len].*;
                result[i..][0..vector_len].* = v * scalar_vec;
            }

            while (i < len) : (i += 1) {
                result[i] = arr[i] * scalar;
            }
        }

        pub fn sum(arr: []const T) T {
            var total: T = 0;
            var i: usize = 0;

            while (i + vector_len <= arr.len) : (i += vector_len) {
                const v: VecT = arr[i..][0..vector_len].*;
                total += @reduce(.Add, v);
            }

            while (i < arr.len) : (i += 1) {
                total += arr[i];
            }

            return total;
        }

        pub fn dotProduct(a: []const T, b: []const T) T {
            const len = @min(a.len, b.len);
            var total: T = 0;
            var i: usize = 0;

            while (i + vector_len <= len) : (i += vector_len) {
                const va: VecT = a[i..][0..vector_len].*;
                const vb: VecT = b[i..][0..vector_len].*;
                total += @reduce(.Add, va * vb);
            }

            while (i < len) : (i += 1) {
                total += a[i] * b[i];
            }

            return total;
        }
    };
}
