//! Build script for Maze
//!
//! Handles:
//! - Linking with Zig-compiled Ananke core
//! - FFI bridge compilation
//! - Platform-specific configuration

use std::env;
use std::path::PathBuf;

fn main() {
    let project_root = PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap())
        .parent()
        .unwrap()
        .to_path_buf();

    // Tell cargo to look for Zig libraries in ../zig-out/lib
    let zig_lib_path = project_root.join("zig-out").join("lib");
    println!("cargo:rustc-link-search=native={}", zig_lib_path.display());

    // Link against Ananke Zig library (when available)
    // For now, this is optional - Maze can run standalone
    if zig_lib_path.exists() {
        println!("cargo:rustc-link-lib=static=ananke");
    }

    // Platform-specific linking
    let target_os = env::var("CARGO_CFG_TARGET_OS").unwrap();
    match target_os.as_str() {
        "linux" => {
            println!("cargo:rustc-link-lib=dylib=pthread");
            println!("cargo:rustc-link-lib=dylib=dl");
            println!("cargo:rustc-link-lib=dylib=m");
        }
        "macos" => {
            println!("cargo:rustc-link-lib=framework=CoreFoundation");
            println!("cargo:rustc-link-lib=framework=Security");
        }
        "windows" => {
            println!("cargo:rustc-link-lib=dylib=ws2_32");
            println!("cargo:rustc-link-lib=dylib=userenv");
        }
        _ => {}
    }

    // Rerun if Zig build changes
    println!("cargo:rerun-if-changed=../build.zig");
    println!("cargo:rerun-if-changed=../src");

    // Emit link-arg for FFI compatibility
    if target_os == "macos" {
        println!("cargo:rustc-link-arg=-Wl,-undefined,dynamic_lookup");
    }
}
