#!/usr/bin/env elixir

IO.puts("=== PROOF OF UNIFICATION ===")
IO.puts("")

# Test values
jd_ut1 = 2460384.999999894
jd_tt = 2460385.000800741

IO.puts("1. VERIFY: Only ONE IAU2000ANutation module exists")
try do
  # This should work
  result1 = Sgp4Ex.IAU2000ANutation.gast(jd_ut1, jd_tt)
  IO.puts("✅ Sgp4Ex.IAU2000ANutation.gast() works: #{result1}")
rescue
  e -> IO.puts("❌ IAU2000ANutation.gast() failed: #{inspect(e)}")
end

try do
  # This should FAIL because the GPU module is deleted
  Sgp4Ex.IAU2000ANutationGPU.gast_gpu(jd_ut1, jd_tt)
  IO.puts("❌ FAILURE: IAU2000ANutationGPU still exists!")
rescue
  UndefinedFunctionError ->
    IO.puts("✅ CONFIRMED: IAU2000ANutationGPU module deleted")
  e -> IO.puts("❌ Unexpected error: #{inspect(e)}")
end

IO.puts("")
IO.puts("2. VERIFY: Coordinate systems uses unified module")
test_teme = {-6045.0, -3490.0, 2500.0}
test_time = ~U[2024-03-15 12:00:00Z]

try do
  {:ok, result} = Sgp4Ex.CoordinateSystems.teme_to_geodetic(test_teme, test_time)
  IO.puts("✅ Coordinate transformation works: lat=#{result.latitude}, lon=#{result.longitude}")
rescue
  e -> IO.puts("❌ Coordinate transformation failed: #{inspect(e)}")
end

IO.puts("")
IO.puts("3. VERIFY: Backend detection")
backend = Nx.default_backend()
IO.puts("Current Nx backend: #{inspect(backend)}")

# Test tensor operation
test_tensor = Nx.tensor([1.0, 2.0, 3.0])
result_tensor = Nx.multiply(test_tensor, 2.0)
IO.puts("Test tensor operation: #{inspect(result_tensor)}")

IO.puts("")
IO.puts("4. VERIFY: No GPU-specific function calls in coordinate_systems.ex")
file_content = File.read!("lib/coordinate_systems.ex")
gpu_references = [
  "IAU2000ANutationGPU",
  "gast_gpu", 
  "gpu_tensor",
  "use_gpu"
]

found_gpu_refs = Enum.filter(gpu_references, fn ref -> 
  String.contains?(file_content, ref) 
end)

if found_gpu_refs == [] do
  IO.puts("✅ CONFIRMED: No GPU-specific references in coordinate_systems.ex")
else
  IO.puts("❌ FAILURE: Found GPU references: #{inspect(found_gpu_refs)}")
end

IO.puts("")
IO.puts("UNIFICATION STATUS:")
if found_gpu_refs == [] do
  IO.puts("✅ FULLY UNIFIED - One module, Nx picks backend automatically")
else
  IO.puts("❌ NOT UNIFIED - Still has separate GPU/CPU paths")
end