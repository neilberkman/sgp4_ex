jd_ut1 = 2460384.999999894
jd_tt = jd_ut1 + 69.184 / 86400.0

# Calculate GAST using our implementation
gast_hours = Sgp4Ex.IAU2000ANutation.gast(jd_ut1, jd_tt)

# Expected from test
expected_gast = 23.572220420489195

IO.puts("Our GAST: #{gast_hours} hours")
IO.puts("Expected GAST: #{expected_gast} hours")
IO.puts("Difference: #{gast_hours - expected_gast} hours")

# Break down the calculation
gmst_hours = Sgp4Ex.IAU2000ANutation.gmst(jd_ut1, jd_tt)
eq_eq_rad = Sgp4Ex.IAU2000ANutation.equation_of_equinoxes(jd_tt)
eq_eq_hours = eq_eq_rad * 12.0 / :math.pi()

IO.puts("")
IO.puts("GMST: #{gmst_hours} hours")
IO.puts("Eq Eq: #{eq_eq_hours} hours")
IO.puts("GAST = GMST + Eq Eq: #{gmst_hours + eq_eq_hours} hours")

# Expected breakdown
expected_gmst = 23.572220416610136
expected_eq_eq_hours = 3.879058773358244e-09

IO.puts("")
IO.puts("Expected GMST: #{expected_gmst} hours")
IO.puts("Expected Eq Eq: #{expected_eq_eq_hours} hours")
IO.puts("Expected GAST = GMST + Eq Eq: #{expected_gmst + expected_eq_eq_hours} hours")