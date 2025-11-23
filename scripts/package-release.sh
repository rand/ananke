#!/usr/bin/env bash
# Package Ananke release artifacts for distribution
# Usage: ./scripts/package-release.sh <version> [target]
# Example: ./scripts/package-release.sh v0.1.0 x86_64-macos

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check arguments
if [ $# -lt 1 ]; then
    echo -e "${RED}Error: Version required${NC}"
    echo "Usage: $0 <version> [target]"
    echo "Example: $0 v0.1.0 x86_64-macos"
    exit 1
fi

VERSION="$1"
TARGET="${2:-native}"
BUILD_DIR="$(pwd)"
DIST_DIR="${BUILD_DIR}/dist"

# Validate version format
if [[ ! "${VERSION}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9]+)?$ ]]; then
    echo -e "${YELLOW}Warning: Version doesn't match expected format (vX.Y.Z)${NC}"
    echo "Continuing anyway..."
fi

echo -e "${GREEN}=== Ananke Release Packaging ===${NC}"
echo "Version: ${VERSION}"
echo "Target: ${TARGET}"
echo

# Detect OS and architecture if target is 'native'
if [ "${TARGET}" = "native" ]; then
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)

    case "${OS}" in
        darwin) OS="macos" ;;
        linux) OS="linux" ;;
        mingw*|msys*|cygwin*) OS="windows" ;;
    esac

    case "${ARCH}" in
        x86_64|amd64) ARCH="x86_64" ;;
        arm64|aarch64) ARCH="aarch64" ;;
    esac

    TARGET="${ARCH}-${OS}"
    echo -e "${YELLOW}Auto-detected target: ${TARGET}${NC}"
fi

# Determine asset name and library extension
ASSET_NAME="ananke-${VERSION}-${TARGET}"
case "${TARGET}" in
    *-linux)
        RUST_TARGET="$(echo ${TARGET} | sed 's/-linux/-unknown-linux-gnu/')"
        LIB_EXT="so"
        ARCHIVE_EXT="tar.gz"
        ;;
    *-macos)
        RUST_TARGET="$(echo ${TARGET} | sed 's/-macos/-apple-darwin/')"
        LIB_EXT="dylib"
        ARCHIVE_EXT="tar.gz"
        ;;
    *-windows)
        RUST_TARGET="$(echo ${TARGET} | sed 's/-windows/-pc-windows-msvc/')"
        LIB_EXT="dll"
        ARCHIVE_EXT="zip"
        ;;
    *)
        echo -e "${RED}Unknown target: ${TARGET}${NC}"
        exit 1
        ;;
esac

echo -e "${BLUE}Package name: ${ASSET_NAME}${NC}"
echo -e "${BLUE}Archive format: ${ARCHIVE_EXT}${NC}"
echo

# Create package structure
echo -e "${GREEN}[1/6] Creating package structure...${NC}"
PKG_DIR="${DIST_DIR}/${ASSET_NAME}"
rm -rf "${PKG_DIR}"
mkdir -p "${PKG_DIR}"/{bin,lib,include,examples,docs}
echo -e "${GREEN}✓ Directory structure created${NC}"
echo

# Copy Zig binary
echo -e "${GREEN}[2/6] Copying Zig binary...${NC}"
if [ -f "zig-out/bin/ananke" ]; then
    cp zig-out/bin/ananke "${PKG_DIR}/bin/"
    chmod +x "${PKG_DIR}/bin/ananke"
    echo -e "${GREEN}✓ Copied zig-out/bin/ananke${NC}"
elif [ -f "zig-out/bin/ananke.exe" ]; then
    cp zig-out/bin/ananke.exe "${PKG_DIR}/bin/"
    echo -e "${GREEN}✓ Copied zig-out/bin/ananke.exe${NC}"
else
    echo -e "${RED}✗ Zig binary not found${NC}"
    exit 1
fi
echo

# Copy libraries
echo -e "${GREEN}[3/6] Copying libraries...${NC}"

# Zig static library
if [ -f "libananke.a" ]; then
    cp libananke.a "${PKG_DIR}/lib/"
    echo -e "${GREEN}✓ Copied libananke.a${NC}"
else
    echo -e "${YELLOW}⚠ libananke.a not found${NC}"
fi

# Rust Maze library
RUST_LIB=""
if [ -f "maze/target/${RUST_TARGET}/release/libmaze.${LIB_EXT}" ]; then
    RUST_LIB="maze/target/${RUST_TARGET}/release/libmaze.${LIB_EXT}"
elif [ -f "maze/target/${RUST_TARGET}/release/maze.${LIB_EXT}" ]; then
    RUST_LIB="maze/target/${RUST_TARGET}/release/maze.${LIB_EXT}"
fi

if [ -n "${RUST_LIB}" ]; then
    cp "${RUST_LIB}" "${PKG_DIR}/lib/"
    echo -e "${GREEN}✓ Copied $(basename ${RUST_LIB})${NC}"
else
    echo -e "${YELLOW}⚠ Rust Maze library not found${NC}"
fi
echo

# Copy headers and examples
echo -e "${GREEN}[4/6] Copying headers and examples...${NC}"

# FFI headers
if [ -f "src/ffi/ananke.h" ]; then
    cp src/ffi/ananke.h "${PKG_DIR}/include/"
    echo -e "${GREEN}✓ Copied FFI headers${NC}"
else
    echo -e "${YELLOW}⚠ Creating placeholder header${NC}"
    cat > "${PKG_DIR}/include/ananke.h" <<'EOF'
/* Ananke FFI Header */
/* See documentation for FFI usage */
#ifndef ANANKE_H
#define ANANKE_H

#ifdef __cplusplus
extern "C" {
#endif

/* FFI functions will be documented here */

#ifdef __cplusplus
}
#endif

#endif /* ANANKE_H */
EOF
fi

# Copy examples
if [ -d "examples" ]; then
    cp examples/*.zig "${PKG_DIR}/examples/" 2>/dev/null || true
    EXAMPLE_COUNT=$(find "${PKG_DIR}/examples/" -name "*.zig" 2>/dev/null | wc -l)
    if [ ${EXAMPLE_COUNT} -gt 0 ]; then
        echo -e "${GREEN}✓ Copied ${EXAMPLE_COUNT} example(s)${NC}"
    fi
fi
echo

# Copy documentation
echo -e "${GREEN}[5/6] Copying documentation...${NC}"
[ -f "README.md" ] && cp README.md "${PKG_DIR}/" && echo -e "${GREEN}✓ Copied README.md${NC}"
[ -f "LICENSE" ] && cp LICENSE "${PKG_DIR}/" && echo -e "${GREEN}✓ Copied LICENSE${NC}"
[ -f "LICENSE-MIT" ] && cp LICENSE-MIT "${PKG_DIR}/" && echo -e "${GREEN}✓ Copied LICENSE-MIT${NC}"
[ -f "LICENSE-APACHE" ] && cp LICENSE-APACHE "${PKG_DIR}/" && echo -e "${GREEN}✓ Copied LICENSE-APACHE${NC}"
[ -f "CHANGELOG.md" ] && cp CHANGELOG.md "${PKG_DIR}/docs/" && echo -e "${GREEN}✓ Copied CHANGELOG.md${NC}"
[ -f "QUICKSTART.md" ] && cp QUICKSTART.md "${PKG_DIR}/docs/" && echo -e "${GREEN}✓ Copied QUICKSTART.md${NC}"

# Create installation script
cat > "${PKG_DIR}/install.sh" <<'INSTALL_EOF'
#!/bin/bash
set -e

PREFIX="${PREFIX:-/usr/local}"
echo "Installing Ananke to ${PREFIX}..."

# Check permissions
if [ ! -w "${PREFIX}/bin" ]; then
    echo "Error: No write permission to ${PREFIX}/bin"
    echo "Try running with sudo or set PREFIX to a directory you own:"
    echo "  PREFIX=~/.local ./install.sh"
    exit 1
fi

# Create directories
mkdir -p "${PREFIX}"/{bin,lib,include}

# Install binary
cp bin/ananke* "${PREFIX}/bin/"
chmod +x "${PREFIX}/bin/ananke"*

# Install libraries
cp lib/* "${PREFIX}/lib/" 2>/dev/null || true

# Install headers
cp include/* "${PREFIX}/include/" 2>/dev/null || true

echo "✓ Ananke installed successfully!"
echo ""
echo "Verify installation:"
echo "  ananke --version"
echo ""
echo "Get started:"
echo "  ananke help"
INSTALL_EOF

chmod +x "${PKG_DIR}/install.sh"
echo -e "${GREEN}✓ Created install.sh${NC}"
echo

# Create archive
echo -e "${GREEN}[6/6] Creating archive...${NC}"
cd "${DIST_DIR}"

if [ "${ARCHIVE_EXT}" = "tar.gz" ]; then
    tar -czf "${ASSET_NAME}.tar.gz" "${ASSET_NAME}"
    ARCHIVE="${ASSET_NAME}.tar.gz"
    echo -e "${GREEN}✓ Created ${ARCHIVE}${NC}"
elif [ "${ARCHIVE_EXT}" = "zip" ]; then
    if command -v zip &> /dev/null; then
        zip -r "${ASSET_NAME}.zip" "${ASSET_NAME}" > /dev/null
        ARCHIVE="${ASSET_NAME}.zip"
        echo -e "${GREEN}✓ Created ${ARCHIVE}${NC}"
    else
        echo -e "${RED}✗ zip command not found${NC}"
        exit 1
    fi
fi

# Generate checksum
if command -v sha256sum &> /dev/null; then
    sha256sum "${ARCHIVE}" > "${ARCHIVE}.sha256"
elif command -v shasum &> /dev/null; then
    shasum -a 256 "${ARCHIVE}" > "${ARCHIVE}.sha256"
else
    echo -e "${YELLOW}⚠ No checksum tool available${NC}"
fi

if [ -f "${ARCHIVE}.sha256" ]; then
    CHECKSUM=$(cut -d' ' -f1 "${ARCHIVE}.sha256")
    echo -e "${GREEN}✓ Generated checksum: ${CHECKSUM:0:16}...${NC}"
fi

cd "${BUILD_DIR}"
echo

# Summary
echo -e "${GREEN}=== Packaging Complete ===${NC}"
echo "Package: ${DIST_DIR}/${ARCHIVE}"
echo "Size: $(du -h ${DIST_DIR}/${ARCHIVE} | cut -f1)"
if [ -f "${DIST_DIR}/${ARCHIVE}.sha256" ]; then
    echo "Checksum: ${DIST_DIR}/${ARCHIVE}.sha256"
fi
echo
echo "Package contents:"
echo "  bin/      - Ananke binary"
echo "  lib/      - Static and dynamic libraries"
echo "  include/  - FFI headers"
echo "  examples/ - Example code"
echo "  docs/     - Documentation"
echo "  install.sh - Installation script"
echo
echo "Test the package:"
echo "  cd ${DIST_DIR}/${ASSET_NAME}"
echo "  ./bin/ananke --version"
echo
echo "Install the package:"
echo "  cd ${DIST_DIR}/${ASSET_NAME}"
echo "  ./install.sh"
