# Check if we can compute nutation matrix and use element [0][1] for equation of equinoxes
jd_ut1 = 2460384.999999894
jd_tt = jd_ut1 + 69.184 / 86400.0

# Get our nutation values
{dpsi, deps} = Sgp4Ex.IAU2000ANutation.iau2000a_nutation(jd_tt)
epsilon = Sgp4Ex.IAU2000ANutation.mean_obliquity(jd_tt)

IO.puts("Our nutation values:")
IO.puts("  dpsi: #{dpsi} radians")
IO.puts("  deps: #{deps} radians")
IO.puts("  epsilon: #{epsilon} radians")

# Calculate true obliquity
true_obliquity = epsilon + deps
IO.puts("  true obliquity: #{true_obliquity} radians")

# Build nutation matrix manually
# This is approximately:
# [  1    dpsi*cos(eps)  dpsi*sin(eps) ]
# [ -dpsi*cos(eps)   1   -deps        ]
# [ -dpsi*sin(eps)  deps      1       ]

cos_eps = :math.cos(epsilon)
sin_eps = :math.sin(epsilon)

matrix_01 = dpsi * cos_eps
matrix_02 = dpsi * sin_eps
matrix_10 = -dpsi * cos_eps
matrix_12 = -deps
matrix_20 = -dpsi * sin_eps
matrix_21 = deps

IO.puts("")
IO.puts("Our nutation matrix elements:")
IO.puts("  [0][1] = dpsi*cos(eps): #{matrix_01} radians")

# Convert to hours
matrix_01_hours = matrix_01 * 12.0 / :math.pi()
IO.puts("  [0][1] in hours: #{matrix_01_hours} hours")

# Expected from Skyfield
expected_eq_eq_hours = -7.909984537946002e-05
IO.puts("")
IO.puts("Expected eq_eq: #{expected_eq_eq_hours} hours")
IO.puts("Difference: #{matrix_01_hours - expected_eq_eq_hours} hours")
IO.puts("Ratio: #{matrix_01_hours / expected_eq_eq_hours}")