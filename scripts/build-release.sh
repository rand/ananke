#!/usr/bin/env bash
# Build optimized release binaries for Ananke
# Usage: ./scripts/build-release.sh [target]
# Example: ./scripts/build-release.sh x86_64-macos

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
TARGET="${1:-native}"
BUILD_DIR="$(pwd)"
OPTIMIZE="ReleaseFast"

echo -e "${GREEN}=== Ananke Release Build ===${NC}"
echo "Target: ${TARGET}"
echo "Build directory: ${BUILD_DIR}"
echo

# Detect OS and architecture if target is 'native'
if [ "${TARGET}" = "native" ]; then
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)

    case "${OS}" in
        darwin)
            OS="macos"
            ;;
        linux)
            OS="linux"
            ;;
        mingw*|msys*|cygwin*)
            OS="windows"
            ;;
    esac

    case "${ARCH}" in
        x86_64|amd64)
            ARCH="x86_64"
            ;;
        arm64|aarch64)
            ARCH="aarch64"
            ;;
    esac

    TARGET="${ARCH}-${OS}"
    echo -e "${YELLOW}Auto-detected target: ${TARGET}${NC}"
    echo
fi

# Map target to Rust target triple
case "${TARGET}" in
    x86_64-linux)
        RUST_TARGET="x86_64-unknown-linux-gnu"
        LIB_EXT="so"
        ;;
    aarch64-linux)
        RUST_TARGET="aarch64-unknown-linux-gnu"
        LIB_EXT="so"
        ;;
    x86_64-macos)
        RUST_TARGET="x86_64-apple-darwin"
        LIB_EXT="dylib"
        ;;
    aarch64-macos)
        RUST_TARGET="aarch64-apple-darwin"
        LIB_EXT="dylib"
        ;;
    x86_64-windows)
        RUST_TARGET="x86_64-pc-windows-msvc"
        LIB_EXT="dll"
        ;;
    *)
        echo -e "${RED}Unknown target: ${TARGET}${NC}"
        echo "Supported targets:"
        echo "  x86_64-linux, aarch64-linux"
        echo "  x86_64-macos, aarch64-macos"
        echo "  x86_64-windows"
        exit 1
        ;;
esac

# Step 1: Build Zig binary
echo -e "${GREEN}[1/4] Building Zig binary...${NC}"
if zig build -Dtarget="${TARGET}" -Doptimize="${OPTIMIZE}"; then
    echo -e "${GREEN}✓ Zig binary built successfully${NC}"
else
    echo -e "${RED}✗ Zig build failed${NC}"
    exit 1
fi
echo

# Step 2: Build Zig static library
echo -e "${GREEN}[2/4] Building Zig static library...${NC}"
if zig build-lib -static -O "${OPTIMIZE}" src/ffi/zig_ffi.zig -femit-bin=libananke.a; then
    echo -e "${GREEN}✓ Zig static library built successfully${NC}"
else
    echo -e "${RED}✗ Zig static library build failed${NC}"
    exit 1
fi
echo

# Step 3: Build Rust Maze library
echo -e "${GREEN}[3/4] Building Rust Maze library...${NC}"
cd maze
if cargo build --release --target "${RUST_TARGET}"; then
    echo -e "${GREEN}✓ Rust library built successfully${NC}"
else
    echo -e "${RED}✗ Rust build failed${NC}"
    exit 1
fi
cd ..
echo

# Step 4: Verify artifacts
echo -e "${GREEN}[4/4] Verifying build artifacts...${NC}"
ARTIFACTS_OK=true

# Check Zig binary
if [ -f "zig-out/bin/ananke" ] || [ -f "zig-out/bin/ananke.exe" ]; then
    echo -e "${GREEN}✓ Zig binary found${NC}"
else
    echo -e "${RED}✗ Zig binary not found${NC}"
    ARTIFACTS_OK=false
fi

# Check Zig static library
if [ -f "libananke.a" ]; then
    SIZE=$(du -h libananke.a | cut -f1)
    echo -e "${GREEN}✓ Zig static library found (${SIZE})${NC}"
else
    echo -e "${RED}✗ Zig static library not found${NC}"
    ARTIFACTS_OK=false
fi

# Check Rust library
if [ -f "maze/target/${RUST_TARGET}/release/libmaze.${LIB_EXT}" ] || \
   [ -f "maze/target/${RUST_TARGET}/release/maze.${LIB_EXT}" ]; then
    RUST_LIB=$(find maze/target/${RUST_TARGET}/release -name "*maze.${LIB_EXT}" | head -1)
    SIZE=$(du -h "${RUST_LIB}" | cut -f1)
    echo -e "${GREEN}✓ Rust library found (${SIZE})${NC}"
else
    echo -e "${RED}✗ Rust library not found${NC}"
    ARTIFACTS_OK=false
fi

echo

if [ "${ARTIFACTS_OK}" = true ]; then
    echo -e "${GREEN}=== Build Complete ===${NC}"
    echo "Build artifacts are ready in:"
    echo "  - zig-out/bin/ (Zig binary)"
    echo "  - libananke.a (Zig static library)"
    echo "  - maze/target/${RUST_TARGET}/release/ (Rust library)"
    echo
    echo "Next steps:"
    echo "  - Run ./scripts/package-release.sh to create distribution packages"
    echo "  - Run ./scripts/verify-release.sh to verify artifacts"
    exit 0
else
    echo -e "${RED}=== Build Failed ===${NC}"
    echo "Some artifacts are missing. Check the build logs above."
    exit 1
fi
