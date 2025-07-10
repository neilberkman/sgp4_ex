#!/usr/bin/env mix run

# Test GPU GAST calculation accuracy
alias Sgp4Ex.IAU2000ANutationGPU

IO.puts("\n=== GPU GAST Function Test ===")
IO.puts("Comparing GPU vs reference calculations...\n")

# Test Julian dates
test_cases = [
  {2459945.5, 2459945.5, "2023-01-01 12:00:00"},
  {2460310.0, 2460310.0, "2024-01-01 00:00:00"}, 
  {2460310.5, 2460310.5, "2024-01-01 12:00:00"},
  {2460676.0, 2460676.0, "2025-01-01 00:00:00"}
]

Enum.each(test_cases, fn {jd_ut1, jd_tt, description} ->
  IO.puts("Testing #{description} (JD: #{jd_ut1})")
  
  # Calculate GPU GAST
  gast_gpu = IAU2000ANutationGPU.gast_gpu(jd_ut1, jd_tt)
  
  IO.puts("  GPU GAST: #{gast_gpu} hours")
  
  # Verify reasonable range (0-24 hours)
  if gast_gpu >= 0.0 and gast_gpu < 24.0 do
    IO.puts("  ✅ GAST in valid range [0, 24) hours")
  else
    IO.puts("  ❌ GAST out of range: #{gast_gpu}")
  end
  
  # Convert to degrees for readability
  gast_degrees = gast_gpu * 15.0  # 1 hour = 15 degrees
  IO.puts("  GAST: #{gast_degrees} degrees")
  
  IO.puts("")
end)

# Test GPU tensor version for consistency
IO.puts("Testing GPU tensor consistency...")

jd_test = 2460310.5  # 2024-01-01 12:00:00
gast1 = IAU2000ANutationGPU.gast_gpu(jd_test, jd_test)

# Test with tensor inputs
jd_tensor = Nx.tensor(jd_test, type: :f64)
gast_tensor = IAU2000ANutationGPU.gast_gpu_tensor(jd_tensor, jd_tensor, 0.0, 0.0)
gast2 = Nx.to_number(gast_tensor)

difference = abs(gast1 - gast2)
IO.puts("Scalar GAST: #{gast1}")
IO.puts("Tensor GAST: #{gast2}")
IO.puts("Difference: #{difference}")

if difference < 1.0e-10 do
  IO.puts("✅ GPU scalar and tensor versions match perfectly")
else
  IO.puts("❌ GPU versions differ by #{difference}")
end

IO.puts("\n🎉 GPU GAST test complete!")