const std = @import("std");
const c_api = @import("c_api.zig");

// Language parser stub implementations
// These will return null until actual language libraries are linked
// To enable a language:
// 1. Install the parser: npm install -g tree-sitter-{language}
// 2. Build the parser: tree-sitter build-wasm {language}
// 3. Or download prebuilt libraries

// Stub functions that will be replaced when linking actual libraries
fn tree_sitter_typescript_stub() callconv(.c) ?*const c_api.TSLanguage {
    return null;
}

fn tree_sitter_tsx_stub() callconv(.c) ?*const c_api.TSLanguage {
    return null;
}

fn tree_sitter_javascript_stub() callconv(.c) ?*const c_api.TSLanguage {
    return null;
}

fn tree_sitter_python_stub() callconv(.c) ?*const c_api.TSLanguage {
    return null;
}

fn tree_sitter_rust_stub() callconv(.c) ?*const c_api.TSLanguage {
    return null;
}

fn tree_sitter_go_stub() callconv(.c) ?*const c_api.TSLanguage {
    return null;
}

fn tree_sitter_zig_stub() callconv(.c) ?*const c_api.TSLanguage {
    return null;
}

fn tree_sitter_c_stub() callconv(.c) ?*const c_api.TSLanguage {
    return null;
}

fn tree_sitter_cpp_stub() callconv(.c) ?*const c_api.TSLanguage {
    return null;
}

fn tree_sitter_java_stub() callconv(.c) ?*const c_api.TSLanguage {
    return null;
}

// Export stub functions with the expected names
// These will be overridden by actual symbols when libraries are linked
pub const tree_sitter_typescript = if (@import("builtin").link_mode == .Dynamic)
    c_api.tree_sitter_typescript
else
    tree_sitter_typescript_stub;

pub const tree_sitter_tsx = if (@import("builtin").link_mode == .Dynamic)
    c_api.tree_sitter_tsx
else
    tree_sitter_tsx_stub;

pub const tree_sitter_javascript = if (@import("builtin").link_mode == .Dynamic)
    c_api.tree_sitter_javascript
else
    tree_sitter_javascript_stub;

pub const tree_sitter_python = if (@import("builtin").link_mode == .Dynamic)
    c_api.tree_sitter_python
else
    tree_sitter_python_stub;

pub const tree_sitter_rust = if (@import("builtin").link_mode == .Dynamic)
    c_api.tree_sitter_rust
else
    tree_sitter_rust_stub;

pub const tree_sitter_go = if (@import("builtin").link_mode == .Dynamic)
    c_api.tree_sitter_go
else
    tree_sitter_go_stub;

pub const tree_sitter_zig = if (@import("builtin").link_mode == .Dynamic)
    c_api.tree_sitter_zig
else
    tree_sitter_zig_stub;

pub const tree_sitter_c = if (@import("builtin").link_mode == .Dynamic)
    c_api.tree_sitter_c
else
    tree_sitter_c_stub;

pub const tree_sitter_cpp = if (@import("builtin").link_mode == .Dynamic)
    c_api.tree_sitter_cpp
else
    tree_sitter_cpp_stub;

pub const tree_sitter_java = if (@import("builtin").link_mode == .Dynamic)
    c_api.tree_sitter_java
else
    tree_sitter_java_stub;