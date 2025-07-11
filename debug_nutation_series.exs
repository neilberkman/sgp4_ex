# Debug nutation series calculation in detail
jd_ut1 = 2460384.999999894
jd_tt = jd_ut1 + 69.184 / 86400.0

# Get our nutation calculation broken down
{dpsi, deps} = Sgp4Ex.IAU2000ANutation.iau2000a_nutation(jd_tt)

IO.puts("Our nutation calculation:")
IO.puts("  dpsi: #{dpsi} radians")
IO.puts("  deps: #{deps} radians")

# Convert to microarcseconds for comparison
asec2rad = 4.84813681109535984270e-06
dpsi_microasec = dpsi / (1.0e-6 * asec2rad)
deps_microasec = deps / (1.0e-6 * asec2rad)

IO.puts("  dpsi: #{dpsi_microasec} microarcseconds")
IO.puts("  deps: #{deps_microasec} microarcseconds")

# Expected from Skyfield
expected_dpsi_microasec = -46563194.85207441
expected_deps_microasec = 92303834.93278898

IO.puts("")
IO.puts("Expected from Skyfield:")
IO.puts("  dpsi: #{expected_dpsi_microasec} microarcseconds")
IO.puts("  deps: #{expected_deps_microasec} microarcseconds")

IO.puts("")
IO.puts("Differences:")
dpsi_diff = dpsi_microasec - expected_dpsi_microasec
deps_diff = deps_microasec - expected_deps_microasec
IO.puts("  dpsi diff: #{dpsi_diff} microarcseconds")
IO.puts("  deps diff: #{deps_diff} microarcseconds")

# Estimate impact on longitude (very rough)
# dpsi directly affects longitude through equation of equinoxes
# Error in dpsi causes proportional error in longitude
epsilon = 0.4090376435778082  # mean obliquity
dpsi_error_rad = dpsi_diff * 1.0e-6 * asec2rad
eq_eq_error_rad = dpsi_error_rad * :math.cos(epsilon) / 10.0  # our /10 factor
eq_eq_error_hours = eq_eq_error_rad * 12.0 / :math.pi()
lon_error_degrees = eq_eq_error_hours * 15.0  # 1 hour = 15 degrees
lon_error_arcsec = lon_error_degrees * 3600.0

IO.puts("")
IO.puts("Estimated longitude impact from dpsi error:")
IO.puts("  dpsi error: #{dpsi_error_rad} radians")
IO.puts("  eq_eq error: #{eq_eq_error_rad} radians")
IO.puts("  longitude error: #{lon_error_degrees} degrees = #{lon_error_arcsec} arcseconds")

IO.puts("")
IO.puts("Our remaining error: 4.18 arcseconds")
IO.puts("Nutation error accounts for: #{Float.round(abs(lon_error_arcsec) / 4.18 * 100, 1)}% of remaining error")