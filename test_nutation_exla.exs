IO.puts("=== IAU 2000A Nutation Performance with EXLA ===")

# Set EXLA as default backend
Nx.default_backend(EXLA.Backend)

# Test IAU 2000A nutation calculation
alias Sgp4Ex.IAU2000ANutationGPU

# Test parameters similar to our typical usage
jd_tt = 2460000.0  # Julian date
jd_ut1 = 2460000.0

# Convert to tensors for EXLA
jd_tt_tensor = Nx.tensor(jd_tt, type: :f64)
jd_ut1_tensor = Nx.tensor(jd_ut1, type: :f64)

# Warmup
_ = IAU2000ANutationGPU.gast_gpu_tensor(jd_ut1_tensor, jd_tt_tensor, 0.0, 0.0)

# Benchmark single calculation
{time_us, _result} = :timer.tc(fn -> 
  IAU2000ANutationGPU.gast_gpu_tensor(jd_ut1_tensor, jd_tt_tensor, 0.0, 0.0)
end)

time_ms = time_us / 1000.0

IO.puts("Single IAU 2000A calculation:")
IO.puts("  Time: #{:io_lib.format("~.3f", [time_ms])}ms")

# Compare with previous benchmarks
python_time = 0.087  # Python Skyfield time
original_time = 33.0  # Our original time

speedup_vs_python = python_time / time_ms
speedup_vs_original = original_time / time_ms

IO.puts("\nComparison:")
IO.puts("  Python Skyfield: #{python_time}ms")
IO.puts("  Original Nx.BinaryBackend: #{original_time}ms")
IO.puts("  EXLA: #{:io_lib.format("~.3f", [time_ms])}ms")
IO.puts("  Speedup vs Python: #{:io_lib.format("~.1f", [speedup_vs_python])}x")
IO.puts("  Speedup vs Original: #{:io_lib.format("~.1f", [speedup_vs_original])}x")

if time_ms < python_time do
  IO.puts("✅ EXLA is faster than Python Skyfield!")
elsif time_ms < 1.0 do
  IO.puts("🟡 EXLA is competitive with Python Skyfield")
else
  IO.puts("❌ EXLA is still slower than Python Skyfield")
end

# Test batch calculations
batch_size = 100
jd_batch = Nx.tensor((for _ <- 1..batch_size, do: jd_tt + :rand.uniform() * 10), type: :f64)
jd_ut1_batch = Nx.tensor((for _ <- 1..batch_size, do: jd_ut1 + :rand.uniform() * 10), type: :f64)

# Warmup batch
_ = IAU2000ANutationGPU.gast_gpu_tensor(jd_ut1_batch, jd_batch, 0.0, 0.0)

# Benchmark batch
{batch_time_us, _batch_result} = :timer.tc(fn -> 
  IAU2000ANutationGPU.gast_gpu_tensor(jd_ut1_batch, jd_batch, 0.0, 0.0)
end)

batch_time_ms = batch_time_us / 1000.0
time_per_calculation = batch_time_ms / batch_size

IO.puts("\nBatch calculation (#{batch_size} calculations):")
IO.puts("  Total time: #{:io_lib.format("~.3f", [batch_time_ms])}ms")
IO.puts("  Time per calculation: #{:io_lib.format("~.3f", [time_per_calculation])}ms")
IO.puts("  Batch speedup: #{:io_lib.format("~.1f", [time_ms / time_per_calculation])}x")