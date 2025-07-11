#!/usr/bin/env mix run

# Test GPU performance with proper JIT warmup
IO.puts("🔥 GPU JIT WARMUP TEST")
IO.puts("=" |> String.duplicate(50))

# Force CUDA configuration
Application.put_env(:exla, :clients, cuda: [platform: :cuda])
Application.put_env(:exla, :default_client, :cuda)
Nx.default_backend(EXLA.Backend)

IO.puts("✅ Configured for CUDA")

# Create test matrices (similar to nutation operations)
matrix_a = Nx.tensor(Enum.map(1..678, fn i -> [i*1.0, i*2.0] end), type: :f64)
matrix_b = Nx.tensor(Enum.map(1..2, fn i -> Enum.map(1..100, fn j -> i*j*1.0 end) end), type: :f64)

IO.puts("Matrix A shape: #{inspect(Nx.shape(matrix_a))}")
IO.puts("Matrix B shape: #{inspect(Nx.shape(matrix_b))}")

# JIT warmup (simulate 678 nutation terms)
IO.puts("🔥 JIT WARMUP (like nutation calculation)...")
for _ <- 1..5 do
  _result = Nx.dot(matrix_a, matrix_b)
  angles = Nx.tensor(Enum.map(1..678, fn i -> i * 0.001 end), type: :f64)
  _sin_result = Nx.sin(angles)
  _cos_result = Nx.cos(angles)
end
IO.puts("✅ JIT warmup complete")

# Now measure actual performance
IO.puts("📊 MEASURING PERFORMANCE...")

times = for _ <- 1..20 do
  start_time = :os.system_time(:microsecond)
  
  # Simulate full nutation calculation
  result = Nx.dot(matrix_a, matrix_b)
  angles = Nx.tensor(Enum.map(1..678, fn i -> i * 0.001 end), type: :f64)
  sin_result = Nx.sin(angles)
  cos_result = Nx.cos(angles)
  
  # Force computation to complete
  _final = Nx.add(Nx.sum(result), Nx.sum(sin_result))
  
  end_time = :os.system_time(:microsecond)
  end_time - start_time
end

avg_time = Enum.sum(times) / length(times)
min_time = Enum.min(times)
max_time = Enum.max(times)

IO.puts("Average time: #{Float.round(avg_time, 1)}μs")
IO.puts("Minimum time: #{min_time}μs") 
IO.puts("Maximum time: #{max_time}μs")

if avg_time < 1000 do
  IO.puts("✅ GPU performance looks reasonable")
else
  IO.puts("❌ GPU performance still too slow")
end

IO.puts("🎯 Target: < 27μs to match Python")