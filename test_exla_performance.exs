IO.puts("=== EXLA Performance Test ===")

# Test EXLA performance with matrix multiplication
Nx.default_backend(EXLA.Backend)

# Test 500x500 matrix multiplication
size = 500
# Create random matrices using available functions
a = Nx.tensor(for _ <- 1..size, do: for _ <- 1..size, do: :rand.uniform()) |> Nx.as_type(:f32)
b = Nx.tensor(for _ <- 1..size, do: for _ <- 1..size, do: :rand.uniform()) |> Nx.as_type(:f32)

# Warmup
_ = Nx.dot(a, b)

# Benchmark
{time_us, _result} = :timer.tc(fn -> Nx.dot(a, b) end)
time_ms = time_us / 1000.0

# Calculate GFLOPS
operations = 2 * size * size * size  # matrix multiplication complexity
gflops = operations / (time_ms * 1_000_000)

IO.puts("Matrix #{size}x#{size} multiplication:")
IO.puts("  Time: #{:io_lib.format("~.2f", [time_ms])}ms")
IO.puts("  Performance: #{:io_lib.format("~.1f", [gflops])} GFLOPS")

# Compare with NumPy reference (from previous benchmark)
numpy_gflops = 329.5
ratio = gflops / numpy_gflops
IO.puts("\nComparison to NumPy Accelerate:")
IO.puts("  NumPy (Accelerate): #{numpy_gflops} GFLOPS")
IO.puts("  EXLA: #{:io_lib.format("~.1f", [gflops])} GFLOPS")
IO.puts("  Ratio: #{:io_lib.format("~.2f", [ratio])}x")

if ratio > 0.5 do
  IO.puts("✅ EXLA performance is competitive with NumPy!")
else
  IO.puts("⚠️  EXLA performance is significantly slower than NumPy")
end