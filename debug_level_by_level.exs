#!/usr/bin/env elixir

# SYSTEMATIC LEVEL-BY-LEVEL DEBUGGING
# Compare working CPU backup vs broken unified module

# Test values
jd_tt = 2460385.000800741
t = (jd_tt - 2451545.0) / 36525.0

IO.puts("=== LEVEL-BY-LEVEL DEBUGGING ===")
IO.puts("JD_TT: #{jd_tt}")
IO.puts("T: #{t}")
IO.puts("")

# Expected values (from when it was working)
expected_dpsi = -1.7623404327618933e-05
expected_deps = -2.186777146728807e-06

IO.puts("=== LEVEL 1: FUNDAMENTAL ARGUMENTS ===")
# We need to test the tensor fundamental arguments calculation
# Let's extract the first few FA values and compare

# Create a simple test tensor calculation
t_tensor = Nx.tensor(t, type: :f64)

# Test FA calculation step by step using the constants from unified module
fa0_tensor = Nx.tensor([
  3.154384999847899,
  2.357551718265301,
  1.6280158027288272,
  5.198471222772339,
  2.182438624381695
], type: :f64)

fa1_tensor = Nx.tensor([
  628_307_584_999.0,
  8_399_684.6073,
  8_433_463.1576,
  7_771_374.8964,
  -33.86238
], type: :f64)

# Just test the linear term first  
simple_fa = Nx.add(fa0_tensor, Nx.multiply(fa1_tensor, t_tensor))
IO.puts("Simple FA (first 5): #{inspect(Nx.to_list(simple_fa))}")

# Now test what the actual unified function gives us
{dpsi_unified, deps_unified} = Sgp4Ex.IAU2000ANutation.iau2000a_nutation(jd_tt)
IO.puts("")
IO.puts("=== RESULTS COMPARISON ===")
IO.puts("Expected dpsi: #{expected_dpsi}")
IO.puts("Unified dpsi:  #{dpsi_unified}")
IO.puts("Ratio:         #{dpsi_unified / expected_dpsi}")
IO.puts("")
IO.puts("Expected deps: #{expected_deps}")
IO.puts("Unified deps:  #{deps_unified}")
IO.puts("Ratio:         #{deps_unified / expected_deps}")

# The key question: Are we using the right coefficient data?
IO.puts("")
IO.puts("=== COEFFICIENT VERIFICATION ===")
lunisolar_coeffs = Sgp4Ex.IAU2000ACoefficients.lunisolar_longitude_coefficients()
IO.puts("Lunisolar coeff shape: #{inspect(Nx.shape(lunisolar_coeffs))}")
IO.puts("First few lunisolar coeffs: #{inspect(Nx.to_list(lunisolar_coeffs[0..2]))}")

lunisolar_mult = Sgp4Ex.IAU2000ACoefficients.lunisolar_arg_multipliers()
IO.puts("Lunisolar mult shape: #{inspect(Nx.shape(lunisolar_mult))}")
IO.puts("First lunisolar multiplier: #{inspect(Nx.to_list(lunisolar_mult[0]))}")