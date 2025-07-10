#!/usr/bin/env mix run

IO.puts("=== Nx Backend Comparison ===")
IO.puts("Default backend: #{inspect(Nx.default_backend())}")

# Simple matrix multiplication test
size = 500

# Create test matrices (simple pattern)
matrix_data = for i <- 1..size, j <- 1..size, do: i + j * 0.1
a = Nx.tensor(matrix_data) |> Nx.reshape({size, size}) |> Nx.as_type(:f64)
b = Nx.transpose(a)  # Different matrix

IO.puts("\n--- Matrix #{size}x#{size} Performance ---")

# Warm up
_warmup = Nx.dot(a, b)

# Time Nx.BinaryBackend
{time_us, _result} = :timer.tc(fn ->
  Nx.dot(a, b)
end)

time_ms = time_us / 1000.0
operations = 2 * size * size * size
gflops = operations / (time_us / 1_000_000) / 1_000_000_000

IO.puts("Nx.BinaryBackend:")
IO.puts("  Time: #{Float.round(time_ms, 2)} ms")
IO.puts("  Performance: #{Float.round(gflops, 1)} GFLOPS")

# Compare to NumPy performance we measured
numpy_gflops = 329.5  # From earlier test
speedup_needed = numpy_gflops / gflops

IO.puts("\nComparison to NumPy Accelerate:")
IO.puts("  NumPy (Accelerate): #{numpy_gflops} GFLOPS")
IO.puts("  Nx (BinaryBackend): #{Float.round(gflops, 1)} GFLOPS")
IO.puts("  NumPy is #{Float.round(speedup_needed, 1)}x faster")

IO.puts("\n=== Explanation ===")
IO.puts("NumPy uses Apple Accelerate framework with:")
IO.puts("- Optimized BLAS/LAPACK routines")
IO.puts("- NEON/ASIMD SIMD instructions") 
IO.puts("- Possible Apple Silicon GPU compute units")
IO.puts("- Highly optimized memory layouts")
IO.puts("")
IO.puts("Nx.BinaryBackend uses:")
IO.puts("- Pure Elixir/Erlang matrix operations")
IO.puts("- No BLAS acceleration")
IO.puts("- No SIMD optimizations")
IO.puts("- BEAM memory model overhead")