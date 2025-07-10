#!/bin/bash
set -e

echo "Building EXLA with custom CUDA-enabled XLA..."

# Define paths
XLA_ARCHIVE_PATH="/Users/neil/.cache/bazel/_bazel_neil/2dd497f85d22f0f3d1acf5881fc923cb/execroot/xla/bazel-out/k8-opt/bin/xla/extension/xla_extension.tar.gz"
EXLA_CACHE_DIR="deps/exla/cache"
XLA_EXTENSION_DIR="$EXLA_CACHE_DIR/xla_extension"

# Clean existing cache
echo "Cleaning existing EXLA cache..."
rm -rf $EXLA_CACHE_DIR
mkdir -p $EXLA_CACHE_DIR

# Extract our custom XLA build
echo "Extracting custom XLA build..."
tar -xzf "$XLA_ARCHIVE_PATH" -C "$EXLA_CACHE_DIR"

# Create snapshot file so EXLA thinks it's already extracted
echo "$XLA_ARCHIVE_PATH" > "$EXLA_CACHE_DIR/xla_snapshot.txt"

# Set environment variables for CUDA build
export CUDA_ENABLED=1
export NVCC=/usr/local/cuda/bin/nvcc
export CUDNN_ROOT=/usr/local/cuda
export CUDA_HOME=/usr/local/cuda
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH
export PATH=/usr/local/cuda/bin:$PATH

# Force rebuild of EXLA with CUDA support
export EXLA_FORCE_REBUILD=full

# Build EXLA
echo "Building EXLA with CUDA support..."
cd deps/exla
make clean
make -j$(nproc)

echo "Build complete!"
echo "Checking for CUDA symbols in the built library..."
nm cache/libexla.so | grep -i cuda || echo "Warning: No CUDA symbols found in libexla.so"

# Check if XLA extension has CUDA support
echo "Checking XLA extension for CUDA support..."
if [ -f cache/xla_extension/lib/libxla_extension.so ]; then
    nm cache/xla_extension/lib/libxla_extension.so | grep -i cuda | head -10 || echo "Warning: No CUDA symbols found in libxla_extension.so"
else
    echo "Warning: libxla_extension.so not found"
fi