#!/usr/bin/env elixir

# Demo showing what GPU acceleration WOULD look like if available
Mix.install([
  {:nx, "~> 0.9.0"},
  {:exla, "~> 0.9.0"}
])

Nx.default_backend(EXLA.Backend)

IO.puts("\n=== CPU vs GPU Acceleration Demo ===\n")

# Check current backend
test = Nx.tensor([1, 2, 3])
backend = inspect(test)

IO.puts("Current backend: #{backend}")

if String.contains?(backend, "cuda:0") do
  IO.puts("Status: 🚀 GPU ACCELERATION ACTIVE")
  IO.puts("\nWhat this means:")
  IO.puts("- All Nx operations run on NVIDIA GPU")
  IO.puts("- Matrix operations are massively parallelized")
  IO.puts("- Large operations will be 10-100x faster")
  
  IO.puts("\nExpected benchmark results with GPU:")
  IO.puts("- Matrix multiply (5000x5000): ~50-100ms")
  IO.puts("- SGP4 propagation batch (1000): ~5-10ms")
else
  IO.puts("Status: 💻 CPU ONLY (#{backend})")
  IO.puts("\nWhat this means:")
  IO.puts("- All Nx operations run on CPU")
  IO.puts("- Limited to CPU core parallelization")
  IO.puts("- No GPU acceleration benefits")
  
  IO.puts("\nExpected benchmark results on CPU:")
  IO.puts("- Matrix multiply (5000x5000): ~1000-5000ms")
  IO.puts("- SGP4 propagation batch (1000): ~500-1000ms")
end

IO.puts("\n=== Performance Test ===")

# Small matrix multiply to show timing
size = 1000
IO.puts("\nTesting #{size}x#{size} matrix multiplication...")

# Create random matrices using iota + operations to simulate random
a = Nx.divide(Nx.iota({size, size}), size)
b = Nx.divide(Nx.iota({size, size}), size)

start = System.monotonic_time(:millisecond)
c = Nx.dot(a, b)
# Force evaluation
_sum = Nx.sum(c)
elapsed = System.monotonic_time(:millisecond) - start

IO.puts("Time: #{elapsed}ms")

if String.contains?(backend, "cuda:0") do
  IO.puts("\n✅ This operation ran on GPU!")
  IO.puts("   Expected speedup: 10-50x vs CPU")
else
  IO.puts("\n⚠️  This operation ran on CPU")
  IO.puts("   To get GPU acceleration:")
  IO.puts("   1. Need NVIDIA GPU with CUDA")
  IO.puts("   2. Set EXLA_TARGET=cuda120")
  IO.puts("   3. Ensure cuDNN is properly installed")
end

IO.puts("\n=== Checking EXLA Configuration ===")
IO.puts("EXLA_TARGET env var: #{System.get_env("EXLA_TARGET") || "not set"}")
IO.puts("XLA_FLAGS env var: #{System.get_env("XLA_FLAGS") || "not set"}")

# Show how to enable GPU if available
IO.puts("\nTo enable GPU acceleration (if GPU available):")
IO.puts("export EXLA_TARGET=cuda120")
IO.puts("export XLA_FLAGS=--xla_gpu_cuda_data_dir=/usr/local/cuda")