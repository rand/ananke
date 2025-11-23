#!/usr/bin/env bash
# Bump version across Ananke project
# Usage: ./scripts/bump-version.sh <new-version>
# Example: ./scripts/bump-version.sh 0.1.1

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

if [ $# -lt 1 ]; then
    echo -e "${RED}Error: New version required${NC}"
    echo "Usage: $0 <new-version>"
    echo "Example: $0 0.1.1"
    echo
    echo "Note: Do not include 'v' prefix (will be added for git tags)"
    exit 1
fi

NEW_VERSION="$1"

# Validate version format
if [[ ! "${NEW_VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9]+)?$ ]]; then
    echo -e "${RED}Error: Invalid version format${NC}"
    echo "Expected: X.Y.Z or X.Y.Z-suffix"
    echo "Got: ${NEW_VERSION}"
    exit 1
fi

BUILD_DIR="$(pwd)"

echo -e "${GREEN}=== Ananke Version Bump ===${NC}"
echo "New version: ${NEW_VERSION}"
echo

# Extract current versions
CURRENT_CARGO_VERSION=""
if [ -f "maze/Cargo.toml" ]; then
    CURRENT_CARGO_VERSION=$(grep '^version = ' maze/Cargo.toml | head -1 | sed 's/version = "\(.*\)"/\1/')
fi

CURRENT_ZIG_VERSION=""
if [ -f "src/main.zig" ]; then
    CURRENT_ZIG_VERSION=$(grep -o 'Ananke v[0-9]*\.[0-9]*\.[0-9]*' src/main.zig | sed 's/Ananke v//')
fi

echo -e "${BLUE}Current versions:${NC}"
[ -n "${CURRENT_CARGO_VERSION}" ] && echo "  Cargo.toml: ${CURRENT_CARGO_VERSION}"
[ -n "${CURRENT_ZIG_VERSION}" ] && echo "  main.zig: ${CURRENT_ZIG_VERSION}"
echo
echo -e "${BLUE}New version: ${NEW_VERSION}${NC}"
echo

# Confirm
echo -e "${YELLOW}This will update version numbers in:${NC}"
echo "  - maze/Cargo.toml"
echo "  - src/main.zig"
echo "  - CHANGELOG.md (create entry)"
echo
read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

# Update Cargo.toml
echo -e "${GREEN}[1/3] Updating maze/Cargo.toml...${NC}"
if [ -f "maze/Cargo.toml" ]; then
    sed -i.bak "s/^version = \".*\"/version = \"${NEW_VERSION}\"/" maze/Cargo.toml
    rm -f maze/Cargo.toml.bak
    echo -e "${GREEN}✓ Updated maze/Cargo.toml${NC}"
else
    echo -e "${YELLOW}⚠ maze/Cargo.toml not found${NC}"
fi
echo

# Update main.zig
echo -e "${GREEN}[2/3] Updating src/main.zig...${NC}"
if [ -f "src/main.zig" ]; then
    # Update version string in printVersion function
    sed -i.bak "s/Ananke v[0-9]*\.[0-9]*\.[0-9]*[^\"]*\"/Ananke v${NEW_VERSION}\"/" src/main.zig
    rm -f src/main.zig.bak
    echo -e "${GREEN}✓ Updated src/main.zig${NC}"
else
    echo -e "${YELLOW}⚠ src/main.zig not found${NC}"
fi
echo

# Update or create CHANGELOG.md entry
echo -e "${GREEN}[3/3] Updating CHANGELOG.md...${NC}"
DATE=$(date +%Y-%m-%d)

if [ ! -f "CHANGELOG.md" ]; then
    cat > CHANGELOG.md <<EOF
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [${NEW_VERSION}] - ${DATE}

### Added
- Initial release

EOF
    echo -e "${GREEN}✓ Created CHANGELOG.md${NC}"
else
    # Check if version already exists
    if grep -q "## \[${NEW_VERSION}\]" CHANGELOG.md; then
        echo -e "${YELLOW}⚠ Version ${NEW_VERSION} already exists in CHANGELOG.md${NC}"
    else
        # Add new version section after [Unreleased]
        sed -i.bak "/## \[Unreleased\]/a\\
\\
## [${NEW_VERSION}] - ${DATE}\\
\\
### Added\\
- \\
\\
### Changed\\
- \\
\\
### Fixed\\
- \\
" CHANGELOG.md
        rm -f CHANGELOG.md.bak
        echo -e "${GREEN}✓ Updated CHANGELOG.md${NC}"
        echo -e "${YELLOW}⚠ Please edit CHANGELOG.md to add release notes${NC}"
    fi
fi
echo

# Verify changes
echo -e "${GREEN}=== Version Update Summary ===${NC}"
echo

if [ -f "maze/Cargo.toml" ]; then
    NEW_CARGO_VERSION=$(grep '^version = ' maze/Cargo.toml | head -1 | sed 's/version = "\(.*\)"/\1/')
    echo "maze/Cargo.toml: ${CURRENT_CARGO_VERSION:-?} → ${NEW_CARGO_VERSION}"
fi

if [ -f "src/main.zig" ]; then
    NEW_ZIG_VERSION=$(grep -o 'Ananke v[0-9]*\.[0-9]*\.[0-9]*[^"]*' src/main.zig | sed 's/Ananke v//')
    echo "src/main.zig: ${CURRENT_ZIG_VERSION:-?} → ${NEW_ZIG_VERSION}"
fi

echo

# Show what to do next
echo -e "${BLUE}=== Next Steps ===${NC}"
echo
echo "1. Review changes:"
echo "   git diff"
echo
echo "2. Edit CHANGELOG.md to add release notes for ${NEW_VERSION}"
echo
echo "3. Test the version:"
echo "   zig build"
echo "   ./zig-out/bin/ananke --version"
echo
echo "4. Commit changes:"
echo "   git add maze/Cargo.toml src/main.zig CHANGELOG.md"
echo "   git commit -m \"Bump version to ${NEW_VERSION}\""
echo
echo "5. Create and push tag:"
echo "   git tag -a v${NEW_VERSION} -m \"Release v${NEW_VERSION}\""
echo "   git push origin main"
echo "   git push origin v${NEW_VERSION}"
echo
echo "6. GitHub Actions will automatically:"
echo "   - Build release binaries"
echo "   - Create GitHub release"
echo "   - Generate checksums"
echo "   - Publish to crates.io (if configured)"
echo "   - Generate Homebrew formula"
echo

echo -e "${GREEN}Version bump complete!${NC}"
