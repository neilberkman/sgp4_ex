#!/usr/bin/env elixir

# Simple test to check if we can detect GPU
Mix.install([
  {:nx, "~> 0.9.0"},
  {:exla, "~> 0.9.0"}
])

# Set EXLA as default backend
Nx.default_backend(EXLA.Backend)

IO.puts("\n=== SIMPLE GPU TEST ===\n")

# Test tensor creation
test = Nx.tensor([1, 2, 3, 4, 5])
IO.puts("Test tensor: #{inspect(test)}")

# Check backend
backend_str = inspect(test)
if String.contains?(backend_str, "cuda:0") do
  IO.puts("\n✅ GPU DETECTED! Running on cuda:0")
else
  IO.puts("\n❌ CPU ONLY! Running on #{backend_str}")
end

# Try a simple operation
result = Nx.add(test, 10)
IO.puts("\nAdd 10: #{inspect(result)}")

# Matrix operation
a = Nx.tensor([[1.0, 2.0], [3.0, 4.0]])
b = Nx.tensor([[5.0, 6.0], [7.0, 8.0]])
c = Nx.dot(a, b)

IO.puts("\nMatrix multiplication result: #{inspect(c)}")

if String.contains?(inspect(c), "cuda:0") do
  IO.puts("✅ Matrix ops on GPU!")
else
  IO.puts("❌ Matrix ops on CPU!")
end