#!/usr/bin/env mix run

# Simple GPU test - no SGP4 lib, just pure EXLA/CUDA
IO.puts("🔥 SIMPLE GPU TEST")
IO.puts("=" |> String.duplicate(50))

# Force CUDA configuration
Application.put_env(:exla, :clients, cuda: [platform: :cuda])
Application.put_env(:exla, :default_client, :cuda)
Nx.default_backend(EXLA.Backend)

IO.puts("✅ Configured for CUDA")

# Simple tensor operation
tensor = Nx.tensor([1.0, 2.0, 3.0, 4.0, 5.0], type: :f64)
IO.puts("Created tensor: #{inspect(tensor)}")

# Matrix multiplication (should use GPU)
matrix_a = Nx.tensor([[1.0, 2.0], [3.0, 4.0]], type: :f64)
matrix_b = Nx.tensor([[5.0, 6.0], [7.0, 8.0]], type: :f64)

IO.puts("Matrix A: #{inspect(matrix_a)}")
IO.puts("Matrix B: #{inspect(matrix_b)}")

# Time the operation
start_time = :os.system_time(:microsecond)
result = Nx.dot(matrix_a, matrix_b)
end_time = :os.system_time(:microsecond)

IO.puts("Result: #{inspect(result)}")
IO.puts("Time: #{end_time - start_time}μs")

# Test sin/cos operations (like nutation)
angles = Nx.tensor([0.0, 1.0, 2.0, 3.0, 4.0, 5.0], type: :f64)
IO.puts("Angles: #{inspect(angles)}")

start_time = :os.system_time(:microsecond)
sin_result = Nx.sin(angles)
cos_result = Nx.cos(angles)
end_time = :os.system_time(:microsecond)

IO.puts("Sin: #{inspect(sin_result)}")
IO.puts("Cos: #{inspect(cos_result)}")
IO.puts("Sin/Cos time: #{end_time - start_time}μs")

IO.puts("✅ GPU test complete")