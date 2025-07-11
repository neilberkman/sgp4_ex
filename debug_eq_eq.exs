jd_ut1 = 2460384.999999894
jd_tt = jd_ut1 + 69.184 / 86400.0

# Get nutation and mean obliquity separately
{dpsi, deps} = Sgp4Ex.IAU2000ANutation.iau2000a_nutation(jd_tt)
epsilon = Sgp4Ex.IAU2000ANutation.mean_obliquity(jd_tt)

IO.puts("dpsi: #{dpsi} radians")
IO.puts("deps: #{deps} radians")  
IO.puts("epsilon: #{epsilon} radians")

# Calculate equation of equinoxes manually
eq_eq_manual = dpsi * :math.cos(epsilon)
IO.puts("Manual eq_eq: #{eq_eq_manual} radians")

# Compare with our function
eq_eq_func = Sgp4Ex.IAU2000ANutation.equation_of_equinoxes(jd_tt)
IO.puts("Function eq_eq: #{eq_eq_func} radians")

# Expected values from Skyfield
expected_dpsi = -0.00022574473900454788
expected_deps = 0.00044750161994292403
expected_epsilon = 0.40903764357780753

IO.puts("")
IO.puts("Expected dpsi: #{expected_dpsi}")
IO.puts("Expected deps: #{expected_deps}")
IO.puts("Expected epsilon: #{expected_epsilon}")

expected_eq_eq = expected_dpsi * :math.cos(expected_epsilon)
IO.puts("Expected eq_eq: #{expected_eq_eq} radians")