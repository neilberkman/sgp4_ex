#!/usr/bin/env elixir

# Test script to DEFINITIVELY prove GPU acceleration is working
Mix.install([
  {:nx, "~> 0.9.0"},
  {:exla, "~> 0.9.0"}
])

# Set EXLA as default backend
Nx.default_backend(EXLA.Backend)

IO.puts("\n=== GPU ACCELERATION VERIFICATION TEST ===\n")

# Test 1: Check backend detection
test_tensor = Nx.tensor([1, 2, 3])
IO.puts("1. Backend detection:")
IO.puts("   Tensor: #{inspect(test_tensor)}")

if String.contains?(inspect(test_tensor), "cuda:0") do
  IO.puts("   ✅ GPU DETECTED (cuda:0)")
else
  IO.puts("   ❌ NO GPU - Running on CPU!")
end

IO.puts("\n2. Performance comparison test:")

# Large matrix multiplication - this will show clear GPU vs CPU difference
size = 5000
IO.puts("   Creating #{size}x#{size} matrices...")

# CPU timing
cpu_start = System.monotonic_time(:millisecond)
a_cpu = Nx.random_uniform({size, size})
b_cpu = Nx.random_uniform({size, size})
cpu_create_time = System.monotonic_time(:millisecond) - cpu_start

cpu_mult_start = System.monotonic_time(:millisecond)
_c_cpu = Nx.dot(a_cpu, b_cpu)
cpu_mult_time = System.monotonic_time(:millisecond) - cpu_mult_start

IO.puts("\n   Matrix creation time: #{cpu_create_time}ms")
IO.puts("   Matrix multiplication time: #{cpu_mult_time}ms")
IO.puts("   Total time: #{cpu_create_time + cpu_mult_time}ms")

# Check if result is on GPU
result_backend = inspect(_c_cpu)
if String.contains?(result_backend, "cuda:0") do
  IO.puts("\n   🚀 RESULT IS ON GPU! Multiplication was GPU-accelerated!")
  IO.puts("   Backend: EXLA.Backend<cuda:0>")
else
  IO.puts("\n   ⚠️  Result is on CPU - GPU acceleration NOT working")
  IO.puts("   Backend: #{result_backend}")
end

IO.puts("\n3. Simple operation test:")
x = Nx.tensor([1.0, 2.0, 3.0, 4.0, 5.0])
y = Nx.tensor([6.0, 7.0, 8.0, 9.0, 10.0])

start = System.monotonic_time(:microsecond)
z = Nx.add(x, y)
time_us = System.monotonic_time(:microsecond) - start

IO.puts("   x + y = #{inspect(z)}")
IO.puts("   Time: #{time_us} microseconds")

if String.contains?(inspect(z), "cuda:0") do
  IO.puts("   ✅ Simple ops running on GPU")
else
  IO.puts("   ❌ Simple ops running on CPU")
end

IO.puts("\n=== CONCLUSION ===")
if String.contains?(inspect(test_tensor), "cuda:0") and 
   String.contains?(inspect(_c_cpu), "cuda:0") and
   String.contains?(inspect(z), "cuda:0") do
  IO.puts("✅ GPU ACCELERATION IS DEFINITELY WORKING!")
  IO.puts("   All operations are executing on cuda:0")
else
  IO.puts("❌ GPU ACCELERATION IS NOT WORKING!")
  IO.puts("   Operations are running on CPU")
end