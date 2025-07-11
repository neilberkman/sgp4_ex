#!/usr/bin/env elixir

# Test hypothesis: coefficients are in arcseconds, not microarcseconds

jd_tt = 2460385.000800741
expected_dpsi = -1.7623404327618933e-05

IO.puts("=== TESTING UNITS HYPOTHESIS ===")

# Get the current wrong result
{dpsi_wrong, deps_wrong} = Sgp4Ex.IAU2000ANutation.iau2000a_nutation(jd_tt)
IO.puts("Current wrong dpsi: #{dpsi_wrong}")
IO.puts("Expected dpsi:      #{expected_dpsi}")
IO.puts("Error ratio:        #{dpsi_wrong / expected_dpsi}")

# Test hypothesis: if coefficients are already in arcseconds, 
# then we shouldn't multiply by 1e-6
# So try dividing by 1e6 to undo that conversion:
dpsi_hypothesis = dpsi_wrong / 1.0e6
IO.puts("")
IO.puts("=== TESTING: Remove 1e-6 conversion ===")
IO.puts("Hypothesis dpsi: #{dpsi_hypothesis}")
IO.puts("Expected dpsi:   #{expected_dpsi}")
IO.puts("New ratio:       #{dpsi_hypothesis / expected_dpsi}")

# Another hypothesis: maybe the asec2rad constant is wrong
# Expected conversion: arcseconds to radians = value * π/180/3600
correct_asec2rad = :math.pi() / 180.0 / 3600.0
current_asec2rad = 4.848136811095359935899141e-6

IO.puts("")
IO.puts("=== TESTING: arcsec2rad constant ===")
IO.puts("Current @asec2rad: #{current_asec2rad}")
IO.puts("Correct arcsec2rad: #{correct_asec2rad}")
IO.puts("Ratio: #{current_asec2rad / correct_asec2rad}")

# Test different unit conversions
IO.puts("")
IO.puts("=== TESTING: Different unit assumptions ===")

# Assume coefficients are in 0.1 microarcseconds (common in astronomy)
dpsi_test1 = dpsi_wrong / 10.0
IO.puts("0.1 microarcsec assumption: #{dpsi_test1} (ratio: #{dpsi_test1 / expected_dpsi})")

# Assume coefficients are in arcseconds  
dpsi_test2 = dpsi_wrong / 1.0e6
IO.puts("Arcsec assumption: #{dpsi_test2} (ratio: #{dpsi_test2 / expected_dpsi})")

# Assume coefficients are in milliarcseconds
dpsi_test3 = dpsi_wrong / 1.0e3  
IO.puts("Milliarcsec assumption: #{dpsi_test3} (ratio: #{dpsi_test3 / expected_dpsi})")