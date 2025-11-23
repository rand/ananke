#!/usr/bin/env bash
# Performance Analysis Script for Ananke
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RESULTS_DIR="$PROJECT_ROOT/bench_results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "Ananke Performance Analysis"
echo "Timestamp: $(date)"
echo

mkdir -p "$RESULTS_DIR"

cd "$PROJECT_ROOT"
echo "Running Zig benchmarks..."
zig build bench-zig -Doptimize=ReleaseFast 2>&1 | tee "$RESULTS_DIR/zig_$TIMESTAMP.txt"

cd "$PROJECT_ROOT/maze"
echo "Running Rust benchmarks..."
cargo bench 2>&1 | tee "$RESULTS_DIR/rust_$TIMESTAMP.txt"

echo
echo "Results saved to $RESULTS_DIR"
