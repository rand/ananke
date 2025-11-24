//! FFI integration example
//!
//! Demonstrates converting between Zig and Rust types via FFI.
//!
//! Build: cargo build --example rust_ffi_integration

use ananke_maze::ffi::{ConstraintIR, Intent, GenerationResult};
use std::ffi::{CString, CStr};

fn main() {
    println!("\n=== Ananke FFI Integration Example ===\n");
    
    // Example 1: Creating ConstraintIR in Rust
    println!("Example 1: Creating ConstraintIR in Rust");
    println!("{}", "-".repeat(50));
    
    let constraint = ConstraintIR {
        name: "no_eval".to_string(),
        json_schema: None,
        grammar: None,
        regex_patterns: vec![],
        token_masks: None,
        priority: 100,
    };
    
    println!("Created constraint: {}", constraint.name);
    println!("Priority: {}", constraint.priority);
    
    // Convert to FFI for passing to Zig
    let ffi_ptr = constraint.to_ffi();
    println!("Converted to FFI pointer: {:?}\n", ffi_ptr);
    
    // Clean up
    unsafe {
        ananke_maze::ffi::free_constraint_ir_ffi(ffi_ptr);
    }
    
    // Example 2: Round-trip conversion
    println!("Example 2: Round-trip Rust → FFI → Rust");
    println!("{}", "-".repeat(50));
    
    let original = ConstraintIR {
        name: "type_safety".to_string(),
        json_schema: None,
        grammar: None,
        regex_patterns: vec![
            ananke_maze::ffi::RegexPattern {
                pattern: r"\d+".to_string(),
                flags: "g".to_string(),
            }
        ],
        token_masks: None,
        priority: 90,
    };
    
    println!("Original: name={}, patterns={}", 
        original.name, original.regex_patterns.len());
    
    // Convert to FFI and back
    let ffi_ptr = original.to_ffi();
    let restored = unsafe {
        ConstraintIR::from_ffi(ffi_ptr).expect("Failed to convert from FFI")
    };
    
    println!("Restored: name={}, patterns={}", 
        restored.name, restored.regex_patterns.len());
    println!("Match: {}\n", original.name == restored.name);
    
    unsafe {
        ananke_maze::ffi::free_constraint_ir_ffi(ffi_ptr);
    }
    
    // Example 3: Creating Intent
    println!("Example 3: Creating Intent for code generation");
    println!("{}", "-".repeat(50));
    
    let intent = Intent {
        raw_input: "Add authentication to the API".to_string(),
        prompt: "Implement JWT-based authentication middleware for Express API".to_string(),
        current_file: Some("src/middleware/auth.ts".to_string()),
        language: Some("typescript".to_string()),
    };
    
    println!("Intent:");
    println!("  Prompt: {}", intent.prompt);
    println!("  File: {:?}", intent.current_file);
    println!("  Language: {:?}\n", intent.language);
    
    // Example 4: Creating GenerationResult
    println!("Example 4: Creating GenerationResult");
    println!("{}", "-".repeat(50));
    
    let result = GenerationResult {
        code: r#"
export const authMiddleware = (req, res, next) => {
    const token = req.headers.authorization?.split(' ')[1];
    
    if (!token) {
        return res.status(401).json({ error: 'No token provided' });
    }
    
    try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        req.user = decoded;
        next();
    } catch (err) {
        return res.status(401).json({ error: 'Invalid token' });
    }
};
"#.to_string(),
        success: true,
        error: None,
        tokens_generated: 87,
        generation_time_ms: 2150,
    };
    
    println!("Result:");
    println!("  Success: {}", result.success);
    println!("  Tokens: {}", result.tokens_generated);
    println!("  Time: {}ms", result.generation_time_ms);
    println!("  Code length: {} bytes\n", result.code.len());
    
    // Convert to FFI
    let result_ffi = result.to_ffi();
    println!("Converted to FFI for Zig consumption");
    
    unsafe {
        println!("  FFI success: {}", (*result_ffi).success);
        println!("  FFI tokens: {}", (*result_ffi).tokens_generated);
        ananke_maze::ffi::free_generation_result_ffi(result_ffi);
    }
    
    // Example 5: Simulating Zig → Rust workflow
    println!("\nExample 5: Simulated Zig → Rust workflow");
    println!("{}", "-".repeat(50));
    
    println!("1. Zig extracts constraints with Clew");
    println!("2. Zig compiles constraints with Braid");
    println!("3. Zig creates ConstraintIR and Intent");
    println!("4. Zig passes to Rust via FFI");
    println!("5. Rust converts from FFI");
    
    let zig_constraint = ConstraintIR {
        name: "from_zig".to_string(),
        json_schema: None,
        grammar: None,
        regex_patterns: vec![],
        token_masks: None,
        priority: 100,
    };
    
    println!("6. Rust processes constraint: {}", zig_constraint.name);
    println!("7. Rust calls Modal for generation");
    println!("8. Rust creates GenerationResult");
    println!("9. Rust converts to FFI");
    println!("10. Zig receives result via FFI");
    
    println!("\n✓ FFI integration examples complete!");
    println!("\nKey Points:");
    println!("  • Always free FFI pointers with appropriate functions");
    println!("  • FFI conversions handle null safety");
    println!("  • String conversion uses CString for safety");
    println!("  • Memory layout matches C ABI for compatibility");
}
