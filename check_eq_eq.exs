jd_ut1 = 2460384.999999894
jd_tt = jd_ut1 + 69.184 / 86400.0

# Calculate equation of equinoxes using our implementation
eq_eq_rad = Sgp4Ex.IAU2000ANutation.equation_of_equinoxes(jd_tt)

# Expected from test (converted from hours)
expected_hours = 3.879058773358244e-09
expected_rad = expected_hours * 12.0 / :math.pi()

IO.puts("Our equation of equinoxes: #{eq_eq_rad} radians")
IO.puts("Expected: #{expected_rad} radians") 
IO.puts("Difference: #{eq_eq_rad - expected_rad}")