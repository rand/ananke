# Ananke Dockerfile
# Multi-stage build for constraint-driven code generation system
#
# Build stages:
#   1. Zig build environment
#   2. Rust build environment
#   3. Final runtime image with CLI binary
#
# Usage:
#   docker build -t ananke:latest .
#   docker run -v $(pwd):/workspace ananke extract /workspace/code.ts

# ============================================================================
# Stage 1: Zig Build Environment
# ============================================================================
FROM alpine:3.19 AS zig-builder

# Install Zig and build dependencies
RUN apk add --no-cache \
    curl \
    tar \
    xz \
    musl-dev \
    gcc \
    g++

# Install Zig 0.15.2
ENV ZIG_VERSION=0.15.2
RUN curl -fsSL "https://ziglang.org/download/${ZIG_VERSION}/zig-linux-x86_64-${ZIG_VERSION}.tar.xz" | tar -xJ -C /usr/local && \
    ln -s "/usr/local/zig-linux-x86_64-${ZIG_VERSION}/zig" /usr/local/bin/zig

# Set working directory
WORKDIR /build

# Copy Zig source files
COPY build.zig build.zig.zon ./
COPY src/ ./src/
COPY examples/ ./examples/

# Build Ananke binary and static library
RUN zig build -Doptimize=ReleaseSafe && \
    zig build-lib -static -O ReleaseSafe src/ffi/zig_ffi.zig -femit-bin=libananke.a

# Verify build artifacts
RUN test -f zig-out/bin/ananke && \
    test -f libananke.a && \
    echo "Zig build successful"

# ============================================================================
# Stage 2: Rust Build Environment
# ============================================================================
FROM rust:1.80-alpine3.19 AS rust-builder

# Install build dependencies
RUN apk add --no-cache \
    musl-dev \
    gcc \
    g++

# Set working directory
WORKDIR /build

# Copy Rust project files
COPY maze/Cargo.toml maze/Cargo.lock ./maze/
COPY maze/src/ ./maze/src/
COPY maze/build.rs ./maze/

# Copy Zig static library from previous stage
COPY --from=zig-builder /build/libananke.a ./

# Build Rust Maze library
RUN cd maze && \
    cargo build --release && \
    cd ..

# Verify build artifacts
RUN test -f maze/target/release/libmaze.so && \
    echo "Rust build successful"

# ============================================================================
# Stage 3: Final Runtime Image
# ============================================================================
FROM alpine:3.19

# Install runtime dependencies
RUN apk add --no-cache \
    libgcc \
    libstdc++ \
    ca-certificates

# Create non-root user for running Ananke
RUN addgroup -g 1000 ananke && \
    adduser -D -u 1000 -G ananke ananke

# Create necessary directories
RUN mkdir -p /usr/local/bin /usr/local/lib /workspace && \
    chown -R ananke:ananke /workspace

# Copy binaries and libraries from build stages
COPY --from=zig-builder /build/zig-out/bin/ananke /usr/local/bin/
COPY --from=zig-builder /build/libananke.a /usr/local/lib/
COPY --from=rust-builder /build/maze/target/release/libmaze.so /usr/local/lib/

# Ensure binary is executable
RUN chmod +x /usr/local/bin/ananke

# Set library path
ENV LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH

# Set working directory
WORKDIR /workspace

# Switch to non-root user
USER ananke

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ananke --version || exit 1

# Default command
ENTRYPOINT ["ananke"]
CMD ["help"]

# Metadata
LABEL org.opencontainers.image.title="Ananke" \
      org.opencontainers.image.description="Constraint-driven code generation with llguidance" \
      org.opencontainers.image.vendor="Ananke Project" \
      org.opencontainers.image.url="https://github.com/ananke-ai/ananke" \
      org.opencontainers.image.documentation="https://github.com/ananke-ai/ananke/blob/main/README.md" \
      org.opencontainers.image.source="https://github.com/ananke-ai/ananke" \
      org.opencontainers.image.licenses="MIT OR Apache-2.0"
