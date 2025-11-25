# Tree-sitter C FFI Integration

This module provides direct C FFI bindings to tree-sitter, bypassing z-tree-sitter compatibility issues with Zig 0.15.x.

## Status

✅ **Phase 1.1 Complete**: Direct tree-sitter C FFI setup
- Core tree-sitter library integration working
- Parser creation and destruction
- Basic parsing (without language grammars)
- Memory management and cleanup
- Test infrastructure in place

## Architecture

```
src/clew/tree_sitter/
├── c_api.zig       # Direct C FFI bindings to libtree-sitter
├── parser.zig      # High-level Zig wrapper around C API
├── languages.zig   # Language parser stubs (unused currently)
└── README.md       # This file
```

## Installation

### macOS (Homebrew)
```bash
# Install core tree-sitter library
brew install tree-sitter
```

### Linux (apt)
```bash
# Install core tree-sitter library
sudo apt-get install libtree-sitter-dev
```

### Language Parsers (Future)

Language-specific parsers are currently stubbed out. To enable them in the future:

1. **Option 1: Build from source**
   ```bash
   git clone https://github.com/tree-sitter/tree-sitter-typescript
   cd tree-sitter-typescript
   npm install
   npm run build
   # Link the generated .so/.dylib file
   ```

2. **Option 2: Use pre-built binaries**
   - Download from tree-sitter language repositories
   - Place in system library path
   - Update build.zig to link them

## Usage

```zig
const tree_sitter = @import("tree_sitter");
const TreeSitterParser = tree_sitter.TreeSitterParser;
const Language = tree_sitter.Language;

// Create parser (will fail with InvalidLanguage until language parsers are installed)
var parser = try TreeSitterParser.init(allocator, .typescript);
defer parser.deinit();

// Parse source code
const tree = try parser.parse("function foo() { return 42; }");
defer tree.deinit();

// Access AST
const root = tree.rootNode();
const child_count = root.childCount();
```

## Current Limitations

1. **No language parsers**: Only core tree-sitter functionality works. Language-specific parsing returns `error.InvalidLanguage`.
2. **Static linking only**: Dynamic loading of language parsers not yet implemented.
3. **Limited AST traversal**: Basic node access implemented, advanced queries pending Phase 1.2.

## Next Steps (Phase 1.2)

- [ ] Dynamic loading of language parser libraries
- [ ] Full AST traversal utilities
- [ ] Query API support
- [ ] Edit API for incremental parsing
- [ ] Integration with Clew extractors

## Testing

```bash
# Run tree-sitter specific tests
zig build test

# Run simple C FFI test
zig test test/clew/tree_sitter_simple_test.zig -ltree-sitter \
  -I/opt/homebrew/opt/tree-sitter/include \
  -L/opt/homebrew/opt/tree-sitter/lib
```

## Troubleshooting

### "undefined symbol: _tree_sitter_typescript"
Language parsers are not installed. This is expected - the stubs return null.

### "Failed to create parser"
Tree-sitter library not found. Install via package manager (see Installation).

### macOS: Library not found
Add to your shell profile:
```bash
export DYLD_LIBRARY_PATH=/opt/homebrew/opt/tree-sitter/lib:$DYLD_LIBRARY_PATH
```

### Linux: Library not found
Add to your shell profile:
```bash
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
```