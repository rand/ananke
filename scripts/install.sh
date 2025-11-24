#!/usr/bin/env bash
# Ananke Installation Script
# Installs Ananke constraint-driven code generation system
# Usage: curl -fsSL https://raw.githubusercontent.com/ananke-ai/ananke/main/scripts/install.sh | bash
# Or: ./scripts/install.sh [--prefix=/path/to/install]

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
VERSION="${ANANKE_VERSION:-latest}"
REPO="ananke-ai/ananke"
PREFIX="${PREFIX:-$HOME/.local}"
INSTALL_DIR="${PREFIX}/bin"
LIB_DIR="${PREFIX}/lib"
INCLUDE_DIR="${PREFIX}/include"
TEMP_DIR=$(mktemp -d)

# Detect OS and architecture
detect_platform() {
    local os arch

    os=$(uname -s | tr '[:upper:]' '[:lower:]')
    arch=$(uname -m)

    case "${os}" in
        darwin)
            OS_TYPE="macos"
            ;;
        linux)
            OS_TYPE="linux"
            ;;
        mingw*|msys*|cygwin*)
            echo -e "${RED}Error: Please use install.ps1 for Windows installation${NC}"
            exit 1
            ;;
        *)
            echo -e "${RED}Error: Unsupported operating system: ${os}${NC}"
            exit 1
            ;;
    esac

    case "${arch}" in
        x86_64|amd64)
            ARCH_TYPE="x86_64"
            ;;
        arm64|aarch64)
            ARCH_TYPE="aarch64"
            ;;
        *)
            echo -e "${RED}Error: Unsupported architecture: ${arch}${NC}"
            exit 1
            ;;
    esac

    PLATFORM="${OS_TYPE}-${ARCH_TYPE}"
}

# Check system requirements
check_requirements() {
    echo -e "${BLUE}[1/6] Checking system requirements...${NC}"

    local missing_deps=()

    # Check for curl or wget
    if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
        missing_deps+=("curl or wget")
    fi

    # Check for tar
    if ! command -v tar &> /dev/null; then
        missing_deps+=("tar")
    fi

    # Check for sha256sum or shasum
    if ! command -v sha256sum &> /dev/null && ! command -v shasum &> /dev/null; then
        echo -e "${YELLOW}Warning: sha256sum/shasum not found, skipping checksum verification${NC}"
        SKIP_CHECKSUM=1
    fi

    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${RED}Error: Missing required dependencies:${NC}"
        printf '%s\n' "${missing_deps[@]}"
        exit 1
    fi

    echo -e "${GREEN}✓ System requirements satisfied${NC}"
}

# Download file with progress
download_file() {
    local url="$1"
    local output="$2"

    if command -v curl &> /dev/null; then
        curl -fsSL --progress-bar -o "${output}" "${url}"
    elif command -v wget &> /dev/null; then
        wget -q --show-progress -O "${output}" "${url}"
    else
        echo -e "${RED}Error: No download tool available${NC}"
        exit 1
    fi
}

# Get latest release version
get_latest_version() {
    local api_url="https://api.github.com/repos/${REPO}/releases/latest"

    if command -v curl &> /dev/null; then
        VERSION=$(curl -fsSL "${api_url}" | grep '"tag_name":' | sed -E 's/.*"tag_name": "([^"]+)".*/\1/')
    elif command -v wget &> /dev/null; then
        VERSION=$(wget -qO- "${api_url}" | grep '"tag_name":' | sed -E 's/.*"tag_name": "([^"]+)".*/\1/')
    fi

    if [ -z "${VERSION}" ]; then
        echo -e "${RED}Error: Failed to fetch latest version${NC}"
        exit 1
    fi
}

# Download and extract Ananke
download_ananke() {
    echo -e "${BLUE}[2/6] Downloading Ananke ${VERSION} for ${PLATFORM}...${NC}"

    if [ "${VERSION}" = "latest" ]; then
        get_latest_version
    fi

    local archive_name="ananke-${VERSION}-${PLATFORM}.tar.gz"
    local download_url="https://github.com/${REPO}/releases/download/${VERSION}/${archive_name}"
    local archive_path="${TEMP_DIR}/${archive_name}"

    download_file "${download_url}" "${archive_path}"

    echo -e "${GREEN}✓ Downloaded ${archive_name}${NC}"

    # Download checksum
    if [ -z "${SKIP_CHECKSUM:-}" ]; then
        echo -e "${BLUE}[3/6] Verifying checksum...${NC}"
        local checksum_url="${download_url}.sha256"
        local checksum_path="${archive_path}.sha256"

        download_file "${checksum_url}" "${checksum_path}" || {
            echo -e "${YELLOW}Warning: Checksum file not found, skipping verification${NC}"
            SKIP_CHECKSUM=1
        }

        if [ -z "${SKIP_CHECKSUM:-}" ]; then
            cd "${TEMP_DIR}"
            if command -v sha256sum &> /dev/null; then
                sha256sum -c "${checksum_path}" || {
                    echo -e "${RED}Error: Checksum verification failed${NC}"
                    exit 1
                }
            elif command -v shasum &> /dev/null; then
                shasum -a 256 -c "${checksum_path}" || {
                    echo -e "${RED}Error: Checksum verification failed${NC}"
                    exit 1
                }
            fi
            echo -e "${GREEN}✓ Checksum verified${NC}"
        fi
    else
        echo -e "${YELLOW}[3/6] Skipping checksum verification${NC}"
    fi

    # Extract archive
    echo -e "${BLUE}[4/6] Extracting archive...${NC}"
    tar -xzf "${archive_path}" -C "${TEMP_DIR}"
    echo -e "${GREEN}✓ Extracted successfully${NC}"
}

# Install Ananke binaries
install_ananke() {
    echo -e "${BLUE}[5/6] Installing Ananke...${NC}"

    # Create installation directories
    mkdir -p "${INSTALL_DIR}" "${LIB_DIR}" "${INCLUDE_DIR}"

    # Find extracted directory
    local extracted_dir=$(find "${TEMP_DIR}" -maxdepth 1 -type d -name "ananke-*" | head -1)

    if [ -z "${extracted_dir}" ]; then
        echo -e "${RED}Error: Extracted directory not found${NC}"
        exit 1
    fi

    # Install binary
    if [ -f "${extracted_dir}/bin/ananke" ]; then
        cp "${extracted_dir}/bin/ananke" "${INSTALL_DIR}/"
        chmod +x "${INSTALL_DIR}/ananke"
        echo -e "${GREEN}✓ Installed binary to ${INSTALL_DIR}/ananke${NC}"
    else
        echo -e "${RED}Error: Binary not found in archive${NC}"
        exit 1
    fi

    # Install libraries
    if [ -d "${extracted_dir}/lib" ]; then
        cp -r "${extracted_dir}/lib/"* "${LIB_DIR}/" 2>/dev/null || true
        echo -e "${GREEN}✓ Installed libraries to ${LIB_DIR}${NC}"
    fi

    # Install headers
    if [ -d "${extracted_dir}/include" ]; then
        cp -r "${extracted_dir}/include/"* "${INCLUDE_DIR}/" 2>/dev/null || true
        echo -e "${GREEN}✓ Installed headers to ${INCLUDE_DIR}${NC}"
    fi
}

# Verify installation
verify_installation() {
    echo -e "${BLUE}[6/6] Verifying installation...${NC}"

    # Check if binary exists and is executable
    if [ ! -x "${INSTALL_DIR}/ananke" ]; then
        echo -e "${RED}Error: Binary not found or not executable${NC}"
        exit 1
    fi

    # Try to run version command
    if "${INSTALL_DIR}/ananke" --version &> /dev/null; then
        echo -e "${GREEN}✓ Installation verified successfully${NC}"
    else
        echo -e "${YELLOW}Warning: Binary installed but version check failed${NC}"
        echo -e "${YELLOW}This may be normal if dependencies are missing${NC}"
    fi
}

# Cleanup temporary files
cleanup() {
    if [ -d "${TEMP_DIR}" ]; then
        rm -rf "${TEMP_DIR}"
    fi
}

# Print success message
print_success() {
    echo
    echo -e "${GREEN}════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Ananke ${VERSION} installed successfully!${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════${NC}"
    echo
    echo "Installation location: ${INSTALL_DIR}/ananke"
    echo
    echo "Next steps:"
    echo "  1. Add ${INSTALL_DIR} to your PATH if not already present:"
    echo "     export PATH=\"${INSTALL_DIR}:\$PATH\""
    echo
    echo "  2. Verify installation:"
    echo "     ananke --version"
    echo
    echo "  3. Get started:"
    echo "     ananke help"
    echo
    echo "Documentation: https://github.com/${REPO}/blob/main/README.md"
    echo "Quickstart: https://github.com/${REPO}/blob/main/QUICKSTART.md"
    echo

    # Check if PATH needs updating
    if ! echo "$PATH" | grep -q "${INSTALL_DIR}"; then
        echo -e "${YELLOW}Note: ${INSTALL_DIR} is not in your PATH${NC}"
        echo
        echo "Add this to your shell profile (~/.bashrc, ~/.zshrc, etc.):"
        echo "  export PATH=\"${INSTALL_DIR}:\$PATH\""
        echo
    fi
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --prefix=*)
                PREFIX="${1#*=}"
                INSTALL_DIR="${PREFIX}/bin"
                LIB_DIR="${PREFIX}/lib"
                INCLUDE_DIR="${PREFIX}/include"
                shift
                ;;
            --prefix)
                PREFIX="$2"
                INSTALL_DIR="${PREFIX}/bin"
                LIB_DIR="${PREFIX}/lib"
                INCLUDE_DIR="${PREFIX}/include"
                shift 2
                ;;
            --version=*)
                VERSION="${1#*=}"
                shift
                ;;
            --version)
                VERSION="$2"
                shift 2
                ;;
            --help)
                echo "Ananke Installation Script"
                echo
                echo "Usage: $0 [OPTIONS]"
                echo
                echo "Options:"
                echo "  --prefix=PATH    Installation prefix (default: \$HOME/.local)"
                echo "  --version=VER    Specific version to install (default: latest)"
                echo "  --help           Show this help message"
                echo
                echo "Environment variables:"
                echo "  PREFIX           Installation prefix"
                echo "  ANANKE_VERSION   Version to install"
                echo
                echo "Examples:"
                echo "  $0"
                echo "  $0 --prefix=/usr/local"
                echo "  $0 --version=v0.1.0"
                echo "  PREFIX=/opt/ananke $0"
                exit 0
                ;;
            *)
                echo -e "${RED}Error: Unknown option: $1${NC}"
                echo "Run '$0 --help' for usage information"
                exit 1
                ;;
        esac
    done
}

# Main installation flow
main() {
    echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Ananke Installation Script${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
    echo

    # Set trap for cleanup
    trap cleanup EXIT

    # Parse arguments
    parse_args "$@"

    # Detect platform
    detect_platform
    echo "Platform: ${PLATFORM}"
    echo "Install prefix: ${PREFIX}"
    echo

    # Run installation steps
    check_requirements
    download_ananke
    install_ananke
    verify_installation

    # Print success message
    print_success
}

# Run main function
main "$@"
