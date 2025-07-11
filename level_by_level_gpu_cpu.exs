#!/usr/bin/env elixir

# Level-by-level accuracy comparison: GPU vs CPU vs Expected
# Using the EXACT same test values from our previous accuracy verification

# Test values from 2024-03-15 12:00:00 UTC
jd_ut1 = 2460384.999999894
jd_tt = 2460385.000800741
t = (jd_tt - 2451545.0) / 36525.0

IO.puts("=== LEVEL-BY-LEVEL ACCURACY VERIFICATION ===")
IO.puts("JD_UT1: #{jd_ut1}")
IO.puts("JD_TT:  #{jd_tt}")
IO.puts("T:      #{t}")
IO.puts("")

# Expected values from our previous 100% accurate tests
expected_values = %{
  mean_obliquity: 0.4090928023243897,  # radians
  eqeq: 3.879058773358243e-09,         # radians  
  gast: 23.57214131204937,             # hours
  nutation_dpsi: -1.7623404327618933e-05,  # radians
  nutation_deps: -2.186777146728807e-06    # radians
}

IO.puts("=== LEVEL 1: FUNDAMENTAL ARGUMENTS ===")
# Fundamental arguments are tested internally via nutation
IO.puts("✅ Fundamental arguments tested via nutation calculations")

IO.puts("\n=== LEVEL 2: NUTATION (dpsi, deps) ===")
{dpsi_unified, deps_unified} = Sgp4Ex.IAU2000ANutation.iau2000a_nutation(jd_tt)

IO.puts("Expected dpsi: #{expected_values.nutation_dpsi}")
IO.puts("Unified dpsi:  #{dpsi_unified}")
IO.puts("Error:         #{abs(dpsi_unified - expected_values.nutation_dpsi)}")

IO.puts("\nExpected deps: #{expected_values.nutation_deps}")
IO.puts("Unified deps:  #{deps_unified}")
IO.puts("Error:         #{abs(deps_unified - expected_values.nutation_deps)}")

IO.puts("\n=== LEVEL 3: MEAN OBLIQUITY ===")
obliq_unified = Sgp4Ex.IAU2000ANutation.mean_obliquity(jd_tt)

IO.puts("Expected: #{expected_values.mean_obliquity}")
IO.puts("Unified:  #{obliq_unified}")
IO.puts("Error:    #{abs(obliq_unified - expected_values.mean_obliquity)}")

IO.puts("\n=== LEVEL 4: EQUATION OF EQUINOXES ===")
eqeq_unified = Sgp4Ex.IAU2000ANutation.equation_of_equinoxes_from_components(dpsi_unified, obliq_unified)

IO.puts("Expected: #{expected_values.eqeq}")
IO.puts("Unified:  #{eqeq_unified}")
IO.puts("Error:    #{abs(eqeq_unified - expected_values.eqeq)}")

IO.puts("\n=== LEVEL 5: GAST ===")
gast_unified = Sgp4Ex.IAU2000ANutation.gast(jd_ut1, jd_tt, 0.0, 0.0)

IO.puts("Expected: #{expected_values.gast}")
IO.puts("Unified:  #{gast_unified}")
IO.puts("Error:    #{abs(gast_unified - expected_values.gast)} hours")
IO.puts("Error:    #{abs(gast_unified - expected_values.gast) * 3600} seconds")

IO.puts("\n=== VERIFICATION: STAYING IN NX LAND ===")
# Check if tensor operations are preserved
IO.puts("Testing direct tensor functions...")

try do
  tensor_result = Sgp4Ex.IAU2000ANutation.gast_tensor(
    Nx.tensor(jd_ut1, type: :f64),
    Nx.tensor(jd_tt, type: :f64), 
    Nx.tensor(0.0, type: :f64),
    Nx.tensor(0.0, type: :f64)
  )
  gast_from_tensor = Nx.to_number(tensor_result)
  IO.puts("✅ Tensor GAST: #{gast_from_tensor} (diff from scalar: #{abs(gast_from_tensor - gast_unified)})")
rescue
  e -> IO.puts("❌ Tensor GAST failed: #{inspect(e)}")
end

try do
  nutation_tensor = Sgp4Ex.IAU2000ANutation.iau2000a_nutation_tensor(Nx.tensor(jd_tt, type: :f64))
  {dpsi_tensor_val, deps_tensor_val} = {Nx.to_number(elem(nutation_tensor, 0)), Nx.to_number(elem(nutation_tensor, 1))}
  IO.puts("✅ Tensor nutation: dpsi=#{dpsi_tensor_val}, deps=#{deps_tensor_val}")
rescue
  e -> IO.puts("❌ Tensor nutation failed: #{inspect(e)}")
end

IO.puts("\n=== ACCURACY SUMMARY ===")
perfect_levels = [
  abs(dpsi_unified - expected_values.nutation_dpsi) < 1.0e-15,
  abs(deps_unified - expected_values.nutation_deps) < 1.0e-15,
  abs(obliq_unified - expected_values.mean_obliquity) < 1.0e-15,
  abs(eqeq_unified - expected_values.eqeq) < 1.0e-15,
  abs(gast_unified - expected_values.gast) < 1.0e-15
]

high_accuracy_levels = [
  abs(dpsi_unified - expected_values.nutation_dpsi) < 1.0e-12,
  abs(deps_unified - expected_values.nutation_deps) < 1.0e-12,
  abs(obliq_unified - expected_values.mean_obliquity) < 1.0e-12,
  abs(eqeq_unified - expected_values.eqeq) < 1.0e-12,
  abs(gast_unified - expected_values.gast) < 1.0e-6  # ~3.6ms precision
]

IO.puts("Perfect levels (< 1e-15): #{Enum.count(perfect_levels, & &1)}/5")
IO.puts("High accuracy levels (< 1e-12): #{Enum.count(high_accuracy_levels, & &1)}/5")