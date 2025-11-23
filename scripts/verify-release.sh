#!/usr/bin/env bash
# Verify Ananke release artifacts
# Usage: ./scripts/verify-release.sh <package-path>
# Example: ./scripts/verify-release.sh dist/ananke-v0.1.0-macos-x86_64.tar.gz

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

if [ $# -lt 1 ]; then
    echo -e "${RED}Error: Package path required${NC}"
    echo "Usage: $0 <package-path>"
    echo "Example: $0 dist/ananke-v0.1.0-macos-x86_64.tar.gz"
    exit 1
fi

PACKAGE="$1"

if [ ! -f "${PACKAGE}" ]; then
    echo -e "${RED}Error: Package not found: ${PACKAGE}${NC}"
    exit 1
fi

echo -e "${GREEN}=== Ananke Release Verification ===${NC}"
echo "Package: ${PACKAGE}"
echo

# Create temporary directory for extraction
TEMP_DIR=$(mktemp -d)
trap "rm -rf ${TEMP_DIR}" EXIT

# Extract package
echo -e "${BLUE}[1/7] Extracting package...${NC}"
cd "${TEMP_DIR}"

if [[ "${PACKAGE}" == *.tar.gz ]]; then
    if tar -xzf "${OLDPWD}/${PACKAGE}"; then
        echo -e "${GREEN}✓ Package extracted${NC}"
    else
        echo -e "${RED}✗ Failed to extract package${NC}"
        exit 1
    fi
elif [[ "${PACKAGE}" == *.zip ]]; then
    if unzip -q "${OLDPWD}/${PACKAGE}"; then
        echo -e "${GREEN}✓ Package extracted${NC}"
    else
        echo -e "${RED}✗ Failed to extract package${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ Unknown package format${NC}"
    exit 1
fi

# Find package directory
PKG_DIR=$(find . -maxdepth 1 -type d ! -name . | head -1)
if [ -z "${PKG_DIR}" ]; then
    echo -e "${RED}✗ No package directory found${NC}"
    exit 1
fi

cd "${PKG_DIR}"
echo

# Verify package structure
echo -e "${BLUE}[2/7] Verifying package structure...${NC}"
REQUIRED_DIRS=("bin" "lib" "include")
OPTIONAL_DIRS=("examples" "docs")
STRUCTURE_OK=true

for dir in "${REQUIRED_DIRS[@]}"; do
    if [ -d "${dir}" ]; then
        echo -e "${GREEN}✓ ${dir}/ exists${NC}"
    else
        echo -e "${RED}✗ ${dir}/ missing${NC}"
        STRUCTURE_OK=false
    fi
done

for dir in "${OPTIONAL_DIRS[@]}"; do
    if [ -d "${dir}" ]; then
        echo -e "${GREEN}✓ ${dir}/ exists${NC}"
    else
        echo -e "${YELLOW}⚠ ${dir}/ missing (optional)${NC}"
    fi
done

if [ "${STRUCTURE_OK}" = false ]; then
    echo -e "${RED}✗ Package structure incomplete${NC}"
    exit 1
fi
echo

# Verify binary
echo -e "${BLUE}[3/7] Verifying binary...${NC}"
BINARY=""
if [ -f "bin/ananke" ]; then
    BINARY="bin/ananke"
elif [ -f "bin/ananke.exe" ]; then
    BINARY="bin/ananke.exe"
else
    echo -e "${RED}✗ Ananke binary not found${NC}"
    exit 1
fi

# Check if executable
if [ -x "${BINARY}" ]; then
    echo -e "${GREEN}✓ Binary is executable${NC}"
else
    echo -e "${YELLOW}⚠ Binary is not executable (checking permissions)${NC}"
    chmod +x "${BINARY}"
fi

# Check file type
FILE_TYPE=$(file "${BINARY}" 2>/dev/null || echo "unknown")
echo -e "${BLUE}  Type: ${FILE_TYPE}${NC}"

# Check size (warn if suspiciously small)
BINARY_SIZE=$(stat -f%z "${BINARY}" 2>/dev/null || stat -c%s "${BINARY}" 2>/dev/null || echo "0")
BINARY_SIZE_MB=$((BINARY_SIZE / 1024 / 1024))
if [ ${BINARY_SIZE} -lt 100000 ]; then
    echo -e "${YELLOW}⚠ Binary seems very small: ${BINARY_SIZE} bytes${NC}"
elif [ ${BINARY_SIZE_MB} -gt 0 ]; then
    echo -e "${GREEN}✓ Binary size: ${BINARY_SIZE_MB}MB${NC}"
else
    SIZE_KB=$((BINARY_SIZE / 1024))
    echo -e "${GREEN}✓ Binary size: ${SIZE_KB}KB${NC}"
fi
echo

# Verify libraries
echo -e "${BLUE}[4/7] Verifying libraries...${NC}"
LIBS_FOUND=0

if [ -f "lib/libananke.a" ]; then
    echo -e "${GREEN}✓ libananke.a found${NC}"
    LIBS_FOUND=$((LIBS_FOUND + 1))
fi

for LIB in lib/libmaze.* lib/maze.*; do
    if [ -f "${LIB}" ]; then
        echo -e "${GREEN}✓ $(basename ${LIB}) found${NC}"
        LIBS_FOUND=$((LIBS_FOUND + 1))
        break
    fi
done

if [ ${LIBS_FOUND} -eq 0 ]; then
    echo -e "${RED}✗ No libraries found${NC}"
    exit 1
fi
echo

# Verify headers
echo -e "${BLUE}[5/7] Verifying headers...${NC}"
if [ -f "include/ananke.h" ]; then
    LINES=$(wc -l < include/ananke.h)
    echo -e "${GREEN}✓ ananke.h found (${LINES} lines)${NC}"

    # Check if header is just a placeholder
    if [ ${LINES} -lt 10 ]; then
        echo -e "${YELLOW}⚠ Header appears to be a placeholder${NC}"
    fi
else
    echo -e "${YELLOW}⚠ ananke.h not found${NC}"
fi
echo

# Verify documentation
echo -e "${BLUE}[6/7] Verifying documentation...${NC}"
DOCS_OK=true

if [ -f "README.md" ]; then
    echo -e "${GREEN}✓ README.md found${NC}"
else
    echo -e "${YELLOW}⚠ README.md missing${NC}"
    DOCS_OK=false
fi

if [ -f "LICENSE" ] || [ -f "LICENSE-MIT" ] || [ -f "LICENSE-APACHE" ]; then
    echo -e "${GREEN}✓ LICENSE found${NC}"
else
    echo -e "${YELLOW}⚠ LICENSE missing${NC}"
    DOCS_OK=false
fi

if [ -f "install.sh" ]; then
    if [ -x "install.sh" ]; then
        echo -e "${GREEN}✓ install.sh found and executable${NC}"
    else
        echo -e "${YELLOW}⚠ install.sh found but not executable${NC}"
    fi
else
    echo -e "${YELLOW}⚠ install.sh missing${NC}"
fi
echo

# Test binary execution
echo -e "${BLUE}[7/7] Testing binary execution...${NC}"

# Try to get version
if ./"${BINARY}" --version > /tmp/ananke-version.txt 2>&1; then
    VERSION_OUTPUT=$(cat /tmp/ananke-version.txt)
    echo -e "${GREEN}✓ Binary executes successfully${NC}"
    echo -e "${BLUE}  Output: ${VERSION_OUTPUT}${NC}"

    # Verify version format
    if echo "${VERSION_OUTPUT}" | grep -q "Ananke"; then
        echo -e "${GREEN}✓ Version output looks correct${NC}"
    else
        echo -e "${YELLOW}⚠ Version output doesn't contain 'Ananke'${NC}"
    fi
else
    EXIT_CODE=$?
    echo -e "${RED}✗ Binary execution failed (exit code: ${EXIT_CODE})${NC}"
    echo "Output:"
    cat /tmp/ananke-version.txt
    echo
    echo "This might be expected if:"
    echo "  - Cross-compiled for a different architecture"
    echo "  - Missing runtime dependencies"
    echo "  - Binary needs to be run on target platform"
fi

rm -f /tmp/ananke-version.txt
echo

# Check for missing runtime dependencies (Unix-like systems)
if command -v ldd &> /dev/null && [ -x "${BINARY}" ]; then
    echo -e "${BLUE}Checking runtime dependencies...${NC}"
    if ldd "${BINARY}" 2>&1 | grep -q "not found"; then
        echo -e "${YELLOW}⚠ Missing runtime dependencies:${NC}"
        ldd "${BINARY}" | grep "not found"
    else
        echo -e "${GREEN}✓ All runtime dependencies satisfied${NC}"
    fi
    echo
elif command -v otool &> /dev/null && [ -x "${BINARY}" ]; then
    echo -e "${BLUE}Checking runtime dependencies (macOS)...${NC}"
    if otool -L "${BINARY}" 2>&1 | grep -q "not found"; then
        echo -e "${YELLOW}⚠ Missing runtime dependencies:${NC}"
        otool -L "${BINARY}" | grep "not found"
    else
        echo -e "${GREEN}✓ Runtime dependencies check passed${NC}"
    fi
    echo
fi

# Final summary
echo -e "${GREEN}=== Verification Summary ===${NC}"
echo "Package: $(basename ${PACKAGE})"
echo
echo "Contents:"
echo "  ✓ Binary: ${BINARY}"
echo "  ✓ Libraries: ${LIBS_FOUND} found"
echo "  $([ -f include/ananke.h ] && echo '✓' || echo '⚠') Headers"
echo "  $([ ${DOCS_OK} = true ] && echo '✓' || echo '⚠') Documentation"
echo
echo "Structure:"
find . -type f | head -20 | while read file; do
    SIZE=$(stat -f%z "${file}" 2>/dev/null || stat -c%s "${file}" 2>/dev/null || echo "?")
    SIZE_H=$(numfmt --to=iec-i --suffix=B ${SIZE} 2>/dev/null || echo "${SIZE}B")
    echo "  ${file} (${SIZE_H})"
done
echo

echo -e "${GREEN}Verification complete!${NC}"
echo
echo "To test installation:"
echo "  cd ${TEMP_DIR}/${PKG_DIR}"
echo "  ./install.sh"
echo
echo "Or install to custom location:"
echo "  PREFIX=~/.local ./install.sh"
